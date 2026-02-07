-- Remove all compiled units from work so the next run recompiles everything from source.
-- Use this when you want to be 100% sure no old object code is used.
--
-- Usage:
--   1. In Questa: do run_clean.do
--   2. Then:      do run_rtl.do
-- Or from command line: vsim -c -do "do run_clean.do; do run_rtl.do; quit -f"

vdel -all -lib work
echo === Work library cleared. Next 'do run_rtl.do' will do a full recompile. ===
