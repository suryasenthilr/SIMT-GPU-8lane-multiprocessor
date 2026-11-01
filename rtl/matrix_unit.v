// =============================================================================
// File: matrix_unit.v
// Module: matrix_unit
// Description: Physical 4x4 Warp-Cooperative Matrix Multiply-Accumulate (MMA) Engine.
//              Contains 16 physical multipliers & 16 accumulators computing
//              64 operations across a 4-cycle pipelined systolic schedule (16 MACs/cycle).
// =============================================================================

`timescale 1ns / 1ps

module matrix_unit (
    input  wire         clk,
    input  wire         rst_n,

    // Instruction Trigger
    input  wire         mma_valid,
    input  wire [1:0]   mma_warp_id,
    input  wire [4:0]   mma_dest_reg,
    output wire         mma_ready,

    // Flattened 4x4 Matrix Operands A and B (16 elements each, 8-bit integers)
    input  wire [127:0] mat_a_flat, // 16 x 8-bit
    input  wire [127:0] mat_b_flat, // 16 x 8-bit
    input  wire [511:0] mat_c_flat, // 16 x 32-bit accumulators

    // Matrix Output D = A * B + C (16 x 32-bit elements)
    output reg          mma_done,
    output reg  [1:0]   mma_done_warp_id,
    output reg  [4:0]   mma_done_dest_reg,
    output reg  [511:0] mat_d_flat
);

    // 16 Accumulators for the 4x4 Result Matrix
    reg [31:0]  acc [3:0][3:0];
    reg [1:0]   step_cnt;
    reg         busy;
    reg [1:0]   latched_warp;
    reg [4:0]   latched_dest;
    reg [127:0] reg_a_flat;
    reg [127:0] reg_b_flat;

    assign mma_ready = !busy;

    // Unpack Inputs into 2D Arrays from latched registers
    wire signed [7:0] a [3:0][3:0];
    wire signed [7:0] b [3:0][3:0];

    genvar r, c;
    generate
        for (r = 0; r < 4; r = r + 1) begin : gen_row
            for (c = 0; c < 4; c = c + 1) begin : gen_col
                assign a[r][c] = reg_a_flat[(r*4 + c)*8 +: 8];
                assign b[r][c] = reg_b_flat[(r*4 + c)*8 +: 8];
            end
        end
    endgenerate

    // 16 Physical Parallel Multipliers computing outer products per cycle
    wire signed [15:0] prod [3:0][3:0];
    generate
        for (r = 0; r < 4; r = r + 1) begin : gen_mult_r
            for (c = 0; c < 4; c = c + 1) begin : gen_mult_c
                // At step_cnt = k, prod[r][c] = A[r][k] * B[k][c]
                assign prod[r][c] = a[r][step_cnt] * b[step_cnt][c];
            end
        end
    endgenerate

    integer i, j;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy              <= 1'b0;
            step_cnt          <= 2'd0;
            mma_done          <= 1'b0;
            mma_done_warp_id  <= 2'd0;
            mma_done_dest_reg <= 5'd0;
            mat_d_flat        <= 512'd0;
            reg_a_flat        <= 128'd0;
            reg_b_flat        <= 128'd0;
            for (i = 0; i < 4; i = i + 1) begin
                for (j = 0; j < 4; j = j + 1) begin
                    acc[i][j] <= 32'd0;
                end
            end
        end else begin
            mma_done <= 1'b0;

            if (mma_valid && !busy) begin
                busy              <= 1'b1;
                step_cnt          <= 2'd0;
                latched_warp      <= mma_warp_id;
                latched_dest      <= mma_dest_reg;
                reg_a_flat        <= mat_a_flat;
                reg_b_flat        <= mat_b_flat;

                // Load initial C matrix into accumulators
                for (i = 0; i < 4; i = i + 1) begin
                    for (j = 0; j < 4; j = j + 1) begin
                        acc[i][j] <= mat_c_flat[(i*4 + j)*32 +: 32];
                    end
                end
            end else if (busy) begin
                step_cnt <= step_cnt + 2'd1;

                if (step_cnt == 2'd3) begin
                    // Step 3 is the final outer product (k=3)
                    busy              <= 1'b0;
                    mma_done          <= 1'b1;
                    mma_done_warp_id  <= latched_warp;
                    mma_done_dest_reg <= latched_dest;

                    // Final accumulation & output packaging
                    for (i = 0; i < 4; i = i + 1) begin
                        for (j = 0; j < 4; j = j + 1) begin
                            mat_d_flat[(i*4 + j)*32 +: 32] <= acc[i][j] + {{16{prod[i][j][15]}}, prod[i][j]};
                        end
                    end
                end else begin
                    // Steps 0, 1, 2: Accumulate outer products
                    for (i = 0; i < 4; i = i + 1) begin
                        for (j = 0; j < 4; j = j + 1) begin
                            acc[i][j] <= acc[i][j] + {{16{prod[i][j][15]}}, prod[i][j]};
                        end
                    end
                end
            end
        end
    end

endmodule
