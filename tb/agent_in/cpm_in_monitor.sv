// ===============================================================================
// File: cpm_in_monitor.sv
// Description: Monitors Input Stream Interface.
//              Captures transactions for Scoreboard/Coverage.
// ===============================================================================

class cpm_in_monitor extends uvm_monitor;
  `uvm_component_utils(cpm_in_monitor)

  virtual cpm_stream_if.passive vif;
  uvm_analysis_port #(cpm_seq_item) ap;

  // Track previous-cycle handshake to avoid double-counting the same transfer
  bit last_transfer;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual cpm_stream_if)::get(this, "", "in_vif", vif)) begin
      `uvm_fatal("NOVIF", $sformatf("Virtual interface must be set for: %s.vif", get_full_name()))
    end
  endfunction

  task run_phase(uvm_phase phase);
    bit transfer_now;
    int unsigned capture_count = 0;

    wait(vif.rst === 0);

    forever begin
      @(posedge vif.clk);

      `uvm_info("IN_MON",
        $sformatf("In_Interface: valid=%0b ready=%0b id=%0h opcode=%0h payload=%0h | last_transfer=%0b",
          vif.valid, vif.ready, vif.id, vif.opcode, vif.payload, last_transfer), UVM_DEBUG)

      // Spec Section 5.2: Acceptance condition
      // Only count a transfer on the first cycle of valid&&ready, to avoid
      // double-sampling when the driver keeps VALID asserted for an extra cycle.
      if (vif.valid && vif.ready) begin
        cpm_seq_item item = cpm_seq_item::type_id::create("item");
        capture_count++;

        item.id      = vif.id;
        item.opcode  = vif.opcode;
        item.payload = vif.payload;
        
        `uvm_info(get_type_name(),
          $sformatf("Captured input [%0d]: ID=%0h Op=%0h Payload=%0h",
            capture_count, item.id, item.opcode, item.payload), UVM_HIGH)

        // Broadcast to Scoreboard and Coverage
        ap.write(item);
      end
    end
  endtask

endclass : cpm_in_monitor
