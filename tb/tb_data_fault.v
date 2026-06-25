//=============================================================================
// tb_data_fault.v — Combined test for read_data_processor + fault modules
//=============================================================================
`include "axi_safety_island_pkg.vh"

module tb_data_fault;
reg clk, rst_n;
integer err;

// read_data_processor signals
reg        dp_valid;
reg [63:0] dp_data, dp_mask, dp_expected;
reg        dp_cmp_en, dp_or_en;
wire       dp_mismatch;
wire [63:0] dp_or;
wire       dp_or_valid;

// fault_detector signals
reg        f_mm0,f_mm1,f_mm2,f_mm3,f_mm4;
reg        f_err0,f_err1,f_err2,f_err3,f_err4;
reg [3:0]  f_et0,f_et1,f_et2,f_et3,f_et4;
reg        f_cfg_err;
reg [3:0]  f_cfg_code;
reg        f_stuck, f_trans, f_latent_in;
wire       f_fault, f_safety, f_latent_out;
wire [3:0] f_ftype;
wire [2:0] f_fch;

// fault_status_manager signals
reg [63:0] clr_data;
reg        clr_valid;
wire [63:0] fs_status, fs_cnt0, fs_cnt1;

read_data_processor u_dp(.clk(clk),.rst_n(rst_n),
    .data_valid(dp_valid),.read_data(dp_data),.mask(dp_mask),.expected(dp_expected),
    .compare_enable(dp_cmp_en),.or_accumulate_enable(dp_or_en),
    .mismatch(dp_mismatch),.or_accumulator(dp_or),.or_valid(dp_or_valid));

fault_detector u_fd(.clk(clk),.rst_n(rst_n),
    .mismatch_ch0(f_mm0),.mismatch_ch1(f_mm1),.mismatch_ch2(f_mm2),
    .mismatch_ch3(f_mm3),.mismatch_ch4(f_mm4),
    .error_ch0(f_err0),.error_ch1(f_err1),.error_ch2(f_err2),
    .error_ch3(f_err3),.error_ch4(f_err4),
    .errtype_ch0(f_et0),.errtype_ch1(f_et1),.errtype_ch2(f_et2),
    .errtype_ch3(f_et3),.errtype_ch4(f_et4),
    .config_error(f_cfg_err),.config_error_code(f_cfg_code),
    .internal_stuck_at(f_stuck),.internal_transient(f_trans),
    .latent_fault_detect(f_latent_out),
    .fault_detect(f_fault),.safety_island_fault_detect(f_safety),
    .safety_island_latent_fault_detect(f_latent_out),
    .fault_type(f_ftype),.fault_channel(f_fch));

fault_status_manager u_fs(.clk(clk),.rst_n(rst_n),
    .fault_detect_in(f_fault),.safety_island_fault_in(f_safety),
    .latent_fault_in(f_latent_out),.fault_type_in(f_ftype),.fault_channel_in(f_fch),
    .fault_clear(clr_data),.fault_clear_valid(clr_valid),
    .fault_status(fs_status),.fault_counter_0(fs_cnt0),.fault_counter_1(fs_cnt1));

always #5 clk=~clk;

initial begin
    clk=0; rst_n=0; err=0;
    dp_valid=0; dp_data=0; dp_mask=64'hFFFFFFFF_FFFFFFFF; dp_expected=0;
    dp_cmp_en=0; dp_or_en=0;
    f_mm0=0;f_mm1=0;f_mm2=0;f_mm3=0;f_mm4=0;
    f_err0=0;f_err1=0;f_err2=0;f_err3=0;f_err4=0;
    f_et0=0;f_et1=0;f_et2=0;f_et3=0;f_et4=0;
    f_cfg_err=0; f_cfg_code=0; f_stuck=0; f_trans=0; f_latent_in=0;
    clr_data=0; clr_valid=0;

    repeat(10) @(posedge clk); rst_n=1; @(posedge clk);

    // DAT-001: Mask compare - match
    $display("\n=== DAT-001: Mask compare match ===");
    dp_data=64'hAAAA; dp_mask=64'hFFFF; dp_expected=64'hAAAA; dp_cmp_en=1;
    dp_valid=1; @(posedge clk); dp_valid=0;
    @(posedge clk);
    if(!dp_mismatch) $display("[PASS] DAT-001: match correct");
    else begin $display("[FAIL] DAT-001: mismatch=%b",dp_mismatch); err=err+1; end

    // DAT-002: Mask compare - mismatch
    $display("\n=== DAT-002: Mask compare mismatch ===");
    dp_data=64'hAAAA; dp_mask=64'hFFFF; dp_expected=64'hBBBB; dp_cmp_en=1;
    dp_valid=1; @(posedge clk); dp_valid=0;
    @(posedge clk);
    if(dp_mismatch) $display("[PASS] DAT-002: mismatch detected");
    else begin $display("[FAIL] DAT-002"); err=err+1; end

    // DAT-003: Masked compare (partial)
    $display("\n=== DAT-003: Partial mask ===");
    dp_data=64'hAAAA_BBBB_CCCC_DDDD; dp_mask=64'h0000_0000_FFFF_FFFF;
    dp_expected=64'h0000_0000_CCCC_DDDD; dp_cmp_en=1;
    dp_valid=1; @(posedge clk); dp_valid=0;
    @(posedge clk);
    if(!dp_mismatch) $display("[PASS] DAT-003: partial mask match");
    else begin $display("[FAIL] DAT-003"); err=err+1; end

    // DAT-004: Bitwise OR
    $display("\n=== DAT-004: Bitwise OR ===");
    dp_data=64'h0001; dp_mask=64'hFFFF; dp_or_en=1; dp_cmp_en=0;
    dp_valid=1; @(posedge clk); dp_valid=0;
    dp_data=64'h0010; dp_valid=1; @(posedge clk); dp_valid=0;
    dp_data=64'h0100; dp_valid=1; @(posedge clk); dp_valid=0;
    @(posedge clk);
    if(dp_or==64'h0111 && dp_or_valid) $display("[PASS] DAT-004: OR=%0h",dp_or);
    else begin $display("[FAIL] DAT-004: OR=%0h v=%b",dp_or,dp_or_valid); err=err+1; end

    // FLT-001: External mismatch → fault_detect
    $display("\n=== FLT-001: External fault ===");
    f_mm0=1; @(posedge clk); f_mm0=0; @(posedge clk);
    @(posedge clk);
    if(f_fault) $display("[PASS] FLT-001: fault_detect=1");
    else begin $display("[FAIL] FLT-001: fd=%b",f_fault); err=err+1; end

    // FLT-002: AXI timeout → fault_detect
    $display("\n=== FLT-002: AXI timeout ===");
    f_err1=1; f_et1=4'd1; @(posedge clk); f_err1=0; f_et1=0; @(posedge clk);
    @(posedge clk);
    if(f_fault && f_ftype==4'h1) $display("[PASS] FLT-002: timeout detected");
    else begin $display("[FAIL] FLT-002"); err=err+1; end

    // FLT-007: Internal stuck-at
    $display("\n=== FLT-007: Internal stuck-at ===");
    f_stuck=1; @(posedge clk); f_stuck=0; @(posedge clk);
    @(posedge clk);
    if(f_safety) $display("[PASS] FLT-007: safety_island_fault=1");
    else begin $display("[FAIL] FLT-007"); err=err+1; end

    // FLT-009: Latent fault
    $display("\n=== FLT-009: Latent fault ===");
    f_latent_in=1; @(posedge clk); f_latent_in=0;
    @(posedge clk);
    if(f_latent_out) $display("[PASS] FLT-009: latent_fault=1");
    else begin $display("[FAIL] FLT-009"); err=err+1; end

    // FLT-005/006: Sticky status + W1C
    $display("\n=== FLT-005/006: Sticky + W1C ===");
    if(fs_status[0] && fs_status[1]) $display("[PASS] FLT-005: sticky status=1");
    else begin $display("[FAIL] FLT-005: status=%0h",fs_status); err=err+1; end

    clr_data=64'h1; clr_valid=1; @(posedge clk); clr_valid=0;
    @(posedge clk);
    if(!fs_status[0] && fs_status[1]) $display("[PASS] FLT-006: W1C bit0 cleared");
    else begin $display("[FAIL] FLT-006: status=%0h",fs_status); err=err+1; end

    // Counters
    if(fs_cnt0 > 0) $display("[PASS] FLT-CNT: external counter=%0d", fs_cnt0);
    else begin $display("[FAIL] FLT-CNT: cnt0=%0d",fs_cnt0); err=err+1; end

    $display("\n========================================");
    if(err==0) $display("  [FINAL RESULT] ALL TESTS PASSED");
    else $display("  [FINAL RESULT] %0d ERRORS", err);
    $display("========================================\n");
    $finish;
end

endmodule
