module x()
    reg [7:0] a;
    reg [7:0] b;
    reg [7:0] c;

    always @(*) begin
        c = a + b;
    end
endmodule