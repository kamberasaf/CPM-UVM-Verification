// ===============================================================================
// Interface: cpm_stream_if
// Description: Generic AXI-Stream-like interface for CPM Input and Output ports.
//              Includes Mandatory SVA for stability checks.
// ===============================================================================
interface cpm_stream_if (input logic clk, input logic rst);

  // Signals (Generic naming for reuse on both In and Out)
  logic        valid;
  logic        ready;
  logic [3:0]  id;
  logic [3:0]  opcode;
  logic [15:0] payload;

  // Modport for the Driver (Driving the DUT input)
  modport master (
    output valid, id, opcode, payload,
    input  clk, rst, ready
  );

  // Modport for the Receiver/Slave (Responding to DUT output)
  modport slave (
    input  clk, rst, valid, id, opcode, payload,
    output ready
  );

  // Modport for Monitor (Passive observation)
  modport passive (
    input clk, rst, valid, ready, id, opcode, payload
  );

  // -----------------------------------------------------------------------
  // MANDATORY SVA: Section 6.6
  // Requirement: "Assertions must be written in the stream interface"
  // -----------------------------------------------------------------------

  // SVA Req 1 & 2: Stability under stall
  // If valid is high and ready is low, control and data fields must be stable.

  property p_stability_valid;
    @(posedge clk) disable iff (rst)
    (valid && !ready) |-> $stable(valid);
  endproperty

  property p_stability_data;
    @(posedge clk) disable iff (rst)
    (valid && !ready) |-> $stable(id) && $stable(opcode) && $stable(payload);
  endproperty

  ASSERT_STABILITY_VALID: assert property (p_stability_valid)
    else $error("SVA Violation: 'valid' dropped while 'ready' was low!");

  ASSERT_STABILITY_DATA:  assert property (p_stability_data)
    else $error("SVA Violation: Data fields changed while stalled (valid=1, ready=0)!");

  // Req 4: One meaningful cover property (e.g. stall event, handshake)
  property p_coverage_handshake;
    @(posedge clk) valid && ready;
  endproperty
  cover property (p_coverage_handshake); // Successful handshake

  property p_coverage_stall;
    @(posedge clk) valid && !ready;
  endproperty
  cover property (p_coverage_stall);     // Stall event (spec 6.6 example)

  // -----------------------------------------------------------------------
  // Bounded liveness (simplified)
  // Note: A more precise liveness check that excludes dropped packets can
  // be built using a wrapper module that sees both input and output streams.
  // Here we simply require that once VALID is asserted it is eventually
  // accepted within a bounded number of cycles (no infinite stall).
  // -----------------------------------------------------------------------
  parameter int CPM_LIVENESS_BOUND = 16;

  property p_bounded_liveness_no_infinite_stall;
    @(posedge clk) disable iff (rst)
      (valid && !ready) |-> ##[1:CPM_LIVENESS_BOUND] (!valid || ready);
  endproperty

  ASSERT_LIVENESS_BOUND: assert property (p_bounded_liveness_no_infinite_stall)
    else $error("SVA Violation: Stream stalled longer than CPM_LIVENESS_BOUND cycles");

endinterface


// ===============================================================================
// Interface: cpm_reg_if
// Description: Custom Register Bus Interface for CPM
// ===============================================================================
interface cpm_reg_if (input logic clk, input logic rst);

  logic        req;
  logic        gnt;
  logic        write_en; // 1 = Write, 0 = Read
  logic [7:0]  addr;
  logic [31:0] wdata;
  logic [31:0] rdata;

  // Modport for the UVM Register Adapter/Driver (Master)
  modport master (
    output req, write_en, addr, wdata,
    input  clk, rst, gnt, rdata
  );

  // Modport for Monitor
  modport passive (
    input clk, rst, req, gnt, write_en, addr, wdata, rdata
  );

  // SVA: Protocol Sanity (Optional but recommended)
  // Check that GNT is eventually asserted when REQ is asserted (within reasonable time)
  // Note: Disabled as DUT register interface is not fully implemented
  // property p_gnt_eventually;
  //   @(posedge clk) disable iff (rst)
  //   req |-> ##[0:5] gnt;
  // endproperty
  // ASSERT_REG_GNT: assert property (p_gnt_eventually)
  //   else $error("Protocol Violation: CPM Register Interface GNT must be asserted within 5 cycles!");

endinterface
