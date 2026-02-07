// ===============================================================================
// File: cpm_virtual_sequencer.sv
// Description: Virtual Sequencer for CPM Testbench.
//              Provides centralized access to all sequencers and register block.
//              Enables top-level virtual sequences to coordinate stimulus.
// ===============================================================================

typedef uvm_sequencer #(cpm_seq_item) cpm_input_sequencer;

class cpm_virtual_sequencer extends uvm_sequencer #(uvm_sequence_item);
  `uvm_component_utils(cpm_virtual_sequencer)

  // -----------------------------------------------------------------------
  // Sequencer Handles
  // -----------------------------------------------------------------------
  cpm_input_sequencer  in_seqr;    // Input stream sequencer
  cpm_reg_sequencer    reg_seqr;   // Register sequencer for RAL

  // -----------------------------------------------------------------------
  // Register Block Handle
  // -----------------------------------------------------------------------
  cpm_reg_block        reg_block;   // RAL register model

  function new(string name = "cpm_virtual_sequencer", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  // Note: This sequencer does not execute items itself.
  // Virtual sequences running on this sequencer will use the child
  // sequencer handles to start sub-sequences on specific agents.

endclass : cpm_virtual_sequencer
