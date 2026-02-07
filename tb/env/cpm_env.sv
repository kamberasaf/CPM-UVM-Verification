// ===============================================================================
// File: cpm_env.sv
// Description: Top-level verification environment.
//              Instantiates Agents, RAL, Scoreboard.
// ===============================================================================

class cpm_env extends uvm_env;
  `uvm_component_utils(cpm_env)

  // -----------------------------------------------------------------------
  // Components
  // -----------------------------------------------------------------------
  cpm_in_agent                     agent_in;
  cpm_out_agent                    agent_out;
  cpm_reg_agent                    agent_reg;

  cpm_reg_block                    reg_block;
  cpm_reg_adapter                  reg_adapter;
  uvm_reg_predictor#(cpm_reg_item) reg_predictor;

  cpm_scoreboard                   scoreboard;
  cpm_coverage                     coverage;
  cpm_virtual_sequencer            vseqr;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // 1. Create Agents
    agent_in   = cpm_in_agent::type_id::create("agent_in", this);
    agent_out  = cpm_out_agent::type_id::create("agent_out", this);
    agent_reg  = cpm_reg_agent::type_id::create("agent_reg", this);

    // 2. Create and Build Register Model
    reg_block = cpm_reg_block::type_id::create("reg_block");
    reg_block.build();
    reg_block.lock_model();

    // 3. Create Register Adapter and Predictor
    reg_adapter   = cpm_reg_adapter::type_id::create("reg_adapter");
    reg_predictor = uvm_reg_predictor#(cpm_reg_item)::type_id::create("reg_predictor", this);

    // 4. Create Scoreboard and Coverage
    scoreboard = cpm_scoreboard::type_id::create("scoreboard", this);
    coverage   = cpm_coverage::type_id::create("coverage",   this);

    // 5. Create Virtual Sequencer
    vseqr = cpm_virtual_sequencer::type_id::create("vseqr", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    // 1. Connect RAL to Register Agent
    if (agent_reg.get_is_active() == UVM_ACTIVE) begin
      reg_block.reg_map.set_sequencer(agent_reg.sequencer, reg_adapter);
    end

    // Predictor connection
    reg_predictor.map     = reg_block.reg_map;
    reg_predictor.adapter = reg_adapter;
    agent_reg.monitor.ap.connect(reg_predictor.bus_in);

    reg_block.reg_map.set_auto_predict(1);

    // 2. Connect Agents to Scoreboard
    agent_in.monitor.ap.connect(scoreboard.in_export);
    agent_out.monitor.ap.connect(scoreboard.out_export);

    // 3. PASS RAL HANDLE TO SCOREBOARD & COVERAGE
    scoreboard.reg_block = reg_block;
    coverage.reg_block   = reg_block;

    // 4. Connect input monitor to coverage subscriber
    agent_in.monitor.ap.connect(coverage.analysis_export);

    // 5. Connect virtual sequencer handles with null checks
    if (agent_in != null && agent_in.sequencer != null) begin
      vseqr.in_seqr = agent_in.sequencer;
    end else begin
      `uvm_warning("ENV_CONNECT", "Input agent or sequencer is null")
    end

    if (agent_reg != null && agent_reg.sequencer != null) begin
      vseqr.reg_seqr = agent_reg.sequencer;
    end else begin
      `uvm_warning("ENV_CONNECT", "Register agent or sequencer is null")
    end

    if (reg_block != null) begin
      vseqr.reg_block = reg_block;
    end else begin
      `uvm_warning("ENV_CONNECT", "Register block is null")
    end
  endfunction

endclass : cpm_env
