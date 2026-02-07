// ===============================================================================
// File: cpm_defines.svh
// Description: CPM simulation defines, constants, and macros for testbench
// ===============================================================================

`ifndef CPM_DEFINES_SVH
`define CPM_DEFINES_SVH

//===============================================================================
// Simulation Time Constants
//===============================================================================

// Clock configuration
`define CPM_CLK_PERIOD      10ns        // 100MHz clock
`define CPM_CLK_HALF_PERIOD 5ns         // Half period for toggling
`define CPM_RESET_CYCLES    5           // Number of reset cycles

// Timeout values
`define CPM_SIM_TIMEOUT     1ms         // Maximum simulation time
`define CPM_DRIVER_TIMEOUT  1000        // Driver handshake timeout (cycles)
`define CPM_READ_TIMEOUT    100         // Register read timeout (cycles)

//===============================================================================
// Register Configuration
//===============================================================================

// Register addresses
`define CPM_CTRL_ADDR       8'h00       // Control register
`define CPM_MODE_ADDR       8'h04       // Mode register
`define CPM_PARAMS_ADDR     8'h08       // Parameters register
`define CPM_DROP_CFG_ADDR   8'h0C       // Drop configuration register
`define CPM_STATUS_ADDR     8'h10       // Status register (RO)
`define CPM_COUNT_IN_ADDR   8'h14       // Input count register (RO)
`define CPM_COUNT_OUT_ADDR  8'h18       // Output count register (RO)
`define CPM_DROPPED_ADDR    8'h1C       // Dropped count register (RO)

// Register field bit positions
`define CPM_CTRL_EN_BIT     0           // Enable bit
`define CPM_CTRL_RESET_BIT  1           // Soft reset bit
`define CPM_MODE_BITS       [1:0]       // 2-bit mode field
`define CPM_STATUS_BUSY_BIT 0           // Busy status bit
`define CPM_DROP_EN_BIT     0           // Drop enable bit

// Register default values
`define CPM_CTRL_DEFAULT    32'h0000_0000
`define CPM_MODE_DEFAULT    32'h0000_0000 // PASS mode
`define CPM_PARAMS_DEFAULT  32'h0000_0000 // No mask/constant
`define CPM_DROP_CFG_DEFAULT 32'h0000_0000 // No drops
`define CPM_STATUS_DEFAULT  32'h0000_0000 // Not busy

//===============================================================================
// Operational Modes
//===============================================================================

`define CPM_MODE_PASS       2'b00       // Passthrough mode
`define CPM_MODE_XOR        2'b01       // XOR with mask mode
`define CPM_MODE_ADD        2'b10       // Add constant with mask
`define CPM_MODE_ROT        2'b11       // Rotate mode

// Mode strings for logging
`define CPM_MODE_STR(mode) \
    ((mode) == 2'b00) ? "PASS" : \
    ((mode) == 2'b01) ? "XOR"  : \
    ((mode) == 2'b10) ? "ADD"  : \
    ((mode) == 2'b11) ? "ROT"  : "UNKNOWN"

//===============================================================================
// Stream Protocol Constants
//===============================================================================

// Data widths
`define CPM_PACKET_ID_WIDTH  4          // Packet ID width
`define CPM_OPCODE_WIDTH     4          // Opcode width
`define CPM_PAYLOAD_WIDTH    16         // Payload data width
`define CPM_TOTAL_WIDTH      24         // Total: ID + OPCODE + PAYLOAD

// Common opcodes for testing
`define CPM_OPCODE_READ      4'h0       // Read operation
`define CPM_OPCODE_WRITE     4'h1       // Write operation
`define CPM_OPCODE_DROP_TRIG 4'h8       // Drop trigger opcode
`define CPM_OPCODE_DROP_TRIG_ALT 4'hF   // Alternate drop trigger

// Backpressure control
`define CPM_READY_PROBABILITY_HIGH   80  // 80% ready during stress testing
`define CPM_READY_PROBABILITY_NORMAL 100 // Always ready (no backpressure)
`define CPM_READY_PROBABILITY_STALL  20  // 20% ready (maximum stall)

//===============================================================================
// Coverage Configuration
//===============================================================================

// Coverage bin definitions
`define CPM_OPCODE_LOW_BIN    [0:7]     // Low opcode values for coverage
`define CPM_OPCODE_MID_BIN    [4:11]    // Mid opcode values
`define CPM_OPCODE_HIGH_BIN   [8:15]    // High opcode values

// Coverage thresholds
`define CPM_COVERAGE_TARGET   95        // Target 95% coverage
`define CPM_MIN_TRANSACTIONS  1000      // Minimum transactions for coverage

//===============================================================================
// Protocol Assertion Bounds
//===============================================================================

// Liveness bounds (from cpm_if.sv assertions)
`define CPM_LIVENESS_BOUND    16        // Maximum allowed stall cycles
`define CPM_STABILITY_WINDOW  1         // Data stability window

//===============================================================================
// Verbosity Control Macros
//===============================================================================

// Macro for conditional verbose output
`define CPM_MSG(level, msg) \
    if(uvm_default_table_printer.knobs.reference == UVM_NO_PRINT) begin \
        `uvm_info("CPM_MSG", $sformatf msg, level) \
    end

// Debug messages (UVM_DEBUG only)
`define CPM_DEBUG(msg) \
    `uvm_info("CPM_DEBUG", $sformatf msg, UVM_DEBUG)

// Info messages (default)
`define CPM_INFO(msg) \
    `uvm_info("CPM_INFO", $sformatf msg, UVM_MEDIUM)

// Warning messages
`define CPM_WARN(msg) \
    `uvm_warning("CPM_WARN", $sformatf msg)

// Error messages
`define CPM_ERROR(msg) \
    `uvm_error("CPM_ERROR", $sformatf msg)

// Severity counters (for end-of-test reporting)
`define CPM_REPORT_STATS \
    $display("========== Test Statistics =========="); \
    $display("Errors:   %0d", uvm_root::get().get_report_server().get_severity_count(UVM_ERROR)); \
    $display("Warnings: %0d", uvm_root::get().get_report_server().get_severity_count(UVM_WARNING)); \
    $display("=====================================");

//===============================================================================
// Testbench Configuration
//===============================================================================

// Default testbench settings
`define CPM_DEFAULT_TEST      "cpm_base_test"
`define CPM_DEFAULT_SEED      0         // Random seed (0 = random)
`define CPM_NUM_SEQUENCES     1         // Default number of sequences
`define CPM_SEQ_LENGTH_MIN    10        // Minimum sequence length
`define CPM_SEQ_LENGTH_MAX    100       // Maximum sequence length

//===============================================================================
// Simulation Control
//===============================================================================

// Test completion status
typedef enum {
    TEST_RUNNING,
    TEST_PASSED,
    TEST_FAILED,
    TEST_TIMEOUT
} test_status_e;

// Global test status variable
test_status_e g_test_status = TEST_RUNNING;

//===============================================================================
// Utility Macros
//===============================================================================

// Safe cast macro with error checking
`define SAFE_CAST(dest_type, src_obj, src_name) \
    if (!$cast(dest_type, src_obj)) begin \
        `uvm_fatal("CAST_FAIL", $sformatf("Failed to cast %0s to %0s", src_name, `"dest_type`")) \
    end

// Null pointer check
`define NULL_CHECK(obj, obj_name) \
    if (obj == null) begin \
        `uvm_fatal("NULL_PTR", $sformatf("Null pointer: %0s", obj_name)) \
    end

// Safe randomize with error checking
`define SAFE_RANDOMIZE(obj) \
    if (!obj.randomize()) begin \
        `uvm_fatal("RANDOMIZE_FAIL", $sformatf("Randomization failed for %0s", `"obj`")) \
    end

// Check constraint violation
`define CHECK_CONSTRAINT(obj, constraint_name) \
    if (!obj.randomize() with {constraint_name == 1;}) begin \
        `uvm_warning("CONSTRAINT_FAIL", $sformatf("Constraint %0s failed", constraint_name)) \
    end

//===============================================================================
// Waveform Dumping (for simulator-specific debugging)
//===============================================================================

// Uncomment the appropriate section for your simulator

// For Xcelium/Xsim:
// initial begin
//     $shm_open("waves");
//     $shm_probe("AS", cpm_tb, "F");
//     $shm_probe("AS", cpm_tb.in_vif, "F");
//     $shm_probe("AS", cpm_tb.out_vif, "F");
// end

// For VCS:
// initial begin
//     $fsdbDumpvars();
// end

// For Questa/ModelSim:
// initial begin
//     $dumpfile("waves.vcd");
//     $dumpvars();
// end

`endif // CPM_DEFINES_SVH

// ===============================================================================
// Revision History:
// Version 1.0 - Initial release with complete define and constant coverage
// ===============================================================================
