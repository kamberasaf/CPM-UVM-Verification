class cpm_base_test extends uvm_test;
  `uvm_component_utils(cpm_base_test)
  cpm_env env;

  function new(string name = "cpm_base_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    int ready_prob = 100;
    int allow_one_leftover = 0;
    uvm_cmdline_processor clp;
    string arg_val;
    super.build_phase(phase);
    // Requirement: apply factory override (e.g. base_traffic_seq -> coverage_traffic_seq for coverage bias)
    base_traffic_seq::type_id::set_type_override(coverage_traffic_seq::type_id::get());
    env = cpm_env::type_id::create("env", this);
    clp = uvm_cmdline_processor::get_inst();
    if (clp.get_arg_value("+READY_PROB=", arg_val)) begin
      int scanned;
      if ($sscanf(arg_val, "%d", scanned) == 1)
        ready_prob = scanned;
    end
    if (clp.get_arg_value("+ALLOW_ONE_LEFTOVER=", arg_val)) begin
      int scanned;
      if ($sscanf(arg_val, "%d", scanned) == 1 && scanned != 0)
        allow_one_leftover = 1;
    end
    uvm_config_db#(int)::set(this, "env.agent_out.driver", "ready_probability", ready_prob);
    if (allow_one_leftover)
      uvm_config_db#(int)::set(this, "env.scoreboard", "allow_one_leftover", 1);
  endfunction

  function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    // Spec 6.4: register driver callback after hierarchy exists (modify outgoing transactions; real reason: parity LSB)
    begin
      cpm_driver_parity_cb par_cb = cpm_driver_parity_cb::type_id::create("par_cb");
      uvm_callbacks#(cpm_in_driver, cpm_in_driver_cb)::add(env.agent_in.driver, par_cb);
    end
  endfunction

  task run_phase(uvm_phase phase);
    cpm_final_seq vseq; // Use the new sequence
    int unsigned max_wait_ms = 15;
    int unsigned wait_start_time;
    `uvm_info("BUILD", "Run started (cpm_base_test run_phase) -- TB code is from last compile", UVM_LOW)
    phase.raise_objection(this);
    // Long drain so all pipeline outputs are captured before scoreboard check
    // After the virtual sequence finishes, wait for the scoreboard expected
    // queue to drain (with a timeout) so no in-flight outputs are missed.
    
    if (env.reg_block != null) env.reg_block.reg_map.set_auto_predict(1);

    vseq = cpm_final_seq::type_id::create("vseq");
    vseq.start(env.vseqr);
    
    // Wait for scoreboard queue to drain (timeout 10ms)
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
    // Extra time so last pipeline output can be captured by output monitor
    #20us;
    if (env.scoreboard != null && env.scoreboard.expected_queue.size() == 0) begin
      `uvm_info("SCB_DRAIN", "Scoreboard queue fully drained", UVM_LOW)
    end

    phase.drop_objection(this);
  endtask
endclass