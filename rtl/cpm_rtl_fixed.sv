// ============================================================
// CPM (Configurable Packet Modifier) - FIXED VERSION
// This is a test version with proposed bug fixes applied
// ============================================================

module cpm_fixed (
  input  logic        clk,
  input  logic        rst,

  // Stream input
  input  logic        in_valid,
  output logic        in_ready,
  input  logic [3:0]  in_id,
  input  logic [3:0]  in_opcode,
  input  logic [15:0] in_payload,

  // Stream output
  output logic        out_valid,
  input  logic        out_ready,
  output logic [3:0]  out_id,
  output logic [3:0]  out_opcode,
  output logic [15:0] out_payload,

  // Register bus
  input  logic        req,
  output logic        gnt,
  input  logic        write_en,
  input  logic [7:0]  addr,
  input  logic [31:0] wdata,
  output logic [31:0] rdata
);

  localparam logic [7:0] ADDR_CTRL         = 8'h00;
  localparam logic [7:0] ADDR_MODE         = 8'h04;
  localparam logic [7:0] ADDR_PARAMS       = 8'h08;
  localparam logic [7:0] ADDR_DROP_CFG     = 8'h0C;
  localparam logic [7:0] ADDR_STATUS       = 8'h10;
  localparam logic [7:0] ADDR_COUNT_IN     = 8'h14;
  localparam logic [7:0] ADDR_COUNT_OUT    = 8'h18;
  localparam logic [7:0] ADDR_DROPPED_CNT  = 8'h1C;

  logic        ctrl_enable;
  logic        ctrl_soft_rst;
  logic [1:0]  reg_mode;
  logic [15:0] reg_mask;
  logic [15:0] reg_add_const;
  logic        drop_en;
  logic [3:0]  drop_opcode;

  logic        status_busy;
  logic [31:0] count_in;
  logic [31:0] count_out;
  logic [31:0] dropped_count;
  logic [15:0] tx_payload;
  logic [1:0]  tx_lat;

  assign gnt = req;

  // Read mux
  always_comb begin
    unique case (addr)
      ADDR_CTRL:        rdata = {30'b0, ctrl_soft_rst, ctrl_enable};
      ADDR_MODE:        rdata = {30'b0, reg_mode};
      ADDR_PARAMS:      rdata = {reg_add_const, reg_mask};
      ADDR_DROP_CFG:    rdata = {24'b0, drop_opcode, 3'b0, drop_en};
      ADDR_STATUS:      rdata = {31'b0, status_busy};
      ADDR_COUNT_IN:    rdata = count_in;
      ADDR_COUNT_OUT:   rdata = count_out;
      ADDR_DROPPED_CNT: rdata = dropped_count;
      default:          rdata = 32'h0;
    endcase
  end

  // Register writes
  always_ff @(posedge clk) begin
    if (rst) begin
      ctrl_enable   <= 1'b0;
      ctrl_soft_rst <= 1'b0;
      reg_mode      <= 2'b00;
      reg_mask      <= 16'h0000;
      reg_add_const <= 16'h0000;
      drop_en       <= 1'b0;
      drop_opcode   <= 4'h0;
    end else begin
      if (req && gnt && write_en) begin
        unique case (addr)
          ADDR_CTRL: begin
            ctrl_enable   <= wdata[0];
            if (wdata[1]) ctrl_soft_rst <= 1'b1;
          end
          ADDR_MODE:   reg_mode <= wdata[1:0];
          ADDR_PARAMS: begin
            reg_mask      <= wdata[15:0];
            reg_add_const <= wdata[31:16];
          end
          ADDR_DROP_CFG: begin
            drop_en     <= wdata[0];
            drop_opcode <= wdata[7:4];
          end
          default: ;
        endcase
      end
    end
  end

  typedef struct packed {
    logic        v;
    logic [3:0]  id;
    logic [3:0]  opcode;
    logic [15:0] payload;
    logic [1:0]  cd;
  } slot_t;

  slot_t s0, s1;

  localparam int ROT_AMT = 4;

  function automatic logic [15:0] rol16(input logic [15:0] x, input int sh);
    logic [15:0] y;
    begin
      y = (x << sh) | (x >> (16 - sh));
      return y;
    end
  endfunction

  function automatic void compute_expected(
    input  logic [1:0]  mode,
    input  logic [15:0] mask,
    input  logic [15:0] addc,
    input  logic [15:0] inpay,
    output logic [15:0] outpay,
    output logic [1:0]  base_lat
  );
    begin
      unique case (mode)
        2'd0: begin
          outpay   = inpay;
          base_lat = 2'd0;
        end
        2'd1: begin
          outpay   = inpay ^ mask;
          base_lat = 2'd1;
        end
        2'd2: begin
          outpay   = inpay + addc;
          base_lat = 2'd1;
        end
        default: begin
          outpay   = rol16(inpay, ROT_AMT);
          base_lat = 2'd1;
        end
      endcase
    end
  endfunction

  wire buffer_full  = s0.v && s1.v;
  assign in_ready  = ctrl_enable && !buffer_full;

  assign out_valid = ctrl_enable && s0.v && (s0.cd == 2'd0);
  assign out_id      = s0.id;
  assign out_opcode  = s0.opcode;
  assign out_payload = s0.payload;

  wire in_fire  = ctrl_enable && in_valid && in_ready;
  wire out_fire = out_valid && out_ready;

  assign status_busy = ctrl_enable && (s0.v || s1.v);

  // ============== KEY FIX #1: Register Value Capture on Packet Acceptance ==============
  // Hypothesis: Register values (mode, mask, add_const) may change between when
  // packet is accepted and when transformation is computed.
  // Fix: Capture register values at moment of packet acceptance in input
  
  logic [1:0]  captured_mode;
  logic [15:0] captured_mask;
  logic [15:0] captured_add_const;
  
  // ============== KEY FIX #2: Ensure Payload is Correctly Latched ==============
  // Make sure the computed payload from compute_expected actually gets stored
  // by explicitly assigning it in the same clock cycle and using captured registers
  
  always_ff @(posedge clk) begin
    if (rst) begin
      s0 <= '{default:'0};
      s1 <= '{default:'0};
      count_in      <= 32'd0;
      count_out     <= 32'd0;
      dropped_count <= 32'd0;
    end else begin
      if (ctrl_soft_rst) begin
        s0 <= '{default:'0};
        s1 <= '{default:'0};
        count_in      <= 32'd0;
        count_out     <= 32'd0;
        dropped_count <= 32'd0;
      end

      if (!ctrl_enable) begin
        s0.v <= 1'b0;
        s1.v <= 1'b0;
      end else begin
        if (s0.v && s0.cd != 0) s0.cd <= s0.cd - 2'd1;
        if (s1.v && s1.cd != 0) s1.cd <= s1.cd - 2'd1;

        // When both out_fire and in_fire same cycle: shift then load (or drop) in one place to avoid losing packet.
        if (out_fire && in_fire) begin
          // Per-packet prints removed for quiet runs; re-add for RTL debug if needed
          if (drop_en && (in_opcode == drop_opcode)) begin
            dropped_count <= dropped_count + 32'd1;
            s0 <= s1;
            s1 <= '{default:'0};
          end else begin
            count_in <= count_in + 32'd1;
            captured_mode      = reg_mode;
            captured_mask      = reg_mask;
            captured_add_const = reg_add_const;
            compute_expected(captured_mode, captured_mask, captured_add_const, in_payload, tx_payload, tx_lat);
            s0 <= s1;
            s1 <= '{v:1'b1, id:in_id, opcode:in_opcode, payload:tx_payload, cd:tx_lat};
          end
        end else begin
          if (out_fire) begin
            s0 <= s1;
            s1 <= '{default:'0};
          end

          if (in_fire) begin
            if (drop_en && (in_opcode == drop_opcode)) begin
              dropped_count <= dropped_count + 32'd1;
            end else begin
              count_in <= count_in + 32'd1;
              captured_mode      = reg_mode;
              captured_mask      = reg_mask;
              captured_add_const = reg_add_const;
              compute_expected(captured_mode, captured_mask, captured_add_const, in_payload, tx_payload, tx_lat);
              if (!s0.v) begin
                s0.v <= 1'b1; s0.id <= in_id; s0.opcode <= in_opcode; s0.payload <= tx_payload; s0.cd <= tx_lat;
              end else if (!s1.v) begin
                s1.v <= 1'b1; s1.id <= in_id; s1.opcode <= in_opcode; s1.payload <= tx_payload; s1.cd <= tx_lat;
              end else begin
                $warning("[RTL_PACKET_LOSS] Both full! Lost ID=%h Op=%h", in_id, in_opcode);
              end
            end
          end
        end

        if (out_fire) begin
          count_out <= count_out + 32'd1;
        end
      end
    end
  end

endmodule
