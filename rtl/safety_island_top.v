//------------------------------------------------------------------------------
// safety_island_top.v  (整合版)
//
// AXI Safety Island 顶层模块。
//
// 整合变更（vs 原版）：
//   - 新增 safety_island_fault_detector 实例化，独立故障检测
//   - 新增 expected_flat 配置通道，支持 Expected 值比较
//   - 新增 STUCK_AT_THRESHOLD 参数
//   - 故障输出直接从 fault_detector 驱动
//
// 架构：
//   safety_island_axi_config_slave  →  配置寄存器 + Shadow 保护
//   safety_island_core_logic        →  扫描调度 + 地址生成 + Outstanding管理
//   safety_island_fault_detector    →  故障分类 + Stuck-at + Latent + Expected
//   safety_island_axi_read_engine ×5 → AXI Read Master + CRC-8 AoU
//------------------------------------------------------------------------------

`timescale 1ns/1ps

module safety_island_top #(
    parameter NUM_MASTERS         = 5,
    parameter NUM_ENTRIES         = 64,
    parameter ADDR_W              = 32,
    parameter DATA_W              = 64,
    parameter ID_W                = 4,
    parameter TIMEOUT_CYCLES      = 1024,
    parameter SUPPORT_OUTSTANDING = 1,
    parameter MAX_OUTSTANDING     = 4,
    parameter STUCK_AT_THRESHOLD  = 10,
    parameter CRC_WIDTH           = 16
) (
    input  wire                                      clk,
    input  wire                                      rst,

    // ─── S_AXI (64-bit AXI4-Lite Slave config) ───
    input  wire [ID_W-1:0]                           s_axi_awid,
    input  wire [ADDR_W-1:0]                         s_axi_awaddr,
    input  wire [7:0]                                s_axi_awlen,
    input  wire [2:0]                                s_axi_awsize,
    input  wire [1:0]                                s_axi_awburst,
    input  wire                                      s_axi_awlock,
    input  wire [3:0]                                s_axi_awcache,
    input  wire [2:0]                                s_axi_awprot,
    input  wire [3:0]                                s_axi_awqos,
    input  wire                                      s_axi_awvalid,
    output wire                                      s_axi_awready,
    input  wire [DATA_W-1:0]                         s_axi_wdata,
    input  wire [(DATA_W/8)-1:0]                     s_axi_wstrb,
    input  wire                                      s_axi_wlast,
    input  wire                                      s_axi_wvalid,
    output wire                                      s_axi_wready,
    output wire [ID_W-1:0]                           s_axi_bid,
    output wire [1:0]                                s_axi_bresp,
    output wire                                      s_axi_bvalid,
    input  wire                                      s_axi_bready,
    input  wire [ID_W-1:0]                           s_axi_arid,
    input  wire [ADDR_W-1:0]                         s_axi_araddr,
    input  wire [7:0]                                s_axi_arlen,
    input  wire [2:0]                                s_axi_arsize,
    input  wire [1:0]                                s_axi_arburst,
    input  wire                                      s_axi_arlock,
    input  wire [3:0]                                s_axi_arcache,
    input  wire [2:0]                                s_axi_arprot,
    input  wire [3:0]                                s_axi_arqos,
    input  wire                                      s_axi_arvalid,
    output wire                                      s_axi_arready,
    output wire [ID_W-1:0]                           s_axi_rid,
    output wire [DATA_W-1:0]                         s_axi_rdata,
    output wire [1:0]                                s_axi_rresp,
    output wire                                      s_axi_rlast,
    output wire                                      s_axi_rvalid,
    input  wire                                      s_axi_rready,

    // ─── M_AXI (5× AXI Read Only Master monitors) ───
    output wire [NUM_MASTERS*ID_W-1:0]               m_axi_awid_flat,
    output wire [NUM_MASTERS*ADDR_W-1:0]             m_axi_awaddr_flat,
    output wire [NUM_MASTERS*8-1:0]                  m_axi_awlen_flat,
    output wire [NUM_MASTERS*3-1:0]                  m_axi_awsize_flat,
    output wire [NUM_MASTERS*2-1:0]                  m_axi_awburst_flat,
    output wire [NUM_MASTERS-1:0]                    m_axi_awlock_flat,
    output wire [NUM_MASTERS*4-1:0]                  m_axi_awcache_flat,
    output wire [NUM_MASTERS*3-1:0]                  m_axi_awprot_flat,
    output wire [NUM_MASTERS*4-1:0]                  m_axi_awqos_flat,
    output wire [NUM_MASTERS-1:0]                    m_axi_awvalid_flat,
    input  wire [NUM_MASTERS-1:0]                    m_axi_awready_flat,
    output wire [NUM_MASTERS*DATA_W-1:0]             m_axi_wdata_flat,
    output wire [NUM_MASTERS*(DATA_W/8)-1:0]         m_axi_wstrb_flat,
    output wire [NUM_MASTERS-1:0]                    m_axi_wlast_flat,
    output wire [NUM_MASTERS-1:0]                    m_axi_wvalid_flat,
    input  wire [NUM_MASTERS-1:0]                    m_axi_wready_flat,
    input  wire [NUM_MASTERS*ID_W-1:0]               m_axi_bid_flat,
    input  wire [NUM_MASTERS*2-1:0]                  m_axi_bresp_flat,
    input  wire [NUM_MASTERS-1:0]                    m_axi_bvalid_flat,
    output wire [NUM_MASTERS-1:0]                    m_axi_bready_flat,
    output wire [NUM_MASTERS*ID_W-1:0]               m_axi_arid_flat,
    output wire [NUM_MASTERS*ADDR_W-1:0]             m_axi_araddr_flat,
    output wire [NUM_MASTERS*8-1:0]                  m_axi_arlen_flat,
    output wire [NUM_MASTERS*3-1:0]                  m_axi_arsize_flat,
    output wire [NUM_MASTERS*2-1:0]                  m_axi_arburst_flat,
    output wire [NUM_MASTERS-1:0]                    m_axi_arlock_flat,
    output wire [NUM_MASTERS*4-1:0]                  m_axi_arcache_flat,
    output wire [NUM_MASTERS*3-1:0]                  m_axi_arprot_flat,
    output wire [NUM_MASTERS*4-1:0]                  m_axi_arqos_flat,
    output wire [NUM_MASTERS-1:0]                    m_axi_arvalid_flat,
    input  wire [NUM_MASTERS-1:0]                    m_axi_arready_flat,
    input  wire [NUM_MASTERS*ID_W-1:0]               m_axi_rid_flat,
    input  wire [NUM_MASTERS*DATA_W-1:0]             m_axi_rdata_flat,
    input  wire [NUM_MASTERS*2-1:0]                  m_axi_rresp_flat,
    input  wire [NUM_MASTERS-1:0]                    m_axi_rlast_flat,
    input  wire [NUM_MASTERS-1:0]                    m_axi_rvalid_flat,
    input  wire [NUM_MASTERS*CRC_WIDTH-1:0]          m_axi_rcheck_flat,
    output wire [NUM_MASTERS-1:0]                    m_axi_rready_flat,

    // ─── Fault outputs (driven by fault_detector) ───
    output wire                                      fault_detect,
    output wire                                      safety_island_fault_detect,
    output wire                                      safety_island_latent_fault_detect,
    output wire [DATA_W-1:0]                         fault_or_result,
    output wire [7:0]                                core_error_code
);

    localparam [2:0] AXI_SIZE = (DATA_W == 64) ? 3'd3 : 3'd2;

    //--------------------------------------------------------------------------
    // 配置总线信号
    //--------------------------------------------------------------------------

    wire                                      cfg_enable;
    wire                                      cfg_scan_once;
    wire                                      cfg_clear_core_status;
    wire [63:0]                               cfg_read_interval;
    wire [NUM_MASTERS*ADDR_W-1:0]             cfg_base_addr_flat;
    wire [NUM_MASTERS*NUM_ENTRIES*ADDR_W-1:0] cfg_offset_flat;
    wire [NUM_MASTERS*NUM_ENTRIES*DATA_W-1:0] cfg_mask_flat;
    wire [NUM_MASTERS*NUM_ENTRIES*DATA_W-1:0] cfg_expected_flat;
    wire [NUM_MASTERS*NUM_ENTRIES*2-1:0]      cfg_burst_type_flat;
    wire [NUM_MASTERS*NUM_ENTRIES*8-1:0]      cfg_burst_len_flat;
    wire [NUM_MASTERS*NUM_ENTRIES-1:0]        cfg_entry_valid_flat;
    wire                                      cfg_valid;
    wire                                      cfg_locked;
    wire                                      cfg_illegal;
    wire                                      cfg_shadow_error;

    wire                                      cfg_kat_enable;
    wire [ADDR_W-1:0]                         cfg_kat_addr;
    wire [DATA_W-1:0]                         cfg_kat_expected;
    wire [DATA_W-1:0]                         cfg_kat_mask;

    //--------------------------------------------------------------------------
    // Core Logic ↔ Read Engine 信号
    //--------------------------------------------------------------------------

    wire [NUM_MASTERS-1:0]                    core_read_req;
    wire [NUM_MASTERS*ADDR_W-1:0]             core_read_addr_flat;
    wire [NUM_MASTERS*2-1:0]                  core_burst_type_flat;
    wire [NUM_MASTERS*8-1:0]                  core_burst_len_flat;
    wire [NUM_MASTERS-1:0]                    core_read_accept;
    wire [NUM_MASTERS-1:0]                    core_read_done;
    wire [NUM_MASTERS*DATA_W-1:0]             core_read_data_flat;
    wire [NUM_MASTERS-1:0]                    core_resp_error;
    wire [NUM_MASTERS-1:0]                    core_timeout;

    //--------------------------------------------------------------------------
    // Core Logic → Fault Detector 信号
    //--------------------------------------------------------------------------

    wire                                      scan_busy;
    wire                                      scan_done_pulse;
    wire                                      scan_start_pulse;
    wire [31:0]                               current_master_idx;
    wire [31:0]                               current_entry_idx;
    wire [31:0]                               outstanding_count;

    wire                                      fd_resp_valid;
    wire [DATA_W-1:0]                         fd_resp_data;
    wire [DATA_W-1:0]                         fd_resp_mask;
    wire [DATA_W-1:0]                         fd_resp_expected;
    wire [31:0]                               fd_resp_master_idx;
    wire [31:0]                               fd_resp_entry_idx;
    wire                                      fd_resp_error;
    wire                                      fd_resp_timeout;

    wire                                      cfg_fault_comb_out;
    wire                                      cfg_illegal_out;
    wire                                      cfg_shadow_error_out;
    wire                                      cfg_interval_fault_out;
    wire                                      core_safety_fault;
    wire [7:0]                                core_safety_error_code;

    //--------------------------------------------------------------------------
    // Fault Detector → Top 信号
    //--------------------------------------------------------------------------

    wire                                      fd_external_fault;
    wire                                      fd_bus_fault;
    wire                                      fd_cfg_fault;
    wire                                      fd_safety_island_fault;
    wire                                      fd_safety_island_latent_fault;
    wire [DATA_W-1:0]                         fd_fault_or_result;
    wire [7:0]                                fd_error_code;

    // Heartbeat signals
    wire                                      heartbeat_fault;
    wire                                      heartbeat_active;
    wire                                      heartbeat_test_inject;
    wire [NUM_MASTERS-1:0]                    read_engine_safety_fault;
    wire [NUM_MASTERS-1:0]                    rsp_fifo_safety_fault;
    wire                                      datapath_safety_fault;
    wire                                      aggregate_safety_fault;
    wire [7:0]                                aggregate_safety_error_code;

    //--------------------------------------------------------------------------
    // Read Engine 响应信号（generate 块中使用）
    //--------------------------------------------------------------------------

    wire [NUM_MASTERS-1:0]                    cmd_ready_flat;
    wire [NUM_MASTERS-1:0]                    axi_done_flat;
    wire [NUM_MASTERS-1:0]                    axi_error_flat;
    wire [NUM_MASTERS-1:0]                    axi_timeout_flat;
    wire [NUM_MASTERS*DATA_W-1:0]             axi_read_data_flat;

    //--------------------------------------------------------------------------
    // 顶层故障输出 = fault_detector 输出
    //--------------------------------------------------------------------------

    assign datapath_safety_fault = (|read_engine_safety_fault) | (|rsp_fifo_safety_fault);
    assign aggregate_safety_fault = core_safety_fault | datapath_safety_fault;
    assign aggregate_safety_error_code = core_safety_fault ? core_safety_error_code : 8'h48;

    (* DONT_TOUCH = "TRUE" *) wire fd_a = fd_external_fault | fd_bus_fault | fd_cfg_fault;
    (* DONT_TOUCH = "TRUE" *) wire fd_b = fd_external_fault | fd_bus_fault | fd_cfg_fault;
    (* DONT_TOUCH = "TRUE" *) wire fd_c = fd_external_fault | fd_bus_fault | fd_cfg_fault;

    wire fd_tmr_mismatch;
    assign fault_detect = (fd_a & fd_b) | (fd_b & fd_c) | (fd_a & fd_c);
    assign fd_tmr_mismatch = (fd_a ^ fd_b) | (fd_a ^ fd_c) | (fd_b ^ fd_c);

    (* DONT_TOUCH = "TRUE" *) wire sifd_a = fd_safety_island_fault | heartbeat_fault | datapath_safety_fault;
    (* DONT_TOUCH = "TRUE" *) wire sifd_b = fd_safety_island_fault | heartbeat_fault | datapath_safety_fault;
    (* DONT_TOUCH = "TRUE" *) wire sifd_c = fd_safety_island_fault | heartbeat_fault | datapath_safety_fault;

    wire sifd_tmr_mismatch;
    assign safety_island_fault_detect = ((sifd_a & sifd_b) | (sifd_b & sifd_c) | (sifd_a & sifd_c))
                                       | fd_tmr_mismatch | sifd_tmr_mismatch;
    assign sifd_tmr_mismatch = (sifd_a ^ sifd_b) | (sifd_a ^ sifd_c) | (sifd_b ^ sifd_c);
    assign safety_island_latent_fault_detect = fd_safety_island_latent_fault |
                                              cfg_shadow_error | fd_safety_island_fault |
                                              datapath_safety_fault;
    assign fault_or_result                 = fd_fault_or_result;
    assign core_error_code                 = fd_error_code;

    //--------------------------------------------------------------------------
    // safety_island_axi_config_slave
    //--------------------------------------------------------------------------

    safety_island_axi_config_slave #(
        .NUM_MASTERS(NUM_MASTERS),
        .NUM_ENTRIES(NUM_ENTRIES),
        .ADDR_W(ADDR_W),
        .DATA_W(DATA_W),
        .ID_W(ID_W)
    ) u_cfg (
        .clk                      (clk),
        .rst                      (rst),
        .s_axi_awid               (s_axi_awid),
        .s_axi_awaddr             (s_axi_awaddr),
        .s_axi_awlen              (s_axi_awlen),
        .s_axi_awsize             (s_axi_awsize),
        .s_axi_awburst            (s_axi_awburst),
        .s_axi_awlock             (s_axi_awlock),
        .s_axi_awcache            (s_axi_awcache),
        .s_axi_awprot             (s_axi_awprot),
        .s_axi_awqos              (s_axi_awqos),
        .s_axi_awvalid            (s_axi_awvalid),
        .s_axi_awready            (s_axi_awready),
        .s_axi_wdata              (s_axi_wdata),
        .s_axi_wstrb              (s_axi_wstrb),
        .s_axi_wlast              (s_axi_wlast),
        .s_axi_wvalid             (s_axi_wvalid),
        .s_axi_wready             (s_axi_wready),
        .s_axi_bid                (s_axi_bid),
        .s_axi_bresp              (s_axi_bresp),
        .s_axi_bvalid             (s_axi_bvalid),
        .s_axi_bready             (s_axi_bready),
        .s_axi_arid               (s_axi_arid),
        .s_axi_araddr             (s_axi_araddr),
        .s_axi_arlen              (s_axi_arlen),
        .s_axi_arsize             (s_axi_arsize),
        .s_axi_arburst            (s_axi_arburst),
        .s_axi_arlock             (s_axi_arlock),
        .s_axi_arcache            (s_axi_arcache),
        .s_axi_arprot             (s_axi_arprot),
        .s_axi_arqos              (s_axi_arqos),
        .s_axi_arvalid            (s_axi_arvalid),
        .s_axi_arready            (s_axi_arready),
        .s_axi_rid                (s_axi_rid),
        .s_axi_rdata              (s_axi_rdata),
        .s_axi_rresp              (s_axi_rresp),
        .s_axi_rlast              (s_axi_rlast),
        .s_axi_rvalid             (s_axi_rvalid),
        .s_axi_rready             (s_axi_rready),
        .enable                   (cfg_enable),
        .scan_once                (cfg_scan_once),
        .clear_core_status        (cfg_clear_core_status),
        .read_interval            (cfg_read_interval),
        .base_addr_flat           (cfg_base_addr_flat),
        .offset_flat              (cfg_offset_flat),
        .mask_flat                (cfg_mask_flat),
        .burst_type_flat          (cfg_burst_type_flat),
        .burst_len_flat           (cfg_burst_len_flat),
        .entry_valid_flat         (cfg_entry_valid_flat),
        .expected_flat            (cfg_expected_flat),
        .cfg_valid                (cfg_valid),
        .cfg_locked               (cfg_locked),
        .cfg_illegal              (cfg_illegal),
        .cfg_shadow_error         (cfg_shadow_error),
        .kat_enable_out          (cfg_kat_enable),
        .kat_addr_out            (cfg_kat_addr),
        .kat_expected_out        (cfg_kat_expected),
        .kat_mask_out            (cfg_kat_mask),
        .scan_busy                (scan_busy),
        .scan_done_pulse          (scan_done_pulse),
        .current_master_idx       (current_master_idx),
        .current_entry_idx        (current_entry_idx),
        .fault_or_result          (fd_fault_or_result),
        .external_fault_event     (fd_external_fault),
        .bus_fault_event          (fd_bus_fault),
        .cfg_fault_event          (fd_cfg_fault),
        .safety_island_fault_event(fd_safety_island_fault),
        .safety_island_latent_fault_event(safety_island_latent_fault_detect),
        .core_error_code          (fd_error_code),
        .outstanding_count        (outstanding_count)
    );

    //--------------------------------------------------------------------------
    // safety_island_core_logic
    //--------------------------------------------------------------------------

    safety_island_core_logic #(
        .NUM_MASTERS        (NUM_MASTERS),
        .NUM_ENTRIES        (NUM_ENTRIES),
        .ADDR_W             (ADDR_W),
        .DATA_W             (DATA_W),
        .BURST_TYPE_W       (2),
        .BURST_LEN_W        (8),
        .SUPPORT_OUTSTANDING(SUPPORT_OUTSTANDING),
        .MAX_OUTSTANDING    (MAX_OUTSTANDING)
    ) u_core (
        .clk                  (clk),
        .rst                  (rst),
        .enable               (cfg_enable),
        .scan_once            (cfg_scan_once),
        .clear_core_status    (cfg_clear_core_status),
        .read_interval        (cfg_read_interval),
        .base_addr_flat       (cfg_base_addr_flat),
        .offset_flat          (cfg_offset_flat),
        .mask_flat            (cfg_mask_flat),
        .expected_flat        (cfg_expected_flat),
        .burst_type_flat      (cfg_burst_type_flat),
        .burst_len_flat       (cfg_burst_len_flat),
        .entry_valid_flat     (cfg_entry_valid_flat),
        .cfg_valid            (cfg_valid),
        .cfg_locked           (cfg_locked),
        .cfg_illegal          (cfg_illegal),
        .cfg_shadow_error     (cfg_shadow_error),
        .kat_enable              (cfg_kat_enable),
        .kat_addr                (cfg_kat_addr),
        .kat_expected            (cfg_kat_expected),
        .kat_mask                (cfg_kat_mask),
        .m_read_req           (core_read_req),
        .m_read_addr_flat     (core_read_addr_flat),
        .m_burst_type_flat    (core_burst_type_flat),
        .m_burst_len_flat     (core_burst_len_flat),
        .m_read_accept        (core_read_accept),
        .m_read_done          (core_read_done),
        .m_read_data_flat     (core_read_data_flat),
        .m_resp_error         (core_resp_error),
        .m_timeout            (core_timeout),
        .scan_busy            (scan_busy),
        .scan_done_pulse      (scan_done_pulse),
        .scan_start_pulse     (scan_start_pulse),
        .current_master_idx   (current_master_idx),
        .current_entry_idx    (current_entry_idx),
        .outstanding_count    (outstanding_count),
        .fd_resp_valid        (fd_resp_valid),
        .fd_resp_data         (fd_resp_data),
        .fd_resp_mask         (fd_resp_mask),
        .fd_resp_expected     (fd_resp_expected),
        .fd_resp_master_idx   (fd_resp_master_idx),
        .fd_resp_entry_idx    (fd_resp_entry_idx),
        .fd_resp_error        (fd_resp_error),
        .fd_resp_timeout      (fd_resp_timeout),
        .cfg_fault_comb_out   (cfg_fault_comb_out),
        .cfg_illegal_out      (cfg_illegal_out),
        .cfg_shadow_error_out (cfg_shadow_error_out),
        .cfg_interval_fault_out(cfg_interval_fault_out),
        .core_safety_fault    (core_safety_fault),
        .core_safety_error_code(core_safety_error_code),
        .test_inject              (heartbeat_test_inject),
        .heartbeat_active         (heartbeat_active)
    );

    //--------------------------------------------------------------------------
    // safety_island_fault_detector
    //--------------------------------------------------------------------------

    safety_island_fault_detector #(
        .NUM_MASTERS        (NUM_MASTERS),
        .NUM_ENTRIES        (NUM_ENTRIES),
        .DATA_W             (DATA_W),
        .STUCK_AT_THRESHOLD (STUCK_AT_THRESHOLD)
    ) u_fault_detector (
        .clk                    (clk),
        .rst                    (rst),
        .enable                 (cfg_enable),
        .fd_resp_valid          (fd_resp_valid),
        .fd_resp_data           (fd_resp_data),
        .fd_resp_mask           (fd_resp_mask),
        .fd_resp_expected       (fd_resp_expected),
        .fd_resp_master_idx     (fd_resp_master_idx),
        .fd_resp_entry_idx      (fd_resp_entry_idx),
        .fd_resp_error          (fd_resp_error),
        .fd_resp_timeout        (fd_resp_timeout),
        .scan_start_pulse       (scan_start_pulse),
        .scan_done_pulse        (scan_done_pulse),
        .clear_status           (cfg_clear_core_status),
        .cfg_illegal            (cfg_illegal_out),
        .cfg_shadow_error       (cfg_shadow_error_out),
        .cfg_interval_zero      (cfg_interval_fault_out),
        .core_safety_fault      (aggregate_safety_fault),
        .core_safety_error_code (aggregate_safety_error_code),
        .fault_detect           (),  // unused — computed at top level
        .external_fault_event   (fd_external_fault),
        .bus_fault_event        (fd_bus_fault),
        .cfg_fault_event        (fd_cfg_fault),
        .safety_island_fault_event(fd_safety_island_fault),
        .safety_island_latent_fault_event(fd_safety_island_latent_fault),
        .fault_or_result        (fd_fault_or_result),
        .fault_status           (),  // 64-bit internal status (exposed via config slave if needed)
        .error_code             (fd_error_code)
    );

    //--------------------------------------------------------------------------
    // safety_island_heartbeat
    //--------------------------------------------------------------------------

    safety_island_heartbeat #(
        .HEARTBEAT_INTERVAL(1024)
    ) u_heartbeat (
        .clk                          (clk),
        .rst                          (rst),
        .enable                       (cfg_enable),
        .scan_busy                    (scan_busy),
        .test_inject                  (heartbeat_test_inject),
        .heartbeat_fault              (heartbeat_fault),
        .heartbeat_active             (heartbeat_active),
        .safety_island_fault_detect   (safety_island_fault_detect)
    );

    //--------------------------------------------------------------------------
    // Generate: N 个 AXI Read Engine + 响应缓冲
    //
    // 响应缓冲 (rsp FIFO)：
    //   读引擎通过单周期脉冲输出完成，缓冲将其转换为持久的 valid 信号，
    //   供 core logic 在任意时刻消费。由于读引擎按请求顺序出队，且
    //   每次最多一响应，故 1 深度 FIFO 即可工作，保留 MAX_OUTSTANDING
    //   深度以应对未来扩展。
    //--------------------------------------------------------------------------

    genvar mi;
    generate
        for (mi = 0; mi < NUM_MASTERS; mi = mi + 1) begin : gen_read_master
            localparam [ID_W-1:0] MASTER_ID = mi;

            reg [DATA_W-1:0] rsp_data_q    [0:MAX_OUTSTANDING-1];
            reg              rsp_error_q   [0:MAX_OUTSTANDING-1];
            reg              rsp_timeout_q [0:MAX_OUTSTANDING-1];
            reg [DATA_W-1:0] rsp_data_inv_q    [0:MAX_OUTSTANDING-1];
            reg              rsp_error_inv_q   [0:MAX_OUTSTANDING-1];
            reg              rsp_timeout_inv_q [0:MAX_OUTSTANDING-1];
            reg [31:0]       rsp_wr_ptr;
            reg [31:0]       rsp_rd_ptr;
            reg [31:0]       rsp_count;
            reg [31:0]       rsp_wr_ptr_inv;
            reg [31:0]       rsp_rd_ptr_inv;
            reg [31:0]       rsp_count_inv;
            reg              rsp_valid_out;
            reg [DATA_W-1:0] rsp_data_out;
            reg              rsp_error_out;
            reg              rsp_timeout_out;
            reg              rsp_valid_out_inv;
            reg [DATA_W-1:0] rsp_data_out_inv;
            reg              rsp_error_out_inv;
            reg              rsp_timeout_out_inv;
            reg              rsp_fifo_shadow_error_comb;
            integer          rsp_i;
            integer          rsp_chk_i;

            always @* begin
                rsp_fifo_shadow_error_comb =
                    (rsp_wr_ptr_inv != ~rsp_wr_ptr) |
                    (rsp_rd_ptr_inv != ~rsp_rd_ptr) |
                    (rsp_count_inv  != ~rsp_count) |
                    (rsp_valid_out_inv != ~rsp_valid_out) |
                    (rsp_data_out_inv != ~rsp_data_out) |
                    (rsp_error_out_inv != ~rsp_error_out) |
                    (rsp_timeout_out_inv != ~rsp_timeout_out);

                for (rsp_chk_i = 0; rsp_chk_i < MAX_OUTSTANDING; rsp_chk_i = rsp_chk_i + 1) begin
                    if ((rsp_data_inv_q[rsp_chk_i] != ~rsp_data_q[rsp_chk_i]) ||
                        (rsp_error_inv_q[rsp_chk_i] != ~rsp_error_q[rsp_chk_i]) ||
                        (rsp_timeout_inv_q[rsp_chk_i] != ~rsp_timeout_q[rsp_chk_i]))
                        rsp_fifo_shadow_error_comb = 1'b1;
                end
            end

            assign rsp_fifo_safety_fault[mi] =
                rsp_fifo_shadow_error_comb |
                (rsp_wr_ptr >= MAX_OUTSTANDING) |
                (rsp_rd_ptr >= MAX_OUTSTANDING) |
                (rsp_count > MAX_OUTSTANDING);

            assign core_read_accept[mi] = core_read_req[mi] & cmd_ready_flat[mi];
            assign core_read_done[mi]   = rsp_valid_out;
            assign core_resp_error[mi]  = rsp_error_out;
            assign core_timeout[mi]     = rsp_timeout_out;
            assign core_read_data_flat[mi*DATA_W +: DATA_W] = rsp_data_out;

            always @(posedge clk) begin
                if (rst) begin
                    rsp_wr_ptr      <= 32'd0;
                    rsp_rd_ptr      <= 32'd0;
                    rsp_count       <= 32'd0;
                    rsp_wr_ptr_inv  <= {32{1'b1}};
                    rsp_rd_ptr_inv  <= {32{1'b1}};
                    rsp_count_inv   <= {32{1'b1}};
                    rsp_valid_out   <= 1'b0;
                    rsp_data_out    <= {DATA_W{1'b0}};
                    rsp_error_out   <= 1'b0;
                    rsp_timeout_out <= 1'b0;
                    rsp_valid_out_inv   <= 1'b1;
                    rsp_data_out_inv    <= {DATA_W{1'b1}};
                    rsp_error_out_inv   <= 1'b1;
                    rsp_timeout_out_inv <= 1'b1;

                    for (rsp_i = 0; rsp_i < MAX_OUTSTANDING; rsp_i = rsp_i + 1) begin
                        rsp_data_q[rsp_i]    <= {DATA_W{1'b0}};
                        rsp_error_q[rsp_i]   <= 1'b0;
                        rsp_timeout_q[rsp_i] <= 1'b0;
                        rsp_data_inv_q[rsp_i]    <= {DATA_W{1'b1}};
                        rsp_error_inv_q[rsp_i]   <= 1'b1;
                        rsp_timeout_inv_q[rsp_i] <= 1'b1;
                    end
                end else begin
                    rsp_valid_out <= 1'b0;
                    rsp_valid_out_inv <= 1'b1;

                    if (rsp_count != 32'd0) begin
                        rsp_valid_out   <= 1'b1;
                        rsp_data_out    <= rsp_data_q[rsp_rd_ptr];
                        rsp_error_out   <= rsp_error_q[rsp_rd_ptr];
                        rsp_timeout_out <= rsp_timeout_q[rsp_rd_ptr];
                        rsp_valid_out_inv   <= 1'b0;
                        rsp_data_out_inv    <= ~rsp_data_q[rsp_rd_ptr];
                        rsp_error_out_inv   <= ~rsp_error_q[rsp_rd_ptr];
                        rsp_timeout_out_inv <= ~rsp_timeout_q[rsp_rd_ptr];

                        if (rsp_rd_ptr >= (MAX_OUTSTANDING - 1)) begin
                            rsp_rd_ptr <= 32'd0;
                            rsp_rd_ptr_inv <= {32{1'b1}};
                        end else begin
                            rsp_rd_ptr <= rsp_rd_ptr + 32'd1;
                            rsp_rd_ptr_inv <= ~(rsp_rd_ptr + 32'd1);
                        end
                    end

                    if (axi_done_flat[mi] || axi_error_flat[mi] || axi_timeout_flat[mi]) begin
                        rsp_data_q[rsp_wr_ptr]    <= axi_read_data_flat[mi*DATA_W +: DATA_W];
                        rsp_error_q[rsp_wr_ptr]   <= axi_error_flat[mi] & ~axi_timeout_flat[mi];
                        rsp_timeout_q[rsp_wr_ptr] <= axi_timeout_flat[mi];
                        rsp_data_inv_q[rsp_wr_ptr]    <= ~axi_read_data_flat[mi*DATA_W +: DATA_W];
                        rsp_error_inv_q[rsp_wr_ptr]   <= ~(axi_error_flat[mi] & ~axi_timeout_flat[mi]);
                        rsp_timeout_inv_q[rsp_wr_ptr] <= ~axi_timeout_flat[mi];

                        if (rsp_wr_ptr >= (MAX_OUTSTANDING - 1)) begin
                            rsp_wr_ptr <= 32'd0;
                            rsp_wr_ptr_inv <= {32{1'b1}};
                        end else begin
                            rsp_wr_ptr <= rsp_wr_ptr + 32'd1;
                            rsp_wr_ptr_inv <= ~(rsp_wr_ptr + 32'd1);
                        end
                    end

                    if ((rsp_count != 32'd0) &&
                        (axi_done_flat[mi] || axi_error_flat[mi] || axi_timeout_flat[mi])) begin
                        rsp_count <= rsp_count;
                    end else if (rsp_count != 32'd0) begin
                        rsp_count <= rsp_count - 32'd1;
                        rsp_count_inv <= ~(rsp_count - 32'd1);
                    end else if (axi_done_flat[mi] || axi_error_flat[mi] || axi_timeout_flat[mi]) begin
                        rsp_count <= rsp_count + 32'd1;
                        rsp_count_inv <= ~(rsp_count + 32'd1);
                    end
                end
            end

            // AW/W/B channels: tied off (read-only master)
            assign m_axi_awid_flat[mi*ID_W +: ID_W] = {ID_W{1'b0}};
            assign m_axi_awaddr_flat[mi*ADDR_W +: ADDR_W] = {ADDR_W{1'b0}};
            assign m_axi_awlen_flat[mi*8 +: 8] = 8'd0;
            assign m_axi_awsize_flat[mi*3 +: 3] = AXI_SIZE;
            assign m_axi_awburst_flat[mi*2 +: 2] = 2'b01;
            assign m_axi_awlock_flat[mi] = 1'b0;
            assign m_axi_awcache_flat[mi*4 +: 4] = 4'b0011;
            assign m_axi_awprot_flat[mi*3 +: 3] = 3'b000;
            assign m_axi_awqos_flat[mi*4 +: 4] = 4'b0000;
            assign m_axi_awvalid_flat[mi] = 1'b0;
            assign m_axi_wdata_flat[mi*DATA_W +: DATA_W] = {DATA_W{1'b0}};
            assign m_axi_wstrb_flat[mi*(DATA_W/8) +: (DATA_W/8)] = {(DATA_W/8){1'b0}};
            assign m_axi_wlast_flat[mi] = 1'b0;
            assign m_axi_wvalid_flat[mi] = 1'b0;
            assign m_axi_bready_flat[mi] = 1'b0;

            safety_island_axi_read_engine #(
                .ADDR_WIDTH     (ADDR_W),
                .DATA_WIDTH     (DATA_W),
                .ID_WIDTH       (ID_W),
                .TIMEOUT_CYCLES (TIMEOUT_CYCLES),
                .MAX_OUTSTANDING(MAX_OUTSTANDING),
                .CRC_WIDTH      (CRC_WIDTH)
            ) u_read_engine (
                .clk           (clk),
                .rst           (rst),
                .cmd_valid     (core_read_req[mi]),
                .cmd_ready     (cmd_ready_flat[mi]),
                .cmd_id        (MASTER_ID),
                .cmd_addr      (core_read_addr_flat[mi*ADDR_W +: ADDR_W]),
                .cmd_len       (core_burst_len_flat[mi*8 +: 8]),
                .cmd_size      (AXI_SIZE),
                .cmd_burst     (core_burst_type_flat[mi*2 +: 2]),
                .done          (axi_done_flat[mi]),
                .error         (axi_error_flat[mi]),
                .timeout       (axi_timeout_flat[mi]),
                .read_data     (axi_read_data_flat[mi*DATA_W +: DATA_W]),
                .m_axi_arid    (m_axi_arid_flat[mi*ID_W +: ID_W]),
                .m_axi_araddr  (m_axi_araddr_flat[mi*ADDR_W +: ADDR_W]),
                .m_axi_arlen   (m_axi_arlen_flat[mi*8 +: 8]),
                .m_axi_arsize  (m_axi_arsize_flat[mi*3 +: 3]),
                .m_axi_arburst (m_axi_arburst_flat[mi*2 +: 2]),
                .m_axi_arlock  (m_axi_arlock_flat[mi]),
                .m_axi_arcache (m_axi_arcache_flat[mi*4 +: 4]),
                .m_axi_arprot  (m_axi_arprot_flat[mi*3 +: 3]),
                .m_axi_arqos   (m_axi_arqos_flat[mi*4 +: 4]),
                .m_axi_arvalid (m_axi_arvalid_flat[mi]),
                .m_axi_arready (m_axi_arready_flat[mi]),
                .m_axi_rid     (m_axi_rid_flat[mi*ID_W +: ID_W]),
                .m_axi_rdata   (m_axi_rdata_flat[mi*DATA_W +: DATA_W]),
                .m_axi_rresp   (m_axi_rresp_flat[mi*2 +: 2]),
                .m_axi_rlast   (m_axi_rlast_flat[mi]),
                .m_axi_rvalid  (m_axi_rvalid_flat[mi]),
                .m_axi_rcheck  (m_axi_rcheck_flat[mi*CRC_WIDTH +: CRC_WIDTH]),
                .m_axi_rready  (m_axi_rready_flat[mi]),
                .internal_safety_fault(read_engine_safety_fault[mi])
            );
        end
    endgenerate

endmodule
