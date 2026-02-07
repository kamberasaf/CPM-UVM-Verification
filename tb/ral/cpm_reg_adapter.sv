// ===============================================================================
// File: tb/src/ral/cpm_reg_adapter.sv
// Description: UVM Register Adapter.
//              Converts between uvm_reg_bus_op and cpm_reg_item.
// ===============================================================================

class cpm_reg_adapter extends uvm_reg_adapter;
  `uvm_object_utils(cpm_reg_adapter)

  function new(string name = "cpm_reg_adapter");
    super.new(name);
    supports_byte_enable = 0;
    provides_responses   = 0;
  endfunction

  virtual function uvm_sequence_item reg2bus(const ref uvm_reg_bus_op rw);
    cpm_reg_item item = cpm_reg_item::type_id::create("item");
    item.write_en = (rw.kind == UVM_WRITE);
    item.addr     = rw.addr;
    item.wdata    = rw.data;
    return item;
  endfunction

  virtual function void bus2reg(uvm_sequence_item bus_item, ref uvm_reg_bus_op rw);
    cpm_reg_item item;
    if (!$cast(item, bus_item)) `uvm_fatal("CAST", "Error casting bus item")
    
    rw.kind = item.write_en ? UVM_WRITE : UVM_READ;
    rw.addr = item.addr;
    rw.data = item.write_en ? item.wdata : item.rdata;
    rw.status = UVM_IS_OK;

<<<<<<< HEAD
    rw.n_bits = 32;
    rw.byte_en = 4'hF;
=======
    rw.n_bits = 32;       // Force 32-bit width
    rw.byte_en = 4'hF;    // Force 4-byte enable (matches register map)
    // ====================
>>>>>>> 039a218325725816f7450277206503b41188e757
  endfunction
endclass
