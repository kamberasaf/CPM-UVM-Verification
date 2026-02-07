// ===============================================================================
// File: cpm_seq_item.sv
// Description: UVM Sequence Item representing a single CPM packet.
//              Matches Packet Definition in Spec Section 3.
// ===============================================================================

class cpm_seq_item extends uvm_sequence_item;

  // -----------------------------------------------------------------------
  // Data Members (Randomizable)
  // -----------------------------------------------------------------------
  // Spec Section 3: Packet Definition
  rand bit [3:0]  id;       // Transaction identifier
  rand bit [3:0]  opcode;   // Operation / classification field
  rand bit [15:0] payload;  // Data payload

  // Control knob for analysis (not sent to DUT, but useful for verification)
  // Example: You might want to flag a packet as "intended to be dropped"
  bit intended_drop;

  // -----------------------------------------------------------------------
  // UVM Automation Macros
  // -----------------------------------------------------------------------
  `uvm_object_utils_begin(cpm_seq_item)
    `uvm_field_int(id,      UVM_ALL_ON | UVM_HEX)
    `uvm_field_int(opcode,  UVM_ALL_ON | UVM_HEX)
    `uvm_field_int(payload, UVM_ALL_ON | UVM_HEX)
  `uvm_object_utils_end

  // -----------------------------------------------------------------------
  // Constraints
  // -----------------------------------------------------------------------

  // Constraint: Reasonable distribution of opcodes
  // While the DUT allows any 4-bit opcode, we often want to focus on
  // specific values that might be used for dropping.
  constraint c_opcode_dist {
    // Soft constraint allows tests to override this if they need specific values
    soft opcode inside {[0:15]};
  }

  // -----------------------------------------------------------------------
  // Constructor
  // -----------------------------------------------------------------------
  function new(string name = "cpm_seq_item");
    super.new(name);
  endfunction

endclass : cpm_seq_item
