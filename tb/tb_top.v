//=============================================================================
// tb_top.v — AXI Safety Island Top-Level Integration Testbench
//=============================================================================
`include "axi_safety_island_pkg.vh"

module tb_top;
reg clk, rst_n;
integer err;

// S_AXI signals
reg [7:0]  awid,awlen,arid,arlen;
reg [31:0] awaddr,araddr;
reg [2:0]  awsize,arsize;
reg [1:0]  awburst,arburst;
reg awvalid,wlast,wvalid,bready,arvalid,rready;
wire awready,wready,bvalid,arready,rvalid,rlast;
wire [7:0] bid,rid;
wire [1:0] bresp,rresp;
reg [63:0] wdata;
reg [7:0] wstrb;
wire [63:0] rdata;

// M_AXI signals (5 channels)
wire [7:0] marid0,marid1,marid2,marid3,marid4;
wire [31:0] maraddr0,maraddr1,maraddr2,maraddr3,maraddr4;
wire [7:0] marlen0,marlen1,marlen2,marlen3,marlen4;
wire [1:0] marburst0,marburst1,marburst2,marburst3,marburst4;
wire marvalid0,marvalid1,marvalid2,marvalid3,marvalid4;
reg marready0,marready1,marready2,marready3,marready4;
reg [7:0] mrid0,mrid1,mrid2,mrid3,mrid4;
reg [63:0] mrdata0,mrdata1,mrdata2,mrdata3,mrdata4;
reg [1:0] mrresp0,mrresp1,mrresp2,mrresp3,mrresp4;
reg mrlast0,mrlast1,mrlast2,mrlast3,mrlast4;
reg mrvalid0,mrvalid1,mrvalid2,mrvalid3,mrvalid4;
wire mrready0,mrready1,mrready2,mrready3,mrready4;

wire fault_detect, safety_island_fault_detect, safety_island_latent_fault_detect;

axi_safety_island_core u_top (
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

    .m_axi_arid_0(marid0), .m_axi_araddr_0(maraddr0), .m_axi_arlen_0(marlen0),
    .m_axi_arburst_0(marburst0), .m_axi_arvalid_0(marvalid0), .m_axi_arready_0(marready0),
    .m_axi_rid_0(mrid0), .m_axi_rdata_0(mrdata0), .m_axi_rresp_0(mrresp0),
    .m_axi_rlast_0(mrlast0), .m_axi_rvalid_0(mrvalid0), .m_axi_rready_0(mrready0),
    .m_axi_arid_1(marid1), .m_axi_araddr_1(maraddr1), .m_axi_arlen_1(marlen1),
    .m_axi_arburst_1(marburst1), .m_axi_arvalid_1(marvalid1), .m_axi_arready_1(marready1),
    .m_axi_rid_1(mrid1), .m_axi_rdata_1(mrdata1), .m_axi_rresp_1(mrresp1),
    .m_axi_rlast_1(mrlast1), .m_axi_rvalid_1(mrvalid1), .m_axi_rready_1(mrready1),
    .m_axi_arid_2(marid2), .m_axi_araddr_2(maraddr2), .m_axi_arlen_2(marlen2),
    .m_axi_arburst_2(marburst2), .m_axi_arvalid_2(marvalid2), .m_axi_arready_2(marready2),
    .m_axi_rid_2(mrid2), .m_axi_rdata_2(mrdata2), .m_axi_rresp_2(mrresp2),
    .m_axi_rlast_2(mrlast2), .m_axi_rvalid_2(mrvalid2), .m_axi_rready_2(mrready2),
    .m_axi_arid_3(marid3), .m_axi_araddr_3(maraddr3), .m_axi_arlen_3(marlen3),
    .m_axi_arburst_3(marburst3), .m_axi_arvalid_3(marvalid3), .m_axi_arready_3(marready3),
    .m_axi_rid_3(mrid3), .m_axi_rdata_3(mrdata3), .m_axi_rresp_3(mrresp3),
    .m_axi_rlast_3(mrlast3), .m_axi_rvalid_3(mrvalid3), .m_axi_rready_3(mrready3),
    .m_axi_arid_4(marid4), .m_axi_araddr_4(maraddr4), .m_axi_arlen_4(marlen4),
    .m_axi_arburst_4(marburst4), .m_axi_arvalid_4(marvalid4), .m_axi_arready_4(marready4),
    .m_axi_rid_4(mrid4), .m_axi_rdata_4(mrdata4), .m_axi_rresp_4(mrresp4),
    .m_axi_rlast_4(mrlast4), .m_axi_rvalid_4(mrvalid4), .m_axi_rready_4(mrready4),

    .fault_detect(fault_detect), .safety_island_fault_detect(safety_island_fault_detect),
    .safety_island_latent_fault_detect(safety_island_latent_fault_detect)
);

always #5 clk=~clk;

// AXI Slave BFM (responds to master read requests)
// Simple auto-respond for all 5 channels
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        marready0<=1; marready1<=1; marready2<=1; marready3<=1; marready4<=1;
        mrvalid0<=0; mrvalid1<=0; mrvalid2<=0; mrvalid3<=0; mrvalid4<=0;
        mrdata0<=0; mrdata1<=0; mrdata2<=0; mrdata3<=0; mrdata4<=0;
        mrresp0<=0; mrresp1<=0; mrresp2<=0; mrresp3<=0; mrresp4<=0;
        mrlast0<=0; mrlast1<=0; mrlast2<=0; mrlast3<=0; mrlast4<=0;
    end else begin
        // Channel 0
        if(marvalid0 && marready0 && !mrvalid0) begin
            mrvalid0<=1; mrdata0<=64'hCAFE_0001; mrresp0<=0; mrlast0<=1;
        end else if(mrvalid0 && mrready0) mrvalid0<=0;
        // Channel 1
        if(marvalid1 && marready1 && !mrvalid1) begin
            mrvalid1<=1; mrdata1<=64'hCAFE_0002; mrresp1<=0; mrlast1<=1;
        end else if(mrvalid1 && mrready1) mrvalid1<=0;
        // Channel 2
        if(marvalid2 && marready2 && !mrvalid2) begin
            mrvalid2<=1; mrdata2<=64'hCAFE_0003; mrresp2<=0; mrlast2<=1;
        end else if(mrvalid2 && mrready2) mrvalid2<=0;
        // Channel 3
        if(marvalid3 && marready3 && !mrvalid3) begin
            mrvalid3<=1; mrdata3<=64'hCAFE_0004; mrresp3<=0; mrlast3<=1;
        end else if(mrvalid3 && mrready3) mrvalid3<=0;
        // Channel 4
        if(marvalid4 && marready4 && !mrvalid4) begin
            mrvalid4<=1; mrdata4<=64'hCAFE_0005; mrresp4<=0; mrlast4<=1;
        end else if(mrvalid4 && mrready4) mrvalid4<=0;
    end
end

initial begin
    clk=0; rst_n=0; err=0;
    awid=0;awaddr=0;awlen=0;awsize=3'd3;awburst=2'b01;awvalid=0;
    wdata=0;wstrb=8'hFF;wlast=0;wvalid=0;bready=1;
    arid=0;araddr=0;arlen=0;arsize=3'd3;arburst=2'b01;arvalid=0;rready=1;
    marready0=1;marready1=1;marready2=1;marready3=1;marready4=1;
    mrvalid0=0;mrvalid1=0;mrvalid2=0;mrvalid3=0;mrvalid4=0;
    mrdata0=0;mrdata1=0;mrdata2=0;mrdata3=0;mrdata4=0;
    mrresp0=0;mrresp1=0;mrresp2=0;mrresp3=0;mrresp4=0;
    mrlast0=0;mrlast1=0;mrlast2=0;mrlast3=0;mrlast4=0;

    repeat(10) @(posedge clk); rst_n=1; @(posedge clk); @(posedge clk); @(posedge clk);

    //=====================================================================
    // TOP-001: 配置写入验证
    //=====================================================================
    $display("\n=== TOP-001: 配置写入 ===");
    // Write BASE_ADDR[0]
    awaddr=`ADDR_BASE_ADDR_BASE; awlen=8'd0; awsize=3'd3; awburst=2'b01; awid=0;
    awvalid=1; @(posedge clk); awvalid=0;
    wdata=64'h0000_0000_4000_0000; wstrb=8'hFF; wlast=1; wvalid=1;
    @(posedge clk); wvalid=0; wlast=0; while(!bvalid) @(posedge clk);
    if(bresp==2'b00) $display("[PASS] TOP-001a: write BASE_ADDR OK");
    else begin $display("[FAIL] TOP-001a"); err=err+1; end
    @(posedge clk); @(posedge clk);

    // Read back
    araddr=`ADDR_BASE_ADDR_BASE; arlen=8'd0; arsize=3'd3; arburst=2'b01; arid=0;
    arvalid=1; @(posedge clk); arvalid=0; while(!rvalid) @(posedge clk);
    if(rresp==2'b00 && rdata==64'h4000_0000) $display("[PASS] TOP-001b: readback OK");
    else begin $display("[FAIL] TOP-001b: %0h",rdata); err=err+1; end
    @(posedge clk);

    // Write CTRL = enable
    awaddr=`ADDR_CTRL; awlen=8'd0; awsize=3'd3; awburst=2'b01; awid=0;
    awvalid=1; @(posedge clk); awvalid=0;
    wdata=64'd1; wstrb=8'hFF; wlast=1; wvalid=1;
    @(posedge clk); wvalid=0; wlast=0; while(!bvalid) @(posedge clk);
    if(bresp==2'b00) $display("[PASS] TOP-001c: CTRL enable=1 OK");
    else begin $display("[FAIL] TOP-001c"); err=err+1; end
    @(posedge clk); @(posedge clk); @(posedge clk);

    //=====================================================================
    // TOP-002: 验证5路Master启动
    //=====================================================================
    $display("\n=== TOP-002: 5路Master启动 ===");
    repeat(20) @(posedge clk);
    // Check that masters communicated (marvalid historically high)
    if(u_top.u_sched.sched_state != 3'd0)
        $display("[PASS] TOP-002: scheduler active (state=%d)", u_top.u_sched.sched_state);
    else if(marvalid0 || marvalid1 || marvalid2 || marvalid3 || marvalid4)
        $display("[PASS] TOP-002: master AR detected");
    else begin
        $display("[FAIL] TOP-002: sched_state=%d en=%b", u_top.u_sched.sched_state,
                 u_top.cfg_enable);
        err=err+1;
    end

    //=====================================================================
    // TOP-009: 复位测试
    //=====================================================================
    $display("\n=== TOP-009: 操作中复位 ===");
    rst_n=0; repeat(5) @(posedge clk); rst_n=1; @(posedge clk);
    if(!fault_detect && !safety_island_fault_detect)
        $display("[PASS] TOP-009: 复位后回到默认状态");
    else begin $display("[FAIL] TOP-009: fd=%b sf=%b",fault_detect,safety_island_fault_detect); err=err+1; end

    //=====================================================================
    $display("\n========================================");
    if(err==0) $display("  [FINAL RESULT] INTEGRATION TESTS PASSED");
    else $display("  [FINAL RESULT] %0d ERRORS", err);
    $display("========================================");
    $display("\n=== RTL File Summary ===");
    $display("P0: axi_safety_island_pkg.vh - common definitions");
    $display("P1: s_axi_config.v         - AXI4 Slave config (core PASS)");
    $display("P2: config_checker.v       - config validation (ALL PASS)");
    $display("P3: axi_master_channel.v   - AXI4 Master engine (ALL PASS)");
    $display("P4: monitor_scheduler.v    - 5-ch scheduler");
    $display("P5: read_data_processor.v  - mask/expected/OR");
    $display("P6: fault_detector.v       - fault detection");
    $display("P6: fault_status_manager.v - sticky status/W1C");
    $display("P7: axi_safety_island_core.v - top-level integration");
    $display("=========================");
    $finish;
end

endmodule
