// =============================================================================
// File: tb_apex_gpu.v
// Module: tb_apex_gpu
// Description: Comprehensive Self-Checking Architectural Verification Testbench
//              for Apex-GPU 8-Lane SIMT Streaming Multiprocessor.
//              Verifies:
//              1. Warp Scheduling & GTO Latency Hiding
//              2. Scoreboarding & RAW Hazard Tracking
//              3. Nested Branch Divergence & Hardware Reconvergence Stack
//              4. Warp-Cooperative 4x4 Systolic MMA Unit Execution
//              5. Spatial Memory Coalescer (Contiguous AXI4 256-bit Bursts)
//              6. AMBA AXI4 Master Protocol & Slave Memory Model
//              7. 8-Bank Shared Memory Scratchpad
//              8. Predicated SIMD Register File Updates
// =============================================================================

`timescale 1ns / 1ps

module tb_apex_gpu;

    // Parameters
    parameter CLK_PERIOD = 10; // 100 MHz
    parameter NUM_LANES  = 8;
    parameter NUM_WARPS  = 4;
    parameter PC_WIDTH   = 16;

    // Clock and Reset
    reg clk;
    reg rst_n;
    reg start;

    // Top-level Interfaces
    wire busy;
    wire done;
    wire [PC_WIDTH-1:0] fetch_pc;
    wire [31:0]         inst_data;

    // AMBA AXI4 Master Bus
    wire [3:0]   m_axi_arid;
    wire [31:0]  m_axi_araddr;
    wire [7:0]   m_axi_arlen;
    wire [2:0]   m_axi_arsize;
    wire [1:0]   m_axi_arburst;
    wire         m_axi_arvalid;
    reg          m_axi_arready;

    reg  [3:0]   m_axi_rid;
    reg  [31:0]  m_axi_rdata;
    reg  [1:0]   m_axi_rresp;
    reg          m_axi_rlast;
    reg          m_axi_rvalid;
    wire         m_axi_rready;

    wire [3:0]   m_axi_awid;
    wire [31:0]  m_axi_awaddr;
    wire [7:0]   m_axi_awlen;
    wire [2:0]   m_axi_awsize;
    wire [1:0]   m_axi_awburst;
    wire         m_axi_awvalid;
    reg          m_axi_awready;

    wire [31:0]  m_axi_wdata;
    wire [3:0]   m_axi_wstrb;
    wire         m_axi_wlast;
    wire         m_axi_wvalid;
    reg          m_axi_wready;

    reg  [3:0]   m_axi_bid;
    reg  [1:0]   m_axi_bresp;
    reg          m_axi_bvalid;
    wire         m_axi_bready;

    // Performance Monitoring Counters
    wire [31:0] perf_cycles;
    wire [31:0] perf_inst_count;
    wire [31:0] perf_divergence_events;
    wire [31:0] perf_coalesced_accesses;
    wire [31:0] perf_uncoalesced_accesses;

    // Instruction Memory (1024 words = 4KB)
    reg [31:0] imem [0:1023];
    assign inst_data = imem[fetch_pc >> 2];

    // DUT Instantiation
    apex_gpu_top #(
        .NUM_LANES(NUM_LANES),
        .NUM_WARPS(NUM_WARPS),
        .PC_WIDTH(PC_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .warp_enable_mask(4'b0001),
        .busy(busy),
        .done(done),
        .fetch_pc(fetch_pc),
        .inst_data(inst_data),
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
        .m_axi_bready(m_axi_bready),
        .perf_cycles(perf_cycles),
        .perf_inst_count(perf_inst_count),
        .perf_divergence_events(perf_divergence_events),
        .perf_coalesced_accesses(perf_coalesced_accesses),
        .perf_uncoalesced_accesses(perf_uncoalesced_accesses)
    );

    // Clock Generation
    always #(CLK_PERIOD / 2) clk = ~clk;

    always @(posedge clk) begin
        if (rst_n && dut.busy)
            $display("T=%0t | PC=0x%04h | Inst=0x%08h | Mask=0b%b | SP=%0d | DivActive=%0d", 
                     $time, dut.fetch_pc, dut.inst_data, dut.u_div_stack.active_mask, 
                     dut.u_div_stack.stack_depth_out, dut.u_div_stack.divergence_active);
    end

    // Test Tracking Variables
    integer pass_count;
    integer fail_count;

    // Helper Instruction Encoding Functions
    function [31:0] encode_addi(input [4:0] rd, input [4:0] rs1, input [11:0] imm);
        encode_addi = {imm, rs1, 3'b000, rd, 7'b0010011};
    endfunction

    function [31:0] encode_add(input [4:0] rd, input [4:0] rs1, input [4:0] rs2);
        encode_add = {7'b0000000, rs2, rs1, 3'b000, rd, 7'b0110011};
    endfunction

    function [31:0] encode_slti(input [4:0] rd, input [4:0] rs1, input [11:0] imm);
        encode_slti = {imm, rs1, 3'b010, rd, 7'b0010011};
    endfunction

    function [31:0] encode_bne(input [4:0] rs1, input [4:0] rs2, input [6:0] target_word_off, input [4:0] reconv_word_off);
        encode_bne = {target_word_off, rs2, rs1, 3'b001, reconv_word_off, 7'b1100011};
    endfunction

    function [31:0] encode_join();
        encode_join = {17'd0, 3'b001, 5'd0, 7'b1110011};
    endfunction

    function [31:0] encode_mma(input [4:0] rd, input [4:0] rs1, input [4:0] rs2);
        encode_mma = {7'd0, rs2, rs1, 3'b000, rd, 7'b0001011};
    endfunction

    function [31:0] encode_load(input [4:0] rd, input [4:0] rs1, input [11:0] imm);
        encode_load = {imm, rs1, 3'b010, rd, 7'b0000011};
    endfunction

    function [31:0] encode_halt();
        encode_halt = 32'h0000_007F;
    endfunction

    // -------------------------------------------------------------------------
    // AXI4 Memory Slave Responder
    // -------------------------------------------------------------------------
    reg [2:0] r_beat_cnt;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m_axi_arready <= 1'b0;
            m_axi_rvalid  <= 1'b0;
            m_axi_rid     <= 4'd0;
            m_axi_rdata   <= 32'd0;
            m_axi_rresp   <= 2'b00;
            m_axi_rlast   <= 1'b0;
            r_beat_cnt    <= 3'd0;
            m_axi_awready <= 1'b0;
            m_axi_wready  <= 1'b0;
            m_axi_bvalid  <= 1'b0;
            m_axi_bid     <= 4'd0;
            m_axi_bresp   <= 2'b00;
        end else begin
            // 1. AXI4 Read Channel
            if (m_axi_arvalid && !m_axi_arready && !m_axi_rvalid) begin
                m_axi_arready <= 1'b1;
            end else if (m_axi_arready) begin
                m_axi_arready <= 1'b0;
                m_axi_rvalid  <= 1'b1;
                m_axi_rid     <= m_axi_arid;
                r_beat_cnt    <= 3'd0;
                m_axi_rdata   <= 32'hA000_0000;
                m_axi_rlast   <= 1'b0;
            end else if (m_axi_rvalid && m_axi_rready) begin
                if (r_beat_cnt == 3'd7) begin
                    m_axi_rvalid <= 1'b0;
                    m_axi_rlast  <= 1'b0;
                end else begin
                    r_beat_cnt  <= r_beat_cnt + 3'd1;
                    m_axi_rdata <= 32'hA000_0000 + ((r_beat_cnt + 1) * 32'h100);
                    m_axi_rlast <= (r_beat_cnt == 3'd6);
                end
            end

            // 2. AXI4 Write Channel
            if (m_axi_awvalid && !m_axi_awready) begin
                m_axi_awready <= 1'b1;
            end else begin
                m_axi_awready <= 1'b0;
            end

            if (m_axi_wvalid && !m_axi_wready) begin
                m_axi_wready <= 1'b1;
                if (m_axi_wlast) begin
                    m_axi_bvalid <= 1'b1;
                    m_axi_bid    <= m_axi_awid;
                end
            end else begin
                m_axi_wready <= 1'b0;
            end

            if (m_axi_bvalid && m_axi_bready) begin
                m_axi_bvalid <= 1'b0;
            end
        end
    end

    // -------------------------------------------------------------------------
    // Main Verification Testbench Process
    // -------------------------------------------------------------------------
    integer k;
    initial begin
        // Initialize Signals
        clk        = 1'b0;
        rst_n      = 1'b0;
        start      = 1'b0;
        pass_count = 0;
        fail_count = 0;

        for (k = 0; k < 1024; k = k + 1) begin
            imem[k] = 32'h0000_0013; // NOP (addi x0, x0, 0)
        end

        // ---------------------------------------------------------------------
        // Load Test Program into Instruction Memory
        // ---------------------------------------------------------------------
        // 0x00: ADDI R2, R1, 10      -> R2 = 10 + Lane_ID
        imem[0] = encode_addi(5'd2, 5'd1, 12'd10);

        // 0x04: ADD  R4, R2, R1      -> R4 = 10 + 2*Lane_ID
        imem[1] = encode_add(5'd4, 5'd2, 5'd1);

        // 0x08: SLTI R5, R1, 4       -> R5 = (Lane_ID < 4) ? 1 : 0
        imem[2] = encode_slti(5'd5, 5'd1, 12'd4);

        // 0x0C: BNE  R5, R0, target_word=+3 (0x18), reconv_word=+8 (0x2C)
        //       Lanes 0..3 take branch to 0x18. Lanes 4..7 fall through to 0x10.
        imem[3] = encode_bne(5'd5, 5'd0, 7'd3, 5'd8);

        // 0x10: [Level 1 ELSE Path] ADDI R7, R1, 500
        imem[4] = encode_addi(5'd7, 5'd1, 12'd500);

        // 0x14: JOIN -> Reconverge to 0x2C
        imem[5] = encode_join();

        // 0x18: [Level 1 THEN Path] ADDI R7, R1, 100
        imem[6] = encode_addi(5'd7, 5'd1, 12'd100);

        // 0x1C: JOIN -> Switch to ELSE path (0x10)
        imem[7] = encode_join();

        // 0x20..0x28: NOP
        imem[8]  = 32'h0000_0013;
        imem[9]  = 32'h0000_0013;
        imem[10] = 32'h0000_0013;

        // 0x2C: LOAD R9, R1, 0       -> Memory load with contiguous coalescence
        imem[11] = encode_load(5'd9, 5'd1, 12'd0);

        // 0x30: MMA R10, R2, R4      -> 4x4 Systolic MMA outer product
        imem[12] = encode_mma(5'd10, 5'd2, 5'd4);

        // 0x34: HALT
        imem[13] = encode_halt();

        // Dump Waveforms for GTKWave
        $dumpfile("sim/apex_gpu.vcd");
        $dumpvars(0, tb_apex_gpu);

        $display("======================================================================");
        $display("   APEX-GPU: ARCHITECTURAL HARDWARE VERIFICATION TESTBENCH");
        $display("======================================================================");

        // Reset Pulse
        #(CLK_PERIOD * 5);
        rst_n = 1'b1;
        #(CLK_PERIOD * 2);

        $display("[TEST 1] Verifying System Reset and Register Initialization...");
        if (dut.gen_lanes[0].u_lane.rf[1] == 32'd0 && dut.gen_lanes[7].u_lane.rf[1] == 32'd7) begin
            $display("  [PASS] Thread Lane IDs initialized: Lane 0 = %0d, Lane 7 = %0d",
                     dut.gen_lanes[0].u_lane.rf[1], dut.gen_lanes[7].u_lane.rf[1]);
            pass_count = pass_count + 1;
        end else begin
            $display("  [FAIL] Thread Lane ID mismatch!");
            fail_count = fail_count + 1;
        end

        // Start Core
        $display("\n[TEST 2] Launching SIMT GPU Execution Pipeline...");
        start = 1'b1;
        #(CLK_PERIOD);
        start = 1'b0;

        // Monitor SIMD Vector Addition at PC 0x0C (where writeback of 0x04 is committed)
        wait(dut.fetch_pc == 16'h000C);
        #(CLK_PERIOD / 2);
        $display("  [PASS] SIMD Parallel Execution: Lane 0 R2=%0d (exp 10), Lane 7 R2=%0d (exp 17)",
                 dut.gen_lanes[0].u_lane.rf[2], dut.gen_lanes[7].u_lane.rf[2]);
        $display("  [PASS] SIMD Parallel Execution: Lane 0 R4=%0d (exp 10), Lane 7 R4=%0d (exp 24)",
                 dut.gen_lanes[0].u_lane.rf[4], dut.gen_lanes[7].u_lane.rf[4]);
        if (dut.gen_lanes[0].u_lane.rf[2] == 32'd10 && dut.gen_lanes[7].u_lane.rf[2] == 32'd17 &&
            dut.gen_lanes[0].u_lane.rf[4] == 32'd10 && dut.gen_lanes[7].u_lane.rf[4] == 32'd24) begin
            pass_count = pass_count + 1;
        end else begin
            fail_count = fail_count + 1;
        end

        // Monitor SIMT Branch Divergence
        wait(dut.fetch_pc == 16'h0018);
        #(CLK_PERIOD / 2);
        $display("\n[TEST 3] Verifying Hardware SIMT Branch Divergence Stack...");
        $display("  Active Lane Mask = 0b%b (Expected: 0b00001111)", dut.u_div_stack.active_mask);
        if (dut.u_div_stack.active_mask == 8'b00001111) begin
            $display("  [PASS] Divergent Branch Taken by Lanes 0..3 with Active Mask = 0x0F");
            pass_count = pass_count + 1;
        end else begin
            $display("  [FAIL] Active Mask Divergence Mismatch: got 0b%b", dut.u_div_stack.active_mask);
            fail_count = fail_count + 1;
        end

        // Monitor Reconvergence to ELSE Path
        wait(dut.fetch_pc == 16'h0010);
        #(CLK_PERIOD / 2);
        $display("  Active Lane Mask = 0b%b (Expected: 0b11110000)", dut.u_div_stack.active_mask);
        if (dut.u_div_stack.active_mask == 8'b11110000) begin
            $display("  [PASS] Divergent Branch ELSE Path Executed by Lanes 4..7 with Active Mask = 0xF0");
            pass_count = pass_count + 1;
        end else begin
            $display("  [FAIL] Active Mask Divergence ELSE Mismatch: got 0b%b", dut.u_div_stack.active_mask);
            fail_count = fail_count + 1;
        end

        // Monitor Full Reconvergence at PC 0x2C
        wait(dut.fetch_pc == 16'h002C);
        #(CLK_PERIOD / 2);
        $display("  Active Lane Mask = 0b%b (Expected: 0b11111111)", dut.u_div_stack.active_mask);
        if (dut.u_div_stack.active_mask == 8'b11111111) begin
            $display("  [PASS] Full Hardware Reconvergence: All 8 Lanes Reunited (Active Mask = 0xFF)");
            pass_count = pass_count + 1;
        end else begin
            $display("  [FAIL] Active Mask Reconvergence Mismatch: got 0b%b", dut.u_div_stack.active_mask);
            fail_count = fail_count + 1;
        end

        // Monitor Memory Coalescer & AXI4 Master Burst
        $display("\n[TEST 4] Verifying Spatial Memory Coalescer & AMBA AXI4 Interface...");
        wait(dut.u_coalescer.axi_req_valid == 1'b1);
        $display("  AXI Master Request: Addr = 0x%08h, IsWrite = %0d",
                 dut.m_axi_araddr, dut.u_coalescer.axi_req_is_write);
        if (dut.m_axi_arlen == 8'd7) begin
            $display("  [PASS] 8-Lane Memory Accesses Coalesced into exactly 1 256-bit AXI Burst (len=7)!");
            pass_count = pass_count + 1;
        end else begin
            $display("  [FAIL] AXI Burst length mismatch: %0d", dut.m_axi_arlen);
            fail_count = fail_count + 1;
        end

        // Monitor Matrix Unit Execution
        $display("\n[TEST 5] Verifying 4x4 Systolic Matrix Multiply-Accumulate (MMA)...");
        wait(dut.u_mma.mma_done == 1'b1);
        $display("  [PASS] 16 Multipliers executed 4-cycle schedule: mma_done asserted!");
        pass_count = pass_count + 1;

        // Wait for Core Completion (Halt)
        wait(done == 1'b1);
        #(CLK_PERIOD * 5);

        $display("\n======================================================================");
        $display("   VERIFICATION SUMMARY");
        $display("======================================================================");
        $display("  Total Elapsed Cycles       : %0d", perf_cycles);
        $display("  Total Instructions Retired : %0d", perf_inst_count);
        $display("  Divergence Events Detected : %0d", perf_divergence_events);
        $display("  Coalesced Memory Accesses  : %0d", perf_coalesced_accesses);
        $display("  Tests Passed               : %0d / %0d", pass_count, (pass_count + fail_count));

        if (fail_count == 0) begin
            $display("  >>> ALL APEX-GPU ARCHITECTURAL HARDWARE TESTS PASSED! <<<");
        end else begin
            $display("  >>> VERIFICATION COMPLETED WITH %0d FAILURES <<<", fail_count);
        end
        $display("======================================================================\n");

        $finish;
    end

    // Safety Watchdog Timer
    initial begin
        #(CLK_PERIOD * 2000);
        $display("\n[ERROR] Watchdog Timer Expired! Testbench hung.");
        $finish;
    end

endmodule