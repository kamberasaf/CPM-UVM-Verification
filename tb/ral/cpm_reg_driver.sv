// ===============================================================================
// File: cpm_reg_driver.sv
// Description: Driver for CPM Register Bus Interface.
//              Handles REQ/GNT handshake protocol.
// ===============================================================================

class cpm_reg_driver extends uvm_driver #(cpm_reg_item);
  `uvm_component_utils(cpm_reg_driver)

  virtual cpm_reg_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual cpm_reg_if)::get(this, "", "reg_vif", vif))
      `uvm_fatal("NOVIF", "Could not get reg_vif")
  endfunction

  virtual task run_phase(uvm_phase phase);
    // Initialize signals
    vif.req      <= 0;
    vif.write_en <= 0;
    vif.addr     <= 0;
    vif.wdata    <= 0;

    wait(vif.rst === 0);
    @(posedge vif.clk);

    forever begin
      seq_item_port.get_next_item(req);
      
      // 1. Drive Request Phase
      @(posedge vif.clk);
      vif.req      <= 1;
      vif.write_en <= req.write_en;
      vif.addr     <= req.addr;
      if (req.write_en) vif.wdata <= req.wdata;

      // 2. Wait for Grant
      do begin
        @(posedge vif.clk);
      end while (vif.gnt === 0);

      // 3. Capture Read Data (if reading)
      if (!req.write_en) req.rdata = vif.rdata;

      // 4. Clear Request (Handshake complete)
      vif.req      <= 0;
      vif.write_en <= 0;
      
      seq_item_port.item_done();
    end
  endtask
endclass : cpm_reg_driver
