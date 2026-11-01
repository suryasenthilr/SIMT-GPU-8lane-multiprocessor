// =============================================================================
// File: memory_coalescer.v
// Module: memory_coalescer
// Description: 2-Pass Spatial Memory Coalescer for 8-Lane SIMT GPU.
//              Detects cache-line alignment, merges contiguous requests into single
//              256-bit AXI4 bursts, and safely serializes divergent/strided accesses.
// =============================================================================

`timescale 1ns / 1ps

module memory_coalescer #(
    parameter NUM_LANES = 8
)(
    input  wire                  clk,
    input  wire                  rst_n,

    // Lane Request Interface
    input  wire                  req_valid,
    input  wire [1:0]            req_warp_id,
    input  wire                  req_is_write,
    input  wire [NUM_LANES-1:0]  req_active_mask,
    input  wire [NUM_LANES*32-1:0] lane_addr_flat,
    input  wire [NUM_LANES*32-1:0] lane_wdata_flat,
    output wire                  req_ready,

    // AXI4 Burst Interface
    output reg                   axi_req_valid,
    output reg  [1:0]            axi_req_warp_id,
    output reg                   axi_req_is_write,
    output reg  [31:0]           axi_req_base_addr,
    output reg  [255:0]          axi_req_wdata_line,
    input  wire                  axi_req_ready,

    // Memory Return Interface (Data from AXI Line Fill)
    input  wire                  mem_fill_valid,
    input  wire [1:0]            mem_fill_warp_id,
    input  wire [255:0]          mem_fill_line,

    // De-Coalesced Data Forwarding to Lanes
    output reg                   lane_resp_valid,
    output reg  [1:0]            lane_resp_warp_id,
    output reg  [NUM_LANES*32-1:0] lane_rdata_flat
);

    // Unpack flattened ports
    wire [31:0] lane_addr  [NUM_LANES-1:0];
    wire [31:0] lane_wdata [NUM_LANES-1:0];
    reg  [31:0] lane_rdata [NUM_LANES-1:0];

    genvar l;
    generate
        for (l = 0; l < NUM_LANES; l = l + 1) begin : gen_unpack_lanes
            assign lane_addr[l]  = lane_addr_flat[l*32 +: 32];
            assign lane_wdata[l] = lane_wdata_flat[l*32 +: 32];
        end
    endgenerate

    // Pack output vector
    integer u;
    always @(*) begin
        for (u = 0; u < NUM_LANES; u = u + 1) begin
            lane_rdata_flat[u*32 +: 32] = lane_rdata[u];
        end
    end

    // Cache-line Tag (Upper 27 bits of 32-bit address)
    wire [26:0] lane_tag [NUM_LANES-1:0];
    generate
        for (l = 0; l < NUM_LANES; l = l + 1) begin : gen_tags
            assign lane_tag[l] = lane_addr[l][31:5];
        end
    endgenerate

    // Check if all active lanes share the same line tag as the first active lane
    reg [2:0] first_active_idx;
    reg       found_first;
    integer k;
    always @(*) begin
        first_active_idx = 3'd0;
        found_first      = 1'b0;
        for (k = 0; k < NUM_LANES; k = k + 1) begin
            if (!found_first && req_active_mask[k]) begin
                first_active_idx = k[2:0];
                found_first      = 1'b1;
            end
        end
    end

    wire [26:0] primary_tag = lane_tag[first_active_idx];
    wire [NUM_LANES-1:0] tag_match_vec;
    generate
        for (l = 0; l < NUM_LANES; l = l + 1) begin : gen_match
            assign tag_match_vec[l] = req_active_mask[l] && (lane_tag[l] == primary_tag);
        end
    endgenerate

    wire is_fully_coalesced = (tag_match_vec == req_active_mask);

    // State Machine & Latched Registers
    localparam S_IDLE       = 2'd0;
    localparam S_COALESCED  = 2'd1;
    localparam S_SERIALIZE  = 2'd2;

    reg [1:0]           state;
    reg [NUM_LANES-1:0] pending_mask;
    reg [1:0]           active_warp;
    reg                 active_is_write;
    reg [31:0]          saved_addr  [NUM_LANES-1:0];
    reg [31:0]          saved_wdata [NUM_LANES-1:0];

    assign req_ready = (state == S_IDLE);

    // Pending lane extraction for serialization
    reg [2:0] next_pending_idx;
    reg       found_pending;
    integer p;
    always @(*) begin
        next_pending_idx = 3'd0;
        found_pending    = 1'b0;
        for (p = 0; p < NUM_LANES; p = p + 1) begin
            if (!found_pending && pending_mask[p]) begin
                next_pending_idx = p[2:0];
                found_pending    = 1'b1;
            end
        end
    end

    wire [26:0] pending_tag = saved_addr[next_pending_idx][31:5];
    wire [NUM_LANES-1:0] pending_match_vec;
    generate
        for (l = 0; l < NUM_LANES; l = l + 1) begin : gen_pending_match
            assign pending_match_vec[l] = pending_mask[l] && (saved_addr[l][31:5] == pending_tag);
        end
    endgenerate

    // Pack 256-bit write line from lane write data
    reg [255:0] packed_write_line;
    always @(*) begin
        packed_write_line = 256'd0;
        for (k = 0; k < NUM_LANES; k = k + 1) begin
            if (req_active_mask[k] && (lane_tag[k] == primary_tag)) begin
                packed_write_line[lane_addr[k][4:2]*32 +: 32] = lane_wdata[k];
            end
        end
    end

    reg [255:0] pending_write_line;
    always @(*) begin
        pending_write_line = 256'd0;
        for (p = 0; p < NUM_LANES; p = p + 1) begin
            if (pending_mask[p] && (saved_addr[p][31:5] == pending_tag)) begin
                pending_write_line[saved_addr[p][4:2]*32 +: 32] = saved_wdata[p];
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state              <= S_IDLE;
            axi_req_valid      <= 1'b0;
            axi_req_warp_id    <= 2'd0;
            axi_req_is_write   <= 1'b0;
            axi_req_base_addr  <= 32'd0;
            axi_req_wdata_line <= 256'd0;
            pending_mask       <= {NUM_LANES{1'b0}};
            lane_resp_valid    <= 1'b0;
            lane_resp_warp_id  <= 2'd0;
            for (k = 0; k < NUM_LANES; k = k + 1) begin
                saved_addr[k]  <= 32'd0;
                saved_wdata[k] <= 32'd0;
                lane_rdata[k]  <= 32'd0;
            end
        end else begin
            lane_resp_valid <= 1'b0;

            case (state)
                S_IDLE: begin
                    if (req_valid) begin
                        active_warp     <= req_warp_id;
                        active_is_write <= req_is_write;
                        for (k = 0; k < NUM_LANES; k = k + 1) begin
                            saved_addr[k]  <= lane_addr[k];
                            saved_wdata[k] <= lane_wdata[k];
                        end

                        // Case 1: Fully Coalesced
                        if (is_fully_coalesced) begin
                            axi_req_valid      <= 1'b1;
                            axi_req_warp_id    <= req_warp_id;
                            axi_req_is_write   <= req_is_write;
                            axi_req_base_addr  <= {primary_tag, 5'b00000};
                            axi_req_wdata_line <= packed_write_line;
                            state              <= S_COALESCED;
                        end
                        // Case 2: Strided/Scattered (Serialize remaining)
                        else begin
                            axi_req_valid      <= 1'b1;
                            axi_req_warp_id    <= req_warp_id;
                            axi_req_is_write   <= req_is_write;
                            axi_req_base_addr  <= {primary_tag, 5'b00000};
                            axi_req_wdata_line <= packed_write_line;
                            pending_mask       <= req_active_mask & (~tag_match_vec);
                            state              <= S_SERIALIZE;
                        end
                    end
                end

                S_COALESCED: begin
                    if (axi_req_ready) begin
                        axi_req_valid <= 1'b0;
                        state         <= S_IDLE;
                    end
                end

                S_SERIALIZE: begin
                    if (axi_req_ready) begin
                        // Check if more pending requests remain
                        if (pending_mask == {NUM_LANES{1'b0}}) begin
                            axi_req_valid <= 1'b0;
                            state         <= S_IDLE;
                        end else begin
                            // Issue next unique tag
                            axi_req_valid      <= 1'b1;
                            axi_req_warp_id    <= active_warp;
                            axi_req_is_write   <= active_is_write;
                            axi_req_base_addr  <= {pending_tag, 5'b00000};
                            axi_req_wdata_line <= pending_write_line;
                            pending_mask       <= pending_mask & (~pending_match_vec);
                        end
                    end
                end
            endcase

            // Handle Memory Fill Reception & Route to Lanes
            if (mem_fill_valid) begin
                lane_resp_valid   <= 1'b1;
                lane_resp_warp_id <= mem_fill_warp_id;
                for (k = 0; k < NUM_LANES; k = k + 1) begin
                    lane_rdata[k] <= mem_fill_line[saved_addr[k][4:2]*32 +: 32];
                end
            end
        end
    end

endmodule
