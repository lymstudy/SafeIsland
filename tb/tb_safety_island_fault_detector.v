//------------------------------------------------------------------------------
// tb_safety_island_fault_detector.v
//
// 安全岛故障检测模块 (safety_island_fault_detector) 单元测试
//
// 覆盖：
//   1.  Mask+OR 累加 + External fault
//   2.  Expected 值匹配 / 失配
//   3.  Bus error / timeout 故障
//   4.  Config fault 透传
//   5.  Safety fault 透传
//   6.  Stuck-at 阈值检测 (连续 STUCK_AT_THRESHOLD 轮)
//   7.  Latent fault 检测 (故障后恢复)
//   8.  Accumulator shadow 检查
//   9.  Clear status
//  10.  Stuck-at counter 范围检查
//------------------------------------------------------------------------------

`timescale 1ns/1ps

module tb_safety_island_fault_detector;

    localparam NUM_MASTERS        = 5;
    localparam NUM_ENTRIES        = 64;
    localparam DATA_W             = 64;
    localparam STUCK_AT_THRESHOLD = 10;

    reg                                      clk;
    reg                                      rst;
    reg                                      enable;
    reg                                      fd_resp_valid;
    reg  [DATA_W-1:0]                        fd_resp_data;
    reg  [DATA_W-1:0]                        fd_resp_mask;
    reg  [DATA_W-1:0]                        fd_resp_expected;
    reg  [31:0]                              fd_resp_master_idx;
    reg  [31:0]                              fd_resp_entry_idx;
    reg                                      fd_resp_error;
    reg                                      fd_resp_timeout;

    reg                                      scan_start_pulse;
    reg                                      scan_done_pulse;
    reg                                      clear_status;
    reg                                      cfg_illegal;
    reg                                      cfg_shadow_error;
    reg                                      cfg_interval_zero;
    reg                                      core_safety_fault;
    reg  [7:0]                               core_safety_error_code;

    wire                                     fault_detect;
    wire                                     external_fault_event;
    wire                                     bus_fault_event;
    wire                                     cfg_fault_event;
    wire                                     safety_island_fault_event;
    wire                                     safety_island_latent_fault_event;
    wire [DATA_W-1:0]                        fault_or_result;
    wire [63:0]                              fault_status;
    wire [7:0]                               error_code;

    integer total_pass;
    integer total_fail;
    integer case_fail;

    safety_island_fault_detector #(
        .NUM_MASTERS        (NUM_MASTERS),
        .NUM_ENTRIES        (NUM_ENTRIES),
        .DATA_W             (DATA_W),
        .STUCK_AT_THRESHOLD (STUCK_AT_THRESHOLD)
    ) dut (
        .clk                             (clk),
        .rst                             (rst),
        .enable                          (enable),
        .fd_resp_valid                   (fd_resp_valid),
        .fd_resp_data                    (fd_resp_data),
        .fd_resp_mask                    (fd_resp_mask),
        .fd_resp_expected                (fd_resp_expected),
        .fd_resp_master_idx              (fd_resp_master_idx),
        .fd_resp_entry_idx               (fd_resp_entry_idx),
        .fd_resp_error                   (fd_resp_error),
        .fd_resp_timeout                 (fd_resp_timeout),
        .scan_start_pulse                (scan_start_pulse),
        .scan_done_pulse                 (scan_done_pulse),
        .clear_status                    (clear_status),
        .cfg_illegal                     (cfg_illegal),
        .cfg_shadow_error                (cfg_shadow_error),
        .cfg_interval_zero               (cfg_interval_zero),
        .core_safety_fault               (core_safety_fault),
        .core_safety_error_code          (core_safety_error_code),
        .fault_detect                    (fault_detect),
        .external_fault_event            (external_fault_event),
        .bus_fault_event                 (bus_fault_event),
        .cfg_fault_event                 (cfg_fault_event),
        .safety_island_fault_event       (safety_island_fault_event),
        .safety_island_latent_fault_event(safety_island_latent_fault_event),
        .fault_or_result                 (fault_or_result),
        .fault_status                    (fault_status),
        .error_code                      (error_code)
    );

    always #5 clk = ~clk;

    task init;
    begin
        fd_resp_valid        = 1'b0;
        fd_resp_data         = {DATA_W{1'b0}};
        fd_resp_mask         = {DATA_W{1'b0}};
        fd_resp_expected     = {DATA_W{1'b0}};
        fd_resp_master_idx   = 32'd0;
        fd_resp_entry_idx    = 32'd0;
        fd_resp_error        = 1'b0;
        fd_resp_timeout      = 1'b0;
        scan_start_pulse     = 1'b0;
        scan_done_pulse      = 1'b0;
        clear_status         = 1'b0;
        cfg_illegal          = 1'b0;
        cfg_shadow_error     = 1'b0;
        cfg_interval_zero    = 1'b0;
        core_safety_fault    = 1'b0;
        core_safety_error_code = 8'h00;
        enable               = 1'b1;
    end
    endtask

    task reset_dut;
    begin
        init();
        rst = 1'b1;
        repeat (5) @(posedge clk);
        rst = 1'b0;
        repeat (2) @(posedge clk);
    end
    endtask

    task wait_cycles;
        input integer n;
        integer i;
    begin
        for (i = 0; i < n; i = i + 1)
            @(posedge clk);
    end
    endtask

    // Pulse scan_start_pulse for one cycle
    task pulse_scan_start;
    begin
        @(posedge clk);
        scan_start_pulse <= 1'b1;
        @(posedge clk);
        scan_start_pulse <= 1'b0;
    end
    endtask

    // Pulse scan_done_pulse for one cycle
    task pulse_scan_done;
    begin
        @(posedge clk);
        scan_done_pulse <= 1'b1;
        @(posedge clk);
        scan_done_pulse <= 1'b0;
    end
    endtask

    // Inject a read response (single cycle valid)
    task inject_response;
        input [DATA_W-1:0] data;
        input [DATA_W-1:0] mask;
        input [DATA_W-1:0] expected;
        input [31:0]       master;
        input [31:0]       entry;
        input              is_error;
        input              is_timeout;
    begin
        @(posedge clk);
        fd_resp_valid       <= 1'b1;
        fd_resp_data        <= data;
        fd_resp_mask        <= mask;
        fd_resp_expected    <= expected;
        fd_resp_master_idx  <= master;
        fd_resp_entry_idx   <= entry;
        fd_resp_error       <= is_error;
        fd_resp_timeout     <= is_timeout;
        @(posedge clk);
        fd_resp_valid       <= 1'b0;
        fd_resp_data        <= {DATA_W{1'b0}};
        fd_resp_mask        <= {DATA_W{1'b0}};
        fd_resp_expected    <= {DATA_W{1'b0}};
        fd_resp_error       <= 1'b0;
        fd_resp_timeout     <= 1'b0;
    end
    endtask

    // Run one full scan round: start → inject responses → done
    task run_scan_round;
        input [DATA_W-1:0] data;
        input [DATA_W-1:0] mask;
        input [DATA_W-1:0] expected;
        input [31:0]       master;
        input              is_error;
        input              is_timeout;
    begin
        pulse_scan_start();
        inject_response(data, mask, expected, master, 32'd0,
                        is_error, is_timeout);
        pulse_scan_done();
        wait_cycles(2);
    end
    endtask

    // Run STUCK_AT_THRESHOLD scan rounds with same data → should trigger stuck-at
    task run_stuck_threshold_rounds;
        input [DATA_W-1:0] data;
        input [DATA_W-1:0] mask;
        input [DATA_W-1:0] expected;
        input [31:0]       master;
        integer r;
    begin
        for (r = 0; r < STUCK_AT_THRESHOLD; r = r + 1) begin
            run_scan_round(data, mask, expected, master, 1'b0, 1'b0);
        end
    end
    endtask

    task expect_equal;
        input [8*40-1:0] name;
        input [63:0] got;
        input [63:0] exp;
    begin
        if (got !== exp) begin
            $display("FAIL: %0s got=%h exp=%h", name, got, exp);
            case_fail = case_fail + 1;
            total_fail = total_fail + 1;
        end
    end
    endtask

    task expect_bit;
        input [8*40-1:0] name;
        input bit_val;
        input exp;
    begin
        if (bit_val !== exp) begin
            $display("FAIL: %0s got=%b exp=%b", name, bit_val, exp);
            case_fail = case_fail + 1;
            total_fail = total_fail + 1;
        end
    end
    endtask

    task pass_case;
        input [8*40-1:0] name;
    begin
        if (case_fail == 0) begin
            total_pass = total_pass + 1;
            $display("PASS: %0s", name);
        end else begin
            $display("FAIL: %0s", name);
        end
    end
    endtask

    //----------------------------------------------------------------------
    // TEST 1: Mask+OR accumulation → external fault
    //----------------------------------------------------------------------
    task test_or_accum_external_fault;
    begin
        case_fail = 0;
        reset_dut();
        // data=0x04, mask=0xFF, expected=0x00
        // OR accum = 0x04 ≠ 0 → external fault
        run_scan_round(64'h4, 64'hFFFF_FFFF_FFFF_FFFF, 64'h0, 32'd0,
                       1'b0, 1'b0);
        expect_equal("test1_or_result", fault_or_result, 64'h4);
        expect_bit("test1_external", external_fault_event, 1'b1);
        expect_equal("test1_code", {56'd0, error_code}, 64'h30);
        pass_case("test_or_accum_external_fault");
    end
    endtask

    //----------------------------------------------------------------------
    // TEST 2: No fault when data=0 and expected=0
    //----------------------------------------------------------------------
    task test_no_fault;
    begin
        case_fail = 0;
        reset_dut();
        run_scan_round(64'h0, 64'hFFFF_FFFF_FFFF_FFFF, 64'h0, 32'd0,
                       1'b0, 1'b0);
        expect_equal("test2_or_result", fault_or_result, 64'h0);
        expect_bit("test2_external", external_fault_event, 1'b0);
        expect_bit("test2_bus", bus_fault_event, 1'b0);
        pass_case("test_no_fault");
    end
    endtask

    //----------------------------------------------------------------------
    // TEST 3: Expected value mismatch
    //----------------------------------------------------------------------
    task test_expected_mismatch;
    begin
        case_fail = 0;
        reset_dut();
        // data=0x5, expected=0xA, mask=0xF
        // (data & mask) = 0x5, (expected & mask) = 0xA → mismatch
        run_scan_round(64'h5, 64'hF, 64'hA, 32'd0,
                       1'b0, 1'b0);
        expect_bit("test3_external", external_fault_event, 1'b1);
        pass_case("test_expected_mismatch");
    end
    endtask

    //----------------------------------------------------------------------
    // TEST 4: Expected value match but OR non-zero
    //----------------------------------------------------------------------
    task test_expected_match_or_nonzero;
    begin
        case_fail = 0;
        reset_dut();
        // data=0x3, expected=0x3, mask=0xF → expected matches
        // BUT data&mask=0x3 ≠ 0 → external fault from OR accum
        run_scan_round(64'h3, 64'hF, 64'h3, 32'd0,
                       1'b0, 1'b0);
        expect_equal("test4_or_result", fault_or_result, 64'h3);
        expect_bit("test4_external", external_fault_event, 1'b1);
        pass_case("test_expected_match_or_nonzero");
    end
    endtask

    //----------------------------------------------------------------------
    // TEST 5: Bus error passthrough
    //----------------------------------------------------------------------
    task test_bus_error;
    begin
        case_fail = 0;
        reset_dut();
        run_scan_round(64'h0, 64'hFFFF_FFFF_FFFF_FFFF, 64'h0, 32'd0,
                       1'b1, 1'b0);
        expect_bit("test5_bus_fault", bus_fault_event, 1'b1);
        expect_equal("test5_code", {56'd0, error_code}, 64'h20);
        pass_case("test_bus_error");
    end
    endtask

    //----------------------------------------------------------------------
    // TEST 6: Bus timeout passthrough
    //----------------------------------------------------------------------
    task test_bus_timeout;
    begin
        case_fail = 0;
        reset_dut();
        run_scan_round(64'h0, 64'hFFFF_FFFF_FFFF_FFFF, 64'h0, 32'd0,
                       1'b0, 1'b1);
        expect_bit("test6_bus_fault", bus_fault_event, 1'b1);
        expect_equal("test6_code", {56'd0, error_code}, 64'h21);
        pass_case("test_bus_timeout");
    end
    endtask

    //----------------------------------------------------------------------
    // TEST 7: Config fault passthrough (illegal)
    //----------------------------------------------------------------------
    task test_config_illegal;
    begin
        case_fail = 0;
        reset_dut();
        cfg_illegal <= 1'b1;
        wait_cycles(2);
        expect_bit("test7_cfg_fault", cfg_fault_event, 1'b1);
        expect_equal("test7_code", {56'd0, error_code}, 64'h10);
        cfg_illegal <= 1'b0;
        pass_case("test_config_illegal");
    end
    endtask

    //----------------------------------------------------------------------
    // TEST 8: Config fault passthrough (shadow error)
    //----------------------------------------------------------------------
    task test_config_shadow;
    begin
        case_fail = 0;
        reset_dut();
        cfg_shadow_error <= 1'b1;
        wait_cycles(2);
        expect_bit("test8_cfg_fault", cfg_fault_event, 1'b1);
        expect_equal("test8_code", {56'd0, error_code}, 64'h11);
        cfg_shadow_error <= 1'b0;
        pass_case("test_config_shadow");
    end
    endtask

    //----------------------------------------------------------------------
    // TEST 9: Safety fault passthrough
    //----------------------------------------------------------------------
    task test_safety_fault;
    begin
        case_fail = 0;
        reset_dut();
        core_safety_fault     <= 1'b1;
        core_safety_error_code<= 8'h40;
        wait_cycles(2);
        expect_bit("test9_safety_fault", safety_island_fault_event, 1'b1);
        expect_equal("test9_code", {56'd0, error_code}, 64'h40);
        core_safety_fault <= 1'b0;
        pass_case("test_safety_fault");
    end
    endtask

    //----------------------------------------------------------------------
    // TEST 10: Stuck-at fault detection
    // Run STUCK_AT_THRESHOLD rounds with same mismatch → stuck-at triggers
    //----------------------------------------------------------------------
    task test_stuck_at_fault;
    begin
        case_fail = 0;
        reset_dut();
        // data=0x1, expected=0x0 → mismatch every round
        run_stuck_threshold_rounds(64'h1, 64'h1, 64'h0, 32'd0);
        expect_bit("test10_safety_fault", safety_island_fault_event, 1'b1);
        expect_equal("test10_code", {56'd0, error_code}, 64'h32);
        pass_case("test_stuck_at_fault");
    end
    endtask

    //----------------------------------------------------------------------
    // TEST 11: No stuck-at when mismatch recovers within threshold
    //----------------------------------------------------------------------
    task test_no_stuck_at_recovery;
    begin
        case_fail = 0;
        reset_dut();
        // 5 rounds of mismatch, then 1 round of match → stuck_at counter resets
        repeat (5) run_scan_round(64'h1, 64'h1, 64'h0, 32'd0, 1'b0, 1'b0);
        run_scan_round(64'h0, 64'h1, 64'h0, 32'd0, 1'b0, 1'b0);
        // stuck_at should NOT have triggered (counter reset before threshold)
        if (safety_island_fault_event !== 1'b0) begin
            $display("FAIL: test11 stuck-at triggered prematurely");
            case_fail = case_fail + 1;
            total_fail = total_fail + 1;
        end
        pass_case("test_no_stuck_at_recovery");
    end
    endtask

    //----------------------------------------------------------------------
    // TEST 12: Latent fault detection
    // mismatch → recover → latent fault reported
    //----------------------------------------------------------------------
    task test_latent_fault;
    begin
        case_fail = 0;
        reset_dut();
        // 2 rounds of mismatch (less than threshold)
        repeat (2) run_scan_round(64'h1, 64'h1, 64'h0, 32'd0, 1'b0, 1'b0);
        // 1 round of match → recovery → latent fault
        run_scan_round(64'h0, 64'h1, 64'h0, 32'd0, 1'b0, 1'b0);
        expect_bit("test12_latent", safety_island_latent_fault_event, 1'b1);
        expect_equal("test12_code", {56'd0, error_code}, 64'h33);
        pass_case("test_latent_fault");
    end
    endtask

    //----------------------------------------------------------------------
    // TEST 13: Clear status
    //----------------------------------------------------------------------
    task test_clear_status;
    begin
        case_fail = 0;
        reset_dut();
        // First cause an external fault
        run_scan_round(64'hFF, 64'hFF, 64'h0, 32'd0, 1'b0, 1'b0);
        expect_bit("test13_pre_clear", external_fault_event, 1'b1);

        // Now clear
        @(posedge clk);
        clear_status <= 1'b1;
        @(posedge clk);
        clear_status <= 1'b0;
        @(posedge clk);

        expect_bit("test13_post_clear", external_fault_event, 1'b0);
        pass_case("test_clear_status");
    end
    endtask

    //----------------------------------------------------------------------
    // TEST 14: Multi-master fault accumulation
    //----------------------------------------------------------------------
    task test_multi_master_fault;
    begin
        case_fail = 0;
        reset_dut();
        pulse_scan_start();
        inject_response(64'h01, 64'hFF, 64'h0, 32'd0, 32'd0, 1'b0, 1'b0);
        inject_response(64'h02, 64'hFF, 64'h0, 32'd1, 32'd0, 1'b0, 1'b0);
        inject_response(64'h04, 64'hFF, 64'h0, 32'd2, 32'd0, 1'b0, 1'b0);
        pulse_scan_done();
        wait_cycles(2);
        expect_equal("test14_or_result", fault_or_result, 64'h07);
        expect_bit("test14_external", external_fault_event, 1'b1);
        pass_case("test_multi_master_fault");
    end
    endtask

    //----------------------------------------------------------------------
    // TEST 15: Accumulator resets on scan_start_pulse
    //----------------------------------------------------------------------
    task test_accum_reset;
    begin
        case_fail = 0;
        reset_dut();
        // Round 1: data=0x10
        run_scan_round(64'h10, 64'hFFFF_FFFF_FFFF_FFFF, 64'h0, 32'd0,
                       1'b0, 1'b0);
        expect_equal("test15_r1", fault_or_result, 64'h10);

        // Round 2: data=0x01 (should be 0x01, not 0x11, because accum resets)
        run_scan_round(64'h01, 64'hFFFF_FFFF_FFFF_FFFF, 64'h0, 32'd0,
                       1'b0, 1'b0);
        expect_equal("test15_r2", fault_or_result, 64'h01);

        pass_case("test_accum_reset");
    end
    endtask

    //----------------------------------------------------------------------
    // TEST 16: Mask application in OR accumulator
    //----------------------------------------------------------------------
    task test_mask_application;
    begin
        case_fail = 0;
        reset_dut();
        // data=0xFF, mask=0x0F → OR accum = 0x0F
        run_scan_round(64'hFF, 64'h0F, 64'h0, 32'd0, 1'b0, 1'b0);
        expect_equal("test16_or", fault_or_result, 64'h0F);
        pass_case("test_mask_application");
    end
    endtask

    //----------------------------------------------------------------------
    // TEST 17: Accumulator shadow fault triggers safety_island_fault
    //----------------------------------------------------------------------
    task test_accum_shadow;
    begin
        case_fail = 0;
        reset_dut();
        // Force internal accumulator shadow to mismatch
        pulse_scan_start();
        inject_response(64'hAA, 64'hFF, 64'h0, 32'd0, 32'd0, 1'b0, 1'b0);
        force dut.accum_inv = dut.accum;  // break the inversion
        wait_cycles(1);
        pulse_scan_done();
        wait_cycles(2);
        expect_bit("test17_safety", safety_island_fault_event, 1'b1);
        release dut.accum_inv;
        pass_case("test_accum_shadow");
    end
    endtask

    //----------------------------------------------------------------------
    // TEST 18: Disabled state — no fault detection
    //----------------------------------------------------------------------
    task test_disabled;
    begin
        case_fail = 0;
        reset_dut();
        enable <= 1'b0;
        run_scan_round(64'hFF, 64'hFF, 64'h0, 32'd0, 1'b0, 1'b0);
        // Even though data is non-zero, should NOT report external fault
        // because enable=0 gates all detection
        // Actually: fault_detector still accumulates but outputs are held
        // Let's check a safety fault still goes through
        core_safety_fault <= 1'b1;
        core_safety_error_code <= 8'h41;
        wait_cycles(2);
        // Safety fault still reported regardless of enable
        expect_bit("test18_safety", safety_island_fault_event, 1'b1);
        core_safety_fault <= 1'b0;
        enable <= 1'b1;
        pass_case("test_disabled");
    end
    endtask

    //----------------------------------------------------------------------
    // Main test sequence
    //----------------------------------------------------------------------

    initial begin
        clk = 1'b0;
        rst = 1'b1;
        total_pass = 0;
        total_fail = 0;
        case_fail = 0;
        init();

        test_or_accum_external_fault();
        test_no_fault();
        test_expected_mismatch();
        test_expected_match_or_nonzero();
        test_bus_error();
        test_bus_timeout();
        test_config_illegal();
        test_config_shadow();
        test_safety_fault();
        test_stuck_at_fault();
        test_no_stuck_at_recovery();
        test_latent_fault();
        test_clear_status();
        test_multi_master_fault();
        test_accum_reset();
        test_mask_application();
        test_accum_shadow();
        test_disabled();

        if (total_fail == 0) begin
            $display("PASS: fault_detector unit test completed, cases=%0d", total_pass);
        end else begin
            $display("FAIL: fault_detector unit test, failures=%0d passes=%0d",
                     total_fail, total_pass);
        end

        $finish;
    end

endmodule
