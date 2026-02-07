// ===============================================================================
// File: tb/src/ral/cpm_reg_item.sv
// Description: Sequence Item for the Register Bus Interface.
//              Matches signals in Spec Section 10.
// ===============================================================================

class cpm_reg_item extends uvm_sequence_item;

  // -----------------------------------------------------------------------
  // Signals matching Spec Section 10
  // -----------------------------------------------------------------------
  rand bit [7:0]  addr;      // Byte address
  rand bit [31:0] wdata;     // Write data
  rand bit        write_en;  // 1 = Write, 0 = Read

  // Response fields (captured by Monitor/Driver)
  bit [31:0] rdata;     // Read data
  bit        gnt;       // Grant signal (used for handshake verification)

  // -----------------------------------------------------------------------
  // UVM Automation
  // -----------------------------------------------------------------------
  `uvm_object_utils_begin(cpm_reg_item)
    `uvm_field_int(addr,     UVM_ALL_ON | UVM_HEX)
    `uvm_field_int(wdata,    UVM_ALL_ON | UVM_HEX)
    `uvm_field_int(write_en, UVM_ALL_ON | UVM_HEX)
    `uvm_field_int(rdata,    UVM_ALL_ON | UVM_HEX)
  `uvm_object_utils_end

  function new(string name = "cpm_reg_item");
    super.new(name);
  endfunction

endclass : cpm_reg_item
