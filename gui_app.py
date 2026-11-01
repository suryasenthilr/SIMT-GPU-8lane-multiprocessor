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

if __name__ == "__main__":
    app = ApexGpuEDAApp()
    app.mainloop()
