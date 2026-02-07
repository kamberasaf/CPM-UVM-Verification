// ===============================================================================
// File: cpm_reg_agent.sv
// Description: Container for Register Driver, Monitor, and Sequencer.
// ===============================================================================

// Standard Sequencer typedef
typedef uvm_sequencer #(cpm_reg_item) cpm_reg_sequencer;

class cpm_reg_agent extends uvm_agent;
  `uvm_component_utils(cpm_reg_agent)

  cpm_reg_driver    driver;
  cpm_reg_monitor   monitor;
  cpm_reg_sequencer sequencer;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    monitor = cpm_reg_monitor::type_id::create("monitor", this);

    if (get_is_active() == UVM_ACTIVE) begin
      driver    = cpm_reg_driver::type_id::create("driver", this);
      sequencer = cpm_reg_sequencer::type_id::create("sequencer", this);
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    if (get_is_active() == UVM_ACTIVE) begin
      driver.seq_item_port.connect(sequencer.seq_item_export);
    end
  endfunction

endclass : cpm_reg_agent
