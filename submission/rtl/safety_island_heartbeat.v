//------------------------------------------------------------------------------
// safety_island_heartbeat.v
//
// Heartbeat self-check for fault_detect output path integrity.
//
// Periodically injects a test fault into the core logic and verifies that
// safety_island_fault_detect asserts within 10 cycles. If not, the
// fault_detect output path is stuck and heartbeat_fault is asserted.
//
// Parameters:
//   HEARTBEAT_INTERVAL - cycles between heartbeat tests (default 1024)
//------------------------------------------------------------------------------

`timescale 1ns/1ps

module safety_island_heartbeat #(
    parameter HEARTBEAT_INTERVAL = 1024
) (
    input  wire clk,
    input  wire rst,

    input  wire enable,
    input  wire scan_busy,

    output reg  test_inject,
    output reg  heartbeat_fault,
    output reg  heartbeat_active,

    input  wire safety_island_fault_detect
);

    localparam [2:0] H_IDLE      = 3'd0;
    localparam [2:0] H_WAIT_IDLE = 3'd1;
    localparam [2:0] H_INJECT    = 3'd2;
    localparam [2:0] H_WAIT_DET  = 3'd3;
    localparam [2:0] H_CLEAR     = 3'd4;
    localparam [2:0] H_FAIL      = 3'd5;

    reg [2:0]  state;
    reg [31:0] counter;
    reg [3:0]  wait_cycles;
    reg [2:0]  state_inv;
    reg [31:0] counter_inv;
    reg [3:0]  wait_cycles_inv;
    reg        heartbeat_fault_int;

    wire heartbeat_internal_fault;
    assign heartbeat_internal_fault =
        (state_inv != ~state) ||
        (counter_inv != ~counter) ||
        (wait_cycles_inv != ~wait_cycles);

    always @(posedge clk) begin
        if (rst) begin
            state            <= H_IDLE;
            counter          <= 32'd0;
            wait_cycles      <= 4'd0;
            state_inv        <= ~H_IDLE;
            counter_inv      <= {32{1'b1}};
            wait_cycles_inv  <= {4{1'b1}};
            test_inject      <= 1'b0;
            heartbeat_fault_int <= 1'b0;
            heartbeat_fault  <= 1'b0;
            heartbeat_active <= 1'b0;
        end else begin
            test_inject <= 1'b0;  // default: pulse for 1 cycle only
            heartbeat_fault <= heartbeat_fault_int | heartbeat_internal_fault;

            case (state)
                H_IDLE: begin
                    heartbeat_active <= 1'b0;
                    if (enable && !heartbeat_fault_int && !heartbeat_internal_fault) begin
                        if (counter >= HEARTBEAT_INTERVAL) begin
                            counter <= 32'd0;
                            counter_inv <= {32{1'b1}};
                            state   <= H_WAIT_IDLE;
                            state_inv <= ~H_WAIT_IDLE;
                        end else begin
                            counter <= counter + 32'd1;
                            counter_inv <= ~(counter + 32'd1);
                        end
                    end
                end

                H_WAIT_IDLE: begin
                    heartbeat_active <= 1'b1;
                    if (!scan_busy) begin
                        state <= H_INJECT;
                        state_inv <= ~H_INJECT;
                    end
                end

                H_INJECT: begin
                    // Pulse test_inject for 1 cycle to flip accum_inv
                    test_inject <= 1'b1;
                    wait_cycles <= 4'd0;
                    wait_cycles_inv <= {4{1'b1}};
                    state       <= H_WAIT_DET;
                    state_inv   <= ~H_WAIT_DET;
                end

                H_WAIT_DET: begin
                    wait_cycles <= wait_cycles + 4'd1;
                    wait_cycles_inv <= ~(wait_cycles + 4'd1);
                    if (safety_island_fault_detect) begin
                        // Heartbeat passed: fault_detect path is alive
                        state <= H_CLEAR;
                        state_inv <= ~H_CLEAR;
                    end else if (wait_cycles >= 4'd10) begin
                        // Timeout: fault_detect path is stuck
                        heartbeat_fault_int <= 1'b1;
                        state           <= H_FAIL;
                        state_inv       <= ~H_FAIL;
                    end
                end

                H_CLEAR: begin
                    // Allow fault_detect to clear naturally, return to idle
                    heartbeat_active <= 1'b0;
                    state <= H_IDLE;
                    state_inv <= ~H_IDLE;
                end

                H_FAIL: begin
                    // heartbeat_fault remains sticky until rst
                    heartbeat_active <= 1'b0;
                end

                default: begin
                    state <= H_IDLE;
                    state_inv <= ~H_IDLE;
                end
            endcase
        end
    end

endmodule
