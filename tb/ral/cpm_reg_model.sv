// ===============================================================================
// File: cpm_reg_model.sv
// Description: UVM Register Model for CPM.
//              Matches Register Map in Spec Section 10.7 - 10.11.
// ===============================================================================

import uvm_pkg::*;
`include "uvm_macros.svh"

// -----------------------------------------------------------------------------
// Register: CTRL (Offset 0x00)
// Spec Section 10.8
// -----------------------------------------------------------------------------
class cpm_reg_ctrl extends uvm_reg;
  `uvm_object_utils(cpm_reg_ctrl)

  rand uvm_reg_field enable;
  rand uvm_reg_field soft_rst;

  function new(string name = "cpm_reg_ctrl");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    enable = uvm_reg_field::type_id::create("enable");
    soft_rst = uvm_reg_field::type_id::create("soft_rst");

    // configure(parent, size, lsb_pos, access, volatile, reset, has_reset, is_rand, individually_accessible)
    enable.configure(this, 1, 0, "RW", 0, 1'b0, 1, 1, 1);
    soft_rst.configure(this, 1, 1, "RW", 0, 1'b0, 1, 1, 1);
  endfunction
endclass

// -----------------------------------------------------------------------------
// Register: MODE (Offset 0x04)
// Spec Section 10.9
// -----------------------------------------------------------------------------
class cpm_reg_mode extends uvm_reg;
  `uvm_object_utils(cpm_reg_mode)

  rand uvm_reg_field mode;

  function new(string name = "cpm_reg_mode");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    mode = uvm_reg_field::type_id::create("mode");
    mode.configure(this, 2, 0, "RW", 0, 2'b00, 1, 1, 1);
  endfunction
endclass

// -----------------------------------------------------------------------------
// Register: PARAMS (Offset 0x08)
// Spec Section 11.0
// -----------------------------------------------------------------------------
class cpm_reg_params extends uvm_reg;
  `uvm_object_utils(cpm_reg_params)

  rand uvm_reg_field mask;
  rand uvm_reg_field add_const;

  function new(string name = "cpm_reg_params");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    mask      = uvm_reg_field::type_id::create("mask");
    add_const = uvm_reg_field::type_id::create("add_const");

    mask.configure(this, 16, 0,  "RW", 0, 16'h0000, 1, 1, 1);
    add_const.configure(this, 16, 16, "RW", 0, 16'h0000, 1, 1, 1);
  endfunction
endclass

// -----------------------------------------------------------------------------
// Register: DROP_CFG (Offset 0x0C)
// Spec Section 11.1
// -----------------------------------------------------------------------------
class cpm_reg_drop_cfg extends uvm_reg;
  `uvm_object_utils(cpm_reg_drop_cfg)

  rand uvm_reg_field drop_en;
  rand uvm_reg_field drop_opcode;

  function new(string name = "cpm_reg_drop_cfg");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    drop_en     = uvm_reg_field::type_id::create("drop_en");
    drop_opcode = uvm_reg_field::type_id::create("drop_opcode");

    drop_en.configure(this, 1, 0, "RW", 0, 1'b0, 1, 1, 1);
    drop_opcode.configure(this, 4, 4, "RW", 0, 4'h0, 1, 1, 1);
  endfunction
endclass

// -----------------------------------------------------------------------------
// Register: STATUS (Offset 0x10) - Read Only
// Spec Section 10.7
// -----------------------------------------------------------------------------
class cpm_reg_status extends uvm_reg;
  `uvm_object_utils(cpm_reg_status)

  uvm_reg_field busy;

  function new(string name = "cpm_reg_status");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    busy = uvm_reg_field::type_id::create("busy");
    // Access is "RO" (Read Only)
    busy.configure(this, 1, 0, "RO", 1, 1'b0, 1, 0, 1);
  endfunction
endclass

// -----------------------------------------------------------------------------
// Generic Counter Register (Used for COUNT_IN, COUNT_OUT, DROPPED_COUNT)
// Spec Section 10.8
// -----------------------------------------------------------------------------
class cpm_reg_counter extends uvm_reg;
  `uvm_object_utils(cpm_reg_counter)

  uvm_reg_field value;

  function new(string name = "cpm_reg_counter");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    value = uvm_reg_field::type_id::create("value");
    // Access is "RO", Volatile = 1 (DUT updates it)
    value.configure(this, 32, 0, "RO", 1, 32'h0, 1, 0, 1);
  endfunction
endclass

// -----------------------------------------------------------------------------
// Block: CPM Register Block (Top Level Model)
// -----------------------------------------------------------------------------
class cpm_reg_block extends uvm_reg_block;
  `uvm_object_utils(cpm_reg_block)

  rand cpm_reg_ctrl      ctrl;
  rand cpm_reg_mode      mode;
  rand cpm_reg_params    params;
  rand cpm_reg_drop_cfg  drop_cfg;

  cpm_reg_status         status;
  cpm_reg_counter        count_in;
  cpm_reg_counter        count_out;
  cpm_reg_counter        dropped_count;

  uvm_reg_map            reg_map;

  function new(string name = "cpm_reg_block");
    super.new(name, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    // 1. Create Instances
    ctrl          = cpm_reg_ctrl::type_id::create("ctrl");
    mode          = cpm_reg_mode::type_id::create("mode");
    params        = cpm_reg_params::type_id::create("params");
    drop_cfg      = cpm_reg_drop_cfg::type_id::create("drop_cfg");
    status        = cpm_reg_status::type_id::create("status");
    count_in      = cpm_reg_counter::type_id::create("count_in");
    count_out     = cpm_reg_counter::type_id::create("count_out");
    dropped_count = cpm_reg_counter::type_id::create("dropped_count");

    // 2. Configure Instances
    ctrl.configure(this);
    mode.configure(this);
    params.configure(this);
    drop_cfg.configure(this);
    status.configure(this);
    count_in.configure(this);
    count_out.configure(this);
    dropped_count.configure(this);

    // 3. Create Map (Name, Base Addr, Bytes per Bus, Endian)
    // Spec Section 10 defines 8-bit addresses but 32-bit data widths.
    // Usually, this implies a 4-byte bus width.
    reg_map = create_map("reg_map", 'h0, 4, UVM_LITTLE_ENDIAN);

    // 4. Add Registers to Map (Instance, Offset, Rights)
    // Offsets from Spec Section 10.7
    reg_map.add_reg(ctrl,          'h00, "RW");
    reg_map.add_reg(mode,          'h04, "RW");
    reg_map.add_reg(params,        'h08, "RW");
    reg_map.add_reg(drop_cfg,      'h0C, "RW");
    reg_map.add_reg(status,        'h10, "RO");
    reg_map.add_reg(count_in,      'h14, "RO");
    reg_map.add_reg(count_out,     'h18, "RO");
    reg_map.add_reg(dropped_count, 'h1C, "RO");

    lock_model();
  endfunction
endclass
