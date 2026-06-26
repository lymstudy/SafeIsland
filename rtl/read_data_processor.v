//=============================================================================
// read_data_processor.v — 读数据处理: Mask/Expected/Bitwise-OR
//=============================================================================
`include "axi_safety_island_pkg.vh"

module read_data_processor (
    input  wire clk, rst_n,
    input  wire data_valid,
    input  wire [`AXI_DATA_WIDTH-1:0] read_data,
    input  wire [`AXI_DATA_WIDTH-1:0] mask,
    input  wire [`AXI_DATA_WIDTH-1:0] expected,
    input  wire compare_enable,
    input  wire or_accumulate_enable,
    output reg  mismatch,
    output reg  [`AXI_DATA_WIDTH-1:0] or_accumulator,
    output reg  or_valid
);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        mismatch <= 0;
        or_accumulator <= 64'd0;
        or_valid <= 0;
    end else begin
        or_valid <= 0;
        mismatch <= 0;

        if (data_valid) begin
            // Masked compare
            if (compare_enable) begin
                if ((read_data & mask) != (expected & mask))
                    mismatch <= 1'b1;
            end

            // Bitwise OR accumulation
            if (or_accumulate_enable) begin
                or_accumulator <= or_accumulator | (read_data & mask);
                or_valid <= 1'b1;
            end
        end
    end
end

endmodule
