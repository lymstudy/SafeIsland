//=============================================================================
// fault_status_manager.v — Sticky故障状态管理, W1C, 故障计数
//=============================================================================
`include "axi_safety_island_pkg.vh"

module fault_status_manager (
    input  wire clk, rst_n,
    input  wire fault_detect_in,
    input  wire safety_island_fault_in,
    input  wire latent_fault_in,
    input  wire [3:0] fault_type_in,
    input  wire [2:0] fault_channel_in,
    // W1C clear from s_axi_config
    input  wire [`AXI_DATA_WIDTH-1:0] fault_clear,
    input  wire fault_clear_valid,
    // Status outputs
    output reg  [`AXI_DATA_WIDTH-1:0] fault_status,
    output reg  [`AXI_DATA_WIDTH-1:0] fault_counter_0,
    output reg  [`AXI_DATA_WIDTH-1:0] fault_counter_1
);

reg [63:0] sticky_status;
reg [63:0] counter_ext;     // 外部故障计数
reg [63:0] counter_internal; // 内部故障计数

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        sticky_status <= 64'd0;
        counter_ext <= 64'd0;
        counter_internal <= 64'd0;
        fault_status <= 64'd0;
        fault_counter_0 <= 64'd0;
        fault_counter_1 <= 64'd0;
    end else begin
        // Sticky fault bits
        if (fault_detect_in) begin
            sticky_status[0] <= 1'b1;
            counter_ext <= counter_ext + 1;
        end
        if (safety_island_fault_in) begin
            sticky_status[1] <= 1'b1;
            counter_internal <= counter_internal + 1;
        end
        if (latent_fault_in) begin
            sticky_status[2] <= 1'b1;
            counter_internal <= counter_internal + 1;
        end

        // W1C clear
        if (fault_clear_valid) begin
            sticky_status <= sticky_status & (~fault_clear);
        end

        // Output
        fault_status <= sticky_status;
        fault_counter_0 <= counter_ext;
        fault_counter_1 <= counter_internal;
    end
end

endmodule
