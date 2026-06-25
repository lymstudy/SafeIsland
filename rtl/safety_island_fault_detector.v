//------------------------------------------------------------------------------
// safety_island_fault_detector.v
//
// AXI Safety Island 故障检测模块（整合版）
//
// 整合了 ymliu 版本（Mask+OR + Shadow保护）与 Jinyu 版本（Expected比较 +
// Stuck-at阈值 + 独立模块化）的优点。
//
// 故障检测功能：
//   1. Mask+OR 累加检测     — 被监控寄存器"任意位置位"检测（ymliu）
//   2. Mask+Expected 值比较 — 被监控寄存器"值不匹配"检测（Jinyu增强）
//   3. Stuck-at 故障检测    — 连续N轮扫描均出现 mismatch（Jinyu增强）
//   4. 潜伏故障检测         — 曾发生 mismatch 但自行恢复（Jinyu增强）
//   5. 总线故障检测         — AXI 响应错误 / 超时
//   6. 配置故障             — 非法配置 / Shadow 失配（透传）
//   7. 安全岛内部故障       — Core Logic 自检故障（透传）
//
// 安全保护：
//   - Accumulator shadow/inversion 检查
//   - Stuck-at 计数器范围检查
//   - Fault status bit 交叉校验
//------------------------------------------------------------------------------

`timescale 1ns/1ps

module safety_island_fault_detector #(
    parameter NUM_MASTERS         = 5,
    parameter NUM_ENTRIES         = 64,
    parameter DATA_W              = 64,
    parameter STUCK_AT_THRESHOLD  = 10
) (
    input  wire                                 clk,
    input  wire                                 rst,

    input  wire                                 enable,

    // ─── Per-response data from core logic ───
    input  wire                                 fd_resp_valid,
    input  wire [DATA_W-1:0]                    fd_resp_data,
    input  wire [DATA_W-1:0]                    fd_resp_mask,
    input  wire [DATA_W-1:0]                    fd_resp_expected,
    input  wire [31:0]                          fd_resp_master_idx,
    input  wire [31:0]                          fd_resp_entry_idx,
    input  wire                                 fd_resp_error,
    input  wire                                 fd_resp_timeout,

    // ─── Scan control ───
    input  wire                                 scan_start_pulse,
    input  wire                                 scan_done_pulse,
    input  wire                                 clear_status,

    // ─── Config faults (from config slave, pass-through) ───
    input  wire                                 cfg_illegal,
    input  wire                                 cfg_shadow_error,
    input  wire                                 cfg_interval_zero,

    // ─── Safety self-check faults (from core logic, pass-through) ───
    input  wire                                 core_safety_fault,
    input  wire [7:0]                           core_safety_error_code,

    // ─── Fault outputs ───
    output wire                                 fault_detect,
    output reg                                  external_fault_event,
    output reg                                  bus_fault_event,
    output reg                                  cfg_fault_event,
    output reg                                  safety_island_fault_event,
    output reg                                  safety_island_latent_fault_event,
    output reg  [DATA_W-1:0]                    fault_or_result,
    output reg  [63:0]                          fault_status,
    output reg  [7:0]                           error_code
);

    //--------------------------------------------------------------------------
    // 错误码定义
    //--------------------------------------------------------------------------

    localparam [7:0] ERR_NONE                = 8'h00;
    localparam [7:0] ERR_CFG_ILLEGAL         = 8'h10;
    localparam [7:0] ERR_CFG_SHADOW          = 8'h11;
    localparam [7:0] ERR_CFG_INTERVAL_ZERO   = 8'h12;
    localparam [7:0] ERR_BUS_RESP            = 8'h20;
    localparam [7:0] ERR_BUS_TIMEOUT         = 8'h21;
    localparam [7:0] ERR_EXTERNAL_FAULT      = 8'h30;
    localparam [7:0] ERR_EXPECTED_MISMATCH   = 8'h31;
    localparam [7:0] ERR_STUCK_AT_FAULT      = 8'h32;
    localparam [7:0] ERR_LATENT_FAULT        = 8'h33;
    localparam [7:0] ERR_ACCUM_SHADOW        = 8'h43;
    localparam [7:0] ERR_STUCK_CTR_RANGE     = 8'h46;
    localparam [7:0] ERR_CORE_SAFETY         = 8'h50;

    //--------------------------------------------------------------------------
    // Fault status bit assignments (64-bit status register)
    //--------------------------------------------------------------------------

    // Bits [4:0]   : per-master timeout
    // Bits [9:5]   : per-master AXI error response
    // Bits [14:10] : per-master expected mismatch
    // Bits [20:15] : per-master stuck-at fault
    // Bits [26:21] : per-master latent fault
    // Bit  [27]    : write protect violation
    // Bit  [28]    : illegal config
    // Bit  [29]    : accumulator shadow error
    // Bit  [30]    : external fault (OR accumulator non-zero)
    // Bit  [31]    : safety island internal fault (aggregate)

    localparam FAULT_TIMEOUT_BIT      = 0;
    localparam FAULT_ERROR_RESP_BIT   = 5;
    localparam FAULT_EXPECTED_BIT     = 10;
    localparam FAULT_STUCK_AT_BIT     = 15;
    localparam FAULT_LATENT_BIT       = 21;
    localparam FAULT_PROTECT_BIT      = 27;
    localparam FAULT_ILLEGAL_CFG_BIT  = 28;
    localparam FAULT_ACCUM_SHADOW_BIT = 29;
    localparam FAULT_EXTERNAL_BIT     = 30;
    localparam FAULT_SAFETY_ISLAND_BIT= 31;

    //--------------------------------------------------------------------------
    // Internal registers
    //--------------------------------------------------------------------------

    // Accumulator with shadow (from ymliu version)
    reg [DATA_W-1:0] accum;
    reg [DATA_W-1:0] accum_inv;

    // Per-master expected mismatch (this scan round)
    reg [NUM_MASTERS-1:0] ch_mismatch_this_round;

    // Per-master stuck-at counter (consecutive rounds with mismatch)
    reg [3:0] stuck_counter [0:NUM_MASTERS-1];

    // Per-master mismatch latched (sticky, for latent detection)
    reg [NUM_MASTERS-1:0] ch_mismatch_latched;

    // Bus fault flags for this scan round
    reg bus_error_seen;
    reg bus_timeout_seen;

    // Accumulator shadow fault
    reg accum_shadow_fault;

    integer ch;
    integer init_ch;

    //--------------------------------------------------------------------------
    // Combinational: per-response masked comparison
    //--------------------------------------------------------------------------

    wire [DATA_W-1:0] resp_masked_data;
    wire [DATA_W-1:0] resp_masked_expected;
    wire              resp_masked_mismatch;
    wire              resp_master_in_range;

    assign resp_masked_data     = fd_resp_data & fd_resp_mask;
    assign resp_masked_expected = fd_resp_expected & fd_resp_mask;
    assign resp_masked_mismatch = resp_masked_data != resp_masked_expected;
    assign resp_master_in_range = (fd_resp_master_idx < NUM_MASTERS);

    //--------------------------------------------------------------------------
    // Combinational: aggregate fault_detect
    //--------------------------------------------------------------------------

    assign fault_detect = external_fault_event |
                          bus_fault_event      |
                          cfg_fault_event;

    //--------------------------------------------------------------------------
    // Sequential: fault detection logic
    //--------------------------------------------------------------------------

    always @(posedge clk) begin
        if (rst) begin
            accum                    <= {DATA_W{1'b0}};
            accum_inv                <= {DATA_W{1'b1}};
            ch_mismatch_this_round   <= {NUM_MASTERS{1'b0}};
            ch_mismatch_latched      <= {NUM_MASTERS{1'b0}};
            bus_error_seen           <= 1'b0;
            bus_timeout_seen         <= 1'b0;
            accum_shadow_fault       <= 1'b0;
            external_fault_event     <= 1'b0;
            bus_fault_event          <= 1'b0;
            cfg_fault_event          <= 1'b0;
            safety_island_fault_event<= 1'b0;
            safety_island_latent_fault_event <= 1'b0;
            fault_or_result          <= {DATA_W{1'b0}};
            fault_status             <= 64'd0;
            error_code               <= ERR_NONE;

            for (init_ch = 0; init_ch < NUM_MASTERS; init_ch = init_ch + 1) begin
                stuck_counter[init_ch] <= 4'd0;
            end
        end else begin
            // ── Per-response processing ──
            if (fd_resp_valid) begin
                // Mask+OR accumulation with shadow
                accum     <= accum | resp_masked_data;
                accum_inv <= ~(accum | resp_masked_data);

                // Expected value mismatch
                if (resp_master_in_range && resp_masked_mismatch) begin
                    ch_mismatch_this_round[fd_resp_master_idx] <= 1'b1;
                    ch_mismatch_latched[fd_resp_master_idx]    <= 1'b1;
                    fault_status[FAULT_EXPECTED_BIT + fd_resp_master_idx] <= 1'b1;
                end

                // Bus faults
                if (fd_resp_error) begin
                    bus_error_seen <= 1'b1;
                    fault_status[FAULT_ERROR_RESP_BIT + fd_resp_master_idx] <= 1'b1;
                end
                if (fd_resp_timeout) begin
                    bus_timeout_seen <= 1'b1;
                    fault_status[FAULT_TIMEOUT_BIT + fd_resp_master_idx] <= 1'b1;
                end
            end

            // ── Config faults (continuously monitored) ──
            if (cfg_illegal) begin
                cfg_fault_event                <= 1'b1;
                fault_status[FAULT_ILLEGAL_CFG_BIT] <= 1'b1;
                if (error_code == ERR_NONE)
                    error_code <= ERR_CFG_ILLEGAL;
            end
            if (cfg_shadow_error) begin
                cfg_fault_event <= 1'b1;
                if (error_code == ERR_NONE)
                    error_code <= ERR_CFG_SHADOW;
            end
            if (cfg_interval_zero) begin
                cfg_fault_event <= 1'b1;
                if (error_code == ERR_NONE)
                    error_code <= ERR_CFG_INTERVAL_ZERO;
            end

            // ── Core safety fault (pass-through) ──
            if (core_safety_fault) begin
                safety_island_fault_event <= 1'b1;
                fault_status[FAULT_SAFETY_ISLAND_BIT] <= 1'b1;
                if (error_code == ERR_NONE)
                    error_code <= core_safety_error_code;
            end

            // ── Accumulator shadow check ──
            if (accum_inv != ~accum) begin
                accum_shadow_fault <= 1'b1;
            end

            // ── Start of new scan: reset per-round state ──
            if (scan_start_pulse) begin
                accum                  <= {DATA_W{1'b0}};
                accum_inv              <= {DATA_W{1'b1}};
                ch_mismatch_this_round <= {NUM_MASTERS{1'b0}};
                bus_error_seen         <= 1'b0;
                bus_timeout_seen       <= 1'b0;
            end

            // ── End of scan: finalize results ──
            if (scan_done_pulse) begin
                fault_or_result <= accum;

                // External fault: any bit set in OR accumulator
                if (accum != {DATA_W{1'b0}}) begin
                    external_fault_event <= 1'b1;
                    fault_status[FAULT_EXTERNAL_BIT] <= 1'b1;
                    if (error_code == ERR_NONE)
                        error_code <= ERR_EXTERNAL_FAULT;
                end

                // Expected mismatch finalized
                if (|ch_mismatch_this_round) begin
                    external_fault_event <= 1'b1;
                    if (error_code == ERR_NONE)
                        error_code <= ERR_EXPECTED_MISMATCH;
                end

                // Bus fault finalized
                if (bus_error_seen || bus_timeout_seen) begin
                    bus_fault_event <= 1'b1;
                    if (error_code == ERR_NONE) begin
                        if (bus_timeout_seen)
                            error_code <= ERR_BUS_TIMEOUT;
                        else
                            error_code <= ERR_BUS_RESP;
                    end
                end

                // ── Per-channel stuck-at and latent detection ──
                for (ch = 0; ch < NUM_MASTERS; ch = ch + 1) begin
                    if (ch_mismatch_this_round[ch] ||
                        fault_status[FAULT_ERROR_RESP_BIT + ch] ||
                        fault_status[FAULT_TIMEOUT_BIT + ch]) begin
                        // Fault persists this round
                        if (stuck_counter[ch] < STUCK_AT_THRESHOLD)
                            stuck_counter[ch] <= stuck_counter[ch] + 4'd1;

                        if (stuck_counter[ch] >= (STUCK_AT_THRESHOLD - 1)) begin
                            fault_status[FAULT_STUCK_AT_BIT + ch] <= 1'b1;
                            safety_island_fault_event <= 1'b1;
                            if (error_code == ERR_NONE)
                                error_code <= ERR_STUCK_AT_FAULT;
                        end
                    end else begin
                        // No fault this round
                        if (stuck_counter[ch] > 4'd0 &&
                            stuck_counter[ch] < STUCK_AT_THRESHOLD &&
                            ch_mismatch_latched[ch]) begin
                            // Was faulting but recovered → latent fault
                            fault_status[FAULT_LATENT_BIT + ch] <= 1'b1;
                            safety_island_latent_fault_event <= 1'b1;
                            if (error_code == ERR_NONE)
                                error_code <= ERR_LATENT_FAULT;
                        end
                        stuck_counter[ch] <= 4'd0;
                    end

                    // Stuck-at counter range check (safety)
                    if (stuck_counter[ch] > STUCK_AT_THRESHOLD) begin
                        safety_island_fault_event <= 1'b1;
                        fault_status[FAULT_SAFETY_ISLAND_BIT] <= 1'b1;
                        if (error_code == ERR_NONE)
                            error_code <= ERR_STUCK_CTR_RANGE;
                    end
                end

                // Accumulator shadow check → safety island fault
                if (accum_shadow_fault) begin
                    safety_island_fault_event <= 1'b1;
                    fault_status[FAULT_ACCUM_SHADOW_BIT] <= 1'b1;
                    fault_status[FAULT_SAFETY_ISLAND_BIT] <= 1'b1;
                    if (error_code == ERR_NONE)
                        error_code <= ERR_ACCUM_SHADOW;
                end

                // Aggregate safety island fault
                if (safety_island_fault_event)
                    fault_status[FAULT_SAFETY_ISLAND_BIT] <= 1'b1;
            end

            // ── Clear status ──
            if (clear_status) begin
                external_fault_event      <= 1'b0;
                bus_fault_event           <= 1'b0;
                cfg_fault_event           <= 1'b0;
                safety_island_fault_event <= 1'b0;
                safety_island_latent_fault_event <= 1'b0;
                fault_status              <= 64'd0;
                error_code                <= ERR_NONE;
                ch_mismatch_latched       <= {NUM_MASTERS{1'b0}};
                accum_shadow_fault        <= 1'b0;
                for (ch = 0; ch < NUM_MASTERS; ch = ch + 1)
                    stuck_counter[ch] <= 4'd0;
            end
        end
    end

endmodule
