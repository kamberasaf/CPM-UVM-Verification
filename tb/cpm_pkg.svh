package cpm_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  `include "cpm_defines.svh"

  // ========================================================== 
  // GLOBAL: Shared configuration state for scoreboard.
  // cpm_final_seq sets these before each phase so the scoreboard
  // sees correct mode/mask/add_const/drop (RAL mirror can lag).
  // ==========================================================
  int global_scb_mode = 0;
  int global_scb_mask = 0;
  int global_scb_add_const = 0;
  int global_scb_drop_en = 0;
  int global_scb_drop_opcode = 0;
  
  // ==========================================================
  // 1. REGISTER LAYER (Defined INLINE to fix dependencies)
  // ==========================================================
  `include "ral/cpm_reg_item.sv"
  `include "ral/cpm_reg_model.sv"

  // --- FIXED ADAPTER (Forces 32-bit access) ---
  class cpm_reg_adapter extends uvm_reg_adapter;
    `uvm_object_utils(cpm_reg_adapter)
    function new(string name="cpm_reg_adapter");
      super.new(name);
      supports_byte_enable = 0; provides_responses = 0;
    endfunction
    virtual function uvm_sequence_item reg2bus(const ref uvm_reg_bus_op rw);
      cpm_reg_item item = cpm_reg_item::type_id::create("item");
      item.write_en = (rw.kind == UVM_WRITE);
      item.addr = rw.addr; item.wdata = rw.data;
      return item;
    endfunction
    virtual function void bus2reg(uvm_sequence_item bus_item, ref uvm_reg_bus_op rw);
      cpm_reg_item item;
      if (!$cast(item, bus_item)) `uvm_fatal("CAST", "Error")
      rw.kind = item.write_en ? UVM_WRITE : UVM_READ;
      rw.addr = item.addr;
      rw.data = item.write_en ? item.wdata : item.rdata;
      rw.status = UVM_IS_OK;
      rw.n_bits = 32; rw.byte_en = 4'hF; // CRITICAL FIX
    endfunction
  endclass

  // --- FIXED DRIVER (Handshake Protocol) ---
  class cpm_reg_driver extends uvm_driver #(cpm_reg_item);
    `uvm_component_utils(cpm_reg_driver)
    virtual cpm_reg_if vif;
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual cpm_reg_if)::get(this, "", "reg_vif", vif))
        `uvm_fatal("NOVIF", "Missing reg_vif")
    endfunction
    virtual task run_phase(uvm_phase phase);
      cpm_reg_item req;
      vif.req <= 0; vif.write_en <= 0; vif.addr <= 0; vif.wdata <= 0;
      wait(vif.rst === 0); @(posedge vif.clk);
      forever begin
        seq_item_port.get_next_item(req);
        @(posedge vif.clk);
        vif.req <= 1; vif.write_en <= req.write_en; vif.addr <= req.addr;
        if (req.write_en) vif.wdata <= req.wdata;
        do begin @(posedge vif.clk); end while (vif.gnt === 0);
        if (!req.write_en) req.rdata = vif.rdata;
        vif.req <= 0; vif.write_en <= 0;
        seq_item_port.item_done();
      end
    endtask
  endclass

  `include "ral/cpm_reg_monitor.sv"
  `include "ral/cpm_reg_agent.sv" // Now safe to include

  // ==========================================================
  // 2. AGENTS & ENV
  // ==========================================================
  `include "cpm_seq_item.sv"
  `include "agent_in/cpm_in_driver.sv"
  `include "agent_in/cpm_in_monitor.sv"
  `include "agent_in/cpm_in_agent.sv"
  `include "agent_out/cpm_out_driver.sv"
  `include "agent_out/cpm_out_monitor.sv"
  `include "agent_out/cpm_out_agent.sv"
  
  `include "test/cpm_scoreboard.sv"
  `include "test/cpm_coverage.sv"
  
  `include "env/cpm_virtual_sequencer.sv"
  `include "env/cpm_env.sv"

  // ==========================================================
  // 3. SEQUENCES (Defined INLINE to fix Coverage/Scoreboard)
  // ==========================================================
  `include "seq/cpm_base_seqs.sv" // Must define base_traffic_seq first

  class cpm_config_seq extends uvm_sequence;
    `uvm_object_utils(cpm_config_seq)
    cpm_reg_block reg_block;
    rand bit [1:0] mode; rand bit [15:0] mask, add_const;
    rand bit drop_en; rand bit [3:0] drop_opcode;
    function new(string name="cpm_config_seq"); super.new(name); endfunction
    task body();
      uvm_status_e s; uvm_reg_data_t d;
      // Write then Read to sync RAL
      reg_block.mode.write(s, {30'b0, mode}); reg_block.mode.read(s, d);
      reg_block.params.write(s, {add_const, mask}); reg_block.params.read(s, d);
      reg_block.drop_cfg.write(s, {24'b0, drop_opcode, 3'b0, drop_en}); reg_block.drop_cfg.read(s, d);
      reg_block.ctrl.write(s, 1); 
      void'(reg_block.ctrl.predict(1)); // Predict enable
      `uvm_info("CFG", $sformatf("Mode=%0d Drop=%0b", mode, drop_en), UVM_LOW)
    endtask
  endclass

  class cpm_final_seq extends uvm_sequence #(uvm_sequence_item);
    `uvm_object_utils(cpm_final_seq)
    cpm_virtual_sequencer p_seqr;
    function new(string name="cpm_final_seq"); super.new(name); endfunction
    virtual task pre_body(); cast_check(); endtask
    virtual function void cast_check(); 
      if(!$cast(p_seqr, m_sequencer)) `uvm_fatal("CAST","Fail"); 
    endfunction

    virtual task body();
      cpm_config_seq cfg = cpm_config_seq::type_id::create("cfg");
      base_traffic_seq traf = base_traffic_seq::type_id::create("traf");
      stress_seq stress = stress_seq::type_id::create("stress");
      drop_seq drop = drop_seq::type_id::create("drop");
      uvm_reg_hw_reset_seq rst = uvm_reg_hw_reset_seq::type_id::create("rst");
      
      cfg.reg_block = p_seqr.reg_block; rst.model = p_seqr.reg_block;
      rst.start(p_seqr.reg_seqr); // Reset

      // 1. Pass — set globals so scoreboard sees config (RAL mirror can lag)
      void'(cfg.randomize() with {mode==0; drop_en==0;});
      global_scb_mode = cfg.mode; global_scb_mask = cfg.mask; global_scb_add_const = cfg.add_const;
      global_scb_drop_en = 0; global_scb_drop_opcode = 0;
      cfg.start(p_seqr.reg_seqr);
      traf.num_packets=50; traf.start(p_seqr.in_seqr); #1us;

      // 2. XOR
      `uvm_info("SEQ", "PHASE: XOR", UVM_LOW)
      void'(cfg.randomize() with {mode==1; drop_en==0;});
      global_scb_mode = cfg.mode; global_scb_mask = cfg.mask; global_scb_add_const = cfg.add_const;
      global_scb_drop_en = 0;
      cfg.start(p_seqr.reg_seqr);
      traf.start(p_seqr.in_seqr); #1us;

      // 3. ROT
      `uvm_info("SEQ", "PHASE: ROT", UVM_LOW)
      void'(cfg.randomize() with {mode==3; drop_en==0;});
      global_scb_mode = cfg.mode; global_scb_mask = cfg.mask; global_scb_add_const = cfg.add_const;
      cfg.start(p_seqr.reg_seqr);
      traf.start(p_seqr.in_seqr); #1us;

      // 4. ADD
      `uvm_info("SEQ", "PHASE: ADD", UVM_LOW)
      void'(cfg.randomize() with {mode==2; drop_en==0;});
      global_scb_mode = cfg.mode; global_scb_mask = cfg.mask; global_scb_add_const = cfg.add_const;
      cfg.start(p_seqr.reg_seqr);
      stress.start(p_seqr.in_seqr); #100us;

      // 5. DROP
      `uvm_info("SEQ", "PHASE: DROP", UVM_LOW)
      void'(cfg.randomize() with {drop_en==1; drop_opcode==4'hE;});
      global_scb_drop_en = 1; global_scb_drop_opcode = 14; // 0xE
      cfg.start(p_seqr.reg_seqr);
      void'(p_seqr.reg_block.drop_cfg.predict(32'hE1));
      uvm_config_db#(int)::set(null, "uvm_test_top.env.scoreboard", "scb_drop_en", 1);
      uvm_config_db#(int)::set(null, "uvm_test_top.env.scoreboard", "scb_drop_opcode", 14);
      #1us;
      drop.target_opcode=4'hE; drop.start(p_seqr.in_seqr);
      #2ms; // drain: allow all non-dropped packets to leave DUT pipeline
      
      `uvm_info("SEQ", "DONE", UVM_LOW)
    endtask
  endclass

  // Synchronized version with RAL mirror delays
  class cpm_final_seq_sync extends uvm_sequence #(uvm_sequence_item);
    `uvm_object_utils(cpm_final_seq_sync)

    cpm_virtual_sequencer p_sequencer;
    int RAL_SYNC_DELAY_US = 50;

    function new(string name = "cpm_final_seq_sync");
      super.new(name);
    endfunction

    virtual task pre_body();
      if (!$cast(p_sequencer, m_sequencer)) 
        `uvm_fatal("NOVSEQ", "Must run on cpm_virtual_sequencer")
      if (uvm_config_db#(int)::get(null, get_full_name(), "ral_sync_delay_us", RAL_SYNC_DELAY_US)) begin
        `uvm_info("SYNC", $sformatf("Using RAL_SYNC_DELAY_US = %0d from config_db", RAL_SYNC_DELAY_US), UVM_LOW)
      end
    endtask

    virtual task body();
      uvm_status_e         status;
      uvm_reg_hw_reset_seq reg_reset;
      cpm_config_seq       cfg_seq;
      base_traffic_seq     traffic_seq;
      stress_seq           stress;
      drop_seq             drop;

      reg_reset = uvm_reg_hw_reset_seq::type_id::create("reg_reset");
      reg_reset.model = p_sequencer.reg_block;
      reg_reset.start(p_sequencer.reg_seqr);

      `uvm_info("VSEQ", "--- PHASE 1: PASS MODE ---", UVM_LOW)
      cfg_seq = cpm_config_seq::type_id::create("cfg_pass");
      cfg_seq.reg_block = p_sequencer.reg_block;
      if(!cfg_seq.randomize() with { mode == 0; drop_en == 0; }) `uvm_error("RND", "Randomize failed")
      cfg_seq.start(p_sequencer.reg_seqr);
      `uvm_info("SYNC", "Waiting 50us for register write", UVM_MEDIUM)
      #(50us);
      // Set global configuration for scoreboard
      global_scb_mode = 0;
      global_scb_mask = 0;
      global_scb_add_const = 0;
      `uvm_info("SYNC", "Set modes: PASS (mode=0)", UVM_MEDIUM)
      #1us;
      
      traffic_seq = base_traffic_seq::type_id::create("traffic_pass");
      traffic_seq.num_packets = 50;
      traffic_seq.start(p_sequencer.in_seqr);
      #100ns;

      `uvm_info("VSEQ", "--- PHASE 2: XOR MODE ---", UVM_LOW)
      if(!cfg_seq.randomize() with { mode == 1; drop_en == 0; }) `uvm_error("RND", "Randomize failed")
      cfg_seq.start(p_sequencer.reg_seqr);
      #(50us);
      // Set global configuration for scoreboard
      global_scb_mode = 1;
      `uvm_info("SYNC", "Set mode: XOR (mode=1)", UVM_MEDIUM)
      #1us;
      
      traffic_seq.start(p_sequencer.in_seqr);
      #100ns;

      `uvm_info("VSEQ", "--- PHASE 3: ROT MODE ---", UVM_LOW)
      if(!cfg_seq.randomize() with { mode == 3; drop_en == 0; }) `uvm_error("RND", "Randomize failed")
      cfg_seq.start(p_sequencer.reg_seqr);
      #(50us);
      // Set global configuration for scoreboard
      global_scb_mode = 3;
      `uvm_info("SYNC", "Set mode: ROT (mode=3)", UVM_MEDIUM)
      #1us;
      
      traffic_seq.start(p_sequencer.in_seqr);
      #100ns;

      `uvm_info("VSEQ", "--- PHASE 4: ADD MODE + STRESS ---", UVM_LOW)
      if(!cfg_seq.randomize() with { mode == 2; drop_en == 0; add_const != 0; }) `uvm_error("RND", "Randomize failed")
      cfg_seq.start(p_sequencer.reg_seqr);
      #(50us);
      // Set global configuration for scoreboard
      global_scb_mode = 2;
      global_scb_add_const = cfg_seq.add_const;
      `uvm_info("SYNC", $sformatf("Set mode: ADD (mode=2, const=%h)", cfg_seq.add_const), UVM_MEDIUM)
      #1us;

      stress = stress_seq::type_id::create("stress");
      stress.start(p_sequencer.in_seqr);
      #100ns;

      `uvm_info("VSEQ", "--- PHASE 5: DROP TEST ---", UVM_LOW)
      if(!cfg_seq.randomize() with { drop_en == 1; drop_opcode == 4'hE; }) `uvm_error("RND", "Randomize failed")
      cfg_seq.start(p_sequencer.reg_seqr);
      void'(p_sequencer.reg_block.drop_cfg.predict(32'hE1));
      #(50us);
      // Set global configuration for scoreboard
      global_scb_drop_en = 1;
      global_scb_drop_opcode = 14; // 14 = 0xE
      `uvm_info("SYNC", "Set DROP enable with opcode=E", UVM_MEDIUM)
      #1us;

      drop = drop_seq::type_id::create("drop");
      drop.target_opcode = 4'hE;
      drop.start(p_sequencer.in_seqr);

      #100ns;
      `uvm_info(get_type_name(), "Virtual sequence complete", UVM_LOW)
    endtask
  endclass

  // ==========================================================
  // 4. TESTS
  // ==========================================================
  `include "test/cpm_base_test.sv"
  `include "test/cpm_simple_test.sv"

  // RAL Sync validation test - runs synchronized sequence with RAL mirror delays
  class cpm_ral_sync_test extends cpm_base_test;
    `uvm_component_utils(cpm_ral_sync_test)

    function new(string name="cpm_ral_sync_test", uvm_component parent=null);
      super.new(name, parent);
    endfunction

    virtual function void configure_test();
      uvm_config_db#(int)::set(this, "*", "num_packets", 4650);
      uvm_config_db#(int)::set(this, "*", "seq_timeout_ms", 10);
      uvm_config_db#(real)::set(this, "*", "ready_prob", 0.8);
      uvm_config_db#(int)::set(this, "*", "ready_delay_max_clks", 50);
      uvm_config_db#(int)::set(this, "*", "ral_sync_delay_us", 50);
      `uvm_info("TEST_CFG", "Configured for RAL sync validation test", UVM_LOW)
    endfunction

    virtual task run_phase(uvm_phase phase);
      cpm_final_seq_sync sync_seq;
      int unsigned max_wait_ms = 10;
      int unsigned wait_start_time;
      
      phase.raise_objection(this);
      
      configure_test();
      
      // Setup auto-predict like base test
      if (env.reg_block != null) env.reg_block.reg_map.set_auto_predict(1);

      // Use synchronized sequence instead of default
      sync_seq = cpm_final_seq_sync::type_id::create("sync_seq");
      sync_seq.start(env.vseqr);
      
      // Drain queue before test completion
      wait_start_time = $time;
      while (env.scoreboard != null && env.scoreboard.expected_queue.size() > 0) begin
        if (($time - wait_start_time) > (max_wait_ms * 1000000)) begin
          `uvm_warning("SCB_DRAIN_TIMEOUT", 
            $sformatf("Scoreboard drain timeout after %0dms: %0d packets still expected",
              max_wait_ms, env.scoreboard.expected_queue.size()))
          break;
        end
        #1us;
      end
      
      phase.drop_objection(this);
    endtask
  endclass

endpackage
