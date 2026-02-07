// ===============================================================================
// File: cpm_tb.sv
// Description: Top-level CPM Testbench Module.
//              Instantiates DUT, interfaces, generates clock/reset.
//              Configures UVM environment and runs test.
// ===============================================================================

module cpm_tb;

  import uvm_pkg::*;
  import cpm_pkg::*;
  `include "uvm_macros.svh"

  // -----------------------------------------------------------------------
  // Clock and Reset Signals
  // -----------------------------------------------------------------------
  logic clk;
  logic rst;

  // -----------------------------------------------------------------------
  // Stream Interfaces
  // -----------------------------------------------------------------------
  cpm_stream_if in_vif  (clk, rst);
  cpm_stream_if out_vif (clk, rst);

  // -----------------------------------------------------------------------
  // Register Bus Interface
  // -----------------------------------------------------------------------
  cpm_reg_if reg_vif (clk, rst);

  // -----------------------------------------------------------------------
  // DUT Instantiation
  // Note: Replace 'cpm_rtl' with actual RTL module name from spec
  // -----------------------------------------------------------------------
  cpm dut (
    .clk        ( clk          ),
    .rst        ( rst          ),
    .in_valid   ( in_vif.valid ),
    .in_ready   ( in_vif.ready ),
    .in_id      ( in_vif.id    ),
    .in_opcode  ( in_vif.opcode ),
    .in_payload ( in_vif.payload ),
    .out_valid  ( out_vif.valid ),
    .out_ready  ( out_vif.ready ),
    .out_id     ( out_vif.id    ),
    .out_opcode ( out_vif.opcode ),
    .out_payload( out_vif.payload ),
    
    // REG INTERFACE
    .req        ( reg_vif.req    ),
    .gnt        ( reg_vif.gnt    ), 
    .write_en   ( reg_vif.write_en ),
    .addr       ( reg_vif.addr   ),
    .wdata      ( reg_vif.wdata  ),
    .rdata      ( reg_vif.rdata  )
  );

  // -----------------------------------------------------------------------
  // Clock Generation (100 MHz)
  // -----------------------------------------------------------------------
  initial begin
    clk = 1'b0;
    forever #5ns clk = ~clk; // 10ns period = 100 MHz
  end

  // -----------------------------------------------------------------------
  // Reset Sequence
  // -----------------------------------------------------------------------
  initial begin
    rst = 1'b1;
    repeat(5) @(posedge clk);
    rst = 1'b0;
  end

  // -----------------------------------------------------------------------
  // UVM Configuration and Setup
  // -----------------------------------------------------------------------
  initial begin
    // Place interface handles into config database
    uvm_config_db#(virtual cpm_stream_if)::set(null, "*", "in_vif",  in_vif);
    uvm_config_db#(virtual cpm_stream_if)::set(null, "*", "out_vif", out_vif);
    uvm_config_db#(virtual cpm_reg_if)::set(null, "*", "reg_vif", reg_vif);

    // Optional: Set verbosity
    uvm_top.set_report_verbosity_level(UVM_HIGH);

    // Run the test: +UVM_TESTNAME on command line, or default cpm_base_test
    if ($test$plusargs("UVM_TESTNAME"))
      run_test();  // UVM reads test name from +UVM_TESTNAME=...
    else
      run_test("cpm_base_test");
  end

  // -----------------------------------------------------------------------
  // Simulation Control (allow UVM to finish: sequence + drain can exceed 20ms)
  // -----------------------------------------------------------------------
  initial begin
    #50ms;
    $display("*** Simulation TIMEOUT ***");
    $finish();
  end

endmodule : cpm_tb
