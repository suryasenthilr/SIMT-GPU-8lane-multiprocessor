"""
Generate Desktop Shortcuts for Apex-GPU EDA Workbench
"""

import os
import sys

DESKTOP = r"C:\Users\surya\OneDrive\Desktop"
PROJECT_DIR = r"C:\Users\surya\OneDrive\Documents\COLLEGE_RESEARCH\apex-gpu"

workbench_bat = os.path.join(DESKTOP, "Launch_ApexGPU_Workbench.bat")
waveforms_bat = os.path.join(DESKTOP, "Launch_ApexGPU_Waveforms.bat")

with open(workbench_bat, "w") as f:
    f.write(f"""@echo off
cd /d "{PROJECT_DIR}"
call C:\\Users\\surya\\.oss-cad-suite\\oss-cad-suite\\environment.bat
python gui_app.py
pause
""")

with open(waveforms_bat, "w") as f:
    f.write(f"""@echo off
cd /d "{PROJECT_DIR}"
call C:\\Users\\surya\\.oss-cad-suite\\oss-cad-suite\\environment.bat
start gtkwave sim\\apex_gpu.vcd sim\\apex_gpu.gtkw
exit
""")

print(f"[OK] Created Desktop Workbench shortcut: {workbench_bat}")
print(f"[OK] Created Desktop Waveforms shortcut: {waveforms_bat}")
