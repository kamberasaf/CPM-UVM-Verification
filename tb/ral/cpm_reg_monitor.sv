// ===============================================================================
// File: tb/src/ral/cpm_reg_monitor.sv
// Description: Monitors the Register Bus Interface.
//              Captures transactions for Analysis Port.
// ===============================================================================

class cpm_reg_monitor extends uvm_monitor;
  `uvm_component_utils(cpm_reg_monitor)

  virtual cpm_reg_if.passive vif;
  uvm_analysis_port #(cpm_reg_item) ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual cpm_reg_if)::get(this, "", "reg_vif", vif))
      `uvm_fatal("NOVIF", "Virtual interface not set for reg monitor")
  endfunction

  task run_phase(uvm_phase phase);
    forever begin
      @(posedge vif.clk);
      // Capture only when Grant is high (Handshake complete)
      if (vif.gnt) begin
        cpm_reg_item item = cpm_reg_item::type_id::create("item");
        
        item.write_en = vif.write_en;
        item.addr     = vif.addr;
        item.wdata    = vif.wdata; // Capture Write Data
        item.rdata    = vif.rdata; // Capture Read Data
        item.gnt      = vif.gnt;

        ap.write(item);
      end
    end
  endtask
endclass
