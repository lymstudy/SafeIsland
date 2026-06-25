`timescale 1ns/1ps

module tb_safety_island_fault_injection;

localparam NUM_MASTERS     = 5;
localparam NUM_ENTRIES     = 64;
localparam ADDR_W          = 32;
localparam DATA_W          = 64;
localparam ID_W            = 4;
localparam MAX_OUTSTANDING = 4;
localparam CRC_WIDTH = 16;

localparam [31:0] ADDR_CONTROL       = 32'h0000_0000;
localparam [31:0] ADDR_READ_INTERVAL = 32'h0000_0008;
localparam [31:0] ADDR_BASE_REGION   = 32'h0000_0100;
localparam [31:0] ADDR_ENTRY_REGION  = 32'h0000_1000;
localparam [31:0] ENTRY_OFFSET_OFF   = 32'h0000_0000;
localparam [31:0] ENTRY_MASK_OFF     = 32'h0000_0008;
localparam [31:0] ENTRY_BURST_OFF    = 32'h0000_0010;
localparam [31:0] ENTRY_EXPECTED_OFF = 32'h0000_0018;

reg clk;
reg rst;

reg  [ID_W-1:0]       s_axi_awid;
reg  [ADDR_W-1:0]     s_axi_awaddr;
reg  [7:0]            s_axi_awlen;
reg  [2:0]            s_axi_awsize;
reg  [1:0]            s_axi_awburst;
reg                   s_axi_awlock;
reg  [3:0]            s_axi_awcache;
reg  [2:0]            s_axi_awprot;
reg  [3:0]            s_axi_awqos;
reg                   s_axi_awvalid;
wire                  s_axi_awready;
reg  [DATA_W-1:0]     s_axi_wdata;
reg  [(DATA_W/8)-1:0] s_axi_wstrb;
reg                   s_axi_wlast;
reg                   s_axi_wvalid;
wire                  s_axi_wready;
wire [ID_W-1:0]       s_axi_bid;
wire [1:0]            s_axi_bresp;
wire                  s_axi_bvalid;
reg                   s_axi_bready;
reg  [ID_W-1:0]       s_axi_arid;
reg  [ADDR_W-1:0]     s_axi_araddr;
reg  [7:0]            s_axi_arlen;
reg  [2:0]            s_axi_arsize;
reg  [1:0]            s_axi_arburst;
reg                   s_axi_arlock;
reg  [3:0]            s_axi_arcache;
reg  [2:0]            s_axi_arprot;
reg  [3:0]            s_axi_arqos;
reg                   s_axi_arvalid;
wire                  s_axi_arready;
wire [ID_W-1:0]       s_axi_rid;
wire [DATA_W-1:0]     s_axi_rdata;
wire [1:0]            s_axi_rresp;
wire                  s_axi_rlast;
wire                  s_axi_rvalid;
reg                   s_axi_rready;

wire [NUM_MASTERS*ID_W-1:0]       m_axi_awid_flat;
wire [NUM_MASTERS*ADDR_W-1:0]     m_axi_awaddr_flat;
wire [NUM_MASTERS*8-1:0]          m_axi_awlen_flat;
wire [NUM_MASTERS*3-1:0]          m_axi_awsize_flat;
wire [NUM_MASTERS*2-1:0]          m_axi_awburst_flat;
wire [NUM_MASTERS-1:0]            m_axi_awlock_flat;
wire [NUM_MASTERS*4-1:0]          m_axi_awcache_flat;
wire [NUM_MASTERS*3-1:0]          m_axi_awprot_flat;
wire [NUM_MASTERS*4-1:0]          m_axi_awqos_flat;
wire [NUM_MASTERS-1:0]            m_axi_awvalid_flat;
reg  [NUM_MASTERS-1:0]            m_axi_awready_flat;
wire [NUM_MASTERS*DATA_W-1:0]     m_axi_wdata_flat;
wire [NUM_MASTERS*(DATA_W/8)-1:0] m_axi_wstrb_flat;
wire [NUM_MASTERS-1:0]            m_axi_wlast_flat;
wire [NUM_MASTERS-1:0]            m_axi_wvalid_flat;
reg  [NUM_MASTERS-1:0]            m_axi_wready_flat;
reg  [NUM_MASTERS*ID_W-1:0]       m_axi_bid_flat;
reg  [NUM_MASTERS*2-1:0]          m_axi_bresp_flat;
reg  [NUM_MASTERS-1:0]            m_axi_bvalid_flat;
wire [NUM_MASTERS-1:0]            m_axi_bready_flat;
wire [NUM_MASTERS*ID_W-1:0]       m_axi_arid_flat;
wire [NUM_MASTERS*ADDR_W-1:0]     m_axi_araddr_flat;
wire [NUM_MASTERS*8-1:0]          m_axi_arlen_flat;
wire [NUM_MASTERS*3-1:0]          m_axi_arsize_flat;
wire [NUM_MASTERS*2-1:0]          m_axi_arburst_flat;
wire [NUM_MASTERS-1:0]            m_axi_arlock_flat;
wire [NUM_MASTERS*4-1:0]          m_axi_arcache_flat;
wire [NUM_MASTERS*3-1:0]          m_axi_arprot_flat;
wire [NUM_MASTERS*4-1:0]          m_axi_arqos_flat;
wire [NUM_MASTERS-1:0]            m_axi_arvalid_flat;
reg  [NUM_MASTERS-1:0]            m_axi_arready_flat;
reg  [NUM_MASTERS*ID_W-1:0]       m_axi_rid_flat;
reg  [NUM_MASTERS*DATA_W-1:0]     m_axi_rdata_flat;
reg  [NUM_MASTERS*2-1:0]          m_axi_rresp_flat;
reg  [NUM_MASTERS-1:0]            m_axi_rlast_flat;
reg  [NUM_MASTERS-1:0]            m_axi_rvalid_flat;
reg  [NUM_MASTERS*CRC_WIDTH-1:0] m_axi_rcheck_flat;
wire [NUM_MASTERS-1:0]            m_axi_rready_flat;

wire                  fault_detect;
wire                  safety_island_fault_detect;
wire                  safety_island_latent_fault_detect;
wire [DATA_W-1:0]     fault_or_result;
wire [7:0]            core_error_code;

integer total_cases;
integer corrected_cases;
integer detected_cases;
integer undetected_cases;
integer cycle_count;
integer summary_fd;
integer protection_rate_pct;
integer resp_error_enable;
integer rid_mismatch_enable;
integer rcheck_error_enable;
reg [1023:0] summary_file;

safety_island_top #(
    .NUM_MASTERS(NUM_MASTERS),
    .NUM_ENTRIES(NUM_ENTRIES),
    .ADDR_W(ADDR_W),
    .DATA_W(DATA_W),
    .ID_W(ID_W),
    .MAX_OUTSTANDING(MAX_OUTSTANDING),
    .CRC_WIDTH(CRC_WIDTH)
) dut (
    .clk(clk),
    .rst(rst),
    .s_axi_awid(s_axi_awid),
    .s_axi_awaddr(s_axi_awaddr),
    .s_axi_awlen(s_axi_awlen),
    .s_axi_awsize(s_axi_awsize),
    .s_axi_awburst(s_axi_awburst),
    .s_axi_awlock(s_axi_awlock),
    .s_axi_awcache(s_axi_awcache),
    .s_axi_awprot(s_axi_awprot),
    .s_axi_awqos(s_axi_awqos),
    .s_axi_awvalid(s_axi_awvalid),
    .s_axi_awready(s_axi_awready),
    .s_axi_wdata(s_axi_wdata),
    .s_axi_wstrb(s_axi_wstrb),
    .s_axi_wlast(s_axi_wlast),
    .s_axi_wvalid(s_axi_wvalid),
    .s_axi_wready(s_axi_wready),
    .s_axi_bid(s_axi_bid),
    .s_axi_bresp(s_axi_bresp),
    .s_axi_bvalid(s_axi_bvalid),
    .s_axi_bready(s_axi_bready),
    .s_axi_arid(s_axi_arid),
    .s_axi_araddr(s_axi_araddr),
    .s_axi_arlen(s_axi_arlen),
    .s_axi_arsize(s_axi_arsize),
    .s_axi_arburst(s_axi_arburst),
    .s_axi_arlock(s_axi_arlock),
    .s_axi_arcache(s_axi_arcache),
    .s_axi_arprot(s_axi_arprot),
    .s_axi_arqos(s_axi_arqos),
    .s_axi_arvalid(s_axi_arvalid),
    .s_axi_arready(s_axi_arready),
    .s_axi_rid(s_axi_rid),
    .s_axi_rdata(s_axi_rdata),
    .s_axi_rresp(s_axi_rresp),
    .s_axi_rlast(s_axi_rlast),
    .s_axi_rvalid(s_axi_rvalid),
    .s_axi_rready(s_axi_rready),
    .m_axi_awid_flat(m_axi_awid_flat),
    .m_axi_awaddr_flat(m_axi_awaddr_flat),
    .m_axi_awlen_flat(m_axi_awlen_flat),
    .m_axi_awsize_flat(m_axi_awsize_flat),
    .m_axi_awburst_flat(m_axi_awburst_flat),
    .m_axi_awlock_flat(m_axi_awlock_flat),
    .m_axi_awcache_flat(m_axi_awcache_flat),
    .m_axi_awprot_flat(m_axi_awprot_flat),
    .m_axi_awqos_flat(m_axi_awqos_flat),
    .m_axi_awvalid_flat(m_axi_awvalid_flat),
    .m_axi_awready_flat(m_axi_awready_flat),
    .m_axi_wdata_flat(m_axi_wdata_flat),
    .m_axi_wstrb_flat(m_axi_wstrb_flat),
    .m_axi_wlast_flat(m_axi_wlast_flat),
    .m_axi_wvalid_flat(m_axi_wvalid_flat),
    .m_axi_wready_flat(m_axi_wready_flat),
    .m_axi_bid_flat(m_axi_bid_flat),
    .m_axi_bresp_flat(m_axi_bresp_flat),
    .m_axi_bvalid_flat(m_axi_bvalid_flat),
    .m_axi_bready_flat(m_axi_bready_flat),
    .m_axi_arid_flat(m_axi_arid_flat),
    .m_axi_araddr_flat(m_axi_araddr_flat),
    .m_axi_arlen_flat(m_axi_arlen_flat),
    .m_axi_arsize_flat(m_axi_arsize_flat),
    .m_axi_arburst_flat(m_axi_arburst_flat),
    .m_axi_arlock_flat(m_axi_arlock_flat),
    .m_axi_arcache_flat(m_axi_arcache_flat),
    .m_axi_arprot_flat(m_axi_arprot_flat),
    .m_axi_arqos_flat(m_axi_arqos_flat),
    .m_axi_arvalid_flat(m_axi_arvalid_flat),
    .m_axi_arready_flat(m_axi_arready_flat),
    .m_axi_rid_flat(m_axi_rid_flat),
    .m_axi_rdata_flat(m_axi_rdata_flat),
    .m_axi_rresp_flat(m_axi_rresp_flat),
    .m_axi_rlast_flat(m_axi_rlast_flat),
    .m_axi_rvalid_flat(m_axi_rvalid_flat),
    .m_axi_rcheck_flat(m_axi_rcheck_flat),
    .m_axi_rready_flat(m_axi_rready_flat),
    .fault_detect(fault_detect),
    .safety_island_fault_detect(safety_island_fault_detect),
    .safety_island_latent_fault_detect(safety_island_latent_fault_detect),
    .fault_or_result(fault_or_result),
    .core_error_code(core_error_code)
);

always #5 clk = ~clk;

function [7:0] crc8_rbeat;
    input [ID_W-1:0] rid;
    input [DATA_W-1:0] rdata;
    input [1:0] rresp;
    input rlast;
    reg [ID_W+DATA_W+2:0] payload;
    reg [7:0] crc;
    reg feedback;
    integer bit_i;
begin
    payload = {rid, rdata, rresp, rlast};
    crc = 8'h00;
    for (bit_i = ID_W + DATA_W + 2; bit_i >= 0; bit_i = bit_i - 1) begin
        feedback = crc[7] ^ payload[bit_i];
        crc = {crc[6:0], 1'b0};
        if (feedback)
            crc = crc ^ 8'h07;
    end
    crc8_rbeat = crc;
end
endfunction

function [15:0] crc16_two_stage;
    input [ID_W-1:0]   ar_id;
    input [ADDR_W-1:0] ar_addr;
    input [7:0]        ar_len;
    input [1:0]        ar_burst;
    input [ID_W-1:0]   r_id;
    input [DATA_W-1:0] r_data;
    input [1:0]        r_resp;
    input              r_last;
    reg [ID_W+ADDR_W+8+3+2-1:0] ar_payload;
    reg [CRC_WIDTH+ID_W+DATA_W+2+1-1:0] r_payload;
    reg [15:0] ar_sig;
    reg [15:0] crc;
    reg feedback;
    integer bit_i;
begin
    // Stage 1: CRC-16 of AR fields (poly 0x1021, init 0xFFFF)
    ar_payload = {ar_id, ar_addr, ar_len, 3'd3, ar_burst};
    crc = 16'hFFFF;
    for (bit_i = ID_W + ADDR_W + 8 + 3 + 2 - 1; bit_i >= 0; bit_i = bit_i - 1) begin
        feedback = crc[15] ^ ar_payload[bit_i];
        crc = {crc[14:0], 1'b0};
        if (feedback) crc = crc ^ 16'h1021;
    end
    ar_sig = crc;
    // Stage 2: CRC-16 of {ar_sig, R fields} (poly 0x1021, init 0xFFFF)
    r_payload = {ar_sig, r_id, r_data, r_resp, r_last};
    crc = 16'hFFFF;
    for (bit_i = CRC_WIDTH + ID_W + DATA_W + 2 + 1 - 1; bit_i >= 0; bit_i = bit_i - 1) begin
        feedback = crc[15] ^ r_payload[bit_i];
        crc = {crc[14:0], 1'b0};
        if (feedback) crc = crc ^ 16'h1021;
    end
    crc16_two_stage = crc;
end
endfunction

task init_signals;
begin
    s_axi_awid = {ID_W{1'b0}};
    s_axi_awaddr = {ADDR_W{1'b0}};
    s_axi_awlen = 8'd0;
    s_axi_awsize = 3'd3;
    s_axi_awburst = 2'b01;
    s_axi_awlock = 1'b0;
    s_axi_awcache = 4'd0;
    s_axi_awprot = 3'd0;
    s_axi_awqos = 4'd0;
    s_axi_awvalid = 1'b0;
    s_axi_wdata = {DATA_W{1'b0}};
    s_axi_wstrb = 8'hFF;
    s_axi_wlast = 1'b1;
    s_axi_wvalid = 1'b0;
    s_axi_bready = 1'b0;
    s_axi_arid = {ID_W{1'b0}};
    s_axi_araddr = {ADDR_W{1'b0}};
    s_axi_arlen = 8'd0;
    s_axi_arsize = 3'd3;
    s_axi_arburst = 2'b01;
    s_axi_arlock = 1'b0;
    s_axi_arcache = 4'd0;
    s_axi_arprot = 3'd0;
    s_axi_arqos = 4'd0;
    s_axi_arvalid = 1'b0;
    s_axi_rready = 1'b0;
    m_axi_awready_flat = {NUM_MASTERS{1'b0}};
    m_axi_wready_flat = {NUM_MASTERS{1'b0}};
    m_axi_bid_flat = {(NUM_MASTERS*ID_W){1'b0}};
    m_axi_bresp_flat = {(NUM_MASTERS*2){1'b0}};
    m_axi_bvalid_flat = {NUM_MASTERS{1'b0}};
    m_axi_arready_flat = {NUM_MASTERS{1'b0}};
    m_axi_rid_flat = {(NUM_MASTERS*ID_W){1'b0}};
    m_axi_rdata_flat = {(NUM_MASTERS*DATA_W){1'b0}};
    m_axi_rresp_flat = {(NUM_MASTERS*2){1'b0}};
    m_axi_rlast_flat = {NUM_MASTERS{1'b0}};
    m_axi_rvalid_flat = {NUM_MASTERS{1'b0}};
    m_axi_rcheck_flat = {(NUM_MASTERS*CRC_WIDTH){1'b0}};
    resp_error_enable = 0;
    rid_mismatch_enable = 0;
    rcheck_error_enable = 0;
end
endtask

task reset_dut;
begin
    init_signals();
    rst = 1'b1;
    repeat (5) @(posedge clk);
    rst = 1'b0;
    repeat (2) @(posedge clk);
end
endtask

task wait_cycles;
    input integer cycles;
    integer i;
begin
    for (i = 0; i < cycles; i = i + 1)
        @(posedge clk);
end
endtask

task axi_cfg_write;
    input [ADDR_W-1:0] addr;
    input [DATA_W-1:0] data;
    integer guard;
begin
    @(posedge clk);
    s_axi_awaddr <= addr;
    s_axi_awvalid <= 1'b1;
    s_axi_wdata <= data;
    s_axi_wstrb <= 8'hFF;
    s_axi_wlast <= 1'b1;
    s_axi_wvalid <= 1'b1;
    s_axi_bready <= 1'b1;
    guard = 0;
    while (!(s_axi_awready && s_axi_wready) && guard < 100) begin
        guard = guard + 1;
        @(posedge clk);
    end
    if (guard >= 100) begin
        $display("FI_ERROR: cfg write handshake timeout addr=%h", addr);
        total_cases = total_cases + 1;
        undetected_cases = undetected_cases + 1;
        $finish;
    end
    @(posedge clk);
    s_axi_awvalid <= 1'b0;
    s_axi_wvalid <= 1'b0;
    guard = 0;
    while (!s_axi_bvalid && guard < 100) begin
        guard = guard + 1;
        @(posedge clk);
    end
    if (guard >= 100) begin
        $display("FI_ERROR: cfg write response timeout addr=%h", addr);
        total_cases = total_cases + 1;
        undetected_cases = undetected_cases + 1;
        $finish;
    end
    @(posedge clk);
    s_axi_bready <= 1'b0;
end
endtask

task config_minimal;
begin
    axi_cfg_write(ADDR_READ_INTERVAL, 64'd8);
    axi_cfg_write(ADDR_BASE_REGION, 64'd0);
    axi_cfg_write(ADDR_ENTRY_REGION + ENTRY_OFFSET_OFF, 64'd0);
    axi_cfg_write(ADDR_ENTRY_REGION + ENTRY_MASK_OFF, 64'hFFFF_FFFF_FFFF_FFFF);
    axi_cfg_write(ADDR_ENTRY_REGION + ENTRY_BURST_OFF, 64'h0000_0000_0001_0001);
    axi_cfg_write(ADDR_ENTRY_REGION + ENTRY_EXPECTED_OFF, 64'd0);
    axi_cfg_write(ADDR_CONTROL, 64'h0000_0000_0000_000B);
    wait_cycles(2);
end
endtask

task simple_read_response;
begin
    if (m_axi_arvalid_flat[0] && !m_axi_arready_flat[0]) begin
        m_axi_arready_flat[0] <= 1'b1;
    end else begin
        m_axi_arready_flat[0] <= 1'b0;
    end

    if (m_axi_arvalid_flat[0] && m_axi_arready_flat[0] && !m_axi_rvalid_flat[0]) begin
        m_axi_rvalid_flat[0] <= 1'b1;
        m_axi_rlast_flat[0] <= 1'b1;
        m_axi_rid_flat[ID_W-1:0] <= rid_mismatch_enable ?
                                     (m_axi_arid_flat[ID_W-1:0] ^ {{(ID_W-1){1'b0}}, 1'b1}) :
                                     m_axi_arid_flat[ID_W-1:0];
        m_axi_rdata_flat[DATA_W-1:0] <= 64'd0;
        m_axi_rresp_flat[1:0] <= resp_error_enable ? 2'b10 : 2'b00;
        if (CRC_WIDTH == 16) begin
            m_axi_rcheck_flat[CRC_WIDTH-1:0] <= crc16_two_stage(
                rid_mismatch_enable ?
                    (m_axi_arid_flat[ID_W-1:0] ^ {{(ID_W-1){1'b0}}, 1'b1}) :
                    m_axi_arid_flat[ID_W-1:0],
                m_axi_araddr_flat[ADDR_W-1:0],
                m_axi_arlen_flat[7:0],
                m_axi_arburst_flat[1:0],
                rid_mismatch_enable ?
                    (m_axi_arid_flat[ID_W-1:0] ^ {{(ID_W-1){1'b0}}, 1'b1}) :
                    m_axi_arid_flat[ID_W-1:0],
                64'd0,
                resp_error_enable ? 2'b10 : 2'b00,
                1'b1
            ) ^ (rcheck_error_enable ? 16'h5A5A : 16'h0000);
        end else begin
            m_axi_rcheck_flat[7:0] <= crc8_rbeat(rid_mismatch_enable ?
                                                 (m_axi_arid_flat[ID_W-1:0] ^ {{(ID_W-1){1'b0}}, 1'b1}) :
                                                 m_axi_arid_flat[ID_W-1:0],
                                                 64'd0,
                                                 resp_error_enable ? 2'b10 : 2'b00,
                                                 1'b1) ^
                                      (rcheck_error_enable ? 8'h5A : 8'h00);
        end
    end else if (m_axi_rvalid_flat[0] && m_axi_rready_flat[0]) begin
        m_axi_rvalid_flat[0] <= 1'b0;
        m_axi_rlast_flat[0] <= 1'b0;
    end
end
endtask

always @(posedge clk) begin
    if (rst) begin
        m_axi_arready_flat <= {NUM_MASTERS{1'b0}};
        m_axi_rvalid_flat <= {NUM_MASTERS{1'b0}};
        m_axi_rlast_flat <= {NUM_MASTERS{1'b0}};
    end else begin
        simple_read_response();
    end
end

task emit_case;
    input [8*64-1:0] name;
    input [8*24-1:0] fault_type;
    input [8*12-1:0] result;
    input integer cycles;
begin
    $display("FI_CASE: name=%0s type=%0s result=%0s cycles=%0d code=%h",
             name, fault_type, result, cycles, core_error_code);
    if (summary_fd != 0)
        $fdisplay(summary_fd, "FI_CASE: name=%0s type=%0s result=%0s cycles=%0d code=%h",
                  name, fault_type, result, cycles, core_error_code);
end
endtask

task report_detected;
    input [8*64-1:0] name;
    input [8*24-1:0] fault_type;
    input integer cycles;
begin
    total_cases = total_cases + 1;
    detected_cases = detected_cases + 1;
    emit_case(name, fault_type, "detected", cycles);
end
endtask

task report_undetected;
    input [8*64-1:0] name;
    input [8*24-1:0] fault_type;
begin
    total_cases = total_cases + 1;
    undetected_cases = undetected_cases + 1;
    emit_case(name, fault_type, "undetected", -1);
    $display("FI_DEBUG: fault=%b safety=%b latent=%b",
             fault_detect, safety_island_fault_detect, safety_island_latent_fault_detect);
end
endtask

task expect_fault_within_10;
    input [8*64-1:0] name;
    input [8*24-1:0] fault_type;
    input expect_fault_detect;
    input expect_safety_detect;
    input expect_latent_detect;
    integer c;
    reg hit;
begin
    c = 0;
    hit = 1'b0;
    while (c <= 10 && !hit) begin
        if (((!expect_fault_detect)  || fault_detect) &&
            ((!expect_safety_detect) || safety_island_fault_detect) &&
            ((!expect_latent_detect) || safety_island_latent_fault_detect)) begin
            hit = 1'b1;
        end else begin
            c = c + 1;
            @(posedge clk);
        end
    end

    if (hit)
        report_detected(name, fault_type, c);
    else
        report_undetected(name, fault_type);
end
endtask

task run_cfg_read_interval_shadow_stuck;
begin
    reset_dut();
    config_minimal();
    force dut.u_cfg.read_interval_inv = 64'h0;
    expect_fault_within_10("read_interval_inv", "config_register", 1'b1, 1'b0, 1'b1);
    release dut.u_cfg.read_interval_inv;
end
endtask

task run_cfg_base_shadow_stuck;
begin
    reset_dut();
    config_minimal();
    force dut.u_cfg.base_addr_inv_q[0] = 32'h0;
    expect_fault_within_10("base_addr_inv_q0", "config_register", 1'b1, 1'b0, 1'b1);
    release dut.u_cfg.base_addr_inv_q[0];
end
endtask

task run_cfg_offset_shadow_stuck;
begin
    reset_dut();
    config_minimal();
    force dut.u_cfg.offset_inv_q[0] = 32'h0;
    expect_fault_within_10("offset_inv_q0", "config_register", 1'b1, 1'b0, 1'b1);
    release dut.u_cfg.offset_inv_q[0];
end
endtask

task run_cfg_mask_shadow_stuck;
begin
    reset_dut();
    config_minimal();
    force dut.u_cfg.mask_inv_q[0] = 64'hFFFF_FFFF_FFFF_FFFF;
    expect_fault_within_10("mask_inv_q0", "config_register", 1'b1, 1'b0, 1'b1);
    release dut.u_cfg.mask_inv_q[0];
end
endtask

task run_cfg_burst_shadow_stuck;
begin
    reset_dut();
    config_minimal();
    force dut.u_cfg.burst_type_inv_q[0] = 2'b00;
    expect_fault_within_10("burst_type_inv_q0", "config_register", 1'b1, 1'b0, 1'b1);
    release dut.u_cfg.burst_type_inv_q[0];
end
endtask

task run_cfg_entry_valid_shadow_stuck;
begin
    reset_dut();
    config_minimal();
    force dut.u_cfg.entry_valid_inv_q[0] = 1'b1;
    expect_fault_within_10("entry_valid_inv_q0", "config_register", 1'b1, 1'b0, 1'b1);
    release dut.u_cfg.entry_valid_inv_q[0];
end
endtask

task run_cfg_expected_shadow_stuck;
begin
    reset_dut();
    config_minimal();
    force dut.u_cfg.expected_inv_q[0] = 64'hFFFF_FFFF_FFFF_FFFF;
    expect_fault_within_10("expected_inv_q0", "config_register", 1'b1, 1'b0, 1'b1);
    release dut.u_cfg.expected_inv_q[0];
end
endtask

task run_core_state_inv_stuck;
begin
    reset_dut();
    config_minimal();
    force dut.u_core.state_inv = 4'h0;
    expect_fault_within_10("state_inv", "core_register", 1'b0, 1'b1, 1'b1);
    release dut.u_core.state_inv;
end
endtask

task run_core_accum_inv_stuck;
begin
    reset_dut();
    config_minimal();
    force dut.u_core.fault_or_accum_inv = 64'h0;
    expect_fault_within_10("fault_or_accum_inv", "core_register", 1'b0, 1'b1, 1'b1);
    release dut.u_core.fault_or_accum_inv;
end
endtask

task run_pending_wr_ptr_stuck;
begin
    reset_dut();
    config_minimal();
    force dut.u_core.pending_wr_ptr = 32'hFFFF_FFFF;
    expect_fault_within_10("pending_wr_ptr", "core_register", 1'b0, 1'b1, 1'b1);
    release dut.u_core.pending_wr_ptr;
end
endtask

task run_pending_rd_ptr_stuck;
begin
    reset_dut();
    config_minimal();
    force dut.u_core.pending_rd_ptr = 32'hFFFF_FFFF;
    expect_fault_within_10("pending_rd_ptr", "core_register", 1'b0, 1'b1, 1'b1);
    release dut.u_core.pending_rd_ptr;
end
endtask

task run_outstanding_count_stuck;
begin
    reset_dut();
    config_minimal();
    force dut.u_core.outstanding_count = 32'hFFFF_FFFF;
    expect_fault_within_10("outstanding_count", "core_register", 1'b0, 1'b1, 1'b1);
    release dut.u_core.outstanding_count;
end
endtask

task run_transient_state_inv_flip;
begin
    reset_dut();
    config_minimal();
    force dut.u_core.state_inv = 4'h0;
    @(posedge clk);
    @(negedge clk);
    release dut.u_core.state_inv;
    expect_fault_within_10("transient_state_inv", "transient", 1'b0, 1'b1, 1'b1);
end
endtask

task run_transient_accum_inv_flip;
begin
    reset_dut();
    config_minimal();
    force dut.u_core.fault_or_accum_inv = 64'h0;
    @(posedge clk);
    @(negedge clk);
    release dut.u_core.fault_or_accum_inv;
    expect_fault_within_10("transient_fault_or_accum_inv", "transient", 1'b0, 1'b1, 1'b1);
end
endtask

task run_transient_cfg_shadow_flip;
begin
    reset_dut();
    config_minimal();
    force dut.u_cfg.mask_inv_q[0] = 64'hFFFF_FFFF_FFFF_FFFF;
    @(posedge clk);
    @(negedge clk);
    release dut.u_cfg.mask_inv_q[0];
    expect_fault_within_10("transient_config_shadow", "transient", 1'b1, 1'b0, 1'b0);
end
endtask

task run_axi_rresp_error_fault;
begin
    reset_dut();
    resp_error_enable = 1;
    config_minimal();
    expect_fault_within_10("axi_rresp_error", "port_interface", 1'b1, 1'b0, 1'b0);
    resp_error_enable = 0;
end
endtask

task run_axi_rid_mismatch_fault;
begin
    reset_dut();
    rid_mismatch_enable = 1;
    config_minimal();
    expect_fault_within_10("axi_rid_mismatch", "port_interface", 1'b1, 1'b0, 1'b0);
    rid_mismatch_enable = 0;
end
endtask

task run_axi_rcheck_error_fault;
begin
    reset_dut();
    rcheck_error_enable = 1;
    config_minimal();
    expect_fault_within_10("axi_rcheck_error", "port_interface", 1'b1, 1'b0, 1'b0);
    rcheck_error_enable = 0;
end
endtask

task run_axi_timeout_fault;
begin
    reset_dut();
    config_minimal();
    force m_axi_arready_flat[0] = 1'b0;
    force m_axi_rvalid_flat[0] = 1'b0;
    wait_cycles(1200);
    if (fault_detect && (core_error_code == 8'h21)) begin
        total_cases = total_cases + 1;
        detected_cases = detected_cases + 1;
        emit_case("axi_read_timeout", "port_interface", "detected", 1200);
    end else begin
        report_undetected("axi_read_timeout", "port_interface");
    end
    release m_axi_arready_flat[0];
    release m_axi_rvalid_flat[0];
end
endtask

initial begin
    $dumpfile("sim_output/safety_island_fault_injection.vcd");
    $dumpvars(0, tb_safety_island_fault_injection);
    $display("[%0t] VCD dump start", $time);
end

initial begin
    clk = 1'b0;
    rst = 1'b1;
    total_cases = 0;
    corrected_cases = 0;
    detected_cases = 0;
    undetected_cases = 0;
    if (!$value$plusargs("SUMMARY_FILE=%s", summary_file))
        summary_file = "fault_injection_summary.txt";
    summary_fd = $fopen(summary_file, "w");
    if (summary_fd == 0)
        $display("FI_WARN: failed to open summary file %0s", summary_file);

    run_cfg_read_interval_shadow_stuck();
    run_cfg_base_shadow_stuck();
    run_cfg_offset_shadow_stuck();
    run_cfg_mask_shadow_stuck();
    run_cfg_burst_shadow_stuck();
    run_cfg_entry_valid_shadow_stuck();
    run_cfg_expected_shadow_stuck();
    run_core_state_inv_stuck();
    run_core_accum_inv_stuck();
    run_pending_wr_ptr_stuck();
    run_pending_rd_ptr_stuck();
    run_outstanding_count_stuck();
    run_axi_timeout_fault();
    run_axi_rresp_error_fault();
    run_axi_rid_mismatch_fault();
    run_axi_rcheck_error_fault();
    run_transient_state_inv_flip();
    run_transient_accum_inv_flip();
    run_transient_cfg_shadow_flip();

    if (total_cases > 0)
        protection_rate_pct = ((corrected_cases + detected_cases) * 100) / total_cases;
    else
        protection_rate_pct = 0;

    $display("FI_SUMMARY: total=%0d corrected=%0d detected=%0d undetected=%0d protection_rate=%0d%%",
             total_cases, corrected_cases, detected_cases, undetected_cases,
             protection_rate_pct);

    if (summary_fd != 0) begin
        $fdisplay(summary_fd, "FI_SUMMARY: total=%0d corrected=%0d detected=%0d undetected=%0d protection_rate=%0d%%",
                  total_cases, corrected_cases, detected_cases, undetected_cases,
                  protection_rate_pct);
        $fclose(summary_fd);
    end

    if (undetected_cases == 0)
        $display("PASS: safety_island fault injection campaign completed");
    else
        $display("FAIL: safety_island fault injection campaign undetected=%0d", undetected_cases);



    $finish;
end

endmodule
