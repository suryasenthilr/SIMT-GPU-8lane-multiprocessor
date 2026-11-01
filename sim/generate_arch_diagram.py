"""
Apex-GPU Visuals Generator: Architectural Block Diagram
Renders the complete 8-Lane SIMT GPU Streaming Multiprocessor (SM) Microarchitecture
"""

import matplotlib.pyplot as plt
import matplotlib.patches as patches
import os

OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "..", "docs", "images")
os.makedirs(OUTPUT_DIR, exist_ok=True)

def generate_arch_diagram():
    fig = plt.figure(figsize=(18, 11), dpi=300)
    fig.patch.set_facecolor('#0b0f19')
    ax = fig.add_subplot(111)
    ax.set_facecolor('#0b0f19')
    ax.set_xlim(0, 100)
    ax.set_ylim(0, 100)
    ax.axis('off')

    # Title & Subtitle
    ax.text(50, 97.5, "Apex-GPU: Synthesizable 8-Lane SIMT Streaming Multiprocessor (SM)",
            ha='center', va='center', fontsize=20, fontweight='bold', color='#58a6ff')
    ax.text(50, 94.5, "Hardware SIMT Divergence Stack | Fine-Grained Multithreading | 4x4 Systolic MMA | 8-Bank Scratchpad | AMBA AXI4",
            ha='center', va='center', fontsize=11, color='#8b949e')

    # Core Outer Bounding Box
    core_box = patches.FancyBboxPatch((3, 4), 94, 87, boxstyle="round,pad=1.2,rounding_size=1.5",
                                     facecolor='#111625', edgecolor='#30363d', linewidth=2)
    ax.add_patch(core_box)
    ax.text(5, 89.5, "APEX-GPU TOP CORE (apex_gpu_top)", fontsize=11, fontweight='bold', color='#79c0ff')

    # ---------------------------------------------------------
    # 1. TOP ROW: FRONTEND & SCHEDULING (y: 72 to 87)
    # ---------------------------------------------------------
    # Instruction Fetch / Decoder
    box_if = patches.FancyBboxPatch((6, 74), 23, 13, boxstyle="round,pad=0.8,rounding_size=1.0",
                                   facecolor='#1a2236', edgecolor='#58a6ff', linewidth=1.8)
    ax.add_patch(box_if)
    ax.text(17.5, 84, "INSTRUCTION FRONTEND", ha='center', va='center', fontsize=10.5, fontweight='bold', color='#58a6ff')
    ax.text(17.5, 80, "• 32-bit Custom RV32I+SIMT\n• Warp PC Tracking (x4)\n• Zero-Cycle Fast Decode", 
            ha='center', va='center', fontsize=8.5, color='#c9d1d9')

    # Warp Scheduler & GTO Arbiter
    box_sched = patches.FancyBboxPatch((32, 74), 31, 13, boxstyle="round,pad=0.8,rounding_size=1.0",
                                      facecolor='#1a2236', edgecolor='#3fb950', linewidth=1.8)
    ax.add_patch(box_sched)
    ax.text(47.5, 84, "WARP SCHEDULER & GTO ARBITER", ha='center', va='center', fontsize=10.5, fontweight='bold', color='#3fb950')
    ax.text(47.5, 80, "• 4 Concurrent Active Warps (W0..W3)\n• Greedy-Then-Oldest (GTO) Latency Hiding\n• Dynamic Round-Robin Core Arbitration", 
            ha='center', va='center', fontsize=8.5, color='#c9d1d9')

    # 128-Bit Hardware Scoreboard
    box_scb = patches.FancyBboxPatch((66, 74), 28, 13, boxstyle="round,pad=0.8,rounding_size=1.0",
                                    facecolor='#1a2236', edgecolor='#d29922', linewidth=1.8)
    ax.add_patch(box_scb)
    ax.text(80, 84, "128-BIT SCOREBOARD MATRIX", ha='center', va='center', fontsize=10.5, fontweight='bold', color='#d29922')
    ax.text(80, 80, "• 4 Warps × 32 Arch Registers\n• Multi-Cycle RAW Hazard Tracking\n• Eliminates False Intra-Warp Stalls", 
            ha='center', va='center', fontsize=8.5, color='#c9d1d9')

    # ---------------------------------------------------------
    # 2. MIDDLE ROW: SIMT DIVERGENCE & SIMD LANES (y: 35 to 68)
    # ---------------------------------------------------------
    # SIMT Divergence Stack (Left panel)
    box_div = patches.FancyBboxPatch((6, 38), 24, 30, boxstyle="round,pad=0.8,rounding_size=1.0",
                                    facecolor='#1e192e', edgecolor='#bc8cff', linewidth=1.8)
    ax.add_patch(box_div)
    ax.text(18, 65, "HARDWARE SIMT STACK", ha='center', va='center', fontsize=10.5, fontweight='bold', color='#bc8cff')
    ax.text(18, 62, "(simt_divergence_stack.v)", ha='center', va='center', fontsize=8, color='#8b949e')

    stack_y = 57
    for lvl in range(4):
        s_rect = patches.Rectangle((8, stack_y), 20, 3.2, facecolor='#2a2140', edgecolor='#bc8cff', linewidth=0.8)
        ax.add_patch(s_rect)
        label = "Stack Top [SP]" if lvl == 0 else f"Nest Level {3-lvl}"
        ax.text(18, stack_y + 1.6, f"{label}: PC, Mask, OrigMask", ha='center', va='center', fontsize=7.5, color='#e2d9f3')
        stack_y -= 4.2

    ax.text(18, 41, "• 8-Entry HW Divergence Stack\n• Bit-Exact IPDOM Reconvergence\n• Combinational Next-PC Evaluation", 
            ha='center', va='center', fontsize=8, color='#c9d1d9')

    # 8 SIMD Execution Lanes (Center-Right container)
    box_lanes = patches.FancyBboxPatch((33, 38), 61, 30, boxstyle="round,pad=0.8,rounding_size=1.0",
                                      facecolor='#161b26', edgecolor='#58a6ff', linewidth=1.8)
    ax.add_patch(box_lanes)
    ax.text(63.5, 65.5, "8 PARALLEL SIMD EXECUTION LANES (simd_lane.v × 8)", ha='center', va='center',
            fontsize=11, fontweight='bold', color='#58a6ff')
    ax.text(63.5, 62.5, "Active Mask Control [7:0] Restricts Register File Writeback to Predicated Active Lanes",
            ha='center', va='center', fontsize=8, color='#8b949e')

    # Draw 8 individual lanes
    lane_w = 6.8
    lane_gap = 0.7
    start_x = 34.5
    for l in range(8):
        lx = start_x + l * (lane_w + lane_gap)
        l_box = patches.FancyBboxPatch((lx, 40), lane_w, 20.5, boxstyle="round,pad=0.4,rounding_size=0.6",
                                      facecolor='#1f2638', edgecolor='#388bfd', linewidth=1.2)
        ax.add_patch(l_box)
        ax.text(lx + lane_w/2, 58.5, f"Lane {l}", ha='center', va='center', fontsize=9, fontweight='bold', color='#79c0ff')
        
        # 32-bit ALU box
        alu_box = patches.Rectangle((lx + 0.4, 49.5), lane_w - 0.8, 6.5, facecolor='#27334d', edgecolor='#58a6ff', linewidth=0.8)
        ax.add_patch(alu_box)
        ax.text(lx + lane_w/2, 53.5, "32-bit\nALU", ha='center', va='center', fontsize=7.5, fontweight='bold', color='#f0f6fc')
        ax.text(lx + lane_w/2, 50.5, "+,-,&,|,<<,*", ha='center', va='center', fontsize=6.5, color='#8b949e')

        # 128-word RF box
        rf_box = patches.Rectangle((lx + 0.4, 41), lane_w - 0.8, 7.5, facecolor='#21262d', edgecolor='#8b949e', linewidth=0.8)
        ax.add_patch(rf_box)
        ax.text(lx + lane_w/2, 45.8, "128-Word\nReg File", ha='center', va='center', fontsize=7.5, fontweight='bold', color='#c9d1d9')
        ax.text(lx + lane_w/2, 42.5, "4W × 32 Regs", ha='center', va='center', fontsize=6.5, color='#8b949e')

    # ---------------------------------------------------------
    # 3. BOTTOM ROW: ACCELERATION & MEMORY SUBSYSTEMS (y: 7 to 32)
    # ---------------------------------------------------------
    # 4x4 Systolic MMA Engine
    box_mma = patches.FancyBboxPatch((6, 9), 27, 23, boxstyle="round,pad=0.8,rounding_size=1.0",
                                    facecolor='#261b23', edgecolor='#f778ba', linewidth=1.8)
    ax.add_patch(box_mma)
    ax.text(19.5, 29, "4x4 SYSTOLIC MMA ENGINE", ha='center', va='center', fontsize=10.5, fontweight='bold', color='#f778ba')
    ax.text(19.5, 26, "(matrix_unit.v)", ha='center', va='center', fontsize=8, color='#8b949e')
    ax.text(19.5, 18, "• 16 Physical DSP Multipliers\n• 16 Accumulators (32-bit)\n• 4-Cycle Systolic Schedule (k=0..3)\n• 16 MACs/Cycle Sustained Rate\n• Computes D = A × B + C", 
            ha='center', va='center', fontsize=8.2, color='#c9d1d9')

    # 8-Bank Shared Memory Scratchpad
    box_smem = patches.FancyBboxPatch((36, 9), 27, 23, boxstyle="round,pad=0.8,rounding_size=1.0",
                                     facecolor='#1b2621', edgecolor='#3fb950', linewidth=1.8)
    ax.add_patch(box_smem)
    ax.text(49.5, 29, "8-BANK SHARED MEMORY (4KB)", ha='center', va='center', fontsize=10.5, fontweight='bold', color='#3fb950')
    ax.text(49.5, 26, "(shared_memory.v)", ha='center', va='center', fontsize=8, color='#8b949e')
    ax.text(49.5, 18, "• 8 Independent Banks (512B/Bank)\n• 8×8 Crossbar Interconnect\n• Bank Conflict Detection Unit\n• 2-Phase Conflict Serialization\n• Hardware Broadcast Support", 
            ha='center', va='center', fontsize=8.2, color='#c9d1d9')

    # Spatial Memory Coalescer & AXI4 Master
    box_coal = patches.FancyBboxPatch((66, 9), 28, 23, boxstyle="round,pad=0.8,rounding_size=1.0",
                                     facecolor='#26201b', edgecolor='#d29922', linewidth=1.8)
    ax.add_patch(box_coal)
    ax.text(80, 29, "SPATIAL MEMORY COALESCER", ha='center', va='center', fontsize=10.5, fontweight='bold', color='#d29922')
    ax.text(80, 26, "(memory_coalescer.v + axi4_master.v)", ha='center', va='center', fontsize=8, color='#8b949e')
    ax.text(80, 18, "• 2-Pass Spatial Tag Analyzer (addr[31:5])\n• Contiguous Line Merging (len=7)\n• Strided Serialization State Machine\n• Full AMBA AXI4 Master Controller\n• 256-Bit Bursts, 4KB Boundary Safe", 
            ha='center', va='center', fontsize=8.2, color='#c9d1d9')

    # ---------------------------------------------------------
    # 4. BUS / ARROW ANNOTATIONS
    # ---------------------------------------------------------
    # Arrow from Frontend to Scheduler
    ax.annotate('', xy=(32, 80.5), xytext=(29, 80.5),
                arrowprops=dict(arrowstyle="-|>", color='#58a6ff', lw=2.5))
    # Arrow from Scheduler to Scoreboard
    ax.annotate('', xy=(66, 80.5), xytext=(63, 80.5),
                arrowprops=dict(arrowstyle="-|>", color='#3fb950', lw=2.5))
    # Arrow from Scheduler to SIMT Stack
    ax.annotate('', xy=(18, 68), xytext=(35, 74),
                arrowprops=dict(arrowstyle="-|>", color='#bc8cff', lw=2.5, connectionstyle="angle,angleA=0,angleB=90,rad=3"))
    # Arrow from SIMT Stack to Lanes (Active Mask)
    ax.annotate('', xy=(33, 53), xytext=(30, 53),
                arrowprops=dict(arrowstyle="-|>", color='#bc8cff', lw=3))
    ax.text(31.5, 55, "Active\nMask", ha='center', va='center', fontsize=7.5, color='#bc8cff', fontweight='bold')

    # Arrow from Lanes to MMA
    ax.annotate('', xy=(19.5, 32), xytext=(40, 38),
                arrowprops=dict(arrowstyle="-|>", color='#f778ba', lw=2.2, connectionstyle="angle,angleA=0,angleB=90,rad=3"))
    # Arrow from Lanes to SMEM
    ax.annotate('', xy=(49.5, 32), xytext=(55, 38),
                arrowprops=dict(arrowstyle="-|>", color='#3fb950', lw=2.2, connectionstyle="angle,angleA=0,angleB=90,rad=3"))
    # Arrow from Lanes to Coalescer
    ax.annotate('', xy=(80, 32), xytext=(70, 38),
                arrowprops=dict(arrowstyle="-|>", color='#d29922', lw=2.2, connectionstyle="angle,angleA=0,angleB=90,rad=3"))

    out_path = os.path.join(OUTPUT_DIR, "apex_gpu_architecture.png")
    plt.savefig(out_path, dpi=300, facecolor=fig.get_facecolor(), edgecolor='none')
    plt.close()
    print(f"[SUCCESS] Generated: {out_path}")

if __name__ == "__main__":
    generate_arch_diagram()
