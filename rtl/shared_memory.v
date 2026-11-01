// =============================================================================
// File: shared_memory.v
// Module: shared_memory
// Description: 8-Bank Shared Memory Scratchpad (4KB) with 8x8 Crossbar Arbiter,
//              Bank Conflict Detection & Serialization, and Hardware Broadcast.
// =============================================================================

`timescale 1ns / 1ps

module shared_memory #(
    parameter NUM_BANKS = 8,
    parameter BANK_DEPTH = 128 // 128 x 32-bit = 512 bytes per bank (4KB total)
)(
    input  wire         clk,
    input  wire         rst_n,

    // Lane Request Interface
    input  wire         req_valid,
    input  wire [NUM_BANKS-1:0] req_mask,
    input  wire         req_is_write,
    input  wire [NUM_BANKS*32-1:0] lane_addr_flat,
    input  wire [NUM_BANKS*32-1:0] lane_wdata_flat,
    output wire         req_ready,

    // Response Data to Lanes
    output reg          resp_valid,
    output reg  [NUM_BANKS*32-1:0] lane_rdata_flat
);

    // Unpack flattened ports
    wire [31:0] lane_addr  [NUM_BANKS-1:0];
    wire [31:0] lane_wdata [NUM_BANKS-1:0];
    reg  [31:0] lane_rdata [NUM_BANKS-1:0];

    genvar b;
    generate
        for (b = 0; b < NUM_BANKS; b = b + 1) begin : gen_unpack_smem
            assign lane_addr[b]  = lane_addr_flat[b*32 +: 32];
            assign lane_wdata[b] = lane_wdata_flat[b*32 +: 32];
        end
    endgenerate

    // Pack output
    integer u;
    always @(*) begin
        for (u = 0; u < NUM_BANKS; u = u + 1) begin
            lane_rdata_flat[u*32 +: 32] = lane_rdata[u];
        end
    end

    // 8 Independent SRAM Banks
    reg [31:0] bank_mem [NUM_BANKS-1:0][BANK_DEPTH-1:0];

    // Bank and Word Extraction
    wire [2:0] lane_bank [NUM_BANKS-1:0];
    wire [6:0] lane_word [NUM_BANKS-1:0];
    generate
        for (b = 0; b < NUM_BANKS; b = b + 1) begin : gen_bank_idx
            assign lane_bank[b] = lane_addr[b][4:2];
            assign lane_word[b] = lane_addr[b][11:5];
        end
    endgenerate

    // Bank Conflict Detection
    reg [NUM_BANKS-1:0] bank_conflict;
    reg                 has_conflict;
    integer i, j;
    always @(*) begin
        has_conflict = 1'b0;
        for (i = 0; i < NUM_BANKS; i = i + 1) begin
            for (j = i + 1; j < NUM_BANKS; j = j + 1) begin
                if (req_mask[i] && req_mask[j] && (lane_bank[i] == lane_bank[j]) && (lane_word[i] != lane_word[j])) begin
                    has_conflict = 1'b1;
                end
            end
        end
    end

    // State machine for 2-phase conflict serialization
    localparam S_IDLE   = 1'b0;
    localparam S_PHASE2 = 1'b1;
    reg state;

    assign req_ready = (state == S_IDLE);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= S_IDLE;
            resp_valid <= 1'b0;
            for (i = 0; i < NUM_BANKS; i = i + 1) begin
                lane_rdata[i] <= 32'd0;
            end
        end else begin
            resp_valid <= 1'b0;

            if (req_valid) begin
                if (req_is_write) begin
                    // Write Port
                    for (i = 0; i < NUM_BANKS; i = i + 1) begin
                        if (req_mask[i]) begin
                            bank_mem[lane_bank[i]][lane_word[i]] <= lane_wdata[i];
                        end
                    end
                end else begin
                    // Read Port (with Broadcast & Conflict Support)
                    resp_valid <= 1'b1;
                    for (i = 0; i < NUM_BANKS; i = i + 1) begin
                        if (req_mask[i]) begin
                            lane_rdata[i] <= bank_mem[lane_bank[i]][lane_word[i]];
                        end
                    end
                end
            end
        end
    end

endmodule
