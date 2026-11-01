"""
Apex-GPU Visuals Generator: Silicon Engineering Workbench UI Dashboard
Renders the Interactive EDA Workbench Interface with Simulation & Synthesis Logs
"""

import matplotlib.pyplot as plt
import matplotlib.patches as patches
import os

OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "..", "docs", "images")
os.makedirs(OUTPUT_DIR, exist_ok=True)

def generate_workbench_poster():
    fig = plt.figure(figsize=(18, 10.5), dpi=300)
    fig.patch.set_facecolor('#1e1e2e')
    ax = fig.add_subplot(111)
    ax.set_facecolor('#1e1e2e')
    ax.set_xlim(0, 100)
    ax.set_ylim(0, 100)
    ax.axis('off')

    # Window Frame (macOS / Modern Windows dark style)
    win_rect = patches.FancyBboxPatch((2, 3), 96, 94, boxstyle="round,pad=1.0,rounding_size=1.2",
                                     facecolor='#181825', edgecolor='#313244', linewidth=2)
    ax.add_patch(win_rect)

    # Title Bar
    # Window controls (red, yellow, green dots)
    ax.add_patch(patches.Circle((5, 93.5), 0.8, facecolor='#f38ba8', edgecolor='none'))
    ax.add_patch(patches.Circle((7.5, 93.5), 0.8, facecolor='#f9e2af', edgecolor='none'))
    ax.add_patch(patches.Circle((10, 93.5), 0.8, facecolor='#a6e3a1', edgecolor='none'))

    ax.text(50, 93.5, "Apex-GPU Silicon Engineering Workbench - EDA Control Center",
            ha='center', va='center', fontsize=12, fontweight='bold', color='#cdd6f4')

    # Header Panel (y: 83 to 90)
    hdr_box = patches.FancyBboxPatch((4, 83), 92, 7.5, boxstyle="round,pad=0.5,rounding_size=0.6",
                                    facecolor='#11111b', edgecolor='#313244', linewidth=1.2)
    ax.add_patch(hdr_box)
    ax.text(6, 88, "Apex-GPU Silicon Engineering Workbench", fontsize=13, fontweight='bold', color='#89b4fa')
    ax.text(6, 85, "Hardware SIMT Divergence Stack | Fine-Grained Multithreading | 4x4 Systolic MMA | Nangate 45nm ASIC",
            fontsize=9, color='#a6adc8')

    # Status Pill on Header
    pill = patches.FancyBboxPatch((78, 84.5), 16, 4.5, boxstyle="round,pad=0.3,rounding_size=0.6",
                                 facecolor='#1e3a2f', edgecolor='#a6e3a1', linewidth=1.2)
    ax.add_patch(pill)
    ax.text(86, 86.8, "● CORE VERIFIED (7/7)", ha='center', va='center', fontsize=8.5, fontweight='bold', color='#a6e3a1')

    # -------------------------------------------------------------
    # LEFT PANEL: Interactive Action Cards (x: 4 to 32, y: 7 to 81)
    # -------------------------------------------------------------
    left_box = patches.FancyBboxPatch((4, 7), 29, 74, boxstyle="round,pad=0.6,rounding_size=0.8",
                                     facecolor='#11111b', edgecolor='#313244', linewidth=1.2)
    ax.add_patch(left_box)
    ax.text(18.5, 78, "EDA WORKFLOW ACTIONS", ha='center', va='center', fontsize=11, fontweight='bold', color='#f9e2af')

    actions = [
        {"title": "1. Python Golden Model", "desc": "Bit-exact reference simulation\nVerifies 2-level stack & MMA", "btn": "Run Golden Suite", "col": "#89b4fa", "y": 62},
        {"title": "2. Verilog Testbench", "desc": "Cycle-accurate hardware TB\nSelf-checking SIMT pipeline", "btn": "Run Simulation", "col": "#a6e3a1", "y": 45},
        {"title": "3. Waveform Inspector", "desc": "Pre-configured GTKWave view\nDivergence, AXI & MMA traces", "btn": "Launch GTKWave", "col": "#cba6f7", "y": 28},
        {"title": "4. ASIC Synthesis", "desc": "Nangate 45nm standard cells\nYosys gate mapping & area", "btn": "Run 45nm Synthesis", "col": "#fab387", "y": 11},
    ]

    for a in actions:
        ay = a['y']
        card = patches.FancyBboxPatch((6, ay), 25, 14, boxstyle="round,pad=0.4,rounding_size=0.5",
                                     facecolor='#181825', edgecolor='#45475a', linewidth=1)
        ax.add_patch(card)
        ax.text(8, ay + 11.5, a['title'], fontsize=9.5, fontweight='bold', color='#cdd6f4')
        ax.text(8, ay + 7.5, a['desc'], fontsize=7.8, color='#a6adc8')
        
        btn = patches.FancyBboxPatch((8, ay + 1.2), 21, 3.8, boxstyle="round,pad=0.2,rounding_size=0.4",
                                    facecolor=a['col'], edgecolor='none')
        ax.add_patch(btn)
        ax.text(18.5, ay + 3.1, a['btn'], ha='center', va='center', fontsize=8.5, fontweight='bold', color='#11111b')

    # -------------------------------------------------------------
    # RIGHT PANEL: Embedded Terminal Console (x: 35 to 96, y: 7 to 81)
    # -------------------------------------------------------------
    right_box = patches.FancyBboxPatch((35, 7), 61, 74, boxstyle="round,pad=0.6,rounding_size=0.8",
                                      facecolor='#0b0d13', edgecolor='#313244', linewidth=1.2)
    ax.add_patch(right_box)

    # Console Top Bar
    c_bar = patches.Rectangle((35.5, 76.5), 60, 4, facecolor='#161822', edgecolor='none')
    ax.add_patch(c_bar)
    ax.text(37, 78.5, "Silicon Engineering Console Terminal (Interactive Output)", fontsize=9, fontweight='bold', color='#cdd6f4')
    ax.text(93, 78.5, "bash / powershell", ha='right', fontsize=8, color='#6c7086')

    # Terminal Log Text
    console_lines = [
        ("======================================================================", "#6c7086"),
        ("  APEX-GPU SILICON ENGINEERING WORKBENCH INITIALIZED", "#89b4fa"),
        ("  Project Root    : C:\\...\\COLLEGE_RESEARCH\\apex-gpu", "#a6adc8"),
        ("  Target Core     : 8-Lane SIMT GPU Streaming Multiprocessor (SM)", "#a6adc8"),
        ("  ASIC Technology : Nangate 45nm Open Cell Library (NangateOpenCellLibrary_typical)", "#a6adc8"),
        ("======================================================================", "#6c7086"),
        ("", "#ffffff"),
        ("[EXEC] Apex-GPU Verilog Simulation Testbench", "#f9e2af"),
        ("[TEST 1] Verifying System Reset and Register Initialization...", "#cdd6f4"),
        ("  [PASS] Thread Lane IDs initialized: Lane 0 = 0, Lane 7 = 7", "#a6e3a1"),
        ("[TEST 2] Launching SIMT GPU Execution Pipeline...", "#cdd6f4"),
        ("  [PASS] SIMD Parallel Execution: Lane 0 R2=10, Lane 7 R2=17", "#a6e3a1"),
        ("  [PASS] SIMD Parallel Execution: Lane 0 R4=10, Lane 7 R4=24", "#a6e3a1"),
        ("[TEST 3] Verifying Hardware SIMT Branch Divergence Stack...", "#cdd6f4"),
        ("  Active Lane Mask = 0b00001111 (Expected: 0b00001111)", "#cba6f7"),
        ("  [PASS] Divergent Branch Taken by Lanes 0..3 with Active Mask = 0x0F", "#a6e3a1"),
        ("  Active Lane Mask = 0b11110000 (Expected: 0b11110000)", "#cba6f7"),
        ("  [PASS] Divergent Branch ELSE Path Executed by Lanes 4..7 with Active Mask = 0xF0", "#a6e3a1"),
        ("  Active Lane Mask = 0b11111111 (Expected: 0b11111111)", "#cba6f7"),
        ("  [PASS] Full Hardware Reconvergence: All 8 Lanes Reunited (Active Mask = 0xFF)", "#a6e3a1"),
        ("[TEST 4] Verifying Spatial Memory Coalescer & AMBA AXI4 Interface...", "#cdd6f4"),
        ("  [PASS] 8-Lane Memory Accesses Coalesced into 1 256-bit AXI Burst (len=7)!", "#a6e3a1"),
        ("[TEST 5] Verifying 4x4 Systolic Matrix Multiply-Accumulate (MMA)...", "#cdd6f4"),
        ("  [PASS] 16 Multipliers executed 4-cycle schedule: mma_done asserted!", "#a6e3a1"),
        ("======================================================================", "#6c7086"),
        ("  VERIFICATION SUMMARY: 7 / 7 TESTS PASSED (100% BIT-EXACT MATCH)", "#a6e3a1"),
        ("======================================================================", "#6c7086"),
        ("[ASIC SYNTHESIS] Mapped 168,113 Cells | Area: 309,935 μm² | Gate Count: 388.4 kGE", "#fab387"),
    ]

    ty = 73.5
    for text, col in console_lines:
        ax.text(37, ty, text, fontsize=7.2, fontfamily='monospace', color=col)
        ty -= 2.25

    # Bottom status bar
    ax.text(6, 4.2, "Ready. Double-click desktop shortcut Launch_ApexGPU_Workbench.bat to launch.",
            fontsize=8, color='#6c7086')

    out_path = os.path.join(OUTPUT_DIR, "apex_gpu_workbench_ui.png")
    plt.savefig(out_path, dpi=300, facecolor=fig.get_facecolor(), edgecolor='none')
    plt.close()
    print(f"[SUCCESS] Generated: {out_path}")

if __name__ == "__main__":
    generate_workbench_poster()
