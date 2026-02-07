// ===============================================================================
// File: cpm_coverage.sv
// Description: Functional coverage subscriber for CPM.
//              Implements MODE, OPCODE, MODE×OPCODE, drop and stall coverage.
// ===============================================================================

class cpm_coverage extends uvm_subscriber #(cpm_seq_item);
  `uvm_component_utils(cpm_coverage)

  // Handle to RAL for configuration sampling
  cpm_reg_block              reg_block;

  // Virtual interfaces for stall/backpressure coverage
  virtual cpm_stream_if.passive in_vif;
  virtual cpm_stream_if.passive out_vif;

  // Local sample variables
  int unsigned sample_mode;
  int unsigned sample_opcode;
  bit          sample_drop;

  // Stall/backpressure sample variables
  bit          in_stall_flag;
  bit          out_stall_flag;

  // Covergroup for packet-level coverage
  covergroup cpm_cg;
    cp_mode   : coverpoint sample_mode {
      bins MODE_PASS = {0};
      bins MODE_XOR  = {1};
      bins MODE_ADD  = {2};
      bins MODE_ROT  = {3};
    }

    cp_opcode : coverpoint sample_opcode {
      bins low    = {[0:3]};
      bins mid    = {[4:11]};
      bins high   = {[12:15]};
    }

    mode_x_opcode : cross cp_mode, cp_opcode;

    cp_drop : coverpoint sample_drop {
      bins not_dropped = {0};
      bins dropped     = {1};
    }
  endgroup
  //
  // Stall/backpressure coverage – sampled explicitly in write(), with
  // null-checks on virtual interfaces to avoid null-handle issues.
  covergroup stall_cg;
    cp_in_stall  : coverpoint in_stall_flag {
      bins no_stall = {0};
      bins stalled  = {1};
    }

    cp_out_stall : coverpoint out_stall_flag {
      bins no_stall = {0};
      bins stalled  = {1};
    }
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    cpm_cg   = new;
    stall_cg = new;
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    // Optional: get virtual interfaces for stall coverage
    void'(uvm_config_db#(virtual cpm_stream_if)::get(this, "", "in_vif",  in_vif));
    void'(uvm_config_db#(virtual cpm_stream_if)::get(this, "", "out_vif", out_vif));
  endfunction

  // Called when input monitor publishes a packet
  virtual function void write(cpm_seq_item t);
    // Use package globals (set by virtual sequence) so coverage matches actual config at accept time
    sample_mode   = cpm_pkg::global_scb_mode;
    sample_opcode = t.opcode;
    sample_drop   = (cpm_pkg::global_scb_drop_en && (t.opcode == cpm_pkg::global_scb_drop_opcode));

    cpm_cg.sample();
    // Stall bins are sampled in run_phase (every cycle) so we see valid&&!ready
  endfunction

  // Sample stall coverage every clock so both no_stall and stalled bins can hit.
  virtual task run_phase(uvm_phase phase);
    if (in_vif == null || out_vif == null) return;
    wait (in_vif.rst === 0);
    forever begin
      @(negedge in_vif.clk);
      in_stall_flag  = (in_vif.valid  && !in_vif.ready);
      out_stall_flag = (out_vif.valid && !out_vif.ready);
      stall_cg.sample();
    end
  endtask

endclass : cpm_coverage

