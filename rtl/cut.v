module simple_cut (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       en,
    input  wire [3:0] data_in,
    output reg  [3:0] data_out,
    output wire       alarm
);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        data_out <= 4'b0000;
    else if (en)
        data_out <= data_in + 4'b0001;
end

assign alarm = (data_out == 4'b1111);

endmodule
