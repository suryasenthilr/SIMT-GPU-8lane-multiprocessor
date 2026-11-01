"""
Academic IEEE-Style Microarchitectural Schematic for Apex-GPU
Clean publication style: White background, precise vector line-art, bus widths, IEEE paper aesthetic.
"""

import matplotlib.pyplot as plt
import matplotlib.patches as patches
import os

OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "..", "docs", "images")
os.makedirs(OUTPUT_DIR, exist_ok=True)

def generate_academic_arch():
    fig = plt.figure(figsize=(16, 9.5), dpi=300)
    fig.patch.set_facecolor('#ffffff')
    ax = fig.add_subplot(111)
    ax.set_facecolor('#ffffff')
    ax.set_xlim(0, 100)
    ax.set_ylim(0, 100)
    ax.axis('off')

    # Border & IEEE Figure Header
    ax.text(50, 97, "Fig. 1. Microarchitectural Block Diagram of the Apex-GPU Streaming Multiprocessor (SM) Core.",
            ha='center', va='center', fontsize=12, fontweight='bold', fontfamily='serif', color='#000000')

    # Main SM Core Bounding Box
    core_box = patches.Rectangle((4, 4), 92, 90, facecolor='#fafbfc', edgecolor='#000000', linewidth=1.5, linestyle='-')
    ax.add_patch(core_box)
    ax.text(6, 91.5, "Apex-GPU Streaming Multiprocessor Top Core (apex_gpu_top)", fontsize=10.5, fontweight='bold', fontfamily='serif', color='#000000')

    # =========================================================
    # 1. FRONTEND & SCHEDULING (Top Row)
    # =========================================================
    # Instruction Dispatch & Warp Table
    ax.add_patch(patches.Rectangle((6, 75), 24, 14, facecolor='#ffffff', edgecolor='#000000', linewidth=1.2))
    ax.text(18, 86, "Instruction Dispatch &\nWarp Management Unit", ha='center', va='center', fontsize=9.5, fontweight='bold', fontfamily='serif')
    ax.text(18, 79.5, "• 4 Warp State Registers\n• Per-Warp Program Counters\n• RV32I + SIMT / MMA Decoder", ha='center', va='center', fontsize=8, fontfamily='serif')

    # Warp Scheduler & GTO Arbiter
    ax.add_patch(patches.Rectangle((33, 75), 32, 14, facecolor='#ffffff', edgecolor='#000000', linewidth=1.2))
    ax.text(49, 86, "Warp Scheduler & Arbiter", ha='center', va='center', fontsize=9.5, fontweight='bold', fontfamily='serif')
    ax.text(49, 79.5, "• Fine-Grained Multithreading (Zero-Cycle)\n• Greedy-Then-Oldest (GTO) Latency Hiding\n• Ready Warp Priority Selector", ha='center', va='center', fontsize=8, fontfamily='serif')

    # Hardware Scoreboard
    ax.add_patch(patches.Rectangle((68, 75), 26, 14, facecolor='#ffffff', edgecolor='#000000', linewidth=1.2))
    ax.text(81, 86, "Hardware Scoreboard Unit", ha='center', va='center', fontsize=9.5, fontweight='bold', fontfamily='serif')
    ax.text(81, 79.5, "• 128-Bit Dependency Matrix (4W × 32R)\n• RAW Hazard Detection & Interlocking\n• Multi-Cycle Writeback Clear Logic", ha='center', va='center', fontsize=8, fontfamily='serif')

    # =========================================================
    # 2. SIMT DIVERGENCE & SIMD EXECUTION LANES (Middle)
    # =========================================================
    # SIMT Divergence Stack
    ax.add_patch(patches.Rectangle((6, 40), 24, 30, facecolor='#f4f6f8', edgecolor='#000000', linewidth=1.2))
    ax.text(18, 67, "Hardware SIMT Stack\n(simt_divergence_stack.v)", ha='center', va='center', fontsize=9.5, fontweight='bold', fontfamily='serif')
    
    # Internal stack entries
    sy = 60
    for i in range(4):
        ax.add_patch(patches.Rectangle((8, sy), 20, 3.2, facecolor='#ffffff', edgecolor='#333333', linewidth=0.8))
        lbl = "TOS [SP]: PC, Mask, OrigMask" if i == 0 else f"Level {3-i} Divergence Frame"
        ax.text(18, sy + 1.6, lbl, ha='center', va='center', fontsize=7.5, fontfamily='serif')
        sy -= 4.2
    ax.text(18, 43, "• 8-Entry Divergence Stack\n• Bit-Exact IPDOM Reconvergence\n• Combinational Next-PC Generation", ha='center', va='center', fontsize=7.5, fontfamily='serif')

    # 8 SIMD Lanes Container
    ax.add_patch(patches.Rectangle((33, 40), 61, 30, facecolor='#f4f6f8', edgecolor='#000000', linewidth=1.2))
    ax.text(63.5, 67.5, "8 Parallel SIMD Execution Lanes (simd_lane.v × 8)", ha='center', va='center', fontsize=10, fontweight='bold', fontfamily='serif')
    ax.text(63.5, 64.5, "Predicated Execution: active_mask[7:0] gates register writeback", ha='center', va='center', fontsize=8, fontstyle='italic', fontfamily='serif')

    # 8 Lanes Detail
    lw = 6.8
    lg = 0.7
    sx = 34.5
    for l in range(8):
        lx = sx + l * (lw + lg)
        ax.add_patch(patches.Rectangle((lx, 42), lw, 20.5, facecolor='#ffffff', edgecolor='#000000', linewidth=0.9))
        ax.text(lx + lw/2, 60.5, f"Lane {l}", ha='center', va='center', fontsize=8.5, fontweight='bold', fontfamily='serif')
        
        # ALU
        ax.add_patch(patches.Rectangle((lx + 0.4, 51.5), lw - 0.8, 6.5, facecolor='#ffffff', edgecolor='#333333', linewidth=0.7))
        ax.text(lx + lw/2, 55.5, "32-bit\nALU", ha='center', va='center', fontsize=7.5, fontweight='bold', fontfamily='serif')
        ax.text(lx + lw/2, 52.5, "+, -, *, &", ha='center', va='center', fontsize=6.5, fontfamily='serif')

        # RF
        ax.add_patch(patches.Rectangle((lx + 0.4, 43), lw - 0.8, 7.5, facecolor='#f9fafb', edgecolor='#333333', linewidth=0.7))
        ax.text(lx + lw/2, 47.5, "Reg File\n128×32b", ha='center', va='center', fontsize=7.5, fontfamily='serif')
        ax.text(lx + lw/2, 44.5, "4 Warps", ha='center', va='center', fontsize=6.5, fontfamily='serif')

    # =========================================================
    # 3. ACCELERATION & MEMORY SUBSYSTEMS (Bottom Row)
    # =========================================================
    # 4x4 Systolic MMA
    ax.add_patch(patches.Rectangle((6, 7), 27, 28, facecolor='#ffffff', edgecolor='#000000', linewidth=1.2))
    ax.text(19.5, 32, "4x4 Systolic MMA Engine\n(matrix_unit.v)", ha='center', va='center', fontsize=9.5, fontweight='bold', fontfamily='serif')
    ax.text(19.5, 20, "• 16 Physical DSP Multipliers\n• 16 Physical 32-bit Accumulators\n• 4-Cycle Systolic Schedule (k=0..3)\n• Sustained 16 MACs/Cycle\n• Outer-Product Tiling: D = A × B + C", 
            ha='center', va='center', fontsize=8, fontfamily='serif')

    # 8-Bank Shared Memory
    ax.add_patch(patches.Rectangle((36, 7), 27, 28, facecolor='#ffffff', edgecolor='#000000', linewidth=1.2))
    ax.text(49.5, 32, "8-Bank Shared Memory (4KB)\n(shared_memory.v)", ha='center', va='center', fontsize=9.5, fontweight='bold', fontfamily='serif')
    ax.text(49.5, 20, "• 8 Independent Banks (512B/Bank)\n• 8×8 Non-Blocking Crossbar\n• Bank Conflict Detection Unit\n• 2-Phase Conflict Serialization\n• Multi-Thread Broadcast Bus", 
            ha='center', va='center', fontsize=8, fontfamily='serif')

    # Memory Coalescer & AXI4
    ax.add_patch(patches.Rectangle((66, 7), 28, 28, facecolor='#ffffff', edgecolor='#000000', linewidth=1.2))
    ax.text(80, 32, "Spatial Memory Coalescer\n& AMBA AXI4 Master", ha='center', va='center', fontsize=9.5, fontweight='bold', fontfamily='serif')
    ax.text(80, 20, "• 2-Pass Spatial Tag Analyzer (addr[31:5])\n• Contiguous Access Line Merging (len=7)\n• Strided Serialization FSM\n• Full AMBA AXI4 Master Protocol\n• 256-Bit Bursts, 4KB Boundary Safe", 
            ha='center', va='center', fontsize=8, fontfamily='serif')

    # =========================================================
    # 4. BUS CONNECTIONS & INTERCONNECTS (Academic clean arrows)
    # =========================================================
    # Fetch -> Scheduler
    ax.annotate('', xy=(33, 82), xytext=(30, 82),
                arrowprops=dict(arrowstyle="-|>", color='#000000', lw=1.5))
    ax.text(31.5, 83.5, "inst", ha='center', fontsize=7.5, fontfamily='serif')

    # Scheduler -> Scoreboard
    ax.annotate('', xy=(68, 82), xytext=(65, 82),
                arrowprops=dict(arrowstyle="<|-|>", color='#000000', lw=1.5))
    ax.text(66.5, 83.5, "hazards", ha='center', fontsize=7.5, fontfamily='serif')

    # Scheduler -> SIMT Stack
    ax.annotate('', xy=(18, 70), xytext=(35, 75),
                arrowprops=dict(arrowstyle="-|>", color='#000000', lw=1.5, connectionstyle="angle,angleA=0,angleB=90,rad=0"))
    ax.text(26, 74, "branch_eval", ha='center', fontsize=7.5, fontfamily='serif')

    # SIMT Stack -> Lanes (Active Mask)
    ax.annotate('', xy=(33, 55), xytext=(30, 55),
                arrowprops=dict(arrowstyle="-|>", color='#000000', lw=1.8))
    # Bus tick
    ax.plot([31.2, 31.8], [54.5, 55.5], color='#000000', lw=1.2)
    ax.text(31.5, 57, "/8 active_mask", ha='center', fontsize=7.5, fontfamily='serif', fontweight='bold')

    # Lanes -> MMA
    ax.annotate('', xy=(19.5, 35), xytext=(40, 40),
                arrowprops=dict(arrowstyle="-|>", color='#000000', lw=1.5, connectionstyle="angle,angleA=0,angleB=90,rad=0"))
    ax.text(28, 38.5, "rs1, rs2 (matrix tile)", ha='center', fontsize=7.5, fontfamily='serif')

    # Lanes -> SMEM
    ax.annotate('', xy=(49.5, 35), xytext=(55, 40),
                arrowprops=dict(arrowstyle="<|-|>", color='#000000', lw=1.5, connectionstyle="angle,angleA=0,angleB=90,rad=0"))
    ax.text(53, 38.5, "lane_addr / rdata", ha='center', fontsize=7.5, fontfamily='serif')

    # Lanes -> Coalescer
    ax.annotate('', xy=(80, 35), xytext=(72, 40),
                arrowprops=dict(arrowstyle="-|>", color='#000000', lw=1.5, connectionstyle="angle,angleA=0,angleB=90,rad=0"))
    ax.text(77, 38.5, "global_mem reqs", ha='center', fontsize=7.5, fontfamily='serif')

    out_path = os.path.join(OUTPUT_DIR, "apex_gpu_architecture.png")
    plt.savefig(out_path, dpi=300, facecolor=fig.get_facecolor(), edgecolor='none')
    plt.close()
    print(f"[SUCCESS] Academic IEEE diagram generated: {out_path}")

if __name__ == "__main__":
    generate_academic_arch()
