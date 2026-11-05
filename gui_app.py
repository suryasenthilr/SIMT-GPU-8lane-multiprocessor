"""
Apex-GPU Silicon Engineering Workbench & EDA Control Center
Graphical User Interface for Architectural Simulation, Synthesis, and Waveform Analysis
Targeting Synthesizable 8-Lane SIMT GPU Streaming Multiprocessor (SM) IP Core.
"""

import sys
import os
import subprocess
import threading
import tkinter as tk
from tkinter import ttk, scrolledtext, messagebox
from PIL import Image, ImageTk

ROOT_DIR = os.path.dirname(os.path.abspath(__file__))
OSS_CAD_DIR = r"C:\Users\surya\.oss-cad-suite\oss-cad-suite"
ENV_BAT = os.path.join(OSS_CAD_DIR, "environment.bat")

class ApexGpuEDAApp(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("Apex-GPU Silicon Engineering Workbench - EDA Control Center")
        self.geometry("1020x760")
        self.minsize(850, 620)
        self.configure(bg="#1e1e2e")

        self.style = ttk.Style(self)
        self.style.theme_use("clam")
        self._configure_styles()

        self._build_header()
        self._build_main_layout()
        self._build_status_bar()

        self.log("=" * 80)
        self.log("  APEX-GPU SILICON ENGINEERING WORKBENCH INITIALIZED")
        self.log(f"  Project Root       : {ROOT_DIR}")
        self.log(f"  OSS CAD Suite      : {OSS_CAD_DIR}")
        self.log("  Target Core        : 8-Lane SIMT GPU Streaming Multiprocessor (SM)")
        self.log("  ASIC Technology    : Nangate 45nm Open Cell Library (NangateOpenCellLibrary_typical)")
        self.log("=" * 80)

    def _configure_styles(self):
        self.style.configure(".", background="#1e1e2e", foreground="#cdd6f4", font=("Segoe UI", 10))
        self.style.configure("Header.TLabel", font=("Segoe UI Semibold", 16), foreground="#89b4fa", background="#181825")
        self.style.configure("SubHeader.TLabel", font=("Segoe UI", 9), foreground="#a6adc8", background="#181825")
        self.style.configure("Card.TFrame", background="#181825", relief="flat")
        self.style.configure("Section.TLabel", font=("Segoe UI Semibold", 11), foreground="#f9e2af", background="#181825")

        self.style.configure("Primary.TButton", font=("Segoe UI Semibold", 10), background="#89b4fa", foreground="#11111b", padding=6)
        self.style.map("Primary.TButton", background=[("active", "#b4befe")])

        self.style.configure("Green.TButton", font=("Segoe UI Semibold", 10), background="#a6e3a1", foreground="#11111b", padding=6)
        self.style.map("Green.TButton", background=[("active", "#94e2d5")])

        self.style.configure("Accent.TButton", font=("Segoe UI Semibold", 10), background="#cba6f7", foreground="#11111b", padding=6)
        self.style.map("Accent.TButton", background=[("active", "#f5c2e7")])

    def _build_header(self):
        hdr_frame = tk.Frame(self, bg="#181825", padx=20, pady=12)
        hdr_frame.pack(fill=tk.X, side=tk.TOP)

        title = ttk.Label(hdr_frame, text="Apex-GPU Silicon Engineering Workbench", style="Header.TLabel")
        title.pack(anchor=tk.W)

        subtitle = ttk.Label(
            hdr_frame,
            text="8-Lane SIMT GPU Streaming Multiprocessor (SM) with Hardware SIMT Stack, 4x4 Systolic MMA, Memory Coalescer & AMBA AXI4",
            style="SubHeader.TLabel"
        )
        subtitle.pack(anchor=tk.W)

    def _build_main_layout(self):
        container = tk.Frame(self, bg="#1e1e2e", padx=15, pady=10)
        container.pack(fill=tk.BOTH, expand=True)

        left_panel = tk.Frame(container, bg="#181825", width=360, padx=15, pady=15, relief="ridge", bd=1)
        left_panel.pack(side=tk.LEFT, fill=tk.Y, padx=(0, 10))
        left_panel.pack_propagate(False)

        right_panel = tk.Frame(container, bg="#11111b")
        right_panel.pack(side=tk.RIGHT, fill=tk.BOTH, expand=True)

        # Left Panel Sections
        lbl_arch = ttk.Label(left_panel, text="ARCHITECTURAL CONTROLS", style="Section.TLabel")
        lbl_arch.pack(anchor=tk.W, pady=(0, 10))

        btn_golden = ttk.Button(left_panel, text="Run Python Golden Model", style="Primary.TButton", command=self.run_golden_model)
        btn_golden.pack(fill=tk.X, pady=4)

        btn_sim = ttk.Button(left_panel, text="Run Verilog Hardware Simulation", style="Green.TButton", command=self.run_simulation)
        btn_sim.pack(fill=tk.X, pady=4)

        btn_wave = ttk.Button(left_panel, text="Open GTKWave Waveforms", style="Accent.TButton", command=self.open_gtkwave)
        btn_wave.pack(fill=tk.X, pady=4)

        btn_synth = ttk.Button(left_panel, text="Run Nangate 45nm ASIC Synthesis", style="Primary.TButton", command=self.run_synthesis)
        btn_synth.pack(fill=tk.X, pady=4)

        btn_pnr = ttk.Button(left_panel, text="🔬 View GDSII Physical Layout", style="Accent.TButton", command=self.open_layout_viewer)
        btn_pnr.pack(fill=tk.X, pady=4)

        btn_klayout = ttk.Button(left_panel, text="🚀 Launch Live KLayout (WSL)", style="Green.TButton", command=self.launch_klayout)
        btn_klayout.pack(fill=tk.X, pady=4)

        # Separator
        ttk.Separator(left_panel, orient=tk.HORIZONTAL).pack(fill=tk.X, pady=15)

        # Architectural Checklist Card
        lbl_concerns = ttk.Label(left_panel, text="ARCHITECTURAL VERIFICATION", style="Section.TLabel")
        lbl_concerns.pack(anchor=tk.W, pady=(0, 6))

        checklist = [
            ("1. Warp Scheduling (GTO Arbitration)", "#a6e3a1"),
            ("2. Scoreboarding & RAW Hazards", "#a6e3a1"),
            ("3. Nested SIMT Divergence Stack", "#a6e3a1"),
            ("4. 4x4 Systolic MMA (16 DSPs)", "#a6e3a1"),
            ("5. Spatial Memory Coalescer", "#a6e3a1"),
            ("6. AMBA AXI4 Master Bursts", "#a6e3a1"),
            ("7. 8-Bank Shared Memory Scratchpad", "#a6e3a1"),
            ("8. Predicated SIMD Lanes", "#a6e3a1"),
            ("9. 45nm ASIC Standard Cell Synthesis", "#a6e3a1"),
            ("10. Self-Checking Corner Verification", "#a6e3a1"),
        ]

        chk_frame = tk.Frame(left_panel, bg="#11111b", padx=10, pady=8, relief="sunken", bd=1)
        chk_frame.pack(fill=tk.BOTH, expand=True)

        for text, color in checklist:
            row = tk.Frame(chk_frame, bg="#11111b")
            row.pack(fill=tk.X, pady=2)
            dot = tk.Label(row, text="✓", fg=color, bg="#11111b", font=("Segoe UI Bold", 10))
            dot.pack(side=tk.LEFT, padx=(0, 6))
            lbl = tk.Label(row, text=text, fg="#cdd6f4", bg="#11111b", font=("Segoe UI", 8), anchor="w")
            lbl.pack(side=tk.LEFT, fill=tk.X)

        # Right Panel: Output Console
        lbl_console = tk.Label(right_panel, text="EDA EXECUTION CONSOLE", fg="#f9e2af", bg="#11111b", font=("Segoe UI Semibold", 11))
        lbl_console.pack(anchor=tk.W, padx=10, pady=(10, 5))

        self.console = scrolledtext.ScrolledText(
            right_panel,
            bg="#181825",
            fg="#cdd6f4",
            insertbackground="#cdd6f4",
            font=("Consolas", 10),
            relief="flat",
            padx=10,
            pady=10
        )
        self.console.pack(fill=tk.BOTH, expand=True, padx=10, pady=(0, 10))

        # Bottom clear button
        btn_clear = tk.Button(right_panel, text="Clear Console", bg="#313244", fg="#cdd6f4", relief="flat", command=self.clear_console)
        btn_clear.pack(anchor=tk.E, padx=10, pady=(0, 10))

    def _build_status_bar(self):
        self.status_bar = tk.Label(
            self,
            text="Ready. Select an action from the control panel.",
            bg="#11111b",
            fg="#a6adc8",
            font=("Segoe UI", 9),
            anchor=tk.W,
            padx=15,
            pady=4
        )
        self.status_bar.pack(side=tk.BOTTOM, fill=tk.X)

    def log(self, text):
        self.console.insert(tk.END, text + "\n")
        self.console.see(tk.END)

    def clear_console(self):
        self.console.delete("1.0", tk.END)

    def set_status(self, text):
        self.status_bar.config(text=text)

    def _run_async(self, cmd, desc, callback=None):
        def worker():
            self.set_status(f"Running: {desc}...")
            self.log(f"\n[EXEC] {desc}")
            self.log(f"Command: {cmd}\n")
            try:
                proc = subprocess.Popen(
                    cmd,
                    shell=True,
                    cwd=ROOT_DIR,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT,
                    text=True,
                    bufsize=1
                )
                for line in proc.stdout:
                    self.log(line.rstrip())
                proc.wait()
                if proc.returncode == 0:
                    self.log(f"\n[SUCCESS] {desc} finished with code 0.")
                    self.set_status(f"Completed: {desc}")
                else:
                    self.log(f"\n[ERROR] {desc} exited with code {proc.returncode}.")
                    self.set_status(f"Failed: {desc} (code {proc.returncode})")
                if callback:
                    callback(proc.returncode)
            except Exception as e:
                self.log(f"[EXCEPTION] {str(e)}")
                self.set_status(f"Error: {desc}")

        t = threading.Thread(target=worker, daemon=True)
        t.start()

    def run_golden_model(self):
        cmd = f'python "{os.path.join(ROOT_DIR, "sim", "golden_gpu_model.py")}"'
        self._run_async(cmd, "Python Golden Model Suite")

    def run_simulation(self):
        cmd = (
            f'cmd.exe /c "call \"{ENV_BAT}\" && '
            f'iverilog -g2012 -o sim\\apex_gpu_sim.vvp rtl\\simt_divergence_stack.v rtl\\warp_scheduler.v rtl\\simd_lane.v rtl\\matrix_unit.v rtl\\memory_coalescer.v rtl\\shared_memory.v rtl\\axi4_master_interface.v rtl\\apex_gpu_top.v sim\\tb_apex_gpu.v && '
            f'vvp sim\\apex_gpu_sim.vvp"'
        )
        self._run_async(cmd, "Apex-GPU Verilog Simulation Testbench")

    def open_gtkwave(self):
        vcd_path = os.path.join(ROOT_DIR, "sim", "apex_gpu.vcd")
        gtkw_path = os.path.join(ROOT_DIR, "sim", "apex_gpu.gtkw")
        if not os.path.exists(vcd_path):
            messagebox.showwarning("Waveform Missing", "apex_gpu.vcd not found. Please run the simulation first.")
            return

        cmd = f'cmd.exe /c "call \"{ENV_BAT}\" && start gtkwave \"{vcd_path}\" \"{gtkw_path}\""'
        subprocess.Popen(cmd, shell=True, cwd=ROOT_DIR)
        self.log(f"[LAUNCH] GTKWave opened with {vcd_path}")
        self.set_status("GTKWave Waveform Viewer running.")

    def run_synthesis(self):
        cmd = (
            f'cmd.exe /c "call \"{ENV_BAT}\" && '
            f'yosys -s synth\\run_synth_asic.ys"'
        )
        self._run_async(cmd, "Nangate 45nm ASIC Standard Cell Synthesis")

    def open_layout_viewer(self):
        img_path = os.path.join(ROOT_DIR, "pnr", "apex_gpu_top_layout.png")
        if not os.path.exists(img_path):
            messagebox.showwarning("Layout Missing", f"Layout rendering not found: {img_path}")
            return

        win = tk.Toplevel(self)
        win.title("Apex-GPU — 45nm ASIC Physical Layout & Silicon Signoff")
        win.geometry("1100x780")
        win.configure(bg="#1e1e2e")

        # Top Bar
        top_bar = tk.Frame(win, bg="#181825", padx=15, pady=10)
        top_bar.pack(fill=tk.X)
        tk.Label(top_bar, text="APEX-GPU: 45nm ASIC PHYSICAL DESIGN & GDSII SIGNOFF",
                 fg="#a6e3a1", bg="#181825", font=("Segoe UI Semibold", 13)).pack(side=tk.LEFT)
        tk.Label(top_bar, text="● 176,699 CELLS | 100% LEGALIZED | 301 mW TOTAL POWER",
                 fg="#11111b", bg="#a6e3a1", font=("Segoe UI Bold", 9), padx=8, pady=3).pack(side=tk.RIGHT)

        # Body split
        body = tk.Frame(win, bg="#1e1e2e", padx=12, pady=10)
        body.pack(fill=tk.BOTH, expand=True)

        # Left Canvas
        c_frame = tk.Frame(body, bg="#11111b", relief="ridge", bd=1)
        c_frame.pack(side=tk.LEFT, fill=tk.BOTH, expand=True, padx=(0, 10))

        canvas = tk.Canvas(c_frame, bg="#050811", highlightthickness=0)
        canvas.pack(fill=tk.BOTH, expand=True)

        def render_canvas():
            w = canvas.winfo_width()
            h = canvas.winfo_height()
            if w < 50 or h < 50:
                w, h = 640, 640
            im = Image.open(img_path)
            im_resized = im.resize((w, h), Image.Resampling.LANCZOS)
            win._img_ref = ImageTk.PhotoImage(im_resized)
            canvas.delete("all")
            canvas.create_image(w // 2, h // 2, image=win._img_ref)

        win.after(150, render_canvas)

        # Right Metrics
        r_panel = tk.Frame(body, bg="#181825", width=360, padx=14, pady=14, relief="ridge", bd=1)
        r_panel.pack(side=tk.RIGHT, fill=tk.Y)
        r_panel.pack_propagate(False)

        tk.Label(r_panel, text="ASIC SIGNOFF METRICS", fg="#89b4fa", bg="#181825", font=("Segoe UI Semibold", 11)).pack(anchor=tk.W, pady=(0, 8))

        stats = [
            ("Die Dimensions", "743.06 µm × 743.06 µm (0.552 mm²)"),
            ("Standard Cells", "176,699 instances (100% legalized)"),
            ("Core Utilization", "60.0% (Cell area: 319,804 µm²)"),
            ("Total Power", "301 mW @ 100MHz (Nangate 45nm)"),
            ("Sequential Power", "88.7 mW (29.4%)"),
            ("Combinational Power", "179 mW (59.4%)"),
            ("Clock Network Power", "33.6 mW (11.2%)"),
            ("Clock Tree (CTS)", "Balanced 9-Level Tree, 38,520 sinks"),
            ("Clock Buffers", "4,422 buffers inserted (CLKBUF_X1..X3)"),
            ("PDN Power Grid", "M1 Rails, M4 Vert (56µm), M7 Horiz (30µm)"),
            ("GDSII Stream File", "apex_gpu_top.gds (15.8 MB)"),
        ]

        for title, val in stats:
            tk.Label(r_panel, text=title, fg="#a6adc8", bg="#181825", font=("Segoe UI Bold", 8)).pack(anchor=tk.W, pady=(4, 0))
            tk.Label(r_panel, text=val, fg="#cdd6f4", bg="#181825", font=("Segoe UI", 9)).pack(anchor=tk.W)

        ttk.Separator(r_panel, orient=tk.HORIZONTAL).pack(fill=tk.X, pady=12)

        btn_k = tk.Button(r_panel, text="🚀 Launch Live KLayout (WSL)", bg="#a6e3a1", fg="#11111b",
                          font=("Segoe UI Bold", 9), pady=6, relief="flat", cursor="hand2", command=self.launch_klayout)
        btn_k.pack(fill=tk.X, pady=4)

        btn_l = tk.Button(r_panel, text="📜 View OpenROAD P&R Log", bg="#89b4fa", fg="#11111b",
                          font=("Segoe UI Bold", 9), pady=6, relief="flat", cursor="hand2", command=self.view_pnr_log)
        btn_l.pack(fill=tk.X, pady=4)

    def launch_klayout(self):
        wsl_path = "/mnt/c/Users/surya/OneDrive/Documents/COLLEGE_RESEARCH/apex-gpu/pnr/apex_gpu_top.gds"
        cmd = f"wsl klayout {wsl_path}"
        threading.Thread(target=lambda: subprocess.run(cmd, shell=True), daemon=True).start()
        messagebox.showinfo("KLayout Launched", f"Launching interactive KLayout viewer for:\napex_gpu_top.gds\n\nRendering multi-layer GDSII stream...")

    def view_pnr_log(self):
        log_path = os.path.join(ROOT_DIR, "pnr", "pnr_gpu.log")
        if not os.path.exists(log_path):
            messagebox.showwarning("Log Missing", f"Log not found: {log_path}")
            return
        top = tk.Toplevel(self)
        top.title("OpenROAD Physical Design Log — apex_gpu_top")
        top.geometry("900x650")
        top.configure(bg="#1e1e2e")
        txt = scrolledtext.ScrolledText(top, bg="#11111b", fg="#cdd6f4", font=("Consolas", 9))
        txt.pack(fill="both", expand=True, padx=10, pady=10)
        with open(log_path, "r", encoding="utf-8", errors="ignore") as f:
            txt.insert("1.0", f.read())
        txt.config(state="disabled")

if __name__ == "__main__":
    app = ApexGpuEDAApp()
    app.mainloop()
