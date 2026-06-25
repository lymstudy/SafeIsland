//=============================================================================
// tb_s_axi_config.v — S_AXI Config Testbench (inline, no macros/tasks)
// Icarus Verilog 0.9.7 compatible
//=============================================================================
`include "axi_safety_island_pkg.vh"

module tb_s_axi_config;
reg clk, rst_n;
integer err, jj;
reg [63:0] cdata; reg [1:0] cresp;

reg [7:0] awid,awlen,arid,arlen;
reg [31:0] awaddr,araddr;
reg [2:0] awsize,arsize;
reg [1:0] awburst,arburst;
reg awvalid,wlast,wvalid,bready,arvalid,rready;
wire awready,wready,bvalid,arready,rvalid,rlast;
wire [7:0] bid,rid;
wire [1:0] bresp,rresp;
reg [63:0] wdata;
reg [7:0] wstrb;
wire [63:0] rdata;
wire cfg_enable,cfg_write_protect,cfg_soft_reset,cfg_aou_enable,cfg_latent_check_enable;
wire [31:0] cfg_read_interval,cfg_timeout_threshold;
wire [7:0] cfg_max_outstanding;
wire [31:0] b0,b1,b2,b3,b4;
wire cfg_valid,cfg_shadow_error;
wire [319:0] cfg_entry_valid_flat;
wire [64*320-1:0] cfg_expected_flat;
wire fault_clear_valid,config_locked;
wire [63:0] fault_clear_out;
reg [63:0] fs,fc0,fc1,fc2,fc3;
reg cbr; reg [12:0] cba; wire cba_ack; wire [63:0] cbd;

s_axi_config dut(.clk(clk),.rst_n(rst_n),
    .s_axi_awid(awid),.s_axi_awaddr(awaddr),.s_axi_awlen(awlen),
    .s_axi_awsize(awsize),.s_axi_awburst(awburst),
    .s_axi_awvalid(awvalid),.s_axi_awready(awready),
    .s_axi_wdata(wdata),.s_axi_wstrb(wstrb),.s_axi_wlast(wlast),
    .s_axi_wvalid(wvalid),.s_axi_wready(wready),
    .s_axi_bid(bid),.s_axi_bresp(bresp),.s_axi_bvalid(bvalid),.s_axi_bready(bready),
    .s_axi_arid(arid),.s_axi_araddr(araddr),.s_axi_arlen(arlen),
    .s_axi_arsize(arsize),.s_axi_arburst(arburst),
    .s_axi_arvalid(arvalid),.s_axi_arready(arready),
    .s_axi_rid(rid),.s_axi_rdata(rdata),.s_axi_rresp(rresp),
    .s_axi_rlast(rlast),.s_axi_rvalid(rvalid),.s_axi_rready(rready),
    .cfg_enable(cfg_enable),.cfg_soft_reset(cfg_soft_reset),
    .cfg_write_protect(cfg_write_protect),.cfg_aou_enable(cfg_aou_enable),
    .cfg_latent_check_enable(cfg_latent_check_enable),
    .cfg_read_interval(cfg_read_interval),.cfg_timeout_threshold(cfg_timeout_threshold),
    .cfg_max_outstanding(cfg_max_outstanding),
    .cfg_base_addr_0(b0),.cfg_base_addr_1(b1),.cfg_base_addr_2(b2),
    .cfg_base_addr_3(b3),.cfg_base_addr_4(b4),
    .cfg_valid(cfg_valid),.cfg_entry_valid_flat(cfg_entry_valid_flat),
    .cfg_expected_flat(cfg_expected_flat),.cfg_shadow_error(cfg_shadow_error),
    .cfg_bus_req(cbr),.cfg_bus_addr(cba),.cfg_bus_ack(cba_ack),.cfg_bus_rdata(cbd),
    .fault_status_in(fs),.fault_counter_0(fc0),.fault_counter_1(fc1),
    .fault_counter_2(fc2),.fault_counter_3(fc3),
    .fault_clear_out(fault_clear_out),.fault_clear_valid(fault_clear_valid),
    .config_locked(config_locked)
);

always #5 clk=~clk;

initial begin
    clk=0; rst_n=0; err=0;
    awid=0;awaddr=0;awlen=0;awsize=3'd3;awburst=2'b01;awvalid=0;
    wdata=0;wstrb=8'hFF;wlast=0;wvalid=0;bready=1;
    arid=0;araddr=0;arlen=0;arsize=3'd3;arburst=2'b01;arvalid=0;rready=1;
    cbr=0;cba=0;fs=0;fc0=0;fc1=0;fc2=0;fc3=0;
    repeat(10) @(posedge clk); rst_n=1; @(posedge clk); @(posedge clk); @(posedge clk);

    //=====================================================================
    // CFG-001: 复位默认值
    //=====================================================================
    $display("\n=== CFG-001: 复位默认值 ===");
    araddr=`ADDR_CTRL; arlen=8'd0; arsize=3'd3; arburst=2'b01; arid=8'd0;
    arvalid=1; @(posedge clk); arvalid=0; while(!rvalid) @(posedge clk);
    cdata=rdata; cresp=rresp; @(posedge clk);
    if(cresp==2'b00 && cdata=={58'd0,6'b000000}) $display("[PASS] CFG-001a: CTRL=0");
    else begin $display("[FAIL] CFG-001a: %0h %b",cdata,cresp); err=err+1; end

    araddr=`ADDR_READ_INTERVAL; arlen=8'd0; arsize=3'd3; arburst=2'b01; arid=8'd0;
    arvalid=1; @(posedge clk); arvalid=0; while(!rvalid) @(posedge clk);
    cdata=rdata; cresp=rresp; @(posedge clk);
    if(cresp==2'b00 && cdata[31:0]==32'd1000) $display("[PASS] CFG-001b: INTERVAL=1000");
    else begin $display("[FAIL] CFG-001b: %0d",cdata[31:0]); err=err+1; end

    if(cfg_enable==0 && cfg_write_protect==0) $display("[PASS] CFG-001c: en/wp=0");
    else begin $display("[FAIL] CFG-001c"); err=err+1; end

    //=====================================================================
    // CFG-002: 单寄存器写读回
    //=====================================================================
    $display("\n=== CFG-002: 读写 ===");
    // write BASE_ADDR[0]
    awaddr=`ADDR_BASE_ADDR_BASE; awlen=8'd0; awsize=3'd3; awburst=2'b01; awid=8'd0;
    awvalid=1; @(posedge clk); awvalid=0;
    wdata=64'h0000_0000_4000_0000; wstrb=8'hFF; wlast=1; wvalid=1;
    @(posedge clk); wvalid=0; wlast=0; while(!bvalid) @(posedge clk);
    cresp=bresp; @(posedge clk);
    if(cresp==2'b00) $display("[PASS] CFG-002a: 写OK");
    else begin $display("[FAIL] CFG-002a: %b",cresp); err=err+1; end
    // read back
    araddr=`ADDR_BASE_ADDR_BASE; arlen=8'd0; arsize=3'd3; arburst=2'b01; arid=8'd0;
    arvalid=1; @(posedge clk); arvalid=0; while(!rvalid) @(posedge clk);
    cdata=rdata; cresp=rresp; @(posedge clk);
    if(cresp==2'b00 && cdata==64'h4000_0000) $display("[PASS] CFG-002b: 一致");
    else begin $display("[FAIL] CFG-002b: %0h",cdata); err=err+1; end

    // write READ_INTERVAL = 500
    awaddr=`ADDR_READ_INTERVAL; awlen=8'd0; awsize=3'd3; awburst=2'b01; awid=8'd0;
    awvalid=1; @(posedge clk); awvalid=0;
    wdata={32'd0,32'd500}; wstrb=8'hFF; wlast=1; wvalid=1;
    @(posedge clk); wvalid=0; wlast=0; while(!bvalid) @(posedge clk);
    cresp=bresp; @(posedge clk);
    if(cresp==2'b00) $display("[PASS] CFG-002c: 写OK");
    else begin $display("[FAIL] CFG-002c"); err=err+1; end
    araddr=`ADDR_READ_INTERVAL; arlen=8'd0; arsize=3'd3; arburst=2'b01; arid=8'd0;
    arvalid=1; @(posedge clk); arvalid=0; while(!rvalid) @(posedge clk);
    cdata=rdata; cresp=rresp; @(posedge clk);
    if(cresp==2'b00 && cdata[31:0]==32'd500) $display("[PASS] CFG-002d: 500");
    else begin $display("[FAIL] CFG-002d: %0d",cdata[31:0]); err=err+1; end

    //=====================================================================
    // CFG-003: Byte strobe
    //=====================================================================
    $display("\n=== CFG-003: Byte strobe ===");
    awaddr=`ADDR_MASK_BASE; awlen=8'd0; awsize=3'd3; awburst=2'b01; awid=8'd0;
    awvalid=1; @(posedge clk); awvalid=0;
    wdata=64'h0; wstrb=8'hFF; wlast=1; wvalid=1; @(posedge clk); wvalid=0; wlast=0;
    while(!bvalid) @(posedge clk); cresp=bresp; @(posedge clk); @(posedge clk);
    // write low 4 bytes (strobe=0x0F)
    awaddr=`ADDR_MASK_BASE; awlen=8'd0; awsize=3'd3; awburst=2'b01; awid=8'd0;
    awvalid=1; @(posedge clk); awvalid=0;
    wdata=64'hAAAA_BBBB_CCCC_DDDD; wstrb=8'h0F; wlast=1; wvalid=1;
    @(posedge clk); wvalid=0; wlast=0; while(!bvalid) @(posedge clk); cresp=bresp; @(posedge clk); @(posedge clk);
    araddr=`ADDR_MASK_BASE; arlen=8'd0; arsize=3'd3; arburst=2'b01; arid=8'd0;
    arvalid=1; @(posedge clk); arvalid=0; while(!rvalid) @(posedge clk);
    cdata=rdata; cresp=rresp; @(posedge clk);
    if(cresp==2'b00 && cdata==64'h0000_0000_CCCC_DDDD) $display("[PASS] CFG-003a: 低4B");
    else begin $display("[FAIL] CFG-003a: %0h",cdata); err=err+1; end
    // write high 4 bytes (strobe=0xF0)
    awaddr=`ADDR_MASK_BASE; awlen=8'd0; awsize=3'd3; awburst=2'b01; awid=8'd0;
    awvalid=1; @(posedge clk); awvalid=0;
    wdata=64'h1111_2222_3333_4444; wstrb=8'hF0; wlast=1; wvalid=1;
    @(posedge clk); wvalid=0; wlast=0; while(!bvalid) @(posedge clk); cresp=bresp; @(posedge clk); @(posedge clk);
    araddr=`ADDR_MASK_BASE; arlen=8'd0; arsize=3'd3; arburst=2'b01; arid=8'd0;
    arvalid=1; @(posedge clk); arvalid=0; while(!rvalid) @(posedge clk);
    cdata=rdata; cresp=rresp; @(posedge clk);
    if(cresp==2'b00 && cdata==64'h1111_2222_CCCC_DDDD) $display("[PASS] CFG-003b: 高4B");
    else begin $display("[FAIL] CFG-003b: %0h",cdata); err=err+1; end

    //=====================================================================
    // CFG-004: INCR burst 4-beat
    //=====================================================================
    $display("\n=== CFG-004: INCR burst ===");
    awaddr=`ADDR_OFFSET_BASE; awlen=8'd3; awsize=3'd3; awburst=2'b01; awid=0;
    awvalid=1; @(posedge clk); awvalid=0;
    for(jj=0;jj<4;jj=jj+1) begin
        wdata=64'hA000000000000000+jj; wstrb=8'hFF; wlast=(jj==3); wvalid=1;
        @(posedge clk);
    end
    wvalid=0; wlast=0; while(!bvalid) @(posedge clk); cresp=bresp; @(posedge clk); @(posedge clk);
    if(cresp==2'b00) $display("[PASS] CFG-004: INCR ok");
    else begin $display("[FAIL] CFG-004: %b",cresp); err=err+1; end

    //=====================================================================
    // CFG-006: burst length 16
    //=====================================================================
    $display("\n=== CFG-006: BL16 ===");
    awaddr=`ADDR_MASK_BASE; awlen=8'd15; awsize=3'd3; awburst=2'b01; awid=0;
    awvalid=1; @(posedge clk); awvalid=0;
    for(jj=0;jj<16;jj=jj+1) begin
        wdata=64'hCAFE000000000000+jj; wstrb=8'hFF; wlast=(jj==15); wvalid=1;
        @(posedge clk);
    end
    wvalid=0; wlast=0; while(!bvalid) @(posedge clk); cresp=bresp; @(posedge clk); @(posedge clk);
    if(cresp==2'b00) $display("[PASS] CFG-006: BL16 ok");
    else begin $display("[FAIL] CFG-006: %b",cresp); err=err+1; end

    //=====================================================================
    // CFG-007: 非法地址 → SLVERR
    //=====================================================================
    $display("\n=== CFG-007: 非法地址 ===");
    // Use clearly invalid address (high bits non-zero)
    awaddr=32'hFFFF0000; awlen=8'd0; awsize=3'd3; awburst=2'b01; awid=0;
    awvalid=1; @(posedge clk); awvalid=0;
    wdata=64'h1; wstrb=8'hFF; wlast=1; wvalid=1; @(posedge clk); wvalid=0; wlast=0;
    while(!bvalid) @(posedge clk); cresp=bresp; @(posedge clk); @(posedge clk);
    if(cresp==2'b10) $display("[PASS] CFG-007: SLVERR");
    else begin $display("[FAIL] CFG-007: bresp=%b wr_err=%b wr_busy=%b wp=%b lock=%b valid=%b safety=%b entry=%b",cresp,dut.wr_err,dut.wr_busy,dut.ctrl_write_protect,dut.config_locked,dut.addr_valid,dut.wr_is_safety,dut.wr_is_entry); err=err+1; end

    //=====================================================================
    // CFG-008: 非对齐 → SLVERR
    //=====================================================================
    $display("\n=== CFG-008: 非对齐 ===");
    awaddr=32'h0004; awlen=8'd0; awsize=3'd3; awburst=2'b01; awid=0;
    awvalid=1; @(posedge clk); awvalid=0;
    wdata=64'h1; wstrb=8'hFF; wlast=1; wvalid=1; @(posedge clk); wvalid=0; wlast=0;
    while(!bvalid) @(posedge clk); cresp=bresp; @(posedge clk); @(posedge clk);
    if(cresp==2'b10) $display("[PASS] CFG-008: SLVERR");
    else begin $display("[FAIL] CFG-008: %b",cresp); err=err+1; end
    @(posedge clk); @(posedge clk);  // settle

    //=====================================================================
    // CFG-009: 写保护
    //=====================================================================
    $display("\n=== CFG-009: 写保护 ===");
    awaddr=`ADDR_CTRL; awlen=8'd0; awsize=3'd3; awburst=2'b01; awid=0;
    awvalid=1; @(posedge clk); awvalid=0;
    wdata=64'd4; wstrb=8'hFF; wlast=1; wvalid=1; @(posedge clk); wvalid=0; wlast=0;
    while(!bvalid) @(posedge clk); cresp=bresp; @(posedge clk); @(posedge clk);
    if(cresp==2'b00) $display("[PASS] CFG-009a: 写CTRL OK");
    else begin $display("[FAIL] CFG-009a: %b wr_err=%b wr_busy=%b wp=%b lock=%b valid=%b safety=%b entry=%b",cresp,dut.wr_err,dut.wr_busy,dut.ctrl_write_protect,dut.config_locked,dut.addr_valid,dut.wr_is_safety,dut.wr_is_entry); err=err+1; end
    // read back
    araddr=`ADDR_CTRL; arlen=8'd0; arsize=3'd3; arburst=2'b01; arid=8'd0;
    arvalid=1; @(posedge clk); arvalid=0; while(!rvalid) @(posedge clk);
    cdata=rdata; cresp=rresp; @(posedge clk);
    if(cresp==2'b00 && cdata==64'd4) $display("[PASS] CFG-009b: CTRL=4");
    else begin $display("[FAIL] CFG-009b: %0h",cdata); err=err+1; end
    if(cfg_write_protect) $display("[PASS] CFG-009c: wp=1");
    else begin $display("[FAIL] CFG-009c: wp=%b",cfg_write_protect); err=err+1; end
    // try write protected reg
    awaddr=`ADDR_BASE_ADDR_BASE; awlen=8'd0; awsize=3'd3; awburst=2'b01; awid=0;
    awvalid=1; @(posedge clk); awvalid=0;
    wdata=64'hDEADBEEF; wstrb=8'hFF; wlast=1; wvalid=1; @(posedge clk); wvalid=0; wlast=0;
    while(!bvalid) @(posedge clk); cresp=bresp; @(posedge clk); @(posedge clk);
    if(cresp==2'b10) $display("[PASS] CFG-009d: wp阻断");
    else begin $display("[FAIL] CFG-009d: %b",cresp); err=err+1; end
    // clear wp
    awaddr=`ADDR_CTRL; awlen=8'd0; awsize=3'd3; awburst=2'b01; awid=0;
    awvalid=1; @(posedge clk); awvalid=0;
    wdata=64'd0; wstrb=8'hFF; wlast=1; wvalid=1; @(posedge clk); wvalid=0; wlast=0;
    while(!bvalid) @(posedge clk); cresp=bresp; @(posedge clk); @(posedge clk);

    //=====================================================================
    // CFG-010: W1C
    //=====================================================================
    $display("\n=== CFG-010: W1C ===");
    fs=64'h0000000F;
    araddr=`ADDR_FAULT_STATUS; arlen=8'd0; arsize=3'd3; arburst=2'b01; arid=8'd0;
    arvalid=1; @(posedge clk); arvalid=0; while(!rvalid) @(posedge clk);
    cdata=rdata; cresp=rresp; @(posedge clk);
    if(cresp==2'b00 && cdata==64'hF) $display("[PASS] CFG-010a: status=F");
    else begin $display("[FAIL] CFG-010a: %0h",cdata); err=err+1; end
    // W1C bit 0
    awaddr=`ADDR_FAULT_STATUS; awlen=8'd0; awsize=3'd3; awburst=2'b01; awid=0;
    awvalid=1; @(posedge clk); awvalid=0;
    wdata=64'h1; wstrb=8'hFF; wlast=1; wvalid=1; @(posedge clk); wvalid=0; wlast=0;
    while(!bvalid) @(posedge clk); cresp=bresp; @(posedge clk); @(posedge clk);
    @(posedge clk); @(posedge clk);
    if(fault_clear_valid && fault_clear_out[0]) $display("[PASS] CFG-010b: W1C");
    else begin $display("[FAIL] CFG-010b: v=%b d=%0h",fault_clear_valid,fault_clear_out); err=err+1; end
    fs=0;

    //=====================================================================
    // CFG-011: 非法 burst
    //=====================================================================
    $display("\n=== CFG-011: 非法 burst ===");
    awaddr=32'h0100; awlen=8'd0; awsize=3'd3; awburst=2'b00; awid=0;
    awvalid=1; @(posedge clk); awvalid=0;
    wdata=64'h1; wstrb=8'hFF; wlast=1; wvalid=1; @(posedge clk); wvalid=0; wlast=0;
    while(!bvalid) @(posedge clk); cresp=bresp; @(posedge clk); @(posedge clk);
    if(cresp==2'b10) $display("[PASS] CFG-011: FIXED→SLVERR");
    else begin $display("[FAIL] CFG-011: %b",cresp); err=err+1; end

    //=====================================================================
    // CFG-012: 运行中保护
    //=====================================================================
    $display("\n=== CFG-012: 运行中保护 ===");
    awaddr=`ADDR_CTRL; awlen=8'd0; awsize=3'd3; awburst=2'b01; awid=0;
    awvalid=1; @(posedge clk); awvalid=0;
    wdata=64'd6; wstrb=8'hFF; wlast=1; wvalid=1; @(posedge clk); wvalid=0; wlast=0;
    while(!bvalid) @(posedge clk); cresp=bresp; @(posedge clk); @(posedge clk);
    if(cresp==2'b00) $display("[PASS] CFG-012a: CTRL=6 OK");
    else begin $display("[FAIL] CFG-012a"); err=err+1; end
    araddr=`ADDR_CTRL; arlen=8'd0; arsize=3'd3; arburst=2'b01; arid=8'd0;
    arvalid=1; @(posedge clk); arvalid=0; while(!rvalid) @(posedge clk);
    cdata=rdata; cresp=rresp; @(posedge clk);
    if(cresp==2'b00 && cdata==64'd6) $display("[PASS] CFG-012b: 读回=6");
    else begin $display("[FAIL] CFG-012b: %0h",cdata); err=err+1; end
    // try write protected
    awaddr=`ADDR_BASE_ADDR_BASE; awlen=8'd0; awsize=3'd3; awburst=2'b01; awid=0;
    awvalid=1; @(posedge clk); awvalid=0;
    wdata=64'hFFFF; wstrb=8'hFF; wlast=1; wvalid=1; @(posedge clk); wvalid=0; wlast=0;
    while(!bvalid) @(posedge clk); cresp=bresp; @(posedge clk); @(posedge clk);
    if(cresp==2'b10) $display("[PASS] CFG-012c: wp阻断");
    else begin $display("[FAIL] CFG-012c: %b",cresp); err=err+1; end

    //=====================================================================
    // CFG-013: expected register readback
    //=====================================================================
    $display("\n=== CFG-013: expected readback ===");
    awaddr=`ADDR_CTRL; awlen=8'd0; awsize=3'd3; awburst=2'b01; awid=0;
    awvalid=1; @(posedge clk); awvalid=0;
    wdata=64'd0; wstrb=8'hFF; wlast=1; wvalid=1; @(posedge clk); wvalid=0; wlast=0;
    while(!bvalid) @(posedge clk); cresp=bresp; @(posedge clk); @(posedge clk);
    awaddr=`ADDR_EXPECTED_BASE; awlen=8'd0; awsize=3'd3; awburst=2'b01; awid=0;
    awvalid=1; @(posedge clk); awvalid=0;
    wdata=64'h1234_5678_9ABC_DEF0; wstrb=8'hFF; wlast=1; wvalid=1;
    @(posedge clk); wvalid=0; wlast=0; while(!bvalid) @(posedge clk); cresp=bresp; @(posedge clk); @(posedge clk);
    if(cresp==2'b00) $display("[PASS] CFG-013a: expected write OK");
    else begin $display("[FAIL] CFG-013a: %b",cresp); err=err+1; end
    araddr=`ADDR_EXPECTED_BASE; arlen=8'd0; arsize=3'd3; arburst=2'b01; arid=8'd0;
    arvalid=1; @(posedge clk); arvalid=0; while(!rvalid) @(posedge clk);
    cdata=rdata; cresp=rresp; @(posedge clk);
    if(cresp==2'b00 && cdata==64'h1234_5678_9ABC_DEF0) $display("[PASS] CFG-013b: expected readback");
    else begin $display("[FAIL] CFG-013b: %0h",cdata); err=err+1; end
    if(cfg_expected_flat[63:0] == 64'h1234_5678_9ABC_DEF0) $display("[PASS] CFG-013c: expected flat");
    else begin $display("[FAIL] CFG-013c: %0h",cfg_expected_flat[63:0]); err=err+1; end

    //=====================================================================
    // CFG-014: entry valid programming/readback
    //=====================================================================
    $display("\n=== CFG-014: entry valid ===");
    awaddr=`ADDR_OFFSET_BASE; awlen=8'd0; awsize=3'd3; awburst=2'b01; awid=0;
    awvalid=1; @(posedge clk); awvalid=0;
    wdata=64'h0000_0008_0000_0040; wstrb=8'hFF; wlast=1; wvalid=1;
    @(posedge clk); wvalid=0; wlast=0; while(!bvalid) @(posedge clk); cresp=bresp; @(posedge clk); @(posedge clk);
    if(cresp==2'b00) $display("[PASS] CFG-014a: entry valid write OK");
    else begin $display("[FAIL] CFG-014a: %b wr_err=%b wr_busy=%b wp=%b lock=%b valid=%b safety=%b entry=%b",cresp,dut.wr_err,dut.wr_busy,dut.ctrl_write_protect,dut.config_locked,dut.addr_valid,dut.wr_is_safety,dut.wr_is_entry); err=err+1; end
    araddr=`ADDR_OFFSET_BASE; arlen=8'd0; arsize=3'd3; arburst=2'b01; arid=8'd0;
    arvalid=1; @(posedge clk); arvalid=0; while(!rvalid) @(posedge clk);
    cdata=rdata; cresp=rresp; @(posedge clk);
    if(cresp==2'b00 && cdata==64'h0000_0008_0000_0040) $display("[PASS] CFG-014b: entry readback");
    else begin $display("[FAIL] CFG-014b: %0h",cdata); err=err+1; end
    if(cfg_entry_valid_flat[0] == 1'b1) $display("[PASS] CFG-014c: entry valid flat");
    else begin $display("[FAIL] CFG-014c: %b",cfg_entry_valid_flat[0]); err=err+1; end

    //=====================================================================
    // CFG-015 / CFG-016: lock blocks rewrite and activates status
    //=====================================================================
    $display("\n=== CFG-015/016: lock status ===");
    if(cfg_valid == 1'b0) $display("[PASS] CFG-016a: cfg_valid idle before lock");
    else begin $display("[FAIL] CFG-016a: cfg_valid=%b",cfg_valid); err=err+1; end
    awaddr=`ADDR_CONFIG_LOCK; awlen=8'd0; awsize=3'd3; awburst=2'b01; awid=0;
    awvalid=1; @(posedge clk); awvalid=0;
    wdata=64'd1; wstrb=8'hFF; wlast=1; wvalid=1; @(posedge clk); wvalid=0; wlast=0;
    while(!bvalid) @(posedge clk); cresp=bresp; @(posedge clk); @(posedge clk);
    if(cresp==2'b00) $display("[PASS] CFG-015a: lock write OK");
    else begin $display("[FAIL] CFG-015a: %b wr_err=%b wr_busy=%b wp=%b lock=%b valid=%b safety=%b entry=%b",cresp,dut.wr_err,dut.wr_busy,dut.ctrl_write_protect,dut.config_locked,dut.addr_valid,dut.wr_is_safety,dut.wr_is_entry); err=err+1; end
    awaddr=`ADDR_EXPECTED_BASE; awlen=8'd0; awsize=3'd3; awburst=2'b01; awid=0;
    awvalid=1; @(posedge clk); awvalid=0;
    wdata=64'h0BAD_F00D_2222_1111; wstrb=8'hFF; wlast=1; wvalid=1;
    @(posedge clk); wvalid=0; wlast=0; while(!bvalid) @(posedge clk); cresp=bresp; @(posedge clk); @(posedge clk);
    if(cresp==2'b10) $display("[PASS] CFG-015b: locked expected rewrite blocked");
    else begin $display("[FAIL] CFG-015b: %b",cresp); err=err+1; end
    araddr=`ADDR_EXPECTED_BASE; arlen=8'd0; arsize=3'd3; arburst=2'b01; arid=8'd0;
    arvalid=1; @(posedge clk); arvalid=0; while(!rvalid) @(posedge clk);
    cdata=rdata; cresp=rresp; @(posedge clk);
    if(cresp==2'b00 && cdata==64'h1234_5678_9ABC_DEF0) $display("[PASS] CFG-015c: expected preserved");
    else begin $display("[FAIL] CFG-015c: %0h",cdata); err=err+1; end
    if(cfg_valid == 1'b1) $display("[PASS] CFG-016b: cfg_valid active after lock");
    else begin $display("[FAIL] CFG-016b: cfg_valid=%b",cfg_valid); err=err+1; end
    if(cfg_shadow_error == 1'b0) $display("[PASS] CFG-016c: cfg_shadow_error clear");
    else begin $display("[FAIL] CFG-016c: cfg_shadow_error=%b",cfg_shadow_error); err=err+1; end

    //=====================================================================
    $display("\n========================================");
    if(err==0) $display("  [FINAL RESULT] ALL TESTS PASSED");
    else $display("  [FINAL RESULT] %0d ERRORS", err);
    $display("========================================\n");
    $finish;
end

endmodule
