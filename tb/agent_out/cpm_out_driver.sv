// ===============================================================================
// File: cpm_out_driver.sv
// Description: Responder Driver for Output Interface.
//              Drives 'out_ready' to control flow and inject backpressure.
//              Respects interface liveness: never stalls longer than
//              CPM_LIVENESS_BOUND (16) cycles when DUT has valid=1.
// ===============================================================================

class cpm_out_driver extends uvm_driver #(cpm_seq_item);
  `uvm_component_utils(cpm_out_driver)

  virtual cpm_stream_if.slave vif;

  // Configuration: Probability of asserting ready (0-100)
  // 100 = Always Ready (Zero latency)
  // <100 = Random backpressure (stall length capped by liveness bound)
  int ready_probability = 100;

  // Liveness: interface requires (valid && !ready) |-> ##[1:16] ready (or !valid).
  // We must not hold ready=0 for more than 15 cycles while valid=1.
  localparam int LIVENESS_BOUND = 16;
  int unsigned stall_cycles;  // Consecutive cycles with valid=1 and we drove ready=0

  function new(string name = "cpm_out_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual cpm_stream_if)::get(this, "", "out_vif", vif)) begin
      `uvm_fatal("NOVIF", $sformatf("Virtual interface must be set for: %s.vif", get_full_name()))
    end
    void'(uvm_config_db#(int)::get(this, "", "ready_probability", ready_probability));
  endfunction

  task run_phase(uvm_phase phase);
    stall_cycles = 0;
    vif.ready <= 1'b0;

    wait(vif.rst === 0);
    @(posedge vif.clk);

    forever begin
      @(posedge vif.clk);
      drive_ready();
    end
  endtask

  // Drive ready: random backpressure but never stall longer than LIVENESS_BOUND-1
  // cycles while DUT has valid=1 (so liveness assertion passes).
  task drive_ready();
    bit do_ready;
    if (ready_probability >= 100) begin
      do_ready = 1'b1;
    end else begin
      if (vif.valid && !vif.ready)
        stall_cycles++;
      else
        stall_cycles = 0;
      // Force ready before we exceed liveness bound (must accept within 16 cycles)
      if (stall_cycles >= LIVENESS_BOUND - 1)
        do_ready = 1'b1;
      else if ($urandom_range(0, 99) < ready_probability)
        do_ready = 1'b1;
      else
        do_ready = 1'b0;
    end
    vif.ready <= do_ready;
    if (do_ready) stall_cycles = 0;
  endtask

endclass : cpm_out_driver
