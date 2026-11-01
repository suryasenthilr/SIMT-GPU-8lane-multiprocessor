// =============================================================================
// File: axi4_master_interface.v
// Module: axi4_master_interface
// Description: AMBA AXI4 Master Burst Controller for GPU 256-bit Memory Bursts.
//              Supports 4KB boundary compliance and Warp ID transaction tracking.
// =============================================================================

`timescale 1ns / 1ps

module axi4_master_interface (
    input  wire         clk,
    input  wire         rst_n,

    // GPU Coalescer Request Interface
    input  wire         req_valid,
    input  wire [1:0]   req_warp_id,
    input  wire         req_is_write,
    input  wire [31:0]  req_addr,
    input  wire [255:0] req_wdata_line,
    output wire         req_ready,

    // GPU Memory Return Interface
    output reg          fill_valid,
    output reg  [1:0]   fill_warp_id,
    output reg  [255:0] fill_line_data,

    // AMBA AXI4 Read Channels
    output reg  [3:0]   m_axi_arid,
    output reg  [31:0]  m_axi_araddr,
    output reg  [7:0]   m_axi_arlen,   // 8 beats
    output reg  [2:0]   m_axi_arsize,  // 4 bytes per beat
    output reg  [1:0]   m_axi_arburst, // INCR (01)
    output reg          m_axi_arvalid,
    input  wire         m_axi_arready,

    input  wire [3:0]   m_axi_rid,
    input  wire [31:0]  m_axi_rdata,
    input  wire [1:0]   m_axi_rresp,
    input  wire         m_axi_rlast,
    input  wire         m_axi_rvalid,
    output wire         m_axi_rready,

    // AMBA AXI4 Write Channels
    output reg  [3:0]   m_axi_awid,
    output reg  [31:0]  m_axi_awaddr,
    output reg  [7:0]   m_axi_awlen,
    output reg  [2:0]   m_axi_awsize,
    output reg  [1:0]   m_axi_awburst,
    output reg          m_axi_awvalid,
    input  wire         m_axi_awready,

    output reg  [31:0]  m_axi_wdata,
    output reg  [3:0]   m_axi_wstrb,
    output reg          m_axi_wlast,
    output reg          m_axi_wvalid,
    input  wire         m_axi_wready,

    input  wire [3:0]   m_axi_bid,
    input  wire [1:0]   m_axi_bresp,
    input  wire         m_axi_bvalid,
    output reg          m_axi_bready
);

    localparam S_IDLE  = 3'd0;
    localparam S_RADDR = 3'd1;
    localparam S_RDATA = 3'd2;
    localparam S_WADDR = 3'd3;
    localparam S_WDATA = 3'd4;
    localparam S_WRESP = 3'd5;

    reg [2:0]   state;
    reg [2:0]   beat_cnt;
    reg [255:0] r_shift;
    reg [255:0] w_latched;

    assign req_ready    = (state == S_IDLE);
    assign m_axi_rready = (state == S_RDATA);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state          <= S_IDLE;
            m_axi_arvalid  <= 1'b0;
            m_axi_arid     <= 4'd0;
            m_axi_araddr   <= 32'd0;
            m_axi_arlen    <= 8'd7;
            m_axi_arsize   <= 3'b010;
            m_axi_arburst  <= 2'b01;
            m_axi_awvalid  <= 1'b0;
            m_axi_awid     <= 4'd0;
            m_axi_awaddr   <= 32'd0;
            m_axi_awlen    <= 8'd7;
            m_axi_awsize   <= 3'b010;
            m_axi_awburst  <= 2'b01;
            m_axi_wvalid   <= 1'b0;
            m_axi_wdata    <= 32'd0;
            m_axi_wstrb    <= 4'h0;
            m_axi_wlast    <= 1'b0;
            m_axi_bready   <= 1'b0;
            beat_cnt       <= 3'd0;
            r_shift        <= 256'd0;
            w_latched      <= 256'd0;
            fill_valid     <= 1'b0;
            fill_warp_id   <= 2'd0;
            fill_line_data <= 256'd0;
        end else begin
            fill_valid <= 1'b0;

            case (state)
                S_IDLE: begin
                    if (req_valid && !req_is_write) begin
                        m_axi_arvalid <= 1'b1;
                        m_axi_arid    <= {2'b00, req_warp_id};
                        m_axi_araddr  <= {req_addr[31:5], 5'b00000};
                        m_axi_arlen   <= 8'd7;
                        m_axi_arsize  <= 3'b010;
                        m_axi_arburst <= 2'b01;
                        state         <= S_RADDR;
                    end else if (req_valid && req_is_write) begin
                        m_axi_awvalid <= 1'b1;
                        m_axi_awid    <= {2'b00, req_warp_id};
                        m_axi_awaddr  <= {req_addr[31:5], 5'b00000};
                        m_axi_awlen   <= 8'd7;
                        m_axi_awsize  <= 3'b010;
                        m_axi_awburst <= 2'b01;
                        w_latched     <= req_wdata_line;
                        state         <= S_WADDR;
                    end
                end

                S_RADDR: begin
                    if (m_axi_arready) begin
                        m_axi_arvalid <= 1'b0;
                        beat_cnt      <= 3'd0;
                        state         <= S_RDATA;
                    end
                end

                S_RDATA: begin
                    if (m_axi_rvalid) begin
                        r_shift[beat_cnt*32 +: 32] <= m_axi_rdata;
                        beat_cnt                   <= beat_cnt + 3'd1;

                        if (m_axi_rlast || (beat_cnt == 3'd7)) begin
                            fill_valid     <= 1'b1;
                            fill_warp_id   <= m_axi_rid[1:0];
                            fill_line_data <= {m_axi_rdata, r_shift[223:0]};
                            state          <= S_IDLE;
                        end
                    end
                end

                S_WADDR: begin
                    if (m_axi_awready) begin
                        m_axi_awvalid <= 1'b0;
                        beat_cnt      <= 3'd0;
                        m_axi_wvalid  <= 1'b1;
                        m_axi_wdata   <= w_latched[31:0];
                        m_axi_wstrb   <= 4'hF;
                        m_axi_wlast   <= 1'b0;
                        state         <= S_WDATA;
                    end
                end

                S_WDATA: begin
                    if (m_axi_wready) begin
                        if (beat_cnt == 3'd7) begin
                            m_axi_wvalid <= 1'b0;
                            m_axi_wlast  <= 1'b0;
                            m_axi_bready <= 1'b1;
                            state        <= S_WRESP;
                        end else begin
                            beat_cnt    <= beat_cnt + 3'd1;
                            m_axi_wdata <= w_latched[(beat_cnt + 1)*32 +: 32];
                            m_axi_wlast <= (beat_cnt == 3'd6);
                        end
                    end
                end

                S_WRESP: begin
                    if (m_axi_bvalid) begin
                        m_axi_bready <= 1'b0;
                        state        <= S_IDLE;
                    end
                end
            endcase
        end
    end

endmodule
