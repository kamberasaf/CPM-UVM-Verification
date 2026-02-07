class cpm_config_seq extends uvm_sequence;
  `uvm_object_utils(cpm_config_seq)
  cpm_reg_block reg_block;
  rand bit [1:0]  mode;
  rand bit [15:0] mask;
  rand bit [15:0] add_const;
  rand bit        drop_en;
  rand bit [3:0]  drop_opcode;

  function new(string name = "cpm_config_seq");
    super.new(name);
  endfunction

  task body();
    uvm_status_e status;
    uvm_reg_data_t rdata;
    if (reg_block == null) `uvm_fatal("CFG", "Null Reg Block")

    // 1. Configure MODE & Readback to sync RAL
    reg_block.mode.write(status, {30'b0, mode});
    reg_block.mode.read(status, rdata); 

    // 2. Configure PARAMS & Readback
    reg_block.params.write(status, {add_const, mask});
    reg_block.params.read(status, rdata);

    // 3. Configure DROP & Readback
    reg_block.drop_cfg.write(status, {24'b0, drop_opcode, 3'b0, drop_en});
    reg_block.drop_cfg.read(status, rdata);

    // 4. Enable
    reg_block.ctrl.write(status, 32'h00000001);
    
    `uvm_info("CFG_SEQ", $sformatf("Configured: Mode=%0d Drop=%0b", mode, drop_en), UVM_LOW)
  endtask
endclass