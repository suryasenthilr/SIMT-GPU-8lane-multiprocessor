// =============================================================================
// File: apex_gpu_top.v
// Module: apex_gpu_top
// Description: Top-Level Synthesizable 8-Lane SIMT GPU Streaming Multiprocessor (SM).
//              Integrates Warp Scheduler, 8-Entry SIMT Divergence Stack, 8 SIMD Lanes,
//              4x4 Matrix Unit (MMA), Memory Coalescer, Shared Memory, and AMBA AXI4.
// =============================================================================

`timescale 1ns / 1ps

module apex_gpu_top #(
    parameter NUM_LANES = 8,
    parameter NUM_WARPS = 4,
    parameter PC_WIDTH  = 16
)(
    input  wire         clk,
    input  wire         rst_n,

    // Host Control & Program Counter Load
    input  wire         start,
    input  wire [NUM_WARPS-1:0] warp_enable_mask,
    output wire         busy,
    output reg          done,

    // Instruction Memory Interface (Fetch)
    output wire [PC_WIDTH-1:0] fetch_pc,
    input  wire [31:0]         inst_data,

    // AMBA AXI4 Master Global Memory Interface
    output wire [3:0]   m_axi_arid,
    output wire [31:0]  m_axi_araddr,
    output wire [7:0]   m_axi_arlen,
    output wire [2:0]   m_axi_arsize,
    output wire [1:0]   m_axi_arburst,
    output wire         m_axi_arvalid,
    input  wire         m_axi_arready,

    input  wire [3:0]   m_axi_rid,
    input  wire [31:0]  m_axi_rdata,
    input  wire [1:0]   m_axi_rresp,
    input  wire         m_axi_rlast,
    input  wire         m_axi_rvalid,
    output wire         m_axi_rready,

    output wire [3:0]   m_axi_awid,
    output wire [31:0]  m_axi_awaddr,
    output wire [7:0]   m_axi_awlen,
    output wire [2:0]   m_axi_awsize,
    output wire [1:0]   m_axi_awburst,
    output wire         m_axi_awvalid,
    input  wire         m_axi_awready,

    output wire [31:0]  m_axi_wdata,
    output wire [3:0]   m_axi_wstrb,
    output wire         m_axi_wlast,
    output wire         m_axi_wvalid,
    input  wire         m_axi_wready,

    input  wire [3:0]   m_axi_bid,
    input  wire [1:0]   m_axi_bresp,
    input  wire         m_axi_bvalid,
    output wire         m_axi_bready,

    // Performance Monitoring Outputs
    output reg  [31:0]  perf_cycles,
    output reg  [31:0]  perf_inst_count,
    output reg  [31:0]  perf_divergence_events,
    output reg  [31:0]  perf_coalesced_accesses,
    output reg  [31:0]  perf_uncoalesced_accesses
);

    // Decoded Instruction Fields
    wire [6:0] opcode   = inst_data[6:0];
    wire [4:0] dec_rd   = inst_data[11:7];
    wire [2:0] funct3   = inst_data[14:12];
    wire [4:0] dec_rs1  = inst_data[19:15];
    wire [4:0] dec_rs2  = inst_data[24:20];
    wire [6:0] funct7   = inst_data[31:25];
    wire [31:0] imm_i   = {{20{inst_data[31]}}, inst_data[31:20]};

    // Instruction Types
    wire is_alu_op     = (opcode == 7'b0110011);
    wire is_imm_op     = (opcode == 7'b0010011);
    wire is_branch_op  = (opcode == 7'b1100011);
    wire is_join_op    = (opcode == 7'b1110011 && funct3 == 3'b001); // Custom JOIN marker
    wire is_load_op    = (opcode == 7'b0000011);
    wire is_store_op   = (opcode == 7'b0100011);
    wire is_mma_op     = (opcode == 7'b0001011); // Custom MMA Matrix Multiply
    wire is_halt_op    = (opcode == 7'b1111111);

    // ALU Op Mapping
    reg [3:0] alu_op;
    always @(*) begin
        if (is_alu_op) begin
            case (funct3)
                3'b000: alu_op = funct7[5] ? 4'd1 : 4'd0; // SUB : ADD
                3'b001: alu_op = 4'd5; // SLL
                3'b010: alu_op = 4'd8; // SLT
                3'b100: alu_op = 4'd4; // XOR
                3'b101: alu_op = funct7[5] ? 4'd7 : 4'd6; // SRA : SRL
                3'b110: alu_op = 4'd3; // OR
                3'b111: alu_op = 4'd2; // AND
                default: alu_op = 4'd0;
            endcase
        end else if (is_imm_op) begin
            case (funct3)
                3'b000: alu_op = 4'd0; // ADDI
                3'b001: alu_op = 4'd5; // SLLI
                3'b010: alu_op = 4'd8; // SLTI
                3'b100: alu_op = 4'd4; // XORI
                3'b101: alu_op = funct7[5] ? 4'd7 : 4'd6; // SRAI : SRLI
                3'b110: alu_op = 4'd3; // ORI
                3'b111: alu_op = 4'd2; // ANDI
                default: alu_op = 4'd0;
            endcase
        end else if (is_branch_op) begin
            case (funct3)
                3'b000: alu_op = 4'd9;  // BEQ
                3'b001: alu_op = 4'd10; // BNE
                3'b100: alu_op = 4'd8;  // BLT
                default: alu_op = 4'd9;
            endcase
        end else begin
            alu_op = 4'd0;
        end
    end

    // Submodule Interconnect Wires
    wire                   sched_issue_valid;
    wire [1:0]             sched_issue_warp;
    wire [PC_WIDTH-1:0]    sched_issue_pc;
    assign fetch_pc = sched_issue_pc;

    wire [NUM_LANES-1:0]   div_active_mask;
    wire [PC_WIDTH-1:0]    div_next_pc;
    wire                   div_active;
    wire [NUM_LANES-1:0]   thread_cond_vec;

    wire [31:0]            lane_alu_out [NUM_LANES-1:0];
    wire                   lane_cond    [NUM_LANES-1:0];

    genvar l;
    generate
        for (l = 0; l < NUM_LANES; l = l + 1) begin : gen_cond
            assign thread_cond_vec[l] = lane_cond[l];
        end
    endgenerate

    // Memory Coalescing Wires
    wire [31:0] lane_mem_addr [NUM_LANES-1:0];
    wire [31:0] coalescer_lane_rdata [NUM_LANES-1:0];
    wire [31:0] smem_rdata [NUM_LANES-1:0];
    wire [NUM_LANES*32-1:0] lane_mem_addr_flat;
    wire [NUM_LANES*32-1:0] lane_alu_out_flat;
    wire [NUM_LANES*32-1:0] coalescer_lane_rdata_flat;
    wire [NUM_LANES*32-1:0] smem_rdata_flat;

    generate
        for (l = 0; l < NUM_LANES; l = l + 1) begin : gen_addr
            assign lane_mem_addr[l] = lane_alu_out[l];
            assign lane_mem_addr_flat[l*32 +: 32] = lane_mem_addr[l];
            assign lane_alu_out_flat[l*32 +: 32]  = lane_alu_out[l];
            assign coalescer_lane_rdata[l]        = coalescer_lane_rdata_flat[l*32 +: 32];
            assign smem_rdata[l]                  = smem_rdata_flat[l*32 +: 32];
        end
    endgenerate

    wire        coalescer_req_ready;
    wire        coalescer_axi_valid;
    wire [1:0]  coalescer_axi_warp;
    wire        coalescer_axi_write;
    wire [31:0] coalescer_axi_addr;
    wire [255:0]coalescer_axi_wdata;
    wire        coalescer_lane_resp_valid;
    wire [1:0]  coalescer_lane_resp_warp;

    wire        axi_fill_valid;
    wire [1:0]  axi_fill_warp;
    wire [255:0]axi_fill_data;
    wire        axi_req_ready;

    // Matrix Unit Wires
    wire        mma_ready;
    wire        mma_done;
    wire [1:0]  mma_done_warp;
    wire [4:0]  mma_done_dest;
    wire [511:0]mma_d_flat;

    // Shared Memory Wires
    wire        smem_ready;
    wire        smem_resp_valid;

    // Core Running State
    reg running;
    assign busy = running;

    // 1. Warp Scheduler Instance
    warp_scheduler #(
        .NUM_WARPS(NUM_WARPS),
        .PC_WIDTH(PC_WIDTH)
    ) u_sched (
        .clk(clk),
        .rst_n(rst_n),
        .warp_enable_mask(warp_enable_mask),
        .dec_rs1(dec_rs1),
        .dec_rs2(dec_rs2),
        .dec_rd(dec_rd),
        .dec_is_multi_cycle(is_load_op || is_mma_op),
        .dec_is_halt(is_halt_op),
        .wb_valid(coalescer_lane_resp_valid || mma_done),
        .wb_warp_id(coalescer_lane_resp_valid ? coalescer_lane_resp_warp : mma_done_warp),
        .wb_rd(mma_done ? mma_done_dest : dec_rd),
        .mem_done_valid(coalescer_lane_resp_valid),
        .mem_done_warp_id(coalescer_lane_resp_warp),
        .mem_stall_req(sched_issue_valid && (is_load_op || is_store_op)),
        .mem_stall_warp_id(sched_issue_warp),
        .issue_valid(sched_issue_valid),
        .issue_warp_id(sched_issue_warp),
        .issue_pc(sched_issue_pc),
        .pc_update_valid(sched_issue_valid),
        .pc_update_warp_id(sched_issue_warp),
        .pc_update_val(div_next_pc)
    );

    // 2. SIMT Branch Divergence Stack
    wire [PC_WIDTH-1:0] branch_target_pc = sched_issue_pc + {{7{funct7[6]}}, funct7, 2'b00};
    wire [PC_WIDTH-1:0] reconv_target_pc = (dec_rd != 5'd0) ? 
                                           (sched_issue_pc + {9'd0, dec_rd, 2'b00}) : 
                                           (sched_issue_pc + 16'd8);

    simt_divergence_stack #(
        .NUM_LANES(NUM_LANES),
        .STACK_DEPTH(8),
        .PC_WIDTH(PC_WIDTH)
    ) u_div_stack (
        .clk(clk),
        .rst_n(rst_n),
        .is_branch(sched_issue_valid && is_branch_op),
        .is_join(sched_issue_valid && is_join_op),
        .current_pc(sched_issue_pc),
        .branch_target_pc(branch_target_pc),
        .reconverge_pc(reconv_target_pc),
        .thread_cond_vec(thread_cond_vec),
        .active_mask(div_active_mask),
        .next_pc(div_next_pc),
        .divergence_active(div_active),
        .stack_depth_out()
    );

    // 3. 8 Parallel SIMD Execution Lanes
    generate
        for (l = 0; l < NUM_LANES; l = l + 1) begin : gen_lanes
            simd_lane #(
                .LANE_ID(l)
            ) u_lane (
                .clk(clk),
                .rst_n(rst_n),
                .lane_active(div_active_mask[l]),
                .warp_id(sched_issue_warp),
                .alu_wb_en(sched_issue_valid && (is_alu_op || is_imm_op)),
                .alu_op(alu_op),
                .rs1(dec_rs1),
                .rs2(dec_rs2),
                .rd(dec_rd),
                .imm_val(imm_i),
                .use_imm(is_imm_op),
                .alu_out(lane_alu_out[l]),
                .cond_flag(lane_cond[l]),
                .ext_wb_valid(coalescer_lane_resp_valid),
                .ext_wb_warp(coalescer_lane_resp_warp),
                .ext_wb_rd(dec_rd),
                .ext_wb_data(coalescer_lane_rdata[l])
            );
        end
    endgenerate

    // 4. Warp-Cooperative 4x4 Matrix Unit
    matrix_unit u_mma (
        .clk(clk),
        .rst_n(rst_n),
        .mma_valid(sched_issue_valid && is_mma_op),
        .mma_warp_id(sched_issue_warp),
        .mma_dest_reg(dec_rd),
        .mma_ready(mma_ready),
        .mat_a_flat({lane_alu_out[3][15:0], lane_alu_out[2][15:0], lane_alu_out[1][15:0], lane_alu_out[0][15:0],
                     lane_alu_out[7][15:0], lane_alu_out[6][15:0], lane_alu_out[5][15:0], lane_alu_out[4][15:0]}),
        .mat_b_flat({lane_alu_out[7][15:0], lane_alu_out[6][15:0], lane_alu_out[5][15:0], lane_alu_out[4][15:0],
                     lane_alu_out[3][15:0], lane_alu_out[2][15:0], lane_alu_out[1][15:0], lane_alu_out[0][15:0]}),
        .mat_c_flat(512'd0),
        .mma_done(mma_done),
        .mma_done_warp_id(mma_done_warp),
        .mma_done_dest_reg(mma_done_dest),
        .mat_d_flat(mma_d_flat)
    );

    // 5. Memory Coalescing Unit
    memory_coalescer #(
        .NUM_LANES(NUM_LANES)
    ) u_coalescer (
        .clk(clk),
        .rst_n(rst_n),
        .req_valid(sched_issue_valid && (is_load_op || is_store_op)),
        .req_warp_id(sched_issue_warp),
        .req_is_write(is_store_op),
        .req_active_mask(div_active_mask),
        .lane_addr_flat(lane_mem_addr_flat),
        .lane_wdata_flat(lane_alu_out_flat),
        .req_ready(coalescer_req_ready),
        .axi_req_valid(coalescer_axi_valid),
        .axi_req_warp_id(coalescer_axi_warp),
        .axi_req_is_write(coalescer_axi_write),
        .axi_req_base_addr(coalescer_axi_addr),
        .axi_req_wdata_line(coalescer_axi_wdata),
        .axi_req_ready(axi_req_ready),
        .mem_fill_valid(axi_fill_valid),
        .mem_fill_warp_id(axi_fill_warp),
        .mem_fill_line(axi_fill_data),
        .lane_resp_valid(coalescer_lane_resp_valid),
        .lane_resp_warp_id(coalescer_lane_resp_warp),
        .lane_rdata_flat(coalescer_lane_rdata_flat)
    );

    // 6. 8-Bank Shared Memory Scratchpad
    shared_memory #(
        .NUM_BANKS(NUM_LANES)
    ) u_smem (
        .clk(clk),
        .rst_n(rst_n),
        .req_valid(sched_issue_valid && (opcode == 7'b1101011)), // Custom SMEM opcode
        .req_mask(div_active_mask),
        .req_is_write(funct3[0]),
        .lane_addr_flat(lane_mem_addr_flat),
        .lane_wdata_flat(lane_alu_out_flat),
        .req_ready(smem_ready),
        .resp_valid(smem_resp_valid),
        .lane_rdata_flat(smem_rdata_flat)
    );

    // 7. AMBA AXI4 Master Controller
    axi4_master_interface u_axi_master (
        .clk(clk),
        .rst_n(rst_n),
        .req_valid(coalescer_axi_valid),
        .req_warp_id(coalescer_axi_warp),
        .req_is_write(coalescer_axi_write),
        .req_addr(coalescer_axi_addr),
        .req_wdata_line(coalescer_axi_wdata),
        .req_ready(axi_req_ready),
        .fill_valid(axi_fill_valid),
        .fill_warp_id(axi_fill_warp),
        .fill_line_data(axi_fill_data),
        .m_axi_arid(m_axi_arid),
        .m_axi_araddr(m_axi_araddr),
        .m_axi_arlen(m_axi_arlen),
        .m_axi_arsize(m_axi_arsize),
        .m_axi_arburst(m_axi_arburst),
        .m_axi_arvalid(m_axi_arvalid),
        .m_axi_arready(m_axi_arready),
        .m_axi_rid(m_axi_rid),
        .m_axi_rdata(m_axi_rdata),
        .m_axi_rresp(m_axi_rresp),
        .m_axi_rlast(m_axi_rlast),
        .m_axi_rvalid(m_axi_rvalid),
        .m_axi_rready(m_axi_rready),
        .m_axi_awid(m_axi_awid),
        .m_axi_awaddr(m_axi_awaddr),
        .m_axi_awlen(m_axi_awlen),
        .m_axi_awsize(m_axi_awsize),
        .m_axi_awburst(m_axi_awburst),
        .m_axi_awvalid(m_axi_awvalid),
        .m_axi_awready(m_axi_awready),
        .m_axi_wdata(m_axi_wdata),
        .m_axi_wstrb(m_axi_wstrb),
        .m_axi_wlast(m_axi_wlast),
        .m_axi_wvalid(m_axi_wvalid),
        .m_axi_wready(m_axi_wready),
        .m_axi_bid(m_axi_bid),
        .m_axi_bresp(m_axi_bresp),
        .m_axi_bvalid(m_axi_bvalid),
        .m_axi_bready(m_axi_bready)
    );

    // Performance Counters & Top State
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            running                     <= 1'b0;
            done                        <= 1'b0;
            perf_cycles                 <= 32'd0;
            perf_inst_count             <= 32'd0;
            perf_divergence_events      <= 32'd0;
            perf_coalesced_accesses     <= 32'd0;
            perf_uncoalesced_accesses   <= 32'd0;
        end else begin
            if (start) begin
                running <= 1'b1;
                done    <= 1'b0;
            end else if (running) begin
                perf_cycles <= perf_cycles + 32'd1;

                if (sched_issue_valid) begin
                    perf_inst_count <= perf_inst_count + 32'd1;

                    if (is_branch_op && u_div_stack.is_divergent) begin
                        perf_divergence_events <= perf_divergence_events + 32'd1;
                    end

                    if (is_load_op || is_store_op) begin
                        perf_coalesced_accesses <= perf_coalesced_accesses + 32'd1;
                    end

                    if (is_halt_op) begin
                        running <= 1'b0;
                        done    <= 1'b1;
                    end
                end
            end
        end
    end

endmodule
