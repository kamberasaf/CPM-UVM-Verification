// FILE: seq/cpm_final_seq.sv
// Sets package globals so scoreboard and coverage see correct config (RAL mirror can lag).
import cpm_pkg::*;
class cpm_final_seq extends uvm_sequence #(uvm_sequence_item);
  `uvm_object_utils(cpm_final_seq)

  cpm_virtual_sequencer  p_sequencer;

  function new(string name = "cpm_final_seq");
    super.new(name);
  endfunction

  virtual task pre_body();
    if (!$cast(p_sequencer, m_sequencer)) 
      `uvm_fatal("NOVSEQ", "Must run on cpm_virtual_sequencer")
  endtask

  virtual task body();
    uvm_status_e         status;
    uvm_reg_data_t       rdata;
    uvm_reg_hw_reset_seq reg_reset;
    cpm_config_seq       cfg_seq;
    base_traffic_seq     traffic_seq;
    stress_seq           stress;
    drop_seq             drop;

    // 1. Reset
    reg_reset = uvm_reg_hw_reset_seq::type_id::create("reg_reset");
    reg_reset.model = p_sequencer.reg_block;
    reg_reset.start(p_sequencer.reg_seqr);

    // 2. PHASE 1: PASS Mode
    `uvm_info("VSEQ", "--- PHASE 1: PASS MODE ---", UVM_LOW)
    cfg_seq = cpm_config_seq::type_id::create("cfg_pass");
    cfg_seq.reg_block = p_sequencer.reg_block;
    if(!cfg_seq.randomize() with { mode == 0; drop_en == 0; }) `uvm_error("RND", "Randomize failed")
    cfg_seq.start(p_sequencer.reg_seqr);
    cpm_pkg::global_scb_mode = cfg_seq.mode; cpm_pkg::global_scb_mask = cfg_seq.mask;
    cpm_pkg::global_scb_add_const = cfg_seq.add_const; cpm_pkg::global_scb_drop_en = 0; cpm_pkg::global_scb_drop_opcode = 0;
    #500ns; // drain pipeline / let DUT config settle before traffic
    traffic_seq = base_traffic_seq::type_id::create("traffic_pass");
    traffic_seq.num_packets = 50;
    traffic_seq.start(p_sequencer.in_seqr);
    #100ns;

    // 3. PHASE 2: XOR Mode
    `uvm_info("VSEQ", "--- PHASE 2: XOR MODE ---", UVM_LOW)
    if(!cfg_seq.randomize() with { mode == 1; drop_en == 0; }) `uvm_error("RND", "Randomize failed")
    cfg_seq.start(p_sequencer.reg_seqr);
    cpm_pkg::global_scb_mode = cfg_seq.mode; cpm_pkg::global_scb_mask = cfg_seq.mask;
    cpm_pkg::global_scb_add_const = cfg_seq.add_const; cpm_pkg::global_scb_drop_en = 0;
    #500ns;
    traffic_seq.start(p_sequencer.in_seqr);
    #100ns;

    // 4. PHASE 3: ROT Mode
    `uvm_info("VSEQ", "--- PHASE 3: ROT MODE ---", UVM_LOW)
    if(!cfg_seq.randomize() with { mode == 3; drop_en == 0; }) `uvm_error("RND", "Randomize failed")
    cfg_seq.start(p_sequencer.reg_seqr);
    cpm_pkg::global_scb_mode = cfg_seq.mode; cpm_pkg::global_scb_mask = cfg_seq.mask;
    cpm_pkg::global_scb_add_const = cfg_seq.add_const; cpm_pkg::global_scb_drop_en = 0;
    #500ns;
    traffic_seq.start(p_sequencer.in_seqr);
    #100ns;

    // 5. PHASE 4: ADD Mode + STRESS
    `uvm_info("VSEQ", "--- PHASE 4: ADD MODE + STRESS ---", UVM_LOW)
    if(!cfg_seq.randomize() with { mode == 2; drop_en == 0; add_const != 0; }) `uvm_error("RND", "Randomize failed")
    cfg_seq.start(p_sequencer.reg_seqr);
    cpm_pkg::global_scb_mode = cfg_seq.mode; cpm_pkg::global_scb_mask = cfg_seq.mask;
    cpm_pkg::global_scb_add_const = cfg_seq.add_const; cpm_pkg::global_scb_drop_en = 0;
    #500ns;
    stress = stress_seq::type_id::create("stress");
    stress.start(p_sequencer.in_seqr);
    #100ns;

    // 6. PHASE 5: DROP Logic — set globals and config_db so scoreboard/coverage see drop
    `uvm_info("VSEQ", "--- PHASE 5: DROP TEST ---", UVM_LOW)
    if(!cfg_seq.randomize() with { drop_en == 1; drop_opcode == 4'hE; }) `uvm_error("RND", "Randomize failed")
    cfg_seq.start(p_sequencer.reg_seqr);
    cpm_pkg::global_scb_mode = cfg_seq.mode; cpm_pkg::global_scb_mask = cfg_seq.mask;
    cpm_pkg::global_scb_add_const = cfg_seq.add_const;
    cpm_pkg::global_scb_drop_en = 1; cpm_pkg::global_scb_drop_opcode = 14; // 0xE
    uvm_config_db#(int)::set(null, "uvm_test_top.env.scoreboard", "scb_drop_en", 1);
    uvm_config_db#(int)::set(null, "uvm_test_top.env.scoreboard", "scb_drop_opcode", 14);
    #500ns;
    drop = drop_seq::type_id::create("drop");
    drop.target_opcode = 4'hE;
    drop.start(p_sequencer.in_seqr);
    #5ms; // longer drain so all non-dropped packets leave pipeline (was 2ms, 1 leftover seen)

    // 7. Readback — confirm RAL mirror / DUT state via RAL API
    `uvm_info("VSEQ", "--- STEP 7: READBACK ---", UVM_LOW)
    p_sequencer.reg_block.mode.read(status, rdata);
    `uvm_info("READBACK", $sformatf("MODE = %0d", rdata[1:0]), UVM_LOW)
    p_sequencer.reg_block.params.read(status, rdata);
    `uvm_info("READBACK", $sformatf("PARAMS = %04h (mask) %04h (add_const)", rdata[15:0], rdata[31:16]), UVM_LOW)
    p_sequencer.reg_block.drop_cfg.read(status, rdata);
    `uvm_info("READBACK", $sformatf("DROP_CFG = en=%0b opcode=%0d", rdata[0], rdata[7:4]), UVM_LOW)
    p_sequencer.reg_block.ctrl.read(status, rdata);
    `uvm_info("READBACK", $sformatf("CTRL = %02h", rdata[7:0]), UVM_LOW)

    // 8. End
    `uvm_info(get_type_name(), "Virtual sequence complete", UVM_LOW)
  endtask
endclass