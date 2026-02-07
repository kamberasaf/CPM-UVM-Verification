class top_virtual_seq extends uvm_sequence #(uvm_sequence_item);
    `uvm_object_utils(top_virtual_seq)
    cpm_virtual_sequencer p_sequencer;

    function new(string name = "top_virtual_seq");
      super.new(name);
    endfunction

    virtual task pre_body();
      if (!$cast(p_sequencer, m_sequencer)) `uvm_fatal("NOVSEQ", "Wrong sequencer")
    endtask

    virtual task body();
      uvm_status_e status;
      uvm_reg_hw_reset_seq reg_reset;
      cpm_config_seq cfg_seq;
      base_traffic_seq traffic_seq;
      stress_seq stress;
      drop_seq drop;

      `uvm_info("VSEQ", "!!! NEW SEQUENCE IS RUNNING !!!", UVM_LOW) // SANITY CHECK PRINT

      // 1. Reset
      reg_reset = uvm_reg_hw_reset_seq::type_id::create("reg_reset");
      reg_reset.model = p_sequencer.reg_block;
      reg_reset.start(p_sequencer.reg_seqr);

      // 2. PHASE 1: PASS Mode
      `uvm_info("VSEQ", "--- PHASE 1: PASS MODE ---", UVM_LOW)
      cfg_seq = cpm_config_seq::type_id::create("cfg_pass");
      cfg_seq.reg_block = p_sequencer.reg_block;
      if(!cfg_seq.randomize() with { mode == 0; drop_en == 0; }) `uvm_error("RND", "Fail")
      cfg_seq.start(p_sequencer.reg_seqr);
      
      traffic_seq = base_traffic_seq::type_id::create("traffic_pass");
      traffic_seq.num_packets = 50;
      traffic_seq.start(p_sequencer.in_seqr);
      #100ns;

      // 3. PHASE 2: XOR Mode 
      `uvm_info("VSEQ", "--- PHASE 2: XOR MODE ---", UVM_LOW)
      if(!cfg_seq.randomize() with { mode == 1; drop_en == 0; }) `uvm_error("RND", "Fail")
      cfg_seq.start(p_sequencer.reg_seqr);
      traffic_seq.start(p_sequencer.in_seqr);
      #100ns;

      // 4. PHASE 3: ROT Mode
      `uvm_info("VSEQ", "--- PHASE 3: ROT MODE ---", UVM_LOW)
      if(!cfg_seq.randomize() with { mode == 3; drop_en == 0; }) `uvm_error("RND", "Fail")
      cfg_seq.start(p_sequencer.reg_seqr);
      traffic_seq.start(p_sequencer.in_seqr);
      #100ns;

      // 5. PHASE 4: ADD Mode + STRESS
      `uvm_info("VSEQ", "--- PHASE 4: ADD MODE + STRESS ---", UVM_LOW)
      if(!cfg_seq.randomize() with { mode == 2; drop_en == 0; add_const != 0; }) `uvm_error("RND", "Fail")
      cfg_seq.start(p_sequencer.reg_seqr);
      
      stress = stress_seq::type_id::create("stress");
      stress.start(p_sequencer.in_seqr);
      #100ns;

      // 6. PHASE 5: DROP Logic
      `uvm_info("VSEQ", "--- PHASE 5: DROP TEST ---", UVM_LOW)
      if(!cfg_seq.randomize() with { drop_en == 1; drop_opcode == 4'hE; }) `uvm_error("RND", "Fail")
      cfg_seq.start(p_sequencer.reg_seqr);

      drop = drop_seq::type_id::create("drop");
      drop.target_opcode = 4'hE;
      drop.start(p_sequencer.in_seqr);
      
      #100ns;
      `uvm_info(get_type_name(), "Virtual sequence complete", UVM_LOW)
    endtask
  endclass