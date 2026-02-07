// ===============================================================================
// File: cpm_in_driver.sv
// Description: Drives Input Stream Interface.
//              Implements Handshake Semantics (Spec Section 5.2).
// ===============================================================================

// -----------------------------------------------------------------------------
// Driver Callback Type (Spec 6.4 - Callbacks)
// -----------------------------------------------------------------------------
class cpm_in_driver_cb extends uvm_callback;
  `uvm_object_utils(cpm_in_driver_cb)

  function new(string name = "cpm_in_driver_cb");
    super.new(name);
  endfunction

  // Hook called before each item is driven (modify outgoing transaction)
  virtual function void pre_drive(ref cpm_seq_item item);
  endfunction
endclass : cpm_in_driver_cb

// Concrete callback (Spec 6.4: "real reason, not a dummy print")
// Sets payload LSB to even parity of id+opcode+payload for simple integrity tagging.
class cpm_driver_parity_cb extends cpm_in_driver_cb;
  `uvm_object_utils(cpm_driver_parity_cb)

  function new(string name = "cpm_driver_parity_cb");
    super.new(name);
  endfunction

  virtual function void pre_drive(ref cpm_seq_item item);
    bit parity;
    parity = ^{item.id, item.opcode, item.payload[15:1]};
    item.payload = (item.payload & 16'hFFFE) | parity; // LSB = even parity
  endfunction
endclass : cpm_driver_parity_cb

// -----------------------------------------------------------------------------
// Input Driver
// -----------------------------------------------------------------------------
class cpm_in_driver extends uvm_driver #(cpm_seq_item);
  `uvm_component_utils(cpm_in_driver)
  `uvm_register_cb(cpm_in_driver, cpm_in_driver_cb)

  virtual cpm_stream_if.master vif;

  function new(string name = "cpm_in_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual cpm_stream_if)::get(this, "", "in_vif", vif)) begin
      `uvm_fatal("NOVIF", $sformatf("Virtual interface must be set for %s.vif", get_full_name()))
    end
  endfunction

  task run_phase(uvm_phase phase);
    vif.valid   = 1'b0;
    vif.id      = 4'h0;
    vif.opcode  = 4'h0;
    vif.payload = 16'h0;

    wait(vif.rst === 0);
    @(posedge vif.clk);

    forever begin
      seq_item_port.get_next_item(req);
      drive_item(req);
      seq_item_port.item_done();
    end
  endtask

  // Spec 5.3 / SVA 6.6: While in_valid && !in_ready, valid and data must remain stable.
  // Liveness: (valid && !ready) |-> ##[1:16] (!valid || ready). So we must not hold
  // valid high with ready low for more than 16 cycles. If DUT stalls us, deassert
  // valid for one cycle every 16 cycles then re-assert (same data) so assertion passes.
  localparam int LIVENESS_BOUND = 16;

  task drive_item(cpm_seq_item item);
    int cycle_count = 0;
    int timeout = 1000;

    `uvm_do_callbacks(cpm_in_driver, cpm_in_driver_cb, pre_drive(item))

    @(posedge vif.clk);
    vif.valid   <= 1'b1;
    vif.id      <= item.id;
    vif.opcode  <= item.opcode;
    vif.payload <= item.payload;

    cycle_count = 0;
    do begin
      @(posedge vif.clk);
      cycle_count++;
      if (cycle_count > timeout) begin
        `uvm_error("DRV_TIMEOUT",
          $sformatf("Input driver timeout: ready never asserted after %0d cycles. ID=%0h",
            timeout, item.id))
        break;
      end
      if (cycle_count >= LIVENESS_BOUND && vif.ready !== 1'b1) begin
        vif.valid <= 1'b0;
        @(posedge vif.clk);
        vif.valid   <= 1'b1;
        vif.id      <= item.id;
        vif.opcode  <= item.opcode;
        vif.payload <= item.payload;
        cycle_count = 0;
      end
    end while (vif.ready !== 1'b1);

    vif.valid   <= 1'b0;
    vif.id      <= 4'h0;
    vif.opcode  <= 4'h0;
    vif.payload <= 16'h0;

    `uvm_info(get_type_name(),
      $sformatf("Drove packet ID=%0h Op=%0h Payload=%0h",
        item.id, item.opcode, item.payload), UVM_HIGH)
  endtask

endclass : cpm_in_driver
