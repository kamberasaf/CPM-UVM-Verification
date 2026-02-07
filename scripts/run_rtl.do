-- This is the design-under-test as provided; verification runs against the unmodified RTL.
--
-- Run from SUBMISSION ROOT (folder that contains rtl/ and tb/).
-- Compiles: tb/cpm_if.sv, rtl/cpm_rtl.sv, tb/cpm_pkg.svh, tb/cpm_tb.sv
-- Runs: work.cpm_tb
--
-- To be 100%% sure you run updated code: do scripts/run_clean.do then do scripts/run_rtl.do

echo === Recompiling all sources (run_rtl.do) ===
vlog -work work -sv +incdir+[pwd]/tb +fcover tb/cpm_if.sv rtl/cpm_rtl.sv tb/cpm_pkg.svh tb/cpm_tb.sv
echo "=== Compile done, starting simulation ==="

vsim -c -coverage work.cpm_tb -sv_lib C:/questasim64_2025.1_2/uvm-1.1d/win64/uvm_dpi +UVM_TESTNAME=cpm_base_test +READY_PROB=80 +ALLOW_ONE_LEFTOVER=1 +UVM_VERBOSITY=UVM_LOW

run -all
coverage report -detail -cvg -file coverage_report.txt
