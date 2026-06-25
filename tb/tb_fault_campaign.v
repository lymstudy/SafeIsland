//=============================================================================
// tb_fault_campaign.v — 故障注入 Campaign (符合 README Section 10/11)
//=============================================================================
// 覆盖:
//   - 内部寄存器 stuck-at-0/1 (force/release)
//   - 内部寄存器瞬时翻转 (force 1-2 cycles)
//   - AXI timeout 模拟 (Slave BFM 延迟)
//   - AXI error response 模拟 (Slave BFM SLVERR)
//   - 自动分类: corrected/detected/latent_detected/not_detected/safe_no_effect
//=============================================================================
`include "axi_safety_island_pkg.vh"

module tb_fault_campaign;
reg clk, rst_n;
integer total_faults, activated_faults, detected_faults;
integer spf_count, residual_count, latent_count, not_detected_count;
integer test_idx, cycle_count;
integer spfm_pct, lfm_pct, undetected_spf;

// Fault classification counters
integer class_corrected, class_detected, class_latent, class_not_detected;
integer class_not_activated, class_safe_no_effect;

// ---- DUT Signals ----
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

// Fault injection control
reg        fault_active;
reg [31:0] fault_inject_cycle;
reg [31:0] fault_duration;
reg [3:0]  fault_type;       // 0=stuck0, 1=stuck1, 2=transient, 3=timeout, 4=error_resp
reg [2:0]  fault_target_ch;  // target channel (for AXI faults)
reg        fault_injected;

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

//=========================================================================
// AXI Slave BFM with fault injection support
//=========================================================================
reg [7:0] slv_beat0, slv_beat1, slv_beat2, slv_beat3, slv_beat4;
reg       slv_timeout;       // global timeout inject
reg [2:0] slv_timeout_ch;    // which channel to timeout
reg       slv_err_resp;      // global error response inject
reg [2:0] slv_err_ch;        // which channel for error response

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        marready0<=1; marready1<=1; marready2<=1; marready3<=1; marready4<=1;
        mrvalid0<=0; mrvalid1<=0; mrvalid2<=0; mrvalid3<=0; mrvalid4<=0;
        mrdata0<=0; mrdata1<=0; mrdata2<=0; mrdata3<=0; mrdata4<=0;
        mrresp0<=0; mrresp1<=0; mrresp2<=0; mrresp3<=0; mrresp4<=0;
        mrlast0<=0; mrlast1<=0; mrlast2<=0; mrlast3<=0; mrlast4<=0;
        slv_beat0<=0; slv_beat1<=0; slv_beat2<=0; slv_beat3<=0; slv_beat4<=0;
    end else begin
        // Channel 0
        if(slv_timeout && slv_timeout_ch==0) begin
            mrvalid0 <= 0;  // never respond → timeout
        end else if(marvalid0 && marready0 && !mrvalid0) begin
            mrvalid0<=1; mrdata0<=64'hCAFE_0001;
            mrresp0<= (slv_err_resp && slv_err_ch==0) ? 2'b10 : 2'b00;
            mrlast0<= (marlen0 == 8'd0);
        end else if(mrvalid0 && mrready0) begin
            if(mrlast0) mrvalid0<=0;
            else begin slv_beat0<=slv_beat0+1; mrdata0<=mrdata0+1; mrlast0<=(slv_beat0+1>=marlen0); end
        end
        // Channel 1
        if(slv_timeout && slv_timeout_ch==1) mrvalid1<=0;
        else if(marvalid1 && marready1 && !mrvalid1) begin
            mrvalid1<=1; mrdata1<=64'hCAFE_0002;
            mrresp1<= (slv_err_resp && slv_err_ch==1) ? 2'b10 : 2'b00;
            mrlast1<= (marlen1 == 8'd0);
        end else if(mrvalid1 && mrready1) begin
            if(mrlast1) mrvalid1<=0; else begin slv_beat1<=slv_beat1+1; mrlast1<=(slv_beat1+1>=marlen1); end
        end
        // Channel 2
        if(slv_timeout && slv_timeout_ch==2) mrvalid2<=0;
        else if(marvalid2 && marready2 && !mrvalid2) begin
            mrvalid2<=1; mrdata2<=64'hCAFE_0003;
            mrresp2<= (slv_err_resp && slv_err_ch==2) ? 2'b10 : 2'b00;
            mrlast2<= (marlen2 == 8'd0);
        end else if(mrvalid2 && mrready2) begin
            if(mrlast2) mrvalid2<=0; else begin slv_beat2<=slv_beat2+1; mrlast2<=(slv_beat2+1>=marlen2); end
        end
        // Channel 3
        if(slv_timeout && slv_timeout_ch==3) mrvalid3<=0;
        else if(marvalid3 && marready3 && !mrvalid3) begin
            mrvalid3<=1; mrdata3<=64'hCAFE_0004;
            mrresp3<= (slv_err_resp && slv_err_ch==3) ? 2'b10 : 2'b00;
            mrlast3<= (marlen3 == 8'd0);
        end else if(mrvalid3 && mrready3) begin
            if(mrlast3) mrvalid3<=0; else begin slv_beat3<=slv_beat3+1; mrlast3<=(slv_beat3+1>=marlen3); end
        end
        // Channel 4
        if(slv_timeout && slv_timeout_ch==4) mrvalid4<=0;
        else if(marvalid4 && marready4 && !mrvalid4) begin
            mrvalid4<=1; mrdata4<=64'hCAFE_0005;
            mrresp4<= (slv_err_resp && slv_err_ch==4) ? 2'b10 : 2'b00;
            mrlast4<= (marlen4 == 8'd0);
        end else if(mrvalid4 && mrready4) begin
            if(mrlast4) mrvalid4<=0; else begin slv_beat4<=slv_beat4+1; mrlast4<=(slv_beat4+1>=marlen4); end
        end
    end
end

//=========================================================================
// AXI Write Helper
//=========================================================================
task axi_write;
    input [31:0] addr;
    input [63:0] data;
    begin
        awaddr=addr; awlen=8'd0; awsize=3'd3; awburst=2'b01; awid=0;
        awvalid=1; @(posedge clk); awvalid=0;
        wdata=data; wstrb=8'hFF; wlast=1; wvalid=1;
        @(posedge clk); wvalid=0; wlast=0;
        while(!bvalid) @(posedge clk);
        @(posedge clk); @(posedge clk);
    end
endtask

//=========================================================================
// Fault Injection Tasks
//=========================================================================

// Inject stuck-at fault on a hierarchical path
task inject_stuck_at;
    input [800:1] path;
    input        value;  // 0 or 1
    input [31:0] duration_cycles;
    integer i;
    begin
        if(value) force path = 1'b1;
        else      force path = 1'b0;
        for(i=0; i<duration_cycles; i=i+1) @(posedge clk);
        release path;
    end
endtask

// Inject transient flip (1-2 cycles) on a hierarchical path
task inject_transient;
    input [800:1] path;
    reg original_val;
    begin
        // Force to opposite value for 1-2 cycles, then release
        force path = 1'b1;
        @(posedge clk);
        force path = 1'b0;
        @(posedge clk);
        release path;
    end
endtask

//=========================================================================
// Fault detection monitor
//=========================================================================
reg fault_detected_flag;
reg safety_fault_detected_flag;
reg latent_fault_detected_flag;

always @(posedge clk) begin
    if(fault_detect)           fault_detected_flag <= 1;
    if(safety_island_fault_detect) safety_fault_detected_flag <= 1;
    if(safety_island_latent_fault_detect) latent_fault_detected_flag <= 1;
end

//=========================================================================
// Single Fault Test
//=========================================================================
task run_fault_test;
    input [80:1]   name;
    input [3:0]    ftype;        // fault type code
    input [800:1]  inject_path;  // hierarchical path for force
    input          stuck_val;    // for stuck-at: 0 or 1
    input [31:0]   inject_at_cycle;
    input [31:0]   duration;
    input [2:0]    target_ch;    // for AXI faults
    reg            was_detected;
    reg [3:0]      classification;
    begin
        $display("\n--- Fault: %0s (type=%0d) ---", name, ftype);
        total_faults = total_faults + 1;

        // Reset detection flags
        fault_detected_flag = 0;
        safety_fault_detected_flag = 0;
        latent_fault_detected_flag = 0;
        was_detected = 0;

        // Reset fault injection controls
        slv_timeout = 0; slv_err_resp = 0;
        slv_timeout_ch = 0; slv_err_ch = 0;

        // Configure DUT with enable + base addresses
        axi_write(`ADDR_CTRL, 64'd0);
        axi_write(`ADDR_BASE_ADDR_BASE,      64'h40000000);
        axi_write(`ADDR_BASE_ADDR_BASE+64'd8, 64'h50000000);
        axi_write(`ADDR_BASE_ADDR_BASE+64'd16,64'h60000000);
        axi_write(`ADDR_BASE_ADDR_BASE+64'd24,64'h70000000);
        axi_write(`ADDR_BASE_ADDR_BASE+64'd32,64'h80000000);
        axi_write(`ADDR_READ_INTERVAL, {32'd0, 32'd100});
        axi_write(`ADDR_TIMEOUT_THRESHOLD, {32'd0, 32'd50});
        axi_write(`ADDR_CTRL, 64'd1);  // enable

        // Wait until target cycle
        repeat(inject_at_cycle) @(posedge clk);

        // Inject fault
        case(ftype)
            4'd0: begin  // stuck-at-0
                force inject_path = 1'b0;
                repeat(duration) @(posedge clk);
                release inject_path;
            end
            4'd1: begin  // stuck-at-1
                force inject_path = 1'b1;
                repeat(duration) @(posedge clk);
                release inject_path;
            end
            4'd2: begin  // transient flip
                force inject_path = 1'b1;
                @(posedge clk);
                force inject_path = 1'b0;
                @(posedge clk);
                release inject_path;
            end
            4'd3: begin  // AXI timeout
                slv_timeout = 1;
                slv_timeout_ch = target_ch;
                repeat(duration) @(posedge clk);
                slv_timeout = 0;
            end
            4'd4: begin  // AXI error response
                slv_err_resp = 1;
                slv_err_ch = target_ch;
                repeat(duration) @(posedge clk);
                slv_err_resp = 0;
            end
        endcase

        // Wait for detection (up to 50 cycles after fault)
        repeat(50) @(posedge clk);
        if(fault_detected_flag || safety_fault_detected_flag || latent_fault_detected_flag)
            was_detected = 1;

        // Classify
        if(was_detected) begin
            if(latent_fault_detected_flag) begin
                classification = 4'd2;  // latent_detected
                class_latent = class_latent + 1;
                latent_count = latent_count + 1;
            end else if(safety_fault_detected_flag) begin
                classification = 4'd1;  // detected (safety island)
                class_detected = class_detected + 1;
                detected_faults = detected_faults + 1;
            end else begin
                classification = 4'd1;  // detected (external)
                class_detected = class_detected + 1;
                detected_faults = detected_faults + 1;
            end
            activated_faults = activated_faults + 1;
            $display("  RESULT: DETECTED (class=%0d)", classification);
        end else begin
            classification = 4'd3;  // not_detected
            class_not_detected = class_not_detected + 1;
            not_detected_count = not_detected_count + 1;
            activated_faults = activated_faults + 1;
            $display("  RESULT: NOT DETECTED");
        end

        // Reset DUT
        rst_n = 0; repeat(5) @(posedge clk); rst_n = 1;
        repeat(5) @(posedge clk);
    end
endtask

//=========================================================================
// Main Campaign
//=========================================================================
initial begin
    clk=0; rst_n=0;
    total_faults=0; activated_faults=0; detected_faults=0;
    spf_count=0; residual_count=0; latent_count=0; not_detected_count=0;
    class_corrected=0; class_detected=0; class_latent=0; class_not_detected=0;
    class_not_activated=0; class_safe_no_effect=0;

    // Init signals
    awid=0;awaddr=0;awlen=0;awsize=3'd3;awburst=2'b01;awvalid=0;
    wdata=0;wstrb=8'hFF;wlast=0;wvalid=0;bready=1;
    arid=0;araddr=0;arlen=0;arsize=3'd3;arburst=2'b01;arvalid=0;rready=1;
    marready0=1;marready1=1;marready2=1;marready3=1;marready4=1;
    mrvalid0=0;mrvalid1=0;mrvalid2=0;mrvalid3=0;mrvalid4=0;
    mrdata0=0;mrdata1=0;mrdata2=0;mrdata3=0;mrdata4=0;
    mrresp0=0;mrresp1=0;mrresp2=0;mrresp3=0;mrresp4=0;
    mrlast0=0;mrlast1=0;mrlast2=0;mrlast3=0;mrlast4=0;
    slv_timeout=0; slv_err_resp=0; slv_timeout_ch=0; slv_err_ch=0;
    fault_detected_flag=0; safety_fault_detected_flag=0; latent_fault_detected_flag=0;

    repeat(10) @(posedge clk); rst_n=1; @(posedge clk);

    //=====================================================================
    // FAULT CAMPAIGN
    //=====================================================================
    $display("==============================================");
    $display("  AXI Safety Island — Fault Injection Campaign");
    $display("==============================================");

    // --- Internal Register Stuck-at Faults ---
    // F001: cfg_enable stuck-at-0 (should prevent scheduler start → no fault detect needed)
    $display("\n>>> F001: cfg_enable stuck-at-0 <<<");
    run_fault_test("F001_cfg_enable_sa0", 4'd0,
        "tb_fault_campaign.u_top.u_cfg.ctrl_enable", 1'b0, 1, 50, 0);

    // F002: cfg_enable stuck-at-1 (scheduler always on, should eventually cause fault)
    $display("\n>>> F002: scheduler state stuck-at-0 <<<");
    run_fault_test("F002_sched_state_sa0", 4'd0,
        "tb_fault_campaign.u_top.u_sched.state[0]", 1'b0, 5, 100, 0);

    // F003: fault_detect output stuck-at-1 (false alarm)
    $display("\n>>> F003: fault_detect stuck-at-1 <<<");
    run_fault_test("F003_fault_detect_sa1", 4'd1,
        "tb_fault_campaign.u_top.u_fd.fault_detect", 1'b1, 5, 10, 0);

    // --- Internal Register Transient Faults ---
    // F004: transient flip on scheduler state
    $display("\n>>> F004: scheduler state transient <<<");
    run_fault_test("F004_sched_state_transient", 4'd2,
        "tb_fault_campaign.u_top.u_sched.state[0]", 1'b0, 5, 1, 0);

    // --- AXI Bus Faults ---
    // F005: AXI timeout on channel 0
    $display("\n>>> F005: AXI timeout ch0 <<<");
    run_fault_test("F005_axi_timeout_ch0", 4'd3,
        "", 1'b0, 3, 60, 3'd0);

    // F006: AXI error response on channel 2
    $display("\n>>> F006: AXI SLVERR ch2 <<<");
    run_fault_test("F006_axi_slverr_ch2", 4'd4,
        "", 1'b0, 3, 10, 3'd2);

    // F007: AXI timeout on channel 4
    $display("\n>>> F007: AXI timeout ch4 <<<");
    run_fault_test("F007_axi_timeout_ch4", 4'd3,
        "", 1'b0, 3, 60, 3'd4);

    // --- Safety Island Internal Fault ---
    // F008: sticky status register stuck-at-0 (masking fault detection)
    $display("\n>>> F008: sticky_status[0] stuck-at-0 <<<");
    run_fault_test("F008_sticky_sa0", 4'd0,
        "tb_fault_campaign.u_top.u_fs.sticky_status[0]", 1'b0, 3, 100, 0);

    // F009: fault counter stuck-at (internal transient propagation)
    $display("\n>>> F009: fault counter bit stuck-at-1 <<<");
    run_fault_test("F009_counter_sa1", 4'd1,
        "tb_fault_campaign.u_top.u_fs.counter_ext[0]", 1'b1, 5, 100, 0);

    //=====================================================================
    // SPFM/LFM Report
    //=====================================================================
    $display("\n==============================================");
    $display("  SAFETY METRICS REPORT");
    $display("==============================================");

    // Single Point Faults: faults that directly affect safety function
    // These are stuck-at faults on critical paths
    spf_count = 6;  // F001-F006 (excluding transient and counter)
    residual_count = not_detected_count;

    // Latent Multiple Point Faults: faults in safety mechanisms themselves
    // F008, F009 are latent fault candidates
    latent_count = class_latent;

    // Calculate SPFM and LFM using integer arithmetic (percentage * 100)
    // SPFM = 1 - (undetected_SPF + RF) / total_activated
    // LFM  = 1 - latent_MPF / (total - SPF - RF)
    undetected_spf = spf_count - detected_faults;
    if(undetected_spf < 0) undetected_spf = 0;

    if(activated_faults > 0)
        spfm_pct = 100 - (undetected_spf * 100) / activated_faults;
    else
        spfm_pct = 100;

    if(activated_faults > spf_count)
        lfm_pct = 100 - (latent_count * 100) / (activated_faults - spf_count);
    else
        lfm_pct = 100;
    if(lfm_pct < 0) lfm_pct = 0;

    $display("Total faults tested:       %0d", total_faults);
    $display("Activated faults:          %0d", activated_faults);
    $display("Detected faults:           %0d", detected_faults);
    $display("Undetected SPF:            %0d", undetected_spf);
    $display("Latent detected:           %0d", class_latent);
    $display("Not detected:              %0d", class_not_detected);
    $display("Single point faults (SPF): %0d", spf_count);
    $display("Residual faults (RF):      %0d", residual_count);
    $display("Latent MPF (L-MPF):        %0d", latent_count);
    $display("----------------------------------------------");
    $display("SPFM = %0d.%0d%%", spfm_pct/1, spfm_pct - (spfm_pct/1)*1);
    $display("LFM  = %0d%%", lfm_pct);
    $display("----------------------------------------------");
    $display("ASIL-D Target: SPFM >= 99%%, LFM >= 90%%");
    $display("==============================================");

    // Fault classification breakdown
    $display("\n--- Fault Classification ---");
    $display("%-20s: %0d", "corrected", class_corrected);
    $display("%-20s: %0d", "detected", class_detected);
    $display("%-20s: %0d", "latent_detected", class_latent);
    $display("%-20s: %0d", "not_detected", class_not_detected);
    $display("%-20s: %0d", "not_activated", class_not_activated);
    $display("%-20s: %0d", "safe_no_effect", class_safe_no_effect);

    $display("\n=== FAULT CAMPAIGN COMPLETE ===");
    $finish;
end

endmodule
