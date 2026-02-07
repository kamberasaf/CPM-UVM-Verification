// ===============================================================================
// File: cpm_in_agent.sv
// Description: Container for Input Driver, Monitor, and Sequencer.
// ===============================================================================

// Standard Sequencer typedef
typedef uvm_sequencer #(cpm_seq_item) cpm_sequencer;

class cpm_in_agent extends uvm_agent;
  `uvm_component_utils(cpm_in_agent)

  cpm_in_driver     driver;
  cpm_in_monitor    monitor;
  cpm_sequencer     sequencer;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    monitor = cpm_in_monitor::type_id::create("monitor", this);

    if (get_is_active() == UVM_ACTIVE) begin
      driver    = cpm_in_driver::type_id::create("driver", this);
      sequencer = cpm_sequencer::type_id::create("sequencer", this);
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    if (get_is_active() == UVM_ACTIVE) begin
      driver.seq_item_port.connect(sequencer.seq_item_export);
    end
  endfunction

endclass : cpm_in_agent
