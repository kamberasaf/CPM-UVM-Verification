class cpm_base_seq extends uvm_sequence #(cpm_seq_item);
  `uvm_object_utils(cpm_base_seq)

  function new(string name = "cpm_base_seq");
    super.new(name);
  endfunction
endclass

// Requirement: "base_traffic_seq: Random packet stimulus"
class base_traffic_seq extends cpm_base_seq;
  `uvm_object_utils(base_traffic_seq)

  rand int num_packets;
  constraint c_num { num_packets inside {[10:50]}; }

  function new(string name = "base_traffic_seq");
    super.new(name);
  endfunction

  virtual task body();
    repeat(num_packets) begin
      `uvm_do(req)
    end
  endtask
endclass

// Requirement: "drop_seq: Force opcode matching drop configuration"
class drop_seq extends cpm_base_seq;
  `uvm_object_utils(drop_seq)

  rand bit [3:0] target_opcode; // Must match what we configured in registers

  function new(string name = "drop_seq");
    super.new(name);
  endfunction

  virtual task body();
    repeat(2000) begin
      // Force the opcode to match the target
      `uvm_do_with(req, { opcode == target_opcode; })
    end
  endtask
endclass

// Requirement: "stress_seq: Burst traffic to cause stalls/backpressure"
class stress_seq extends cpm_base_seq;
  `uvm_object_utils(stress_seq)

  // Number of bursts and burst length to generate
  rand int num_bursts;
  rand int burst_len;

  constraint c_bursts { num_bursts inside {[40:50]}; } // ~45 burst
  constraint c_len    { burst_len  inside {[40:60]}; } // ~50 packets each
  // Total = 45*50 = ~2250 packets

  function new(string name = "stress_seq");
    super.new(name);
  endfunction

  virtual task body();
    int i, j;
    // Hardcode counts to ensure high traffic (~2500 packets)
    // Randomization is good, but volume is required for coverage closure.
    num_bursts = 50; 
    burst_len  = 50; 

    for (i = 0; i < num_bursts; i++) begin
      for (j = 0; j < burst_len; j++) begin
        `uvm_do(req)
      end
      #(0); // Zero delay for back-to-back burst
    end
  endtask
endclass

// coverage_traffic_seq: used via factory override to bias
// towards rare MODE/OPCODE/DROP combinations (Spec 6.3).
class coverage_traffic_seq extends base_traffic_seq;
  `uvm_object_utils(coverage_traffic_seq)

  function new(string name = "coverage_traffic_seq");
    super.new(name);
  endfunction

  // Bias opcodes towards high values that are often used as drop opcodes
  constraint c_cov_opcode_bias {
    req.opcode dist { [0:7]  := 1, [8:15] := 4 };
  }
endclass
