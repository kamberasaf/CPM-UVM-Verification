# CPM UVM Verification – Final Project

**Author:** Asaf Kamber  
**Design:** Configurable Packet Modifier (CPM)  
**Deliverables:** Full source (UVM TB + assertions + RAL), verification plan, coverage report, assertion report, reflection report.

---

## Contents of This Submission

| Item | Description |
|------|--------------|
| **rtl/** | RTL: `cpm_rtl.sv` (original DUT), `cpm_rtl_fixed.sv` (optional comparison) |
| **tb/** | Full UVM testbench: interface, package, agents, env, RAL, sequences, test, scoreboard, coverage |
| **scripts/** | `run_rtl.do` (main run), `run_clean.do` (clean before recompile) |
| **results/** | `transcript_final.txt` (run log), `coverage_report.txt` (functional coverage), `assertion_report.txt` (assertion tool output summary) |
| **docs/** | `RUN_FROM_COMMAND_LINE.md` (command-line run instructions) |
| **Bug-Tracker-Asaf Kamber.xlsx** | Log of RTL issues found during verification |
| **Verification-Plan-CPM.pdf** | Verification plan (scope, requirements, strategy, coverage, tests) |
| **Reflection_Report.pdf** | Reflection report (challenges, limitations, future work) |
| **Configurable-Packet-Modifier-CPM-Design-Specification-Version-1.0.pdf** | Design specification |
| **CPM-Final-Project-Verification-Requirements-and-Deliverables.pdf** | Project requirements and deliverables |
| **cpm_registers.csv** | Register map (if used by your flow) |

---

## Tool Requirements

- **Simulator:** QuestaSim (e.g. 2025.1_2) or ModelSim
- **UVM:** UVM 1.1d (or compatible)
- **UVM DPI path:** Set in the run script for your installation (see below).

---

## How to Run

### From Questa GUI

1. Open Questa and change to this folder (the submission root):
   ```
   cd <path-to-Submitted-files>
   ```
2. *(Optional)* Clean and recompile:
   ```
   do scripts/run_clean.do
   ```
3. Run the test (compile + simulate + coverage):
   ```
   do scripts/run_rtl.do
   ```

### From Command Line (no GUI)

From this folder:

```batch
vsim -c -do "do scripts/run_rtl.do; quit -f"
```

Or use the instructions in **docs/RUN_FROM_COMMAND_LINE.md** if you use a batch file.

### Setting the UVM DPI Path

The script uses a hardcoded UVM DPI path. Edit **scripts/run_rtl.do** and set `-sv_lib` to your UVM DPI library, for example:

- Windows: `C:/questasim64_2025.1_2/uvm-1.1d/win64/uvm_dpi`
- Linux: `<questa_install>/uvm-1.1d/linux_x86_64/uvm_dpi`

---

## Run Configuration (Closure)

- **Test:** `cpm_base_test`
- **Plusargs:**
  - `+UVM_TESTNAME=cpm_base_test`
  - `+READY_PROB=80` – output backpressure
  - `+ALLOW_ONE_LEFTOVER=1` – allow one expected packet never received (known with original RTL)
  - `+UVM_VERBOSITY=UVM_LOW` – reduced log volume

---

## Expected Result

- **UVM_ERROR:** 0  
- **UVM_FATAL:** 0  
- **UVM_WARNING:** 3 (expected: drain timeout, one leftover, invariant off-by-one; see reflection report)  
- **Functional coverage:** 100% (MODE, OPCODE, MODE×OPCODE, drop, stall)  
- **Scoreboard:** 0 mismatches; one allowed “leftover” with original RTL  

- **Coverage report:** Written to **coverage_report.txt** in the run directory (or copy to **results/coverage_report.txt**).
- **Assertion report:** **results/assertion_report.txt** – lists assertions (in `cpm_if.sv`) and tool output summary (0 assertion failures; see transcript “Errors: 0”).

---

## RTL Note

Verification was run against the **original RTL** (`cpm_rtl.sv`) without modifying it. The file `cpm_rtl_fixed.sv` is provided only for comparison; it is not used by the main run script. RTL issues are documented in the bug tracker and in the reflection report.

---

## File Layout (for reference)

```
Submitted-files/
├── README.md
├── Bug-Tracker-Asaf Kamber.xlsx
├── Verification-Plan-CPM.pdf
├── Reflection_Report.pdf
├── Configurable-Packet-Modifier-CPM-Design-Specification-Version-1.0.pdf
├── CPM-Final-Project-Verification-Requirements-and-Deliverables.pdf
├── cpm_registers.csv
├── docs/
│   └── RUN_FROM_COMMAND_LINE.md
├── results/
│   ├── assertion_report.txt
│   ├── coverage_report.txt
│   └── transcript_final.txt
├── rtl/
│   ├── cpm_rtl.sv
│   └── cpm_rtl_fixed.sv
├── scripts/
│   ├── run_clean.do
│   └── run_rtl.do
└── tb/
    ├── cpm_if.sv, cpm_pkg.svh, cpm_defines.svh, cpm_seq_item.sv, cpm_tb.sv
    ├── agent_in/
    ├── agent_out/
    ├── env/
    ├── ral/
    ├── seq/
    └── test/
```
