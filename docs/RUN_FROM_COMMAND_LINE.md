# Run from command line (no Questa GUI)

To avoid the GUI and project cache, run the test from the **command line** so every run recompiles from source.

## 1. Open Questa command prompt

- **Start menu** → **Intel FPGA / Questa** → **Questa 2025.x** → **Command Prompt**  
  (or similar; this puts `vlib`, `vlog`, `vsim` on `PATH`).

## 2. Go to the project folder

**In CMD (Windows Command Prompt):**
```bat
cd "C:\questasim64_2025.1_2\Projects\Logic Design Veirifcation\UVM-final-project"
```

**In Git Bash / WSL / MinGW** (backslashes get eaten – use forward slashes):
```bash
cd "C:/questasim64_2025.1_2/Projects/Logic Design Veirifcation/UVM-final-project"
```

Or open the folder in Explorer, type `cmd` in the address bar, and press Enter – you’ll be in the project folder. Then run `run_fixed_rtl_batch.bat`.

## 3. Run the batch script

```bat
run_fixed_rtl_batch.bat
```

This script:

1. Deletes the `work` library (clean state).
2. Recreates `work` and compiles with **+fcover**: `cpm_if.sv`, `cpm_rtl_fixed.sv`, `cpm_pkg.svh`, `cpm_tb_fixed.sv`.
3. Runs `vsim -c -coverage` and saves coverage to **`sim.ucdb`** on exit.

No project file (`.mpf`) is used; everything is driven by the script.

**Coverage:** Open **`sim.ucdb`** in Questa (e.g. **File → Open** the `.ucdb` file, or run the test from the GUI and use **Tools → Coverage Report**). Use the GUI or transcript to view/save the covergroup report for submission.

## Save the log

```bat
run_fixed_rtl_batch.bat > sim_log.txt 2>&1
```

Then open `sim_log.txt` to check for errors or to search for `RTL_FIXED_BOTH_FIRE`.

## If `vdel` fails (“work in use”)

Another process (e.g. another vsim or the GUI) has `work` open. Close all other Questa windows and run the batch again. The script still runs `vlog` after that, so the next `vsim` will use the newly compiled design.

## Paths

If your Questa or UVM install is elsewhere, edit `run_fixed_rtl_batch.bat` and set:

- `UVM_DPI` to the folder that contains `uvm_dpi.dll` (e.g. `.../uvm-1.1d/win64/uvm_dpi`).
