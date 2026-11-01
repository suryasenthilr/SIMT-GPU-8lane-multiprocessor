// =============================================================================
// File: simt_divergence_stack.v
// Module: simt_divergence_stack
// Description: Hardware SIMT Branch Divergence & Reconvergence Stack.
//              Supports up to 8 levels of nested branches across 8 thread lanes.
// =============================================================================

`timescale 1ns / 1ps

module simt_divergence_stack #(
    parameter NUM_LANES   = 8,
    parameter STACK_DEPTH = 8,
    parameter PC_WIDTH    = 16
)(
    input  wire                  clk,
    input  wire                  rst_n,

    // Instruction Interface
    input  wire                  is_branch,
    input  wire                  is_join,
    input  wire [PC_WIDTH-1:0]   current_pc,
    input  wire [PC_WIDTH-1:0]   branch_target_pc,
    input  wire [PC_WIDTH-1:0]   reconverge_pc,
    input  wire [NUM_LANES-1:0]  thread_cond_vec,

    // Active Mask & Next PC Output
    output reg  [NUM_LANES-1:0]  active_mask,
    output reg  [PC_WIDTH-1:0]   next_pc,
    output wire                  divergence_active,
    output wire [2:0]            stack_depth_out
);

    // Stack Entry Structure:
    // [0]: Reconverge PC
    // [1]: Alternate (Else) PC
    // [2]: Alternate Mask
    // [3]: State (0: Executing THEN path, 1: Executing ELSE path)
    reg [PC_WIDTH-1:0]   stack_reconv_pc [STACK_DEPTH-1:0];
    reg [PC_WIDTH-1:0]   stack_else_pc   [STACK_DEPTH-1:0];
    reg [NUM_LANES-1:0]  stack_else_mask [STACK_DEPTH-1:0];
    reg [NUM_LANES-1:0]  stack_orig_mask [STACK_DEPTH-1:0];
    reg                  stack_state     [STACK_DEPTH-1:0];
    reg [2:0]            sp; // Stack Pointer (0 to 7)

    assign divergence_active = (sp != 3'd0);
    assign stack_depth_out   = sp;

    wire [NUM_LANES-1:0] taken_mask     = active_mask & thread_cond_vec;
    wire [NUM_LANES-1:0] not_taken_mask = active_mask & (~thread_cond_vec);

    wire is_divergent = is_branch && (taken_mask != {NUM_LANES{1'b0}}) && (not_taken_mask != {NUM_LANES{1'b0}});
    wire is_all_taken = is_branch && (taken_mask == active_mask);
    wire is_all_not_taken = is_branch && (taken_mask == {NUM_LANES{1'b0}});

    // Combinational Next-PC Generation
    always @(*) begin
        if (is_branch) begin
            if (is_divergent || is_all_taken) begin
                next_pc = branch_target_pc;
            end else begin
                next_pc = current_pc + 16'd4;
            end
        end else if (is_join && (sp > 3'd0)) begin
            if (stack_state[sp - 1] == 1'b0) begin
                next_pc = stack_else_pc[sp - 1];
            end else begin
                next_pc = stack_reconv_pc[sp - 1];
            end
        end else begin
            next_pc = current_pc + 16'd4;
        end
    end

    integer i;

    // Sequential SIMT Stack and Active Mask Management
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            active_mask <= {NUM_LANES{1'b1}}; // All lanes active on reset
            sp          <= 3'd0;
            for (i = 0; i < STACK_DEPTH; i = i + 1) begin
                stack_reconv_pc[i] <= {PC_WIDTH{1'b0}};
                stack_else_pc[i]   <= {PC_WIDTH{1'b0}};
                stack_else_mask[i] <= {NUM_LANES{1'b0}};
                stack_orig_mask[i] <= {NUM_LANES{1'b0}};
                stack_state[i]     <= 1'b0;
            end
        end else begin
            // 1. Branch Evaluation
            if (is_branch) begin
                if (is_divergent && (sp < STACK_DEPTH - 1)) begin
                    // Push Divergence Context
                    stack_reconv_pc[sp] <= reconverge_pc;
                    stack_else_pc[sp]   <= current_pc + 16'd4; // fallthrough
                    stack_else_mask[sp] <= not_taken_mask;
                    stack_orig_mask[sp] <= active_mask; // Save caller's active mask
                    stack_state[sp]     <= 1'b0; // currently in THEN phase
                    sp                  <= sp + 3'd1;

                    // Execute THEN branch
                    active_mask         <= taken_mask;
                end
            end
            // 2. Reconvergence / Join Event
            else if (is_join && (sp > 3'd0)) begin
                // Check top of stack
                if (stack_state[sp - 1] == 1'b0) begin
                    // Finished THEN phase, now transition to ELSE phase!
                    active_mask         <= stack_else_mask[sp - 1];
                    stack_state[sp - 1] <= 1'b1; // Mark in ELSE phase
                end else begin
                    // Finished BOTH phases! Full Reconvergence.
                    active_mask <= stack_orig_mask[sp - 1];
                    sp          <= sp - 3'd1;
                end
            end
        end
    end

endmodule
