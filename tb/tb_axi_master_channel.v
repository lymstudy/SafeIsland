//=============================================================================
// tb_axi_master_channel.v — AXI Master Channel Testbench
//=============================================================================
`include "axi_safety_island_pkg.vh"

module tb_axi_master_channel;
reg clk, rst_n;
integer err;

reg        start;
reg [31:0] read_addr;
reg [7:0]  burst_len;
reg [1:0]  burst_type;
reg [7:0]  channel_id;
reg [31:0] timeout_cycles;
wire       done, error;
wire [3:0] error_type;
wire       data_valid, data_last;
wire [63:0] data_out;
wire [7:0] beat_num;

wire [7:0]  arid;
wire [31:0] araddr;
wire [7:0]  arlen;
wire [2:0]  arsize;
wire [1:0]  arburst;
wire       arvalid;
reg        arready;
reg  [7:0]  slv_rid;
reg  [63:0] slv_rdata;
reg  [1:0]  slv_rresp;
reg         slv_rlast, slv_rvalid;
wire        rready;

axi_master_channel u_dut (
    .clk(clk), .rst_n(rst_n),
    .start(start), .read_addr(read_addr), .burst_len(burst_len),
    .burst_type(burst_type), .channel_id(channel_id),
    .timeout_cycles(timeout_cycles),
    .done(done), .error(error), .error_type(error_type),
    .data_valid(data_valid), .data_out(data_out),
    .data_last(data_last), .beat_num(beat_num),
    .m_arid(arid), .m_araddr(araddr), .m_arlen(arlen),
    .m_arsize(arsize), .m_arburst(arburst),
    .m_arvalid(arvalid), .m_arready(arready),
    .m_rid(slv_rid), .m_rdata(slv_rdata), .m_rresp(slv_rresp),
    .m_rlast(slv_rlast), .m_rvalid(slv_rvalid), .m_rready(rready)
);

always #5 clk=~clk;

// AXI Slave BFM
reg [7:0] sbeat;
reg [1:0] sresp;
reg       sdelay;

reg ar_accepted;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        slv_rvalid<=0; slv_rdata<=0; slv_rresp<=0; slv_rlast<=0; slv_rid<=0;
        sbeat<=0; ar_accepted<=0; arready<=1;
    end else begin
        arready <= 1'b1;
        if (arvalid && arready) begin
            sbeat <= 0;
            ar_accepted <= 1;
        end

        if (sdelay) begin
            slv_rvalid <= 0;
        end else if (ar_accepted && !slv_rvalid) begin
            // First beat response (next cycle after AR accept)
            slv_rvalid <= 1;
            slv_rdata  <= {32'd0, 24'd0, 8'd0};
            slv_rlast  <= (arlen == 8'd0);
            slv_rresp  <= sresp;
            slv_rid    <= 8'd55;
            ar_accepted <= 0;
        end else if (slv_rvalid && rready) begin
            if (sbeat >= arlen) begin
                slv_rvalid <= 0;
                slv_rlast  <= 0;
            end else begin
                sbeat <= sbeat + 1;
                slv_rdata <= {32'd0, 24'd0, sbeat + 8'd1};
                slv_rlast <= (sbeat + 1 >= arlen);
                slv_rresp <= sresp;
            end
        end
    end
end

initial begin
    clk=0; rst_n=0; err=0;
    start=0; read_addr=0; burst_len=0; burst_type=2'b01; channel_id=0;
    timeout_cycles=32'd100; sresp=0; sdelay=0;
    repeat(10) @(posedge clk); rst_n=1; @(posedge clk); @(posedge clk);

    // MST-001: Single beat read
    $display("\n=== MST-001: 单beat读 ===");
    start=1; read_addr=32'h40000000; burst_len=8'd0; burst_type=2'b01; channel_id=8'd1;
    @(posedge clk); start=0;
    while(!done) @(posedge clk);
    if(!error) $display("[PASS] MST-001: data=%0h",data_out);
    else begin $display("[FAIL] MST-001: err=%b type=%d",error,error_type); err=err+1; end

    // MST-003: INCR burst 4-beat
    $display("\n=== MST-003: INCR 4-beat ===");
    @(posedge clk);
    start=1; read_addr=32'h50000000; burst_len=8'd3; burst_type=2'b01; channel_id=8'd2;
    @(posedge clk); start=0;
    while(!done) @(posedge clk);
    if(!error) $display("[PASS] MST-003: INCR OK");
    else begin $display("[FAIL] MST-003"); err=err+1; end

    // MST-008: Error response
    $display("\n=== MST-008: SLVERR ===");
    sresp=2'b10;
    @(posedge clk);
    start=1; read_addr=32'h60000000; burst_len=8'd0; burst_type=2'b01; channel_id=8'd3;
    @(posedge clk); start=0;
    while(!done) @(posedge clk);
    if(error && error_type==4'd2) $display("[PASS] MST-008: SLVERR");
    else begin $display("[FAIL] MST-008: err=%b type=%d",error,error_type); err=err+1; end
    sresp=0;

    // MST-009: Timeout
    $display("\n=== MST-009: Timeout ===");
    sdelay=1; timeout_cycles=32'd5;
    @(posedge clk);
    start=1; read_addr=32'h70000000; burst_len=8'd0; burst_type=2'b01; channel_id=8'd4;
    @(posedge clk); start=0;
    while(!done) @(posedge clk);
    if(error && error_type==4'd1) $display("[PASS] MST-009: timeout");
    else begin $display("[FAIL] MST-009: err=%b type=%d",error,error_type); err=err+1; end
    sdelay=0; timeout_cycles=32'd100;

    // MST-005: BL16
    $display("\n=== MST-005: BL16 ===");
    @(posedge clk);
    start=1; read_addr=32'h80000000; burst_len=8'd15; burst_type=2'b01; channel_id=8'd5;
    @(posedge clk); start=0;
    while(!done) @(posedge clk);
    if(!error) $display("[PASS] MST-005: BL16 OK");
    else begin $display("[FAIL] MST-005"); err=err+1; end

    $display("\n========================================");
    if(err==0) $display("  [FINAL RESULT] ALL TESTS PASSED");
    else $display("  [FINAL RESULT] %0d ERRORS", err);
    $display("========================================\n");
    $finish;
end

endmodule
