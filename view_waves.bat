@echo off
cd /d "%~dp0"
call C:\Users\surya\.oss-cad-suite\oss-cad-suite\environment.bat
if not exist "sim\apex_gpu.vcd" (
    echo [INFO] Generating apex_gpu.vcd waveform dump...
    iverilog -g2012 -o sim\apex_gpu_sim.vvp rtl\simt_divergence_stack.v rtl\warp_scheduler.v rtl\simd_lane.v rtl\matrix_unit.v rtl\memory_coalescer.v rtl\shared_memory.v rtl\axi4_master_interface.v rtl\apex_gpu_top.v sim\tb_apex_gpu.v
    vvp sim\apex_gpu_sim.vvp
)
start gtkwave sim\apex_gpu.vcd sim\apex_gpu.gtkw
exit
