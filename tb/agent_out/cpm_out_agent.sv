// ===============================================================================
// File: cpm_out_agent.sv
// Description: Container for Output Driver and Monitor.
// ===============================================================================

class cpm_out_agent extends uvm_agent;
  `uvm_component_utils(cpm_out_agent)

  cpm_out_driver    driver;
  cpm_out_monitor   monitor;
  // Note: Output agent technically doesn't need a sequencer because it doesn't
  // execute sequences in the traditional sense (it just responds).
  // However, we often keep it if we want to control backpressure sequences later.

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    monitor = cpm_out_monitor::type_id::create("monitor", this);

    if (get_is_active() == UVM_ACTIVE) begin
      driver = cpm_out_driver::type_id::create("driver", this);
    end
  endfunction

  // No connection phase needed strictly for driver/sequencer here unless
  // we add a "Response Sequence" later.
endclass : cpm_out_agent
