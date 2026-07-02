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
localparam [31:0] ADDR_KAT_CTRL      = 32'h0000_0038;
localparam [31:0] ADDR_KAT_ADDR      = 32'h0000_0040;
localparam [31:0] ADDR_KAT_EXPECTED  = 32'h0000_0048;
localparam [31:0] ADDR_KAT_MASK      = 32'h0000_0050;
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
integer csv_fd;
integer protection_rate_pct;
integer resp_error_enable;
integer rid_mismatch_enable;
integer rcheck_error_enable;
integer selected_fault_index;
integer selected_bit_index;
integer run_one_fault;
integer run_bit_fault;
reg [1023:0] summary_file;
reg [1023:0] csv_file;
reg [8*64-1:0] selected_fault_kind;
reg [63:0] fault_corrupt64;
reg [31:0] fault_corrupt32;
reg [7:0]  fault_corrupt8;
reg [3:0]  fault_corrupt4;

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

task config_minimal_unlocked;
begin
    axi_cfg_write(ADDR_READ_INTERVAL, 64'd8);
    axi_cfg_write(ADDR_BASE_REGION, 64'd0);
    axi_cfg_write(ADDR_ENTRY_REGION + ENTRY_OFFSET_OFF, 64'd0);
    axi_cfg_write(ADDR_ENTRY_REGION + ENTRY_MASK_OFF, 64'hFFFF_FFFF_FFFF_FFFF);
    axi_cfg_write(ADDR_ENTRY_REGION + ENTRY_BURST_OFF, 64'h0000_0000_0001_0001);
    axi_cfg_write(ADDR_ENTRY_REGION + ENTRY_EXPECTED_OFF, 64'd0);
end
endtask

task lock_enable_scan;
begin
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
    if (summary_fd != 0) begin
        $fdisplay(summary_fd, "FI_CASE: name=%0s type=%0s result=%0s cycles=%0d code=%h",
                  name, fault_type, result, cycles, core_error_code);
    end
    if (csv_fd != 0) begin
        $fdisplay(csv_fd, "%0s,%0s,%0s,%0d,%0h,%0b,%0b,%0b",
                  name, fault_type, result, cycles, core_error_code,
                  fault_detect, safety_island_fault_detect,
                  safety_island_latent_fault_detect);
    end
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

task report_corrected;
    input [8*64-1:0] name;
    input [8*24-1:0] fault_type;
    input integer cycles;
begin
    total_cases = total_cases + 1;
    corrected_cases = corrected_cases + 1;
    emit_case(name, fault_type, "corrected", cycles);
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
    integer max_cyc;
    reg hit;
begin
    c = 0;
    hit = 1'b0;
    max_cyc = ((fault_type == "port_interface") ||
               (fault_type == "safety_self_test")) ? 200 : 10;
    while (c <= max_cyc && !hit) begin
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
    force dut.u_cfg.expected_inv_q[0] = 64'h0000_0000_0000_0000;
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

task run_kat_mismatch_fault;
begin
    reset_dut();
    resp_error_enable = 0;
    // Enable KAT with wrong expected value
    config_minimal_unlocked();
    axi_cfg_write(ADDR_KAT_ADDR, 64'd0);
    axi_cfg_write(ADDR_KAT_EXPECTED, 64'hDEAD_BEEF_DEAD_BEEF);
    axi_cfg_write(ADDR_KAT_MASK, 64'hFFFF_FFFF_FFFF_FFFF);
    axi_cfg_write(ADDR_KAT_CTRL, 64'h1);
    lock_enable_scan();
    expect_fault_within_10("kat_mismatch", "safety_self_test", 1'b0, 1'b1, 1'b0);
end
endtask

task run_tmr_double_fault;
begin
    reset_dut();
    config_minimal();
    force dut.u_core.state_b = 4'hF;
    force dut.u_core.state_c = 4'hE;
    expect_fault_within_10("tmr_double_fault", "core_register", 1'b0, 1'b1, 1'b0);
    release dut.u_core.state_b;
    release dut.u_core.state_c;
end
endtask

task run_e2e_crc16_mismatch;
begin
    reset_dut();
    rcheck_error_enable = 1;
    config_minimal();
    expect_fault_within_10("e2e_crc16_mismatch", "port_interface", 1'b1, 1'b0, 1'b0);
    rcheck_error_enable = 0;
end
endtask

task run_axi_timeout_fault;
begin
    reset_dut();
    config_minimal();
    force m_axi_rvalid_flat[0] = 1'b0;
    wait_cycles(1200);
    if (fault_detect && (core_error_code == 8'h21)) begin
        total_cases = total_cases + 1;
        detected_cases = detected_cases + 1;
        emit_case("axi_read_timeout", "port_interface", "detected", 1200);
    end else begin
        report_undetected("axi_read_timeout", "port_interface");
    end
    release m_axi_rvalid_flat[0];
end
endtask

task report_invalid_bit_index;
    input [8*64-1:0] name;
    input integer bit_index;
begin
    total_cases = total_cases + 1;
    undetected_cases = undetected_cases + 1;
    emit_case(name, "invalid_bit", "undetected", bit_index);
    $display("FI_ERROR: invalid BIT_INDEX=%0d for %0s", bit_index, name);
end
endtask

task run_cfg_read_interval_inv_bit;
    input integer bit_index;
begin
    reset_dut();
    config_minimal();
    if ((bit_index < 0) || (bit_index >= 64)) begin
        report_invalid_bit_index("cfg_read_interval_inv", bit_index);
    end else begin
        fault_corrupt64 = ~dut.u_cfg.read_interval;
        fault_corrupt64[bit_index] = dut.u_cfg.read_interval[bit_index];
        force dut.u_cfg.read_interval_inv = fault_corrupt64;
        expect_fault_within_10("cfg_read_interval_inv", "config_bit", 1'b1, 1'b0, 1'b1);
        release dut.u_cfg.read_interval_inv;
    end
end
endtask

`ifdef FI_ARRAY_BIT_TARGETS
task run_cfg_base_addr_inv_q0_bit;
    input integer bit_index;
begin
    reset_dut();
    config_minimal();
    if ((bit_index < 0) || (bit_index >= ADDR_W)) begin
        report_invalid_bit_index("cfg_base_addr_inv_q0", bit_index);
    end else begin
        fault_corrupt32 = ~dut.u_cfg.base_addr_q[0];
        fault_corrupt32[bit_index] = dut.u_cfg.base_addr_q[0][bit_index];
        force dut.u_cfg.base_addr_inv_q[0] = fault_corrupt32;
        expect_fault_within_10("cfg_base_addr_inv_q0", "config_bit", 1'b1, 1'b0, 1'b1);
        release dut.u_cfg.base_addr_inv_q[0];
    end
end
endtask

task run_cfg_offset_inv_q0_bit;
    input integer bit_index;
begin
    reset_dut();
    config_minimal();
    if ((bit_index < 0) || (bit_index >= ADDR_W)) begin
        report_invalid_bit_index("cfg_offset_inv_q0", bit_index);
    end else begin
        fault_corrupt32 = ~dut.u_cfg.offset_q[0];
        fault_corrupt32[bit_index] = dut.u_cfg.offset_q[0][bit_index];
        force dut.u_cfg.offset_inv_q[0] = fault_corrupt32;
        expect_fault_within_10("cfg_offset_inv_q0", "config_bit", 1'b1, 1'b0, 1'b1);
        release dut.u_cfg.offset_inv_q[0];
    end
end
endtask

task run_cfg_mask_inv_q0_bit;
    input integer bit_index;
begin
    reset_dut();
    config_minimal();
    if ((bit_index < 0) || (bit_index >= DATA_W)) begin
        report_invalid_bit_index("cfg_mask_inv_q0", bit_index);
    end else begin
        fault_corrupt64 = ~dut.u_cfg.mask_q[0];
        fault_corrupt64[bit_index] = dut.u_cfg.mask_q[0][bit_index];
        force dut.u_cfg.mask_inv_q[0] = fault_corrupt64;
        expect_fault_within_10("cfg_mask_inv_q0", "config_bit", 1'b1, 1'b0, 1'b1);
        release dut.u_cfg.mask_inv_q[0];
    end
end
endtask

task run_cfg_expected_inv_q0_bit;
    input integer bit_index;
begin
    reset_dut();
    config_minimal();
    if ((bit_index < 0) || (bit_index >= DATA_W)) begin
        report_invalid_bit_index("cfg_expected_inv_q0", bit_index);
    end else begin
        fault_corrupt64 = ~dut.u_cfg.expected_q[0];
        fault_corrupt64[bit_index] = dut.u_cfg.expected_q[0][bit_index];
        force dut.u_cfg.expected_inv_q[0] = fault_corrupt64;
        expect_fault_within_10("cfg_expected_inv_q0", "config_bit", 1'b1, 1'b0, 1'b1);
        release dut.u_cfg.expected_inv_q[0];
    end
end
endtask
`endif

task run_core_state_inv_bit;
    input integer bit_index;
begin
    reset_dut();
    config_minimal();
    if ((bit_index < 0) || (bit_index >= 4)) begin
        report_invalid_bit_index("core_state_inv", bit_index);
    end else begin
        fault_corrupt4 = ~dut.u_core.state;
        fault_corrupt4[bit_index] = dut.u_core.state[bit_index];
        force dut.u_core.state_inv = fault_corrupt4;
        expect_fault_within_10("core_state_inv", "core_bit", 1'b0, 1'b1, 1'b1);
        release dut.u_core.state_inv;
    end
end
endtask

task run_core_fault_or_accum_inv_bit;
    input integer bit_index;
begin
    reset_dut();
    config_minimal();
    if ((bit_index < 0) || (bit_index >= DATA_W)) begin
        report_invalid_bit_index("core_fault_or_accum_inv", bit_index);
    end else begin
        fault_corrupt64 = ~dut.u_core.fault_or_accum;
        fault_corrupt64[bit_index] = dut.u_core.fault_or_accum[bit_index];
        force dut.u_core.fault_or_accum_inv = fault_corrupt64;
        expect_fault_within_10("core_fault_or_accum_inv", "core_bit", 1'b0, 1'b1, 1'b1);
        release dut.u_core.fault_or_accum_inv;
    end
end
endtask

task run_fd_fault_status_inv_bit;
    input integer bit_index;
begin
    reset_dut();
    config_minimal();
    if ((bit_index < 0) || (bit_index >= 64)) begin
        report_invalid_bit_index("fd_fault_status_inv", bit_index);
    end else begin
        fault_corrupt64 = ~dut.u_fault_detector.fault_status;
        fault_corrupt64[bit_index] = dut.u_fault_detector.fault_status[bit_index];
        force dut.u_fault_detector.fault_status_inv = fault_corrupt64;
        expect_fault_within_10("fd_fault_status_inv", "fault_detector_bit", 1'b0, 1'b1, 1'b0);
        release dut.u_fault_detector.fault_status_inv;
    end
end
endtask

task run_fd_error_code_inv_bit;
    input integer bit_index;
begin
    reset_dut();
    config_minimal();
    if ((bit_index < 0) || (bit_index >= 8)) begin
        report_invalid_bit_index("fd_error_code_inv", bit_index);
    end else begin
        fault_corrupt8 = ~dut.u_fault_detector.error_code;
        fault_corrupt8[bit_index] = dut.u_fault_detector.error_code[bit_index];
        force dut.u_fault_detector.error_code_inv = fault_corrupt8;
        expect_fault_within_10("fd_error_code_inv", "fault_detector_bit", 1'b0, 1'b1, 1'b0);
        release dut.u_fault_detector.error_code_inv;
    end
end
endtask

task run_heartbeat_counter_inv_bit;
    input integer bit_index;
begin
    reset_dut();
    config_minimal();
    if ((bit_index < 0) || (bit_index >= 32)) begin
        report_invalid_bit_index("heartbeat_counter_inv", bit_index);
    end else begin
        fault_corrupt32 = ~dut.u_heartbeat.counter;
        fault_corrupt32[bit_index] = dut.u_heartbeat.counter[bit_index];
        force dut.u_heartbeat.counter_inv = fault_corrupt32;
        expect_fault_within_10("heartbeat_counter_inv", "heartbeat_bit", 1'b0, 1'b1, 1'b0);
        release dut.u_heartbeat.counter_inv;
    end
end
endtask

`ifdef FI_ARRAY_BIT_TARGETS
task run_top_rsp_data_inv_q0_bit;
    input integer bit_index;
begin
    reset_dut();
    config_minimal();
    if ((bit_index < 0) || (bit_index >= DATA_W)) begin
        report_invalid_bit_index("top_rsp_data_inv_q0", bit_index);
    end else begin
        fault_corrupt64 = ~dut.gen_read_master[0].rsp_data_q[0];
        fault_corrupt64[bit_index] = dut.gen_read_master[0].rsp_data_q[0][bit_index];
        force dut.gen_read_master[0].rsp_data_inv_q[0] = fault_corrupt64;
        expect_fault_within_10("top_rsp_data_inv_q0", "top_rsp_bit", 1'b0, 1'b1, 1'b1);
        release dut.gen_read_master[0].rsp_data_inv_q[0];
    end
end
endtask

task run_read_engine_slot_accum_inv_q0_bit;
    input integer bit_index;
begin
    reset_dut();
    config_minimal();
    if ((bit_index < 0) || (bit_index >= DATA_W)) begin
        report_invalid_bit_index("read_engine_slot_accum_inv_q0", bit_index);
    end else begin
        fault_corrupt64 = ~dut.gen_read_master[0].u_read_engine.slot_accum_q[0];
        fault_corrupt64[bit_index] = dut.gen_read_master[0].u_read_engine.slot_accum_q[0][bit_index];
        force dut.gen_read_master[0].u_read_engine.slot_accum_inv_q[0] = fault_corrupt64;
        expect_fault_within_10("read_engine_slot_accum_inv_q0", "read_engine_bit", 1'b0, 1'b1, 1'b1);
        release dut.gen_read_master[0].u_read_engine.slot_accum_inv_q[0];
    end
end
endtask
`endif

task run_bit_fault_by_kind;
    input [8*64-1:0] fault_kind;
    input integer bit_index;
begin
    if (fault_kind == "cfg_read_interval_inv")
        run_cfg_read_interval_inv_bit(bit_index);
`ifdef FI_ARRAY_BIT_TARGETS
    else if (fault_kind == "cfg_base_addr_inv_q0")
        run_cfg_base_addr_inv_q0_bit(bit_index);
    else if (fault_kind == "cfg_offset_inv_q0")
        run_cfg_offset_inv_q0_bit(bit_index);
    else if (fault_kind == "cfg_mask_inv_q0")
        run_cfg_mask_inv_q0_bit(bit_index);
    else if (fault_kind == "cfg_expected_inv_q0")
        run_cfg_expected_inv_q0_bit(bit_index);
`endif
    else if (fault_kind == "core_state_inv")
        run_core_state_inv_bit(bit_index);
    else if (fault_kind == "core_fault_or_accum_inv")
        run_core_fault_or_accum_inv_bit(bit_index);
    else if (fault_kind == "fd_fault_status_inv")
        run_fd_fault_status_inv_bit(bit_index);
    else if (fault_kind == "fd_error_code_inv")
        run_fd_error_code_inv_bit(bit_index);
    else if (fault_kind == "heartbeat_counter_inv")
        run_heartbeat_counter_inv_bit(bit_index);
    else if (fault_kind == "cfg_shadow_error_comb")
        run_dig_cfg_shadow_comp_direct();
    else if (fault_kind == "fd_event_shadow_fault")
        run_dig_event_shadow_direct();
    else if (fault_kind == "core_accum_shadow_fault")
        run_dig_accum_shadow_direct();
    else if (fault_kind == "re_crc_mismatch")
        run_dig_crc_mismatch_direct();
    else if (fault_kind == "core_cfg_burst_type")
        run_dig_cfg_burst_type_direct();
    else if (fault_kind == "core_cfg_burst_len")
        run_dig_cfg_burst_len_direct();
    else if (fault_kind == "core_scan_start")
        run_dig_scan_start_stuck();
    else if (fault_kind == "core_cfg_interval")
        run_dig_cfg_interval_direct();
    else if (fault_kind == "core_cfg_fault_comb")
        run_dig_cfg_fault_tmr();
    else if (fault_kind == "core_safety_fault_comb")
        run_dig_safety_fault_tmr();
`ifdef FI_ARRAY_BIT_TARGETS
    else if (fault_kind == "top_rsp_data_inv_q0")
        run_top_rsp_data_inv_q0_bit(bit_index);
    else if (fault_kind == "read_engine_slot_accum_inv_q0")
        run_read_engine_slot_accum_inv_q0_bit(bit_index);
`else
    else if ((fault_kind == "cfg_base_addr_inv_q0") ||
             (fault_kind == "cfg_offset_inv_q0") ||
             (fault_kind == "cfg_mask_inv_q0") ||
             (fault_kind == "cfg_expected_inv_q0") ||
             (fault_kind == "top_rsp_data_inv_q0") ||
             (fault_kind == "read_engine_slot_accum_inv_q0")) begin
        total_cases = total_cases + 1;
        undetected_cases = undetected_cases + 1;
        emit_case(fault_kind, "array_kind_disabled", "undetected", bit_index);
        $display("FI_ERROR: FAULT_KIND=%0s requires +define+FI_ARRAY_BIT_TARGETS", fault_kind);
    end
`endif
    else begin
        total_cases = total_cases + 1;
        undetected_cases = undetected_cases + 1;
        emit_case(fault_kind, "unsupported_kind", "undetected", bit_index);
        $display("FI_ERROR: unsupported FAULT_KIND=%0s", fault_kind);
    end
end
endtask

// ─── BATCH: sweep all bit-level faults in one simulation ───
// Phase 1: baseline 22 cases
// Phase 2: full bit sweep on scalar / representative registers (proves detection per bit)
// Phase 3: array entry sweep — bit 0 of every entry (proves all shadow registers connected)

task run_batch_all;
    integer bi, ei, mi, si;
    integer num_entries_all;   // NUM_MASTERS * NUM_ENTRIES = 320
begin
    $display("FI_BATCH: starting full bit-level fault sweep");
    num_entries_all = NUM_MASTERS * NUM_ENTRIES;

    // ══════════════════════════════════════════════════════════════
    // Phase 1: baseline representative cases (22)
    // ══════════════════════════════════════════════════════════════
    $display("FI_BATCH_PHASE1: 22 baseline cases");
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
    run_kat_mismatch_fault();
    run_tmr_double_fault();
    run_e2e_crc16_mismatch();

    // ══════════════════════════════════════════════════════════════
    // Phase 2: full bit sweep on scalar/representative registers
    // ══════════════════════════════════════════════════════════════
    $display("FI_BATCH_PHASE2: full bit sweep on representative registers");

    $display("FI_BATCH: cfg_read_interval_inv 64 bits");
    for (bi = 0; bi < 64; bi = bi + 1) run_cfg_read_interval_inv_bit(bi);

    `ifdef FI_ARRAY_BIT_TARGETS
    $display("FI_BATCH: cfg_base_addr_inv_q0 32 bits");
    for (bi = 0; bi < ADDR_W; bi = bi + 1) run_cfg_base_addr_inv_q0_bit(bi);
    $display("FI_BATCH: cfg_offset_inv_q0 32 bits");
    for (bi = 0; bi < ADDR_W; bi = bi + 1) run_cfg_offset_inv_q0_bit(bi);
    $display("FI_BATCH: cfg_mask_inv_q0 64 bits");
    for (bi = 0; bi < DATA_W; bi = bi + 1) run_cfg_mask_inv_q0_bit(bi);
    $display("FI_BATCH: cfg_expected_inv_q0 64 bits");
    for (bi = 0; bi < DATA_W; bi = bi + 1) run_cfg_expected_inv_q0_bit(bi);
    `endif

    $display("FI_BATCH: core_state_inv 4 bits");
    for (bi = 0; bi < 4; bi = bi + 1) run_core_state_inv_bit(bi);
    $display("FI_BATCH: core_fault_or_accum_inv 64 bits");
    for (bi = 0; bi < 64; bi = bi + 1) run_core_fault_or_accum_inv_bit(bi);

    $display("FI_BATCH: fd_fault_status_inv 64 bits");
    for (bi = 0; bi < 64; bi = bi + 1) run_fd_fault_status_inv_bit(bi);
    $display("FI_BATCH: fd_error_code_inv 8 bits");
    for (bi = 0; bi < 8; bi = bi + 1) run_fd_error_code_inv_bit(bi);

    $display("FI_BATCH: heartbeat_counter_inv 32 bits");
    for (bi = 0; bi < 32; bi = bi + 1) run_heartbeat_counter_inv_bit(bi);

    `ifdef FI_ARRAY_BIT_TARGETS
    $display("FI_BATCH: top_rsp_data_inv_q0 64 bits");
    for (bi = 0; bi < DATA_W; bi = bi + 1) run_top_rsp_data_inv_q0_bit(bi);

    $display("FI_BATCH: read_engine_slot_accum_inv_q0 64 bits");
    for (bi = 0; bi < DATA_W; bi = bi + 1) run_read_engine_slot_accum_inv_q0_bit(bi);
    `endif

    // ══════════════════════════════════════════════════════════════
    // Phase 2b: digital logic fault path sweep
    // ══════════════════════════════════════════════════════════════
    $display("FI_BATCH_PHASE2b: digital logic fault path sweep");
    run_dig_crc_compare_corrupt();
    run_dig_response_decode_fault();
    run_dig_cfg_error_code_priority_fault();
    run_dig_heartbeat_internal_fault();
    run_dig_fd_event_shadow_fault();
    run_dig_accum_shadow_comparator_fault();
    run_dig_kat_shadow_fault();
    run_dig_scan_trigger_fault();
    run_dig_slot_ptr_oob();
    run_dig_slot_age_timeout();
    run_dig_data_path_stuck();
    run_dig_illegal_entry_fault();
    run_dig_outstanding_mismatch();
    run_dig_cmd_ready_stall();
    run_dig_fsm_illegal_state();
    run_dig_current_index_oob();
    // Direct FI expansion (2026-06-30): 16 new digital logic targets
    run_dig_cfg_shadow_comp_direct();
    run_dig_event_shadow_direct();
    run_dig_accum_shadow_direct();
    run_dig_crc_mismatch_direct();
    run_dig_crc_expected_stuck();
    run_dig_re_wr_ptr_oob();
    run_dig_re_rd_ptr_oob();
    run_dig_re_outstanding_oob();
    run_dig_write_verify_stuck();
    run_dig_cfg_burst_type_direct();
    run_dig_cfg_burst_len_direct();
    run_dig_scan_start_stuck();
    run_dig_cfg_interval_direct();
    run_dig_slot_valid_tmr();
    run_dig_cfg_fault_tmr();
    run_dig_safety_fault_tmr();

    $display("FI_BATCH: sweep complete (Phase 3 array entry sweep handled by TCL driver)");
end
endtask

// ─── Digital logic fault injection tasks ───

// CRC core comparison register corrupt — tests r_crc_expected integrity
task run_dig_crc_compare_corrupt;
begin
    reset_dut(); config_minimal();
    // Force r_crc_expected_dup to mismatch r_crc_expected — simulates
    // CRC comparison register stuck-at on one copy
    force dut.gen_read_master[0].u_read_engine.r_crc_expected_dup = 16'hDEAD;
    expect_fault_within_10("dig_crc_compare_corrupt", "digital_logic_crc", 1'b0, 1'b1, 1'b0);
    release dut.gen_read_master[0].u_read_engine.r_crc_expected_dup;
end
endtask

// Response decode path fault — force wrong done flag
task run_dig_response_decode_fault;
begin
    reset_dut(); config_minimal();
    // Force a pending entry master index out of range to trigger
    // pending_index_fault_comb via the response decode tree
    force dut.u_core.pending_master_q[0] = NUM_MASTERS + 1;
    expect_fault_within_10("dig_response_decode", "digital_logic_resp_decode", 1'b0, 1'b1, 1'b0);
    release dut.u_core.pending_master_q[0];
end
endtask

// Error code priority path — force error_code_inv to match error_code (mismatch)
task run_dig_cfg_error_code_priority_fault;
begin
    reset_dut(); config_minimal();
    // Force error_code_inv to match error_code — creates shadow mismatch
    force dut.u_fault_detector.error_code_inv = dut.u_fault_detector.error_code;
    expect_fault_within_10("dig_error_code_priority", "digital_logic_priority", 1'b0, 1'b1, 1'b0);
    release dut.u_fault_detector.error_code_inv;
end
endtask

// Heartbeat internal fault path
task run_dig_heartbeat_internal_fault;
begin
    reset_dut(); config_minimal();
    // Force heartbeat state_inv mismatch — tests heartbeat_internal_fault
    force dut.u_heartbeat.state_inv = dut.u_heartbeat.state;
    expect_fault_within_10("dig_heartbeat_internal", "digital_logic_hb", 1'b0, 1'b1, 1'b0);
    release dut.u_heartbeat.state_inv;
end
endtask

// Fault detector event_shadow_fault path
task run_dig_fd_event_shadow_fault;
begin
    reset_dut(); config_minimal();
    // Force external_fault_event_inv to mismatch — tests event_shadow_fault
    force dut.u_fault_detector.external_fault_event_inv = dut.u_fault_detector.external_fault_event;
    expect_fault_within_10("dig_fd_event_shadow", "digital_logic_fd", 1'b0, 1'b1, 1'b0);
    release dut.u_fault_detector.external_fault_event_inv;
end
endtask

// Accum shadow comparator integrity
task run_dig_accum_shadow_comparator_fault;
    integer c;
begin
    reset_dut(); config_minimal();
    // Wait for scan to start and accumulate some data
    repeat (30) @(posedge clk);
    // Force accum_inv to match accum — simulates comparator stuck-at-pass
    force dut.u_fault_detector.accum_inv = dut.u_fault_detector.accum;
    // Wait for scan_done_pulse (accum_shadow_fault checked at scan done)
    c = 0;
    while (c < 200 && !safety_island_fault_detect) begin
        c = c + 1;
        @(posedge clk);
    end
    if (safety_island_fault_detect)
        report_detected("dig_accum_shadow_comparator", "digital_logic_shadow", c);
    else
        report_undetected("dig_accum_shadow_comparator", "digital_logic_shadow");
    release dut.u_fault_detector.accum_inv;
end
endtask

// KAT shadow check path
task run_dig_kat_shadow_fault;
begin
    reset_dut(); config_minimal();
    // Force KAT mask inv to mismatch
    force dut.u_cfg.kat_mask_inv = dut.u_cfg.kat_mask;
    expect_fault_within_10("dig_kat_shadow", "digital_logic_kat_shadow", 1'b1, 1'b0, 1'b1);
    release dut.u_cfg.kat_mask_inv;
end
endtask

// Scan trigger combinational path — force interval=0 to trigger cfg_interval_fault
task run_dig_scan_trigger_fault;
begin
    reset_dut(); config_minimal();
    // Force read_interval to 0 — cfg_interval_fault_comb should fire
    force dut.u_cfg.read_interval = 64'd0;
    expect_fault_within_10("dig_scan_trigger", "digital_logic_scan", 1'b1, 1'b0, 1'b0);
    release dut.u_cfg.read_interval;
end
endtask

// ─── Extended digital logic fault tasks ───

// Slot pointer out-of-bounds → pending_ptr_fault_comb should fire
task run_dig_slot_ptr_oob;
begin
    reset_dut(); config_minimal();
    force dut.u_core.pending_wr_ptr = 32'hFFFF_FFFF;
    expect_fault_within_10("dig_slot_ptr_oob", "digital_logic_slot", 1'b0, 1'b1, 1'b0);
    release dut.u_core.pending_wr_ptr;
end
endtask

// Slot aging timeout → force slot_age past TIMEOUT threshold
task run_dig_slot_age_timeout;
begin
    reset_dut(); config_minimal();
    force dut.gen_read_master[0].u_read_engine.slot_age_q[0] = 32'hFFFF_FFFF;
    expect_fault_within_10("dig_slot_age_timeout", "digital_logic_slot", 1'b0, 1'b1, 1'b0);
    release dut.gen_read_master[0].u_read_engine.slot_age_q[0];
end
endtask

// Config entry address decode path: bit-0 fault on entry[4]
// Tests that shadow detection works identically across different array indices
// (address decoder for multi-entry shadow arrays)
task run_dig_data_path_stuck;
begin
    reset_dut(); config_minimal();
    force dut.u_cfg.expected_inv_q[4][0] = dut.u_cfg.expected_q[4][0];
    expect_fault_within_10("dig_entry4_shadow", "digital_logic_data", 1'b1, 1'b0, 1'b1);
    release dut.u_cfg.expected_inv_q[4][0];
end
endtask

// Illegal entry configuration → cfg_table_fault_comb
task run_dig_illegal_entry_fault;
begin
    reset_dut(); config_minimal();
    // Force bust_type to illegal value (2'b11) → cfg_burst_type_fault_comb
    force dut.u_cfg.burst_type_q[0] = 2'b11;
    expect_fault_within_10("dig_illegal_entry", "digital_logic_cfg", 1'b1, 1'b0, 1'b0);
    release dut.u_cfg.burst_type_q[0];
end
endtask

// Outstanding count mismatch → outstanding_fault_comb
task run_dig_outstanding_mismatch;
begin
    reset_dut(); config_minimal();
    force dut.u_core.outstanding_count = 32'd999;
    expect_fault_within_10("dig_outstanding_mismatch", "digital_logic_slot", 1'b0, 1'b1, 1'b0);
    release dut.u_core.outstanding_count;
end
endtask

// cmd_ready stall — force outstanding_count to max to prevent new requests
task run_dig_cmd_ready_stall;
    integer c;
begin
    reset_dut(); config_minimal();
    // Force read engine outstanding_count to MAX → cmd_ready should go low
    force dut.gen_read_master[0].u_read_engine.outstanding_count = MAX_OUTSTANDING;
    // outstanding_fault_comb should fire from the mismatch
    c = 0;
    while (c < 50 && !safety_island_fault_detect) begin
        c = c + 1;
        @(posedge clk);
    end
    if (safety_island_fault_detect)
        report_detected("dig_cmd_ready_stall", "digital_logic_slot", c);
    else
        report_undetected("dig_cmd_ready_stall", "digital_logic_slot");
    release dut.gen_read_master[0].u_read_engine.outstanding_count;
end
endtask

// FSM illegal state → fsm_state_illegal_comb → safety_fault
task run_dig_fsm_illegal_state;
begin
    reset_dut(); config_minimal();
    // Force state_a to illegal encoding (4'hF = undefined)
    force dut.u_core.state_b = 4'hF;
    force dut.u_core.state_c = 4'hF;
    expect_fault_within_10("dig_fsm_illegal_state", "digital_logic_fsm", 1'b0, 1'b1, 1'b0);
    release dut.u_core.state_b;
    release dut.u_core.state_c;
end
endtask

// Current master/entry index out-of-range → current_index_fault_comb
task run_dig_current_index_oob;
begin
    reset_dut(); config_minimal();
    force dut.u_core.current_master_idx = 32'd99;
    expect_fault_within_10("dig_current_index_oob", "digital_logic_core", 1'b0, 1'b1, 1'b0);
    release dut.u_core.current_master_idx;
end
endtask

// ─── Added 2026-06-30: digital logic direct FI expansion (FAULT_INDEX 39..54) ───

// shadow_error_comb direct — force shadow compare to silent
task run_dig_cfg_shadow_comp_direct;
begin
    reset_dut(); config_minimal();
    force dut.u_cfg.shadow_error_comb_a = 1'b0;
    // A real shadow error exists but comparators forced silent
    force dut.u_cfg.read_interval_inv = 64'h0;
    expect_fault_within_10("dig_cfg_shadow_comp_stuck", "digital_logic_shadow", 1'b1, 1'b0, 1'b1);
    release dut.u_cfg.shadow_error_comb_a;
    release dut.u_cfg.read_interval_inv;
end
endtask

// event_shadow_fault direct — force fault detector event shadow to 1
task run_dig_event_shadow_direct;
begin
    reset_dut(); config_minimal();
    force dut.u_fault_detector.event_shadow_fault = 1'b1;
    expect_fault_within_10("dig_event_shadow_direct", "digital_logic_fd", 1'b0, 1'b1, 1'b0);
    release dut.u_fault_detector.event_shadow_fault;
end
endtask

// accum_shadow_fault_comb direct — force accum shadow mismatch
task run_dig_accum_shadow_direct;
begin
    reset_dut(); config_minimal();
    force dut.u_core.accum_shadow_fault_comb = 1'b1;
    expect_fault_within_10("dig_accum_shadow_direct", "digital_logic_core", 1'b0, 1'b1, 1'b0);
    release dut.u_core.accum_shadow_fault_comb;
end
endtask

// crc_calc_mismatch direct — force CRC DMR mismatch to 1
task run_dig_crc_mismatch_direct;
begin
    reset_dut(); config_minimal();
    force dut.gen_read_master[0].u_read_engine.crc_calc_mismatch_a = 1'b1;
    expect_fault_within_10("dig_crc_mismatch_direct", "digital_logic_crc", 1'b0, 1'b1, 1'b0);
    release dut.gen_read_master[0].u_read_engine.crc_calc_mismatch_a;
end
endtask

// r_crc_expected stuck-at — force wrong CRC expected value
task run_dig_crc_expected_stuck;
begin
    reset_dut(); config_minimal();
    force dut.gen_read_master[0].u_read_engine.r_crc_expected = 16'hDEAD;
    force dut.gen_read_master[0].u_read_engine.r_crc_expected_triple = 16'hDEAD;
    expect_fault_within_10("dig_crc_expected_stuck", "digital_logic_crc", 1'b0, 1'b1, 1'b0);
    release dut.gen_read_master[0].u_read_engine.r_crc_expected;
    release dut.gen_read_master[0].u_read_engine.r_crc_expected_triple;
end
endtask

// wr_ptr out-of-range → internal_safety_fault
task run_dig_re_wr_ptr_oob;
begin
    reset_dut(); config_minimal();
    force dut.gen_read_master[0].u_read_engine.wr_ptr = MAX_OUTSTANDING;
    expect_fault_within_10("dig_re_wr_ptr_oob", "digital_logic_slot", 1'b0, 1'b1, 1'b0);
    release dut.gen_read_master[0].u_read_engine.wr_ptr;
end
endtask

// rd_ptr out-of-range → internal_safety_fault
task run_dig_re_rd_ptr_oob;
begin
    reset_dut(); config_minimal();
    force dut.gen_read_master[0].u_read_engine.rd_ptr = MAX_OUTSTANDING;
    expect_fault_within_10("dig_re_rd_ptr_oob", "digital_logic_slot", 1'b0, 1'b1, 1'b0);
    release dut.gen_read_master[0].u_read_engine.rd_ptr;
end
endtask

// outstanding_count out-of-range → internal_safety_fault
task run_dig_re_outstanding_oob;
begin
    reset_dut(); config_minimal();
    force dut.gen_read_master[0].u_read_engine.outstanding_count = MAX_OUTSTANDING + 1;
    expect_fault_within_10("dig_re_outstanding_oob", "digital_logic_slot", 1'b0, 1'b1, 1'b0);
    release dut.gen_read_master[0].u_read_engine.outstanding_count;
end
endtask

// write-verify path stuck — force shadow after write → SLVERR
task run_dig_write_verify_stuck;
    reg [DATA_W-1:0] saved_interval;
begin
    reset_dut(); config_minimal();
    // Write new interval value while forcing shadow_error TMR copies to mismatch
    saved_interval = dut.u_cfg.read_interval;
    force dut.u_cfg.shadow_error_comb_a = 1'b1;
    axi_cfg_write(ADDR_READ_INTERVAL, 64'hCAFE);
    #100;
    release dut.u_cfg.shadow_error_comb_a;
    // If write-verify works: SLVERR responded + cfg_illegal asserted → fault_detect
    if (dut.u_cfg.cfg_illegal || fault_detect)
        report_detected("dig_write_verify_stuck", "digital_logic_cfg", 100);
    else
        report_undetected("dig_write_verify_stuck", "digital_logic_cfg");
end
endtask

// cfg_burst_type_fault_comb direct — force to 1
task run_dig_cfg_burst_type_direct;
begin
    reset_dut(); config_minimal();
    force dut.u_core.cfg_burst_type_fault_comb = 1'b1;
    expect_fault_within_10("dig_cfg_burst_type_direct", "digital_logic_cfg", 1'b1, 1'b0, 1'b0);
    release dut.u_core.cfg_burst_type_fault_comb;
end
endtask

// cfg_burst_len_fault_comb direct — force to 1
task run_dig_cfg_burst_len_direct;
begin
    reset_dut(); config_minimal();
    force dut.u_core.cfg_burst_len_fault_comb = 1'b1;
    expect_fault_within_10("dig_cfg_burst_len_direct", "digital_logic_cfg", 1'b1, 1'b0, 1'b0);
    release dut.u_core.cfg_burst_len_fault_comb;
end
endtask

// scan_start_comb stuck — force to 0 to prevent scan; heartbeat fires after timeout
task run_dig_scan_start_stuck;
    integer c;
begin
    reset_dut(); config_minimal();
    force dut.u_core.scan_start_comb = 1'b0;
    for (c = 0; c < 2500; c = c + 1) @(posedge clk);
    if (safety_island_fault_detect || dut.heartbeat_fault)
        report_detected("dig_scan_start_stuck", "digital_logic_scan", c);
    else
        report_undetected("dig_scan_start_stuck", "digital_logic_scan");
    release dut.u_core.scan_start_comb;
end
endtask

// cfg_interval_fault_comb direct — force to 1
task run_dig_cfg_interval_direct;
begin
    reset_dut(); config_minimal();
    force dut.u_core.cfg_interval_fault_comb = 1'b1;
    expect_fault_within_10("dig_cfg_interval_direct", "digital_logic_cfg", 1'b1, 1'b0, 1'b0);
    release dut.u_core.cfg_interval_fault_comb;
end
endtask

// slot_valid TMR copy corrupt — forces one TMR copy to 1 while others are 0
// TMR voter produces correct result (2-of-3 majority) → functionally corrected
// tmr_err fires → safety_island_fault_detect provides detection of the discrepancy
task run_dig_slot_valid_tmr;
    integer c;
    reg hit;
begin
    reset_dut(); config_minimal();
    force dut.gen_read_master[0].u_read_engine.slot_valid_q_a[0] = 1'b1;
    // Corrupting only 1 of 3 copies: voted output is correct (majority 2:0)
    // but slot_valid_q_tmr_err fires → slot_shadow_error_comb → internal_safety_fault
    // Classification: CORRECTED (function preserved, fault flagged)
    c = 0;
    hit = 1'b0;
    while (c <= 10 && !hit) begin
        if ((dut.gen_read_master[0].u_read_engine.slot_valid_q_voted[0] === 1'b0) &&
            (dut.gen_read_master[0].u_read_engine.slot_valid_q_tmr_err[0] === 1'b1) &&
            safety_island_fault_detect) begin
            hit = 1'b1;
        end else begin
            c = c + 1;
            @(posedge clk);
        end
    end
    if (hit)
        report_corrected("dig_slot_valid_tmr", "digital_logic_slot", c);
    else
        report_undetected("dig_slot_valid_tmr", "digital_logic_slot");
    release dut.gen_read_master[0].u_read_engine.slot_valid_q_a[0];
end
endtask

// cfg_fault_comb TMR copy corrupt — single TMR copy stuck high
// TMR voter produces correct result (2-of-3 majority=0) → functionally corrected
// tmr_err fires → cfg_fault_comb = voted|tmr_err = 1 → fault_detect (corrective+detection)
task run_dig_cfg_fault_tmr;
    integer c;
    reg hit;
begin
    reset_dut(); config_minimal();
    force dut.u_core.cfg_fault_comb_a = 1'b1;
    // Only 1 of 3 copies corrupt: voted=0 (correct, no real fault), tmr_err=1
    // Classification: CORRECTED (cfg_fault voted output preserved, mismatch flagged)
    c = 0;
    hit = 1'b0;
    while (c <= 10 && !hit) begin
        if ((dut.u_core.cfg_fault_comb_voted === 1'b0) &&
            (dut.u_core.cfg_fault_comb_tmr_err === 1'b1) &&
            fault_detect) begin
            hit = 1'b1;
        end else begin
            c = c + 1;
            @(posedge clk);
        end
    end
    if (hit)
        report_corrected("dig_cfg_fault_tmr", "digital_logic_cfg", c);
    else
        report_undetected("dig_cfg_fault_tmr", "digital_logic_cfg");
    release dut.u_core.cfg_fault_comb_a;
end
endtask

// safety_fault_comb TMR copy corrupt — single TMR copy stuck high
// TMR voter produces correct result (2-of-3 majority=0) → functionally corrected
// tmr_err fires → safety_fault_comb = voted|tmr_err = 1 → safety_island_fault_detect
task run_dig_safety_fault_tmr;
    integer c;
    reg hit;
begin
    reset_dut(); config_minimal();
    force dut.u_core.safety_fault_comb_a = 1'b1;
    // Only 1 of 3 copies corrupt: voted=0 (correct), tmr_err=1
    // Classification: CORRECTED (voted safety_fault stays 0, mismatch flagged for inspection)
    c = 0;
    hit = 1'b0;
    while (c <= 10 && !hit) begin
        if ((dut.u_core.safety_fault_comb_voted === 1'b0) &&
            (dut.u_core.safety_fault_comb_tmr_err === 1'b1) &&
            safety_island_fault_detect) begin
            hit = 1'b1;
        end else begin
            c = c + 1;
            @(posedge clk);
        end
    end
    if (hit)
        report_corrected("dig_safety_fault_tmr", "digital_logic_core", c);
    else
        report_undetected("dig_safety_fault_tmr", "digital_logic_core");
    release dut.u_core.safety_fault_comb_a;
end
endtask

task run_fault_by_index;
    input integer fault_index;
begin
    case (fault_index)
        1:  run_cfg_read_interval_shadow_stuck();
        2:  run_cfg_base_shadow_stuck();
        3:  run_cfg_offset_shadow_stuck();
        4:  run_cfg_mask_shadow_stuck();
        5:  run_cfg_burst_shadow_stuck();
        6:  run_cfg_entry_valid_shadow_stuck();
        7:  run_cfg_expected_shadow_stuck();
        8:  run_core_state_inv_stuck();
        9:  run_core_accum_inv_stuck();
        10: run_pending_wr_ptr_stuck();
        11: run_pending_rd_ptr_stuck();
        12: run_outstanding_count_stuck();
        13: run_axi_timeout_fault();
        14: run_axi_rresp_error_fault();
        15: run_axi_rid_mismatch_fault();
        16: run_axi_rcheck_error_fault();
        17: run_transient_state_inv_flip();
        18: run_transient_accum_inv_flip();
        19: run_transient_cfg_shadow_flip();
        20: run_kat_mismatch_fault();
        21: run_tmr_double_fault();
        22: run_e2e_crc16_mismatch();
        23: run_dig_crc_compare_corrupt();
        24: run_dig_response_decode_fault();
        25: run_dig_cfg_error_code_priority_fault();
        26: run_dig_heartbeat_internal_fault();
        27: run_dig_fd_event_shadow_fault();
        28: run_dig_accum_shadow_comparator_fault();
        29: run_dig_kat_shadow_fault();
        30: run_dig_scan_trigger_fault();
        31: run_dig_slot_ptr_oob();
        32: run_dig_slot_age_timeout();
        33: run_dig_data_path_stuck();
        34: run_dig_illegal_entry_fault();
        35: run_dig_outstanding_mismatch();
        36: run_dig_cmd_ready_stall();
        37: run_dig_fsm_illegal_state();
        38: run_dig_current_index_oob();
        39: run_dig_cfg_shadow_comp_direct();
        40: run_dig_event_shadow_direct();
        41: run_dig_accum_shadow_direct();
        42: run_dig_crc_mismatch_direct();
        43: run_dig_crc_expected_stuck();
        44: run_dig_re_wr_ptr_oob();
        45: run_dig_re_rd_ptr_oob();
        46: run_dig_re_outstanding_oob();
        47: run_dig_write_verify_stuck();
        48: run_dig_cfg_burst_type_direct();
        49: run_dig_cfg_burst_len_direct();
        50: run_dig_scan_start_stuck();
        51: run_dig_cfg_interval_direct();
        52: run_dig_slot_valid_tmr();
        53: run_dig_cfg_fault_tmr();
        54: run_dig_safety_fault_tmr();
        default: begin
            $display("FI_ERROR: unsupported FAULT_INDEX=%0d", fault_index);
            total_cases = total_cases + 1;
            undetected_cases = undetected_cases + 1;
        end
    endcase
end
endtask

initial begin
`ifdef FSDB
    $fsdbDumpfile("waves/fault_injection.fsdb");
    $fsdbDumpvars(0, tb_safety_island_fault_injection);
`endif

    clk = 1'b0;
    rst = 1'b1;
    total_cases = 0;
    corrected_cases = 0;
    detected_cases = 0;
    undetected_cases = 0;
    selected_fault_index = 0;
    selected_bit_index = 0;
    selected_fault_kind = 0;
    run_one_fault = $value$plusargs("FAULT_INDEX=%d", selected_fault_index);
    run_bit_fault = $value$plusargs("FAULT_KIND=%s", selected_fault_kind);
    if (!$value$plusargs("BIT_INDEX=%d", selected_bit_index))
        selected_bit_index = 0;
    if (!$value$plusargs("SUMMARY_FILE=%s", summary_file))
        summary_file = "fault_injection_summary.txt";
    if (!$value$plusargs("CSV_FILE=%s", csv_file))
        csv_file = "fault_injection_report.csv";
    summary_fd = $fopen(summary_file, "w");
    if (summary_fd == 0)
        $display("FI_WARN: failed to open summary file %0s", summary_file);
    csv_fd = $fopen(csv_file, "w");
    if (csv_fd == 0) begin
        $display("FI_WARN: failed to open CSV file %0s", csv_file);
    end else begin
        $fdisplay(csv_fd, "name,type,result,cycles,error_code,fault_detect,safety_fault,latent_fault");
    end

    if ($test$plusargs("SINGLE_FAULT")) begin
        // TCL-driven mode: just set up clock, release reset, configure, wait
        repeat (5) @(posedge clk);
        rst <= 1'b0;
        config_minimal();
        // TCL applies force externally, then runs simulation
        // Wait indefinitely — TCL's run timer controls stop
    end else if (run_bit_fault) begin
        run_bit_fault_by_kind(selected_fault_kind, selected_bit_index);
    end else if ($test$plusargs("BATCH_ALL")) begin
        run_batch_all();
    end else if (run_one_fault) begin
        run_fault_by_index(selected_fault_index);
    end else begin
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
        run_kat_mismatch_fault();
        run_tmr_double_fault();
        run_e2e_crc16_mismatch();
        run_dig_crc_compare_corrupt();
        run_dig_response_decode_fault();
        run_dig_cfg_error_code_priority_fault();
        run_dig_heartbeat_internal_fault();
        run_dig_fd_event_shadow_fault();
        run_dig_accum_shadow_comparator_fault();
        run_dig_kat_shadow_fault();
        run_dig_scan_trigger_fault();
        run_dig_slot_ptr_oob();
        run_dig_slot_age_timeout();
        run_dig_data_path_stuck();
        run_dig_illegal_entry_fault();
        run_dig_outstanding_mismatch();
        run_dig_cmd_ready_stall();
        run_dig_fsm_illegal_state();
        run_dig_current_index_oob();
        run_dig_cfg_shadow_comp_direct();
        run_dig_event_shadow_direct();
        run_dig_accum_shadow_direct();
        run_dig_crc_mismatch_direct();
        run_dig_crc_expected_stuck();
        run_dig_re_wr_ptr_oob();
        run_dig_re_rd_ptr_oob();
        run_dig_re_outstanding_oob();
        run_dig_write_verify_stuck();
        run_dig_cfg_burst_type_direct();
        run_dig_cfg_burst_len_direct();
        run_dig_scan_start_stuck();
        run_dig_cfg_interval_direct();
        run_dig_slot_valid_tmr();
        run_dig_cfg_fault_tmr();
        run_dig_safety_fault_tmr();
    end

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
    if (csv_fd != 0) begin
        $fdisplay(csv_fd, "SUMMARY,total=%0d corrected=%0d detected=%0d undetected=%0d protection_rate=%0d%%,,,,",
                  total_cases, corrected_cases, detected_cases, undetected_cases,
                  protection_rate_pct);
        $fclose(csv_fd);
    end

    if (undetected_cases == 0)
        $display("PASS: safety_island fault injection campaign completed");
    else
        $display("FAIL: safety_island fault injection campaign undetected=%0d", undetected_cases);



    $finish;
end

endmodule
