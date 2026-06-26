//=============================================================================
// tb_config_checker.v — Config Checker Testbench
//=============================================================================
`include "axi_safety_island_pkg.vh"

module tb_config_checker;
reg clk, rst_n;
integer err;

// Config inputs
reg        cfg_enable, cfg_write_protect, cfg_aou_enable;
reg [31:0] cfg_read_interval, cfg_timeout_threshold;
reg [7:0]  cfg_max_outstanding;
reg [31:0] b0,b1,b2,b3,b4;
reg        check_trigger;
reg [2:0]  check_ch;
reg [5:0]  check_off;
reg [1:0]  check_burst_type;
reg [7:0]  check_burst_len;
reg [63:0] check_mask, check_expected;
reg [31:0] check_offset_addr;
wire       check_done, check_pass;
wire [3:0] check_error_code;

config_checker u_dut (
    .clk(clk), .rst_n(rst_n),
    .cfg_enable(cfg_enable), .cfg_write_protect(cfg_write_protect),
    .cfg_aou_enable(cfg_aou_enable),
    .cfg_read_interval(cfg_read_interval),
    .cfg_timeout_threshold(cfg_timeout_threshold),
    .cfg_max_outstanding(cfg_max_outstanding),
    .cfg_base_addr_0(b0), .cfg_base_addr_1(b1), .cfg_base_addr_2(b2),
    .cfg_base_addr_3(b3), .cfg_base_addr_4(b4),
    .check_trigger(check_trigger), .check_ch(check_ch),
    .check_off(check_off), .check_burst_type(check_burst_type),
    .check_burst_len(check_burst_len), .check_mask(check_mask),
    .check_expected(check_expected), .check_offset_addr(check_offset_addr),
    .check_done(check_done), .check_pass(check_pass),
    .check_error_code(check_error_code)
);

always #5 clk = ~clk;

task do_check;
    input [2:0] ch;
    input [5:0] off;
    input [1:0] btype;
    input [7:0] blen;
    input [63:0] mask;
    input [31:0] off_addr;
    begin
        check_ch = ch;
        check_off = off;
        check_burst_type = btype;
        check_burst_len = blen;
        check_mask = mask;
        check_offset_addr = off_addr;
        check_trigger = 1'b1;
        @(posedge clk);  // DUT enters CHECK state
        check_trigger = 1'b0;
        @(posedge clk);  // DUT transitions CHECK→DONE
        @(posedge clk);  // DUT transitions DONE→IDLE
    end
endtask

initial begin
    clk=0; rst_n=0; err=0;
    cfg_enable=0; cfg_write_protect=0; cfg_aou_enable=0;
    cfg_read_interval=32'd1000; cfg_timeout_threshold=32'd10000;
    cfg_max_outstanding=8'd16;
    b0=32'h40000000; b1=32'h50000000; b2=32'h60000000;
    b3=32'h70000000; b4=32'h80000000;
    check_trigger=0; check_ch=0; check_off=0;
    check_burst_type=2'b01; check_burst_len=8'd1;
    check_mask=64'hFFFFFFFF_FFFFFFFF;
    check_expected=64'd0; check_offset_addr=32'd0;

    repeat(10) @(posedge clk); rst_n=1; @(posedge clk); @(posedge clk);

    //=====================================================================
    // CC-001: Valid configuration
    //=====================================================================
    $display("\n=== CC-001: 合法配置 ===");
    do_check(0, 0, 2'b01, 8'd1, 64'hFF, 32'h00000100);
    @(posedge clk);  // wait for DONE
    if(check_pass) $display("[PASS] CC-001: 合法配置通过");
    else begin $display("[FAIL] CC-001: code=%0d",check_error_code); err=err+1; end

    //=====================================================================
    // CC-002: 基地址非对齐
    //=====================================================================
    $display("\n=== CC-002: 基地址非对齐 ===");
    b0 = 32'h40000004;  // 非8字节对齐
    do_check(0, 0, 2'b01, 8'd1, 64'hFF, 32'd0);
    @(posedge clk);
    if(!check_pass && check_error_code == 4'h1) $display("[PASS] CC-002: 检测到基地址非对齐");
    else begin $display("[FAIL] CC-002: pass=%b code=%0d",check_pass,check_error_code); err=err+1; end
    b0 = 32'h40000000;  // restore

    //=====================================================================
    // CC-003: Offset地址非对齐
    //=====================================================================
    $display("\n=== CC-003: Offset非对齐 ===");
    do_check(0, 0, 2'b01, 8'd1, 64'hFF, 32'h00000004);
    @(posedge clk);
    if(!check_pass && check_error_code == 4'h3) $display("[PASS] CC-003: 检测到offset非对齐");
    else begin $display("[FAIL] CC-003: pass=%b code=%0d",check_pass,check_error_code); err=err+1; end

    //=====================================================================
    // CC-004: 非法 burst 类型
    //=====================================================================
    $display("\n=== CC-004: 非法burst ===");
    do_check(0, 0, 2'b00, 8'd1, 64'hFF, 32'd0);
    @(posedge clk);
    if(!check_pass && check_error_code == 4'h5) $display("[PASS] CC-004: FIXED=非法");
    else begin $display("[FAIL] CC-004: pass=%b code=%0d",check_pass,check_error_code); err=err+1; end

    //=====================================================================
    // CC-005: Burst长度=0
    //=====================================================================
    $display("\n=== CC-005: Burst len=0 ===");
    do_check(0, 0, 2'b01, 8'd0, 64'hFF, 32'd0);
    @(posedge clk);
    if(!check_pass && check_error_code == 4'h6) $display("[PASS] CC-005: len=0非法");
    else begin $display("[FAIL] CC-005"); err=err+1; end

    //=====================================================================
    // CC-006: Mask全0
    //=====================================================================
    $display("\n=== CC-006: Mask全0 ===");
    do_check(0, 0, 2'b01, 8'd1, 64'd0, 32'd0);
    @(posedge clk);
    if(!check_pass && check_error_code == 4'h8) $display("[PASS] CC-006: mask=0非法");
    else begin $display("[FAIL] CC-006: pass=%b code=%0d",check_pass,check_error_code); err=err+1; end

    //=====================================================================
    // CC-007: 读取间隔过小
    //=====================================================================
    $display("\n=== CC-007: 间隔过小 ===");
    cfg_read_interval = 32'd5;
    do_check(0, 0, 2'b01, 8'd1, 64'hFF, 32'd0);
    @(posedge clk);
    if(!check_pass && check_error_code == 4'h9) $display("[PASS] CC-007: 间隔<10非法");
    else begin $display("[FAIL] CC-007"); err=err+1; end
    cfg_read_interval = 32'd1000;

    //=====================================================================
    // CC-008: AoU约束
    //=====================================================================
    $display("\n=== CC-008: AoU冲突 ===");
    cfg_aou_enable = 1;
    do_check(0, 0, 2'b01, 8'd1, 64'hFFFFFFFF_FFFFFFFF, 32'd0);
    @(posedge clk);
    if(!check_pass && check_error_code == 4'hA) $display("[PASS] CC-008: AoU全1mask冲突");
    else begin $display("[FAIL] CC-008"); err=err+1; end
    cfg_aou_enable = 0;

    //=====================================================================
    // CC-009: WRAP burst is valid
    //=====================================================================
    $display("\n=== CC-009: WRAP有效 ===");
    do_check(0, 0, 2'b10, 8'd4, 64'hFF, 32'd0);
    @(posedge clk);
    if(check_pass) $display("[PASS] CC-009: WRAP合法");
    else begin $display("[FAIL] CC-009"); err=err+1; end

    //=====================================================================
    $display("\n========================================");
    if(err==0) $display("  [FINAL RESULT] ALL TESTS PASSED");
    else $display("  [FINAL RESULT] %0d ERRORS", err);
    $display("========================================\n");
    $finish;
end

endmodule
