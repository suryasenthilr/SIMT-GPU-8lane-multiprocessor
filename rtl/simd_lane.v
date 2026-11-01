// =============================================================================
// File: simd_lane.v
// Module: simd_lane
// Description: Individual 32-bit SIMD Execution Lane with 128-word Register File
//              (4 Warps x 32 Registers) and Predicated Writeback.
// =============================================================================

`timescale 1ns / 1ps

module simd_lane #(
    parameter LANE_ID = 0
)(
    input  wire         clk,
    input  wire         rst_n,

    // Execution Control
    input  wire         lane_active,
    input  wire [1:0]   warp_id,
    input  wire         alu_wb_en,
    input  wire [3:0]   alu_op,
    input  wire [4:0]   rs1,
    input  wire [4:0]   rs2,
    input  wire [4:0]   rd,
    input  wire [31:0]  imm_val,
    input  wire         use_imm,

    // ALU Results & Flags
    output reg  [31:0]  alu_out,
    output wire         cond_flag,

    // Direct Writeback Port (for Loads or External Writeback)
    input  wire         ext_wb_valid,
    input  wire [1:0]   ext_wb_warp,
    input  wire [4:0]   ext_wb_rd,
    input  wire [31:0]  ext_wb_data
);

    // Register File: 4 Warps x 32 Registers = 128 x 32-bit
    reg [31:0] rf [127:0];

    wire [6:0] rs1_addr = {warp_id, rs1};
    wire [6:0] rs2_addr = {warp_id, rs2};
    wire [6:0] rd_addr  = {warp_id, rd};

    // Read Operands (R0 is hardwired 0)
    wire [31:0] op1 = (rs1 == 5'd0) ? 32'd0 : rf[rs1_addr];
    wire [31:0] op2 = use_imm ? imm_val : ((rs2 == 5'd0) ? 32'd0 : rf[rs2_addr]);

    // ALU Operations
    localparam ALU_ADD = 4'd0;
    localparam ALU_SUB = 4'd1;
    localparam ALU_AND = 4'd2;
    localparam ALU_OR  = 4'd3;
    localparam ALU_XOR = 4'd4;
    localparam ALU_SLL = 4'd5;
    localparam ALU_SRL = 4'd6;
    localparam ALU_SRA = 4'd7;
    localparam ALU_SLT = 4'd8;
    localparam ALU_EQ  = 4'd9;
    localparam ALU_NE  = 4'd10;
    localparam ALU_MUL = 4'd11;

    always @(*) begin
        case (alu_op)
            ALU_ADD: alu_out = op1 + op2;
            ALU_SUB: alu_out = op1 - op2;
            ALU_AND: alu_out = op1 & op2;
            ALU_OR:  alu_out = op1 | op2;
            ALU_XOR: alu_out = op1 ^ op2;
            ALU_SLL: alu_out = op1 << op2[4:0];
            ALU_SRL: alu_out = op1 >> op2[4:0];
            ALU_SRA: alu_out = $signed(op1) >>> op2[4:0];
            ALU_SLT: alu_out = ($signed(op1) < $signed(op2)) ? 32'd1 : 32'd0;
            ALU_EQ:  alu_out = (op1 == op2) ? 32'd1 : 32'd0;
            ALU_NE:  alu_out = (op1 != op2) ? 32'd1 : 32'd0;
            ALU_MUL: alu_out = op1 * op2;
            default: alu_out = 32'd0;
        endcase
    end

    // Condition Flag for Branch Evaluation
    assign cond_flag = (alu_out != 32'd0);

    // Synchronous Predicated Register File Writeback
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize R1 with Thread/Lane ID across all 4 warps
            rf[{2'd0, 5'd1}] <= LANE_ID;
            rf[{2'd1, 5'd1}] <= LANE_ID;
            rf[{2'd2, 5'd1}] <= LANE_ID;
            rf[{2'd3, 5'd1}] <= LANE_ID;
        end else begin
            // 1. External Writeback (Memory load or matrix result)
            if (ext_wb_valid && lane_active && (ext_wb_rd != 5'd0)) begin
                rf[{ext_wb_warp, ext_wb_rd}] <= ext_wb_data;
            end
            // 2. Direct ALU Writeback
            else if (alu_wb_en && lane_active && (rd != 5'd0) && (alu_op != ALU_EQ) && (alu_op != ALU_NE)) begin
                rf[rd_addr] <= alu_out;
            end
        end
    end

endmodule
