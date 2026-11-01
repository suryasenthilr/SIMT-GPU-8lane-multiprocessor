"""
Apex-GPU Visuals Generator: ASIC Physical Synthesis Dashboard
Target: Nangate 45nm Open Cell Library (NangateOpenCellLibrary_typical)
"""

import matplotlib.pyplot as plt
import matplotlib.patches as patches
import numpy as np
import os

OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "..", "docs", "images")
os.makedirs(OUTPUT_DIR, exist_ok=True)

# ------------------------------------------------------------------------------
# 1. ASIC Physical Synthesis Metrics & Standard Cell Breakdown Dashboard
# ------------------------------------------------------------------------------
def generate_asic_dashboard():
    plt.style.use('dark_background')
    fig = plt.figure(figsize=(16, 9), dpi=300)
    fig.patch.set_facecolor('#0d1117')

    # Grid layout: 2 rows, 2 columns
    gs = fig.add_gridspec(2, 2, height_ratios=[1.1, 1.9], width_ratios=[1, 1.2],
                          left=0.06, right=0.95, top=0.90, bottom=0.08, wspace=0.22, hspace=0.32)

    # Title & Subtitle
    fig.text(0.06, 0.95, "Apex-GPU: Nangate 45nm ASIC Physical Synthesis Analysis", 
             fontsize=20, fontweight='bold', color='#58a6ff')
    fig.text(0.06, 0.92, "Top-Level Streaming Multiprocessor (apex_gpu_top) | Process Corner: 1.10V, 25°C Typical", 
             fontsize=12, color='#8b949e')

    # --- PANEL 1: Key Metric KPI Cards (Top Left & Top Right merged or Top Left) ---
    ax_kpi = fig.add_subplot(gs[0, :])
    ax_kpi.axis('off')

    kpis = [
        {"title": "TOTAL STANDARD CELLS", "val": "168,113", "sub": "Logic & Sequential Cells", "color": "#58a6ff"},
        {"title": "CORE SILICON AREA", "val": "309,935 μm²", "sub": "0.310 mm² Top-Level Core", "color": "#3fb950"},
        {"title": "GATE EQUIVALENTS (GE)", "val": "388.4 kGE", "sub": "Normalized to NAND2_X1 (0.80μm²)", "color": "#d29922"},
        {"title": "SEQUENTIAL ELEMENTS", "val": "35,125 DFFs", "sub": "Register Files & Buffers (52.1%)", "color": "#bc8cff"},
        {"title": "COMBINATIONAL GATES", "val": "132,966 Gates", "sub": "ALU, MMA, SMEM & Interconnect", "color": "#f778ba"},
    ]

    card_w = 0.185
    card_gap = 0.016
    for idx, k in enumerate(kpis):
        x = idx * (card_w + card_gap)
        # Card background
        rect = patches.FancyBboxPatch((x, 0.05), card_w, 0.88,
                                      boxstyle="round,pad=0.03,rounding_size=0.04",
                                      facecolor='#161b22', edgecolor='#30363d', linewidth=1.5)
        ax_kpi.add_patch(rect)
        # Top color accent bar
        bar = patches.FancyBboxPatch((x + 0.01, 0.86), card_w - 0.02, 0.05,
                                     boxstyle="round,pad=0.01,rounding_size=0.02",
                                     facecolor=k['color'], edgecolor='none')
        ax_kpi.add_patch(bar)

        ax_kpi.text(x + card_w/2, 0.68, k['title'], ha='center', va='center',
                    fontsize=8.5, fontweight='bold', color='#8b949e')
        ax_kpi.text(x + card_w/2, 0.40, k['val'], ha='center', va='center',
                    fontsize=14.5, fontweight='bold', color=k['color'])
        ax_kpi.text(x + card_w/2, 0.18, k['sub'], ha='center', va='center',
                    fontsize=7.5, color='#c9d1d9')

    # --- PANEL 2: Area Distribution Donut Chart (Bottom Left) ---
    ax_donut = fig.add_subplot(gs[1, 0])
    ax_donut.set_facecolor('#161b22')

    labels = ['Sequential Area\n(161,525 μm² | 52.1%)', 'Combinational Area\n(148,410 μm² | 47.9%)']
    sizes = [161525.31, 148410.44]
    colors = ['#bc8cff', '#58a6ff']
    explode = (0.04, 0.0)

    wedges, texts, autotexts = ax_donut.pie(
        sizes, explode=explode, labels=labels, autopct='%1.1f%%',
        startangle=140, colors=colors, pctdistance=0.75,
        wedgeprops=dict(width=0.45, edgecolor='#30363d', linewidth=1.5)
    )

    for text in texts:
        text.set_color('#c9d1d9')
        text.set_fontsize(10.5)
        text.set_fontweight('bold')
    for autotext in autotexts:
        autotext.set_color('#0d1117')
        autotext.set_fontsize(11)
        autotext.set_fontweight('bold')

    ax_donut.text(0, 0, "TOTAL AREA\n309.9k μm²\n(388.4 kGE)", ha='center', va='center',
                  fontsize=11.5, fontweight='bold', color='#f0f6fc')
    ax_donut.set_title("Silicon Area Breakdown by Circuit Class", fontsize=12.5, fontweight='bold', color='#f0f6fc', pad=15)

    # --- PANEL 3: Standard Cell Distribution Bar Chart (Bottom Right) ---
    ax_bar = fig.add_subplot(gs[1, 1])
    ax_bar.set_facecolor('#161b22')

    cells = [
        ('DFF_X1 (Flip-Flops)', 31754, '#bc8cff'),
        ('NAND2_X1 (2-In NAND)', 30012, '#58a6ff'),
        ('OAI21_X1 (OR-AND-Inv)', 29513, '#3fb950'),
        ('AOI22_X1 (AND-OR-Inv)', 25606, '#d29922'),
        ('AOI21_X1 (AND-OR-Inv)', 9227, '#f778ba'),
        ('NOR2_X1 (2-In NOR)', 8708, '#79c0ff'),
        ('NAND4_X1 (4-In NAND)', 6855, '#56d364'),
        ('AOI222_X1 (Wide AOI)', 4419, '#e3b341'),
        ('DFFR_X1 (Reset DFF)', 3313, '#d2a8ff'),
        ('INV_X1 (Inverters)', 2563, '#ffa657'),
        ('MUX2_X1 (2:1 Muxes)', 2229, '#ff7b72'),
    ]

    cell_names = [c[0] for c in cells][::-1]
    cell_counts = [c[1] for c in cells][::-1]
    bar_colors = [c[2] for c in cells][::-1]

    bars = ax_bar.barh(cell_names, cell_counts, color=bar_colors, edgecolor='#30363d', height=0.68)
    ax_bar.set_xlim(0, 36000)
    ax_bar.set_xlabel("Mapped Cell Count (Instances)", fontsize=10.5, color='#8b949e', labelpad=8)
    ax_bar.set_title("Top Nangate 45nm Cell Types Instantiated", fontsize=12.5, fontweight='bold', color='#f0f6fc', pad=15)
    ax_bar.tick_params(axis='both', colors='#c9d1d9', labelsize=9.5)
    ax_bar.grid(axis='x', color='#30363d', linestyle='--', alpha=0.6)

    # Value labels on bars
    for bar in bars:
        w = bar.get_width()
        ax_bar.text(w + 600, bar.get_y() + bar.get_height()/2, f"{w:,}",
                    va='center', ha='left', fontsize=9, color='#c9d1d9', fontweight='semibold')

    # Border frame styling
    for spine in ax_bar.spines.values():
        spine.set_color('#30363d')
        spine.set_linewidth(1.2)

    out_path = os.path.join(OUTPUT_DIR, "apex_gpu_asic_metrics.png")
    plt.savefig(out_path, dpi=300, facecolor=fig.get_facecolor(), edgecolor='none')
    plt.close()
    print(f"[SUCCESS] Generated: {out_path}")

if __name__ == "__main__":
    generate_asic_dashboard()
