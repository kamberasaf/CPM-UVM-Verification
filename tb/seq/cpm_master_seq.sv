class cpm_master_seq extends uvm_sequence #(uvm_sequence_item);
  `uvm_object_utils(cpm_master_seq)
  cpm_virtual_sequencer p_sequencer;
  function new(string name="cpm_master_seq"); super.new(name); endfunction

  virtual task pre_body();
    if(!$cast(p_sequencer, m_sequencer)) `uvm_fatal("CAST","Fail")
  endtask

  virtual task body();
    cpm_config_seq cfg = cpm_config_seq::type_id::create("cfg");
    base_traffic_seq traf = base_traffic_seq::type_id::create("traf");
    stress_seq stress = stress_seq::type_id::create("stress");
    drop_seq drop = drop_seq::type_id::create("drop");
    uvm_reg_hw_reset_seq rst = uvm_reg_hw_reset_seq::type_id::create("rst");
    
    cfg.reg_block = p_sequencer.reg_block;
    rst.model = p_sequencer.reg_block;
    rst.start(p_sequencer.reg_seqr);

    `uvm_info("SEQ", "=== STARTING MASTER SEQUENCE ===", UVM_LOW)

    // Phase 1: PASS
    cfg.randomize() with {mode==0; drop_en==0;}; cfg.start(p_sequencer.reg_seqr);
    traf.num_packets=50; traf.start(p_sequencer.in_seqr); #1us;

    // Phase 2: XOR
    cfg.randomize() with {mode==1; drop_en==0;}; cfg.start(p_sequencer.reg_seqr);
    traf.start(p_sequencer.in_seqr); #1us;

    // Phase 3: ROT
    cfg.randomize() with {mode==3; drop_en==0;}; cfg.start(p_sequencer.reg_seqr);
    traf.start(p_sequencer.in_seqr); #1us;

    // Phase 4: ADD
    cfg.randomize() with {mode==2; drop_en==0;}; cfg.start(p_sequencer.reg_seqr);
    stress.start(p_sequencer.in_seqr); #100us;

    // Phase 5: DROP
    cfg.randomize() with {drop_en==1; drop_opcode==4'hE;}; cfg.start(p_sequencer.reg_seqr);
    drop.target_opcode=4'hE; drop.start(p_sequencer.in_seqr); #100us;
    
    `uvm_info("SEQ", "=== MASTER SEQUENCE DONE ===", UVM_LOW)
  endtask
endclass