// ===============================================================================
// File: cpm_out_monitor.sv
// Description: Monitors Output Stream Interface.
//              Captures observed packets for Scoreboard.
// ===============================================================================

class cpm_out_monitor extends uvm_monitor;
  `uvm_component_utils(cpm_out_monitor)

  virtual cpm_stream_if.passive vif;
  uvm_analysis_port #(cpm_seq_item) ap;

  int unsigned packet_count = 0;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual cpm_stream_if)::get(this, "", "out_vif", vif)) begin
      `uvm_fatal("NOVIF", $sformatf("Virtual interface must be set for: %s.vif", get_full_name()))
    end
  endfunction

  task run_phase(uvm_phase phase);
    bit is_all_zeros;
    cpm_seq_item item;

    wait(vif.rst === 0);

    forever begin
      // Sample at negedge so valid/ready are stable (avoids race with driver NBA at posedge)
      @(negedge vif.clk);

      // Spec Section 6.2: A packet is transferred when out_valid && out_ready.
      if (vif.valid && vif.ready) begin
        item = cpm_seq_item::type_id::create("item");
        packet_count++;

        item.id      = vif.id;
        item.opcode  = vif.opcode;
        item.payload = vif.payload;

        is_all_zeros = (item.id == 0 && item.opcode == 0 && item.payload == 0);

        `uvm_info(get_type_name(),
          $sformatf("Captured output [%0d]: ID=%0h Op=%0h Payload=%0h | ALL_ZEROS=%0b",
            packet_count, item.id, item.opcode, item.payload, is_all_zeros), UVM_HIGH)

        ap.write(item);
      end
    end
  endtask

endclass : cpm_out_monitor
