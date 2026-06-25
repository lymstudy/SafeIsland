// Mini debug test for s_axi_config
`include "axi_safety_island_pkg.vh"

module tb_mini;
reg clk, rst_n;

reg [7:0] awid, awlen, arid, arlen;
reg [31:0] awaddr, araddr;
reg [2:0] awsize, arsize;
reg [1:0] awburst, arburst;
reg awvalid, wlast, wvalid, bready, arvalid, rready;
wire awready, wready, bvalid, arready, rvalid, rlast;
wire [7:0] bid, rid;
wire [1:0] bresp, rresp;
reg [63:0] wdata;
reg [7:0] wstrb;
wire [63:0] rdata;
wire cfg_enable, cfg_soft_reset, cfg_write_protect, cfg_aou_enable, cfg_latent_check_enable;
wire [31:0] cfg_read_interval, cfg_timeout_threshold;
wire [7:0] cfg_max_outstanding;
wire [31:0] cfg_base_addr_0, cfg_base_addr_1, cfg_base_addr_2, cfg_base_addr_3, cfg_base_addr_4;
reg cfg_bus_req;
reg [12:0] cfg_bus_addr;
wire cfg_bus_ack;
wire [63:0] cfg_bus_rdata;
reg [63:0] fault_status_in, fc_0, fc_1, fc_2, fc_3;
wire [63:0] fault_clear_out;
wire fault_clear_valid, config_locked;

s_axi_config u_dut (
    .clk(clk), .rst_n(rst_n),
    .s_axi_awid(awid), .s_axi_awaddr(awaddr), .s_axi_awlen(awlen),
    .s_axi_awsize(awsize), .s_axi_awburst(awburst),
    .s_axi_awvalid(awvalid), .s_axi_awready(awready),
    .s_axi_wdata(wdata), .s_axi_wstrb(wstrb), .s_axi_wlast(wlast),
    .s_axi_wvalid(wvalid), .s_axi_wready(wready),
    .s_axi_bid(bid), .s_axi_bresp(bresp), .s_axi_bvalid(bvalid), .s_axi_bready(bready),
    .s_axi_arid(arid), .s_axi_araddr(araddr), .s_axi_arlen(arlen),
    .s_axi_arsize(arsize), .s_axi_arburst(arburst),
    .s_axi_arvalid(arvalid), .s_axi_arready(arready),
    .s_axi_rid(rid), .s_axi_rdata(rdata), .s_axi_rresp(rresp),
    .s_axi_rlast(rlast), .s_axi_rvalid(rvalid), .s_axi_rready(rready),
    .cfg_enable(cfg_enable), .cfg_soft_reset(cfg_soft_reset),
    .cfg_write_protect(cfg_write_protect), .cfg_aou_enable(cfg_aou_enable),
    .cfg_latent_check_enable(cfg_latent_check_enable),
    .cfg_read_interval(cfg_read_interval), .cfg_timeout_threshold(cfg_timeout_threshold),
    .cfg_max_outstanding(cfg_max_outstanding),
    .cfg_base_addr_0(cfg_base_addr_0), .cfg_base_addr_1(cfg_base_addr_1),
    .cfg_base_addr_2(cfg_base_addr_2), .cfg_base_addr_3(cfg_base_addr_3),
    .cfg_base_addr_4(cfg_base_addr_4),
    .cfg_bus_req(cfg_bus_req), .cfg_bus_addr(cfg_bus_addr),
    .cfg_bus_ack(cfg_bus_ack), .cfg_bus_rdata(cfg_bus_rdata),
    .fault_status_in(fault_status_in),
    .fault_counter_0(fc_0), .fault_counter_1(fc_1),
    .fault_counter_2(fc_2), .fault_counter_3(fc_3),
    .fault_clear_out(fault_clear_out), .fault_clear_valid(fault_clear_valid),
    .config_locked(config_locked)
);

always #5 clk = ~clk;

integer cyc;
initial begin
    clk=0; rst_n=0; cyc=0;
    awid=0; awaddr=0; awlen=0; awsize=3'd3; awburst=`AXI_BURST_INCR; awvalid=0;
    wdata=0; wstrb=8'hFF; wlast=0; wvalid=0;
    bready=1;
    arid=0; araddr=0; arlen=0; arsize=3'd3; arburst=`AXI_BURST_INCR; arvalid=0;
    rready=1;
    cfg_bus_req=0; cfg_bus_addr=0;
    fault_status_in=0; fc_0=0; fc_1=0; fc_2=0; fc_3=0;

    // Reset
    repeat(10) @(posedge clk);
    rst_n=1;
    @(posedge clk);

    // Test 1: Write then Read
    $display("T=%-4d: Starting write to CTRL", $time);
    awaddr=`ADDR_CTRL; awlen=8'd0; awsize=3'd3; awburst=`AXI_BURST_INCR; awid=0;
    awvalid=1;
    @(posedge clk);
    awvalid=0;
    $display("T=%-4d: AW done, starting W. awready=%b wr_busy=%b", $time, awready, u_dut.wr_busy);
    wdata={58'd0, 6'b101010}; wstrb=8'hFF; wlast=1; wvalid=1;
    @(posedge clk);
    wvalid=0; wlast=0;
    $display("T=%-4d: W done. wready=%b wr_busy=%b", $time, wready, u_dut.wr_busy);
    while (!bvalid) @(posedge clk);
    $display("T=%-4d: Bvalid! bresp=%b", $time, bresp);
    @(posedge clk);

    // Test 2: Read CTRL
    $display("T=%-4d: Starting read from CTRL. arready=%b rd_busy=%b", $time, arready, u_dut.rd_busy);
    araddr=`ADDR_CTRL; arlen=8'd0; arsize=3'd3; arburst=`AXI_BURST_INCR; arid=0;
    arvalid=1;
    @(posedge clk);
    arvalid=0;
    $display("T=%-4d: AR done. arready=%b rd_busy=%b rvalid=%b", $time, arready, u_dut.rd_busy, rvalid);
    while (!rvalid) @(posedge clk);
    $display("T=%-4d: Rvalid! rdata=%0h rresp=%b", $time, rdata, rresp);
    @(posedge clk);
    $display("T=%-4d: After read. rvalid=%b rd_busy=%b", $time, rvalid, u_dut.rd_busy);

    // Test 3: Second write
    $display("T=%-4d: Second write to READ_INTERVAL", $time);
    awaddr=`ADDR_READ_INTERVAL; awlen=8'd0; awsize=3'd3; awburst=`AXI_BURST_INCR; awid=0;
    awvalid=1;
    @(posedge clk);
    awvalid=0;
    $display("T=%-4d: AW2 done. awready=%b wr_busy=%b", $time, awready, u_dut.wr_busy);
    wdata={32'd0, 32'd999}; wstrb=8'hFF; wlast=1; wvalid=1;
    @(posedge clk);
    wvalid=0; wlast=0;
    $display("T=%-4d: W2 done. wready=%b wr_busy=%b", $time, wready, u_dut.wr_busy);
    while (!bvalid) @(posedge clk);
    $display("T=%-4d: Bvalid2! bresp=%b", $time, bresp);
    @(posedge clk);

    // Test 4: Second read
    $display("T=%-4d: Second read from READ_INTERVAL. arready=%b rd_busy=%b", $time, arready, u_dut.rd_busy);
    araddr=`ADDR_READ_INTERVAL; arlen=8'd0; arsize=3'd3; arburst=`AXI_BURST_INCR; arid=0;
    arvalid=1;
    @(posedge clk);
    arvalid=0;
    $display("T=%-4d: AR2 done. arready=%b rd_busy=%b rvalid=%b", $time, arready, u_dut.rd_busy, rvalid);
    while (!rvalid) @(posedge clk);
    $display("T=%-4d: Rvalid2! rdata=%0h rresp=%b", $time, rdata, rresp);
    @(posedge clk);

    $display("ALL MINI TESTS DONE");
    $finish;
end

// Watchdog
initial begin
    #100000;
    $display("TIMEOUT 1000ns");
    $finish;
end

endmodule
