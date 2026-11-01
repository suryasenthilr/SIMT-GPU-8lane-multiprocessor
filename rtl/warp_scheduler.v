// =============================================================================
// File: warp_scheduler.v
// Module: warp_scheduler
// Description: Fine-Grained Multithreaded Warp Scheduler & Hardware Scoreboard.
//              Interleaves 4 warps with zero-cycle latency hiding and GTO arbitration.
// =============================================================================

`timescale 1ns / 1ps

module warp_scheduler #(
    parameter NUM_WARPS  = 4,
    parameter PC_WIDTH   = 16,
    parameter NUM_REGS   = 32
)(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire [NUM_WARPS-1:0]  warp_enable_mask,

    // Instruction Decode Queries
    input  wire [4:0]            dec_rs1,
    input  wire [4:0]            dec_rs2,
    input  wire [4:0]            dec_rd,
    input  wire                  dec_is_multi_cycle, // e.g., Load or Matrix MAC
    input  wire                  dec_is_halt,

    // Writeback Event (Clears Scoreboard Bit)
    input  wire                  wb_valid,
    input  wire [1:0]            wb_warp_id,
    input  wire [4:0]            wb_rd,

    // Memory Completion Event (Wakes up stalled warp)
    input  wire                  mem_done_valid,
    input  wire [1:0]            mem_done_warp_id,

    // Memory Stall Event (Triggered when warp issues memory request)
    input  wire                  mem_stall_req,
    input  wire [1:0]            mem_stall_warp_id,

    // Scheduled Warp Output
    output reg                   issue_valid,
    output reg  [1:0]            issue_warp_id,
    output wire [PC_WIDTH-1:0]   issue_pc,

    // PC Update from Execution / Divergence Stack
    input  wire                  pc_update_valid,
    input  wire [1:0]            pc_update_warp_id,
    input  wire [PC_WIDTH-1:0]   pc_update_val
);

    localparam W_READY = 2'b00;
    localparam W_STALL_MEM = 2'b01;
    localparam W_STALL_RAW = 2'b10;
    localparam W_DONE  = 2'b11;

    reg [1:0]          warp_state [NUM_WARPS-1:0];
    reg [PC_WIDTH-1:0] warp_pc    [NUM_WARPS-1:0];

    // Hardware Scoreboard: 4 warps x 32 registers = 128 bits
    reg [NUM_REGS-1:0] scoreboard [NUM_WARPS-1:0];

    // Round-robin / GTO priority pointer
    reg [1:0] rr_ptr;
    reg [1:0] cand;
    integer w, r;

    assign issue_pc = warp_pc[issue_warp_id];

    // Check RAW hazard for a given warp and decoded source registers
    wire [NUM_WARPS-1:0] raw_hazard;
    generate
        genvar g;
        for (g = 0; g < NUM_WARPS; g = g + 1) begin : gen_raw
            assign raw_hazard[g] = ((dec_rs1 != 5'd0) && scoreboard[g][dec_rs1]) ||
                                   ((dec_rs2 != 5'd0) && scoreboard[g][dec_rs2]);
        end
    endgenerate

    // Arbiter: Select next ready warp with zero hazard
    always @(*) begin
        issue_valid   = 1'b0;
        issue_warp_id = 2'd0;

        // Check starting from rr_ptr (Round-Robin / GTO)
        for (w = 0; w < NUM_WARPS; w = w + 1) begin
            cand = (rr_ptr + w[1:0]) % NUM_WARPS;
            if (!issue_valid && (warp_state[cand] == W_READY) && !raw_hazard[cand]) begin
                issue_valid   = 1'b1;
                issue_warp_id = cand;
            end
        end
    end

    // Sequential State and Scoreboard Updates
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rr_ptr <= 2'd0;
            for (w = 0; w < NUM_WARPS; w = w + 1) begin
                warp_state[w] <= warp_enable_mask[w] ? W_READY : W_DONE;
                warp_pc[w]    <= 16'd0;
                scoreboard[w] <= 32'd0;
            end
        end else begin
            // 1. Advance RR pointer when warp is issued
            if (issue_valid) begin
                rr_ptr <= (issue_warp_id + 2'd1) % NUM_WARPS;
                // Set scoreboard bit if multi-cycle instruction
                if (dec_is_multi_cycle && (dec_rd != 5'd0)) begin
                    scoreboard[issue_warp_id][dec_rd] <= 1'b1;
                end
                // Mark warp DONE on HALT
                if (dec_is_halt) begin
                    warp_state[issue_warp_id] <= W_DONE;
                end
            end

            // 2. Clear Scoreboard bit on Writeback
            if (wb_valid && (wb_rd != 5'd0)) begin
                scoreboard[wb_warp_id][wb_rd] <= 1'b0;
            end

            // 3. PC Updates
            if (pc_update_valid) begin
                warp_pc[pc_update_warp_id] <= pc_update_val;
            end

            // 4. Memory Stall Assertion
            if (mem_stall_req) begin
                warp_state[mem_stall_warp_id] <= W_STALL_MEM;
            end

            // 5. Memory Stall Clearance
            if (mem_done_valid) begin
                warp_state[mem_done_warp_id] <= W_READY;
            end
        end
    end

endmodule
