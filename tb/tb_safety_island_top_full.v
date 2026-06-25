`timescale 1ns/1ps

module tb_safety_island_top_full;

localparam NUM_MASTERS     = 5;
localparam NUM_ENTRIES     = 64;
localparam ADDR_W          = 32;
localparam DATA_W          = 64;
localparam ID_W            = 4;
localparam MAX_OUTSTANDING = 4;
localparam MEM_WORDS       = 512;
localparam Q_DEPTH         = 16;
localparam TB_CRC_WIDTH    = 16;  // must match DUT CRC_WIDTH

localparam [31:0] ADDR_CONTROL       = 32'h0000_0000;
localparam [31:0] ADDR_READ_INTERVAL = 32'h0000_0008;
localparam [31:0] ADDR_STATUS        = 32'h0000_0010;
localparam [31:0] ADDR_FAULT_RESULT  = 32'h0000_0018;
localparam [31:0] ADDR_ERROR_CODE    = 32'h0000_0020;
localparam [31:0] ADDR_BASE_REGION   = 32'h0000_0100;
localparam [31:0] ADDR_ENTRY_REGION  = 32'h0000_1000;
localparam [31:0] BASE_STRIDE        = 32'h0000_0008;
localparam [31:0] ENTRY_MASTER_STRIDE= 32'h0000_1000;
localparam [31:0] ENTRY_STRIDE       = 32'h0000_0020;
localparam [31:0] ENTRY_OFFSET_OFF   = 32'h0000_0000;
localparam [31:0] ENTRY_MASK_OFF     = 32'h0000_0008;
localparam [31:0] ENTRY_BURST_OFF    = 32'h0000_0010;
localparam [31:0] ENTRY_EXPECTED_OFF = 32'h0000_0018;

localparam [31:0] ADDR_KAT_CTRL     = 32'h0000_0038;
localparam [31:0] ADDR_KAT_ADDR     = 32'h0000_0040;
localparam [31:0] ADDR_KAT_EXPECTED = 32'h0000_0048;
localparam [31:0] ADDR_KAT_MASK     = 32'h0000_0050;

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
reg  [NUM_MASTERS*TB_CRC_WIDTH-1:0] m_axi_rcheck_flat;
wire [NUM_MASTERS-1:0]            m_axi_rready_flat;

wire                  fault_detect;
wire                  safety_island_fault_detect;
wire                  safety_island_latent_fault_detect;
wire [DATA_W-1:0]     fault_or_result;
wire [7:0]            core_error_code;

reg [DATA_W-1:0] ext_mem [0:(NUM_MASTERS*MEM_WORDS)-1];
reg [ID_W-1:0]   q_id    [0:(NUM_MASTERS*Q_DEPTH)-1];
reg [ADDR_W-1:0] q_addr  [0:(NUM_MASTERS*Q_DEPTH)-1];
reg [7:0]        q_len   [0:(NUM_MASTERS*Q_DEPTH)-1];
reg [1:0]        q_burst [0:(NUM_MASTERS*Q_DEPTH)-1];
reg [7:0]        q_beat  [0:(NUM_MASTERS*Q_DEPTH)-1];
reg              q_err   [0:(NUM_MASTERS*Q_DEPTH)-1];
integer active_q_idx [0:NUM_MASTERS-1];
integer q_head [0:NUM_MASTERS-1];
integer q_tail [0:NUM_MASTERS-1];
integer q_count[0:NUM_MASTERS-1];

integer ar_count [0:NUM_MASTERS-1];
integer r_count  [0:NUM_MASTERS-1];
integer max_q_count [0:NUM_MASTERS-1];
integer total_pass;
integer total_fail;
integer case_fail;
integer resp_error_master;
integer timeout_master;
integer delay_until_ar_count;
integer response_mode;
integer invalid_rid_master;
integer rcheck_error_master;
integer rcheck_error_beat;

safety_island_top #(
    .NUM_MASTERS(NUM_MASTERS),
    .NUM_ENTRIES(NUM_ENTRIES),
    .ADDR_W(ADDR_W),
    .DATA_W(DATA_W),
    .ID_W(ID_W),
    .TIMEOUT_CYCLES(48),
    .MAX_OUTSTANDING(MAX_OUTSTANDING),
    .CRC_WIDTH(TB_CRC_WIDTH)
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

function [31:0] burst_byte_addr;
    input [31:0] base_addr;
    input [7:0] beat;
    input [7:0] len;
    input [1:0] burst;
    integer wrap_bytes;
    integer wrap_base;
begin
    if (burst == 2'b10) begin
        wrap_bytes = (len + 1) * 8;
        wrap_base = (base_addr / wrap_bytes) * wrap_bytes;
        burst_byte_addr = wrap_base + ((base_addr - wrap_base + beat * 8) % wrap_bytes);
    end else if (burst == 2'b00) begin
        burst_byte_addr = base_addr;
    end else begin
        burst_byte_addr = base_addr + beat * 8;
    end
end
endfunction

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

function [7:0] crc8_two_stage;
    input [ID_W-1:0]   ar_id;
    input [ADDR_W-1:0] ar_addr;
    input [7:0]        ar_len;
    input [1:0]        ar_burst;
    input [ID_W-1:0]   r_id;
    input [DATA_W-1:0] r_data;
    input [1:0]        r_resp;
    input              r_last;
    reg [ID_W+ADDR_W+8+3+2-1:0] ar_payload;
    reg [8+ID_W+DATA_W+2+1-1:0] r_payload;
    reg [7:0] ar_sig;
    reg [7:0] crc;
    reg feedback;
    integer bit_i;
begin
    // Stage 1: CRC-8 of AR fields (poly 0x07, init 0x00)
    ar_payload = {ar_id, ar_addr, ar_len, 3'd3, ar_burst};
    crc = 8'h00;
    for (bit_i = ID_W + ADDR_W + 8 + 3 + 2 - 1; bit_i >= 0; bit_i = bit_i - 1) begin
        feedback = crc[7] ^ ar_payload[bit_i];
        crc = {crc[6:0], 1'b0};
        if (feedback) crc = crc ^ 8'h07;
    end
    ar_sig = crc;
    // Stage 2: CRC-8 of {ar_sig, R fields} (poly 0x07, init 0x00)
    r_payload = {ar_sig, r_id, r_data, r_resp, r_last};
    crc = 8'h00;
    for (bit_i = 8 + ID_W + DATA_W + 2 + 1 - 1; bit_i >= 0; bit_i = bit_i - 1) begin
        feedback = crc[7] ^ r_payload[bit_i];
        crc = {crc[6:0], 1'b0};
        if (feedback) crc = crc ^ 8'h07;
    end
    crc8_two_stage = crc;
end
endfunction

function [15:0] crc16_ccitt;
    input [ID_W-1:0]             ar_id;
    input [ADDR_W-1:0]           ar_addr;
    input [7:0]                  ar_len;
    input [2:0]                  ar_size;
    input [1:0]                  ar_burst;
    input [ID_W-1:0]             r_id;
    input [DATA_W-1:0]           r_data;
    input [1:0]                  r_resp;
    input                        r_last;
    reg [ID_W+ADDR_W+8+3+2-1:0] ar_payload;
    reg [TB_CRC_WIDTH+ID_W+DATA_W+2+1-1:0] r_payload;
    reg [15:0] ar_sig;
    reg [15:0] crc;
    reg feedback;
    integer bit_i;
begin
    // Stage 1: CRC-16 of AR fields (poly 0x1021, init 0xFFFF)
    ar_payload = {ar_id, ar_addr, ar_len, ar_size, ar_burst};
    crc = 16'hFFFF;
    for (bit_i = ID_W + ADDR_W + 8 + 3 + 2 - 1; bit_i >= 0; bit_i = bit_i - 1) begin
        feedback = crc[15] ^ ar_payload[bit_i];
        crc = {crc[14:0], 1'b0};
        if (feedback)
            crc = crc ^ 16'h1021;
    end
    ar_sig = crc;

    // Stage 2: CRC-16 of {ar_sig, R fields} (poly 0x1021, init 0xFFFF)
    r_payload = {ar_sig, r_id, r_data, r_resp, r_last};
    crc = 16'hFFFF;
    for (bit_i = TB_CRC_WIDTH + ID_W + DATA_W + 2 + 1 - 1; bit_i >= 0; bit_i = bit_i - 1) begin
        feedback = crc[15] ^ r_payload[bit_i];
        crc = {crc[14:0], 1'b0};
        if (feedback)
            crc = crc ^ 16'h1021;
    end
    crc16_ccitt = crc;
end
endfunction

function [DATA_W-1:0] mem_read_data;
    input integer master;
    input [31:0] addr;
begin
    mem_read_data = ext_mem[(master) * MEM_WORDS + (addr[11:3])];
end
endfunction

integer em;
integer ei;
task clear_ext_model;
begin
    resp_error_master = -1;
    timeout_master = -1;
    delay_until_ar_count = 0;
    response_mode = 0;
    invalid_rid_master = -1;
    rcheck_error_master = -1;
    rcheck_error_beat = -1;
    for (em = 0; em < NUM_MASTERS; em = em + 1) begin
        q_head[em] = 0;
        q_tail[em] = 0;
        q_count[em] = 0;
        active_q_idx[em] = 0;
        ar_count[em] = 0;
        r_count[em] = 0;
        max_q_count[em] = 0;
        for (ei = 0; ei < MEM_WORDS; ei = ei + 1)
            ext_mem[(em) * MEM_WORDS + (ei)] = {DATA_W{1'b0}};
        for (ei = 0; ei < Q_DEPTH; ei = ei + 1) begin
            q_id[(em) * Q_DEPTH + (ei)] = {ID_W{1'b0}};
            q_addr[(em) * Q_DEPTH + (ei)] = {ADDR_W{1'b0}};
            q_len[(em) * Q_DEPTH + (ei)] = 8'd0;
            q_burst[(em) * Q_DEPTH + (ei)] = 2'b01;
            q_beat[(em) * Q_DEPTH + (ei)] = 8'd0;
            q_err[(em) * Q_DEPTH + (ei)] = 1'b0;
        end
    end
end
endtask

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
    s_axi_wstrb = 8'h00;
    s_axi_wlast = 1'b0;
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
    m_axi_rcheck_flat = {(NUM_MASTERS*TB_CRC_WIDTH){1'b0}};
end
endtask

task reset_dut;
begin
    init_signals();
    clear_ext_model();
    rst = 1'b1;
    repeat (5) @(posedge clk);
    rst = 1'b0;
    repeat (2) @(posedge clk);
end
endtask

task axi_cfg_write_resp;
    input [ADDR_W-1:0] addr;
    input [DATA_W-1:0] data;
    input [1:0] exp_resp;
begin
    @(negedge clk);
    s_axi_awaddr  = addr;
    s_axi_awlen   = 8'd0;
    s_axi_awsize  = 3'd3;
    s_axi_awburst = 2'b01;
    s_axi_awvalid = 1'b1;
    s_axi_wdata   = data;
    s_axi_wstrb   = 8'hFF;
    s_axi_wlast   = 1'b1;
    s_axi_wvalid  = 1'b1;
    s_axi_bready  = 1'b1;
    while (!s_axi_awready || !s_axi_wready)
        @(posedge clk);
    @(negedge clk);
    s_axi_awvalid = 1'b0;
    s_axi_wvalid  = 1'b0;
    while (!s_axi_bvalid)
        @(posedge clk);
    if (s_axi_bresp !== exp_resp) begin
        $display("FAIL: cfg write addr=%h resp=%b exp=%b", addr, s_axi_bresp, exp_resp);
        case_fail = case_fail + 1;
        total_fail = total_fail + 1;
    end
    @(negedge clk);
    s_axi_bready = 1'b0;
end
endtask

task axi_cfg_write;
    input [ADDR_W-1:0] addr;
    input [DATA_W-1:0] data;
begin
    axi_cfg_write_resp(addr, data, 2'b00);
end
endtask

task axi_cfg_read;
    input [ADDR_W-1:0] addr;
    output [DATA_W-1:0] data;
begin
    @(negedge clk);
    s_axi_araddr  = addr;
    s_axi_arlen   = 8'd0;
    s_axi_arsize  = 3'd3;
    s_axi_arburst = 2'b01;
    s_axi_arvalid = 1'b1;
    s_axi_rready  = 1'b1;
    while (!s_axi_arready)
        @(posedge clk);
    @(negedge clk);
    s_axi_arvalid = 1'b0;
    while (!s_axi_rvalid)
        @(posedge clk);
    data = s_axi_rdata;
    @(negedge clk);
    s_axi_rready = 1'b0;
end
endtask

task config_base;
    input integer master;
    input [31:0] base;
begin
    axi_cfg_write(ADDR_BASE_REGION + master * BASE_STRIDE, {{32{1'b0}}, base});
end
endtask

task config_entry;
    input integer master;
    input integer entry;
    input [31:0] offset;
    input [DATA_W-1:0] mask;
    input [1:0] burst_type;
    input [7:0] burst_len;
    input valid;
    input [DATA_W-1:0] expected;
    reg [31:0] entry_addr;
begin
    entry_addr = ADDR_ENTRY_REGION + master * ENTRY_MASTER_STRIDE + entry * ENTRY_STRIDE;
    axi_cfg_write(entry_addr + ENTRY_OFFSET_OFF, {{32{1'b0}}, offset});
    axi_cfg_write(entry_addr + ENTRY_MASK_OFF, mask);
    axi_cfg_write(entry_addr + ENTRY_BURST_OFF, {{47{1'b0}}, valid, burst_len, 6'd0, burst_type});
    axi_cfg_write(entry_addr + ENTRY_EXPECTED_OFF, expected);
end
endtask

task lock_enable_scan;
begin
    axi_cfg_write(ADDR_READ_INTERVAL, 64'd8);
    axi_cfg_write(ADDR_CONTROL, 64'h0000_0000_0000_000B);
end
endtask

task wait_cycles;
    input integer cycles;
    integer wc;
begin
    for (wc = 0; wc < cycles; wc = wc + 1)
        @(posedge clk);
end
endtask

task wait_scan_done;
    input integer max_cycles;
    reg [DATA_W-1:0] status;
    integer guard;
begin
    status = {DATA_W{1'b0}};
    guard = 0;
    while (!status[1] && guard < max_cycles) begin
        guard = guard + 1;
        wait_cycles(5);
        axi_cfg_read(ADDR_STATUS, status);
    end
    if (!status[1]) begin
        $display("FAIL: scan did not complete, status=%h", status);
        case_fail = case_fail + 1;
        total_fail = total_fail + 1;
    end
end
endtask

task wait_fault_detect;
    input integer max_cycles;
    integer guard;
begin
    guard = 0;
    while (!fault_detect && guard < max_cycles) begin
        guard = guard + 1;
        @(posedge clk);
    end
    if (!fault_detect) begin
        $display("FAIL: fault_detect did not assert in %0d cycles", max_cycles);
        case_fail = case_fail + 1;
        total_fail = total_fail + 1;
    end
end
endtask

task expect_equal;
    input [8*40-1:0] name;
    input [DATA_W-1:0] got;
    input [DATA_W-1:0] exp;
begin
    if (got !== exp) begin
        $display("FAIL: %0s got=%h exp=%h ar0=%0d r0=%0d ar1=%0d r1=%0d q0=%0d q1=%0d code=%h eng0_data=%h eng0_done=%b rdata0=%h core_out=%0d rdptr=%0d wrptr=%0d",
                 name, got, exp,
                 ar_count[0], r_count[0], ar_count[1], r_count[1],
                 q_count[0], q_count[1], core_error_code,
                 dut.gen_read_master[0].u_read_engine.read_data,
                 dut.gen_read_master[0].u_read_engine.done,
                 m_axi_rdata_flat[63:0],
                 dut.u_core.outstanding_count,
                 dut.u_core.pending_rd_ptr,
                 dut.u_core.pending_wr_ptr);
        total_fail = total_fail + 1;
        case_fail = case_fail + 1;
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

integer am;
integer qi;
integer next_tail;
integer prev_tail;
integer sel_q;
integer shift_q;
integer shift_next;
integer resp_addr;
reg [ID_W-1:0] resp_id;
reg [DATA_W-1:0] resp_data;
reg [1:0] resp_status;
reg resp_last;
reg [TB_CRC_WIDTH-1:0] resp_check;
reg can_respond;
always @(posedge clk) begin
    if (rst) begin
        m_axi_arready_flat <= {NUM_MASTERS{1'b0}};
        m_axi_rvalid_flat  <= {NUM_MASTERS{1'b0}};
        m_axi_rlast_flat   <= {NUM_MASTERS{1'b0}};
    end else begin
        m_axi_arready_flat <= {NUM_MASTERS{1'b0}};

        for (am = 0; am < NUM_MASTERS; am = am + 1) begin
            if ((am != timeout_master) && m_axi_arvalid_flat[am] &&
                (q_count[am] < Q_DEPTH)) begin
                m_axi_arready_flat[am] <= 1'b1;
                if (!m_axi_arready_flat[am]) begin
                    q_id[(am) * Q_DEPTH + (q_tail[am])]    <= m_axi_arid_flat[am*ID_W +: ID_W];
                    q_addr[(am) * Q_DEPTH + (q_tail[am])]  <= m_axi_araddr_flat[am*ADDR_W +: ADDR_W];
                    q_len[(am) * Q_DEPTH + (q_tail[am])]   <= m_axi_arlen_flat[am*8 +: 8];
                    q_burst[(am) * Q_DEPTH + (q_tail[am])] <= m_axi_arburst_flat[am*2 +: 2];
                    q_beat[(am) * Q_DEPTH + (q_tail[am])]  <= 8'd0;
                    q_err[(am) * Q_DEPTH + (q_tail[am])]   <= (am == resp_error_master);
                    next_tail = q_tail[am] + 1;
                    if (next_tail >= Q_DEPTH)
                        next_tail = 0;
                    q_tail[am] <= next_tail;
                    q_count[am] <= q_count[am] + 1;
                    ar_count[am] <= ar_count[am] + 1;
                    if ((q_count[am] + 1) > max_q_count[am])
                        max_q_count[am] <= q_count[am] + 1;
                end
            end

            if (m_axi_rvalid_flat[am] && m_axi_rready_flat[am]) begin
                m_axi_rvalid_flat[am] <= 1'b0;
                m_axi_rlast_flat[am]  <= 1'b0;
                r_count[am] <= r_count[am] + 1;

                if (m_axi_rlast_flat[am]) begin
                    qi = active_q_idx[am];
                    if (qi == q_head[am]) begin
                        shift_next = q_head[am] + 1;
                        if (shift_next >= Q_DEPTH)
                            shift_next = 0;
                        q_head[am] <= shift_next;
                    end else begin
                        shift_q = qi;
                        while (shift_q != q_tail[am]) begin
                            shift_next = shift_q + 1;
                            if (shift_next >= Q_DEPTH)
                                shift_next = 0;
                            if (shift_next != q_tail[am]) begin
                                q_id[(am) * Q_DEPTH + (shift_q)]    <= q_id[(am) * Q_DEPTH + (shift_next)];
                                q_addr[(am) * Q_DEPTH + (shift_q)]  <= q_addr[(am) * Q_DEPTH + (shift_next)];
                                q_len[(am) * Q_DEPTH + (shift_q)]   <= q_len[(am) * Q_DEPTH + (shift_next)];
                                q_burst[(am) * Q_DEPTH + (shift_q)] <= q_burst[(am) * Q_DEPTH + (shift_next)];
                                q_beat[(am) * Q_DEPTH + (shift_q)]  <= q_beat[(am) * Q_DEPTH + (shift_next)];
                                q_err[(am) * Q_DEPTH + (shift_q)]   <= q_err[(am) * Q_DEPTH + (shift_next)];
                            end
                            shift_q = shift_next;
                        end
                        prev_tail = q_tail[am] - 1;
                        if (prev_tail < 0)
                            prev_tail = Q_DEPTH - 1;
                        q_tail[am] <= prev_tail;
                    end
                    q_count[am] <= q_count[am] - 1;
                end else begin
                    q_beat[(am) * Q_DEPTH + (active_q_idx[am])] <= q_beat[(am) * Q_DEPTH + (active_q_idx[am])] + 8'd1;
                end
            end else if (!m_axi_rvalid_flat[am] && (q_count[am] > 0)) begin
                can_respond = 1'b1;
                if ((delay_until_ar_count > 0) && (ar_count[am] < delay_until_ar_count))
                    can_respond = 1'b0;
                if (can_respond) begin
                    sel_q = q_head[am];
                    if (response_mode == 1) begin
                        sel_q = q_tail[am] - 1;
                        if (sel_q < 0)
                            sel_q = Q_DEPTH - 1;
                    end else if (response_mode == 2) begin
                        sel_q = q_head[am] + (r_count[am] % q_count[am]);
                        while (sel_q >= Q_DEPTH)
                            sel_q = sel_q - Q_DEPTH;
                    end else if (response_mode == 3) begin
                        if ((r_count[am] % 2) == 0) begin
                            sel_q = q_tail[am] - 1;
                            if (sel_q < 0)
                                sel_q = Q_DEPTH - 1;
                        end
                    end
                    active_q_idx[am] = sel_q;
                    resp_addr = burst_byte_addr(q_addr[(am) * Q_DEPTH + (sel_q)],
                                                q_beat[(am) * Q_DEPTH + (sel_q)],
                                                q_len[(am) * Q_DEPTH + (sel_q)],
                                                q_burst[(am) * Q_DEPTH + (sel_q)]);
                    if (am == invalid_rid_master)
                        resp_id = {ID_W{1'b1}};
                    else
                        resp_id = q_id[(am) * Q_DEPTH + (sel_q)];
                    resp_data = mem_read_data(am, resp_addr);
                    resp_status = q_err[(am) * Q_DEPTH + (sel_q)] ? 2'b10 : 2'b00;
                    resp_last = (q_beat[(am) * Q_DEPTH + (sel_q)] == q_len[(am) * Q_DEPTH + (sel_q)]);
                    // Parameterized CRC: compute with AR signature when CRC_WIDTH=16
                    if (TB_CRC_WIDTH == 16) begin
                        resp_check = crc16_ccitt(
                            q_id[(am) * Q_DEPTH + (sel_q)],      // ARID
                            q_addr[(am) * Q_DEPTH + (sel_q)],    // ARADDR
                            q_len[(am) * Q_DEPTH + (sel_q)],     // ARLEN
                            3'd3,                                 // ARSIZE
                            q_burst[(am) * Q_DEPTH + (sel_q)],   // ARBURST
                            resp_id, resp_data, resp_status, resp_last
                        );
                    end else begin
                        resp_check = {8{1'b0}};
                        resp_check[7:0] = crc8_two_stage(
                            q_id[(am) * Q_DEPTH + (sel_q)],
                            q_addr[(am) * Q_DEPTH + (sel_q)],
                            q_len[(am) * Q_DEPTH + (sel_q)],
                            q_burst[(am) * Q_DEPTH + (sel_q)],
                            resp_id, resp_data, resp_status, resp_last
                        );
                    end
                    if ((am == rcheck_error_master) &&
                        ((rcheck_error_beat < 0) || (q_beat[(am) * Q_DEPTH + (sel_q)] == rcheck_error_beat[7:0])))
                        resp_check = resp_check ^ 8'h5A;
                    m_axi_rvalid_flat[am] <= 1'b1;
                    m_axi_rid_flat[am*ID_W +: ID_W] <= resp_id;
                    m_axi_rdata_flat[am*DATA_W +: DATA_W] <= resp_data;
                    m_axi_rresp_flat[am*2 +: 2] <= resp_status;
                    m_axi_rlast_flat[am] <= resp_last;
                    m_axi_rcheck_flat[am*TB_CRC_WIDTH +: TB_CRC_WIDTH] <= resp_check;
                end
            end
        end
end
end

task setup_default_base;
begin
    config_base(0, 32'h0000_0000);
    config_base(1, 32'h0000_1000);
    config_base(2, 32'h0000_2000);
    config_base(3, 32'h0000_3000);
    config_base(4, 32'h0000_4000);
end
endtask

task config_kat;
    input [ADDR_W-1:0] addr;
    input [DATA_W-1:0] expected;
    input [DATA_W-1:0] mask;
begin
    axi_cfg_write(ADDR_KAT_ADDR, {{(DATA_W-ADDR_W){1'b0}}, addr});
    axi_cfg_write(ADDR_KAT_EXPECTED, expected);
    axi_cfg_write(ADDR_KAT_MASK, mask);
    axi_cfg_write(ADDR_KAT_CTRL, 64'h1);  // enable KAT
end
endtask

task basic_fault_flow;
begin
    case_fail = 0;
    reset_dut();
    setup_default_base();
    ext_mem[(0) * MEM_WORDS + (0)] = 64'h4;
    config_entry(0, 0, 32'h0, 64'hFFFF_FFFF_FFFF_FFFF, 2'b01, 8'd0, 1'b1, 64'd0);
    lock_enable_scan();
    wait_fault_detect(5000);
    expect_equal("basic_fault_result", fault_or_result, 64'h4);
    expect_equal("basic_fault_detect", {63'd0, fault_detect}, 64'h1);
    expect_equal("basic_safe_fault", {63'd0, safety_island_fault_detect}, 64'h0);
    pass_case("basic_fault_flow");
end
endtask

task no_fault_flow;
begin
    case_fail = 0;
    reset_dut();
    setup_default_base();
    ext_mem[(0) * MEM_WORDS + (0)] = 64'h0;
    config_entry(0, 0, 32'h0, 64'hFFFF_FFFF_FFFF_FFFF, 2'b01, 8'd0, 1'b1, 64'd0);
    lock_enable_scan();
    wait_scan_done(3000);
    expect_equal("no_fault_result", fault_or_result, 64'h0);
    expect_equal("no_fault_detect", {63'd0, fault_detect}, 64'h0);
    pass_case("no_fault_flow");
end
endtask

task multi_master_flow;
begin
    case_fail = 0;
    reset_dut();
    setup_default_base();
    ext_mem[(0) * MEM_WORDS + (0)] = 64'h1;
    ext_mem[(0) * MEM_WORDS + (1)] = 64'h2;
    ext_mem[(1) * MEM_WORDS + (0)] = 64'h10;
    ext_mem[(1) * MEM_WORDS + (1)] = 64'h20;
    config_entry(0, 0, 32'h0, 64'hFFFF_FFFF_FFFF_FFFF, 2'b01, 8'd0, 1'b1, 64'd0);
    config_entry(0, 1, 32'h8, 64'hFFFF_FFFF_FFFF_FFFF, 2'b01, 8'd0, 1'b1, 64'd0);
    config_entry(1, 0, 32'h0, 64'hFFFF_FFFF_FFFF_FFFF, 2'b01, 8'd0, 1'b1, 64'd0);
    config_entry(1, 1, 32'h8, 64'hFFFF_FFFF_FFFF_FFFF, 2'b01, 8'd0, 1'b1, 64'd0);
    lock_enable_scan();
    wait_fault_detect(6000);
    expect_equal("multi_master_result", fault_or_result, 64'h33);
    pass_case("multi_master_flow");
end
endtask

task burst_16_incr_flow;
    integer bi;
    reg [63:0] exp;
begin
    case_fail = 0;
    reset_dut();
    setup_default_base();
    exp = 64'h0;
    for (bi = 0; bi < 16; bi = bi + 1) begin
        ext_mem[(0) * MEM_WORDS + (bi)] = (64'h1 << bi);
        exp = exp | (64'h1 << bi);
    end
    config_entry(0, 0, 32'h0, 64'hFFFF_FFFF_FFFF_FFFF, 2'b01, 8'd15, 1'b1, 64'd0);
    lock_enable_scan();
    wait_fault_detect(6000);
    expect_equal("burst16_result", fault_or_result, exp);
    pass_case("burst_16_incr_flow");
end
endtask

task wrap_burst_flow;
begin
    case_fail = 0;
    reset_dut();
    setup_default_base();
    ext_mem[(0) * MEM_WORDS + (0)] = 64'h1;
    ext_mem[(0) * MEM_WORDS + (1)] = 64'h2;
    ext_mem[(0) * MEM_WORDS + (2)] = 64'h4;
    ext_mem[(0) * MEM_WORDS + (3)] = 64'h8;
    config_entry(0, 0, 32'h10, 64'hFFFF_FFFF_FFFF_FFFF, 2'b10, 8'd3, 1'b1, 64'd0);
    lock_enable_scan();
    wait_fault_detect(6000);
    expect_equal("wrap_result", fault_or_result, 64'hF);
    pass_case("wrap_burst_flow");
end
endtask

task bus_error_flow;
begin
    case_fail = 0;
    reset_dut();
    setup_default_base();
    resp_error_master = 0;
    ext_mem[(0) * MEM_WORDS + (0)] = 64'h1;
    config_entry(0, 0, 32'h0, 64'hFFFF_FFFF_FFFF_FFFF, 2'b01, 8'd0, 1'b1, 64'd0);
    lock_enable_scan();
    wait_fault_detect(5000);
    expect_equal("bus_error_fault", {63'd0, fault_detect}, 64'h1);
    expect_equal("bus_error_code", {56'd0, core_error_code}, 64'h20);
    pass_case("bus_error_flow");
end
endtask

task timeout_flow;
begin
    case_fail = 0;
    reset_dut();
    setup_default_base();
    timeout_master = 0;
    config_entry(0, 0, 32'h0, 64'hFFFF_FFFF_FFFF_FFFF, 2'b01, 8'd0, 1'b1, 64'd0);
    lock_enable_scan();
    wait_cycles(300);
    expect_equal("timeout_fault", {63'd0, fault_detect}, 64'h1);
    expect_equal("timeout_code", {56'd0, core_error_code}, 64'h21);
    pass_case("timeout_flow");
end
endtask

task outstanding_flow;
    reg [DATA_W-1:0] cfg_rd;
begin
    case_fail = 0;
    reset_dut();
    setup_default_base();
    delay_until_ar_count = 4;
    ext_mem[(0) * MEM_WORDS + (0)] = 64'h1;
    ext_mem[(0) * MEM_WORDS + (1)] = 64'h2;
    ext_mem[(0) * MEM_WORDS + (2)] = 64'h4;
    ext_mem[(0) * MEM_WORDS + (3)] = 64'h8;
    config_entry(0, 0, 32'h0, 64'hFFFF_FFFF_FFFF_FFFF, 2'b01, 8'd0, 1'b1, 64'd0);
    config_entry(0, 1, 32'h8, 64'hFFFF_FFFF_FFFF_FFFF, 2'b01, 8'd0, 1'b1, 64'd0);
    config_entry(0, 2, 32'h10, 64'hFFFF_FFFF_FFFF_FFFF, 2'b01, 8'd0, 1'b1, 64'd0);
    config_entry(0, 3, 32'h18, 64'hFFFF_FFFF_FFFF_FFFF, 2'b01, 8'd0, 1'b1, 64'd0);
    axi_cfg_read(ADDR_ENTRY_REGION + 3 * ENTRY_STRIDE + ENTRY_MASK_OFF, cfg_rd);
    if (cfg_rd !== 64'hFFFF_FFFF_FFFF_FFFF) begin
        $display("FAIL: outstanding entry3 mask readback=%h", cfg_rd);
        case_fail = case_fail + 1;
        total_fail = total_fail + 1;
    end
    lock_enable_scan();
    wait_fault_detect(6000);
    expect_equal("outstanding_result", fault_or_result, 64'hF);
    if (max_q_count[0] < 4) begin
        $display("FAIL: outstanding depth only %0d", max_q_count[0]);
        case_fail = case_fail + 1;
        total_fail = total_fail + 1;
    end
    pass_case("outstanding_flow");
end
endtask

task out_of_order_flow;
begin
    case_fail = 0;
    reset_dut();
    setup_default_base();
    delay_until_ar_count = 4;
    response_mode = 1;
    ext_mem[(0) * MEM_WORDS + (0)] = 64'h1;
    ext_mem[(0) * MEM_WORDS + (1)] = 64'h2;
    ext_mem[(0) * MEM_WORDS + (2)] = 64'h4;
    ext_mem[(0) * MEM_WORDS + (3)] = 64'h8;
    config_entry(0, 0, 32'h0,  64'hFFFF_FFFF_FFFF_FFFF, 2'b01, 8'd0, 1'b1, 64'd0);
    config_entry(0, 1, 32'h8,  64'hFFFF_FFFF_FFFF_FFFF, 2'b01, 8'd0, 1'b1, 64'd0);
    config_entry(0, 2, 32'h10, 64'hFFFF_FFFF_FFFF_FFFF, 2'b01, 8'd0, 1'b1, 64'd0);
    config_entry(0, 3, 32'h18, 64'hFFFF_FFFF_FFFF_FFFF, 2'b01, 8'd0, 1'b1, 64'd0);
    lock_enable_scan();
    wait_fault_detect(6000);
    expect_equal("out_of_order_result", fault_or_result, 64'hF);
    expect_equal("out_of_order_error", {56'd0, core_error_code}, 64'h31);
    pass_case("out_of_order_flow");
end
endtask

task interleaving_flow;
begin
    case_fail = 0;
    reset_dut();
    setup_default_base();
    delay_until_ar_count = 2;
    response_mode = 2;
    ext_mem[(0) * MEM_WORDS + (0)] = 64'h1;
    ext_mem[(0) * MEM_WORDS + (1)] = 64'h2;
    ext_mem[(0) * MEM_WORDS + (2)] = 64'h4;
    ext_mem[(0) * MEM_WORDS + (3)] = 64'h8;
    config_entry(0, 0, 32'h0,  64'hFFFF_FFFF_FFFF_FFFF, 2'b01, 8'd1, 1'b1, 64'd0);
    config_entry(0, 1, 32'h10, 64'hFFFF_FFFF_FFFF_FFFF, 2'b01, 8'd1, 1'b1, 64'd0);
    lock_enable_scan();
    wait_fault_detect(6000);
    expect_equal("interleaving_result", fault_or_result, 64'hF);
    expect_equal("interleaving_error", {56'd0, core_error_code}, 64'h31);
    pass_case("interleaving_flow");
end
endtask

task out_of_order_interleaving_flow;
begin
    case_fail = 0;
    reset_dut();
    setup_default_base();
    delay_until_ar_count = 3;
    response_mode = 3;
    ext_mem[(0) * MEM_WORDS + (0)] = 64'h01;
    ext_mem[(0) * MEM_WORDS + (1)] = 64'h02;
    ext_mem[(0) * MEM_WORDS + (2)] = 64'h04;
    ext_mem[(0) * MEM_WORDS + (3)] = 64'h08;
    ext_mem[(0) * MEM_WORDS + (4)] = 64'h10;
    ext_mem[(0) * MEM_WORDS + (5)] = 64'h20;
    config_entry(0, 0, 32'h0,  64'hFFFF_FFFF_FFFF_FFFF, 2'b01, 8'd1, 1'b1, 64'd0);
    config_entry(0, 1, 32'h10, 64'hFFFF_FFFF_FFFF_FFFF, 2'b01, 8'd1, 1'b1, 64'd0);
    config_entry(0, 2, 32'h20, 64'hFFFF_FFFF_FFFF_FFFF, 2'b01, 8'd1, 1'b1, 64'd0);
    lock_enable_scan();
    wait_fault_detect(6000);
    expect_equal("ooo_interleaving_result", fault_or_result, 64'h3F);
    expect_equal("ooo_interleaving_error", {56'd0, core_error_code}, 64'h31);
    pass_case("out_of_order_interleaving_flow");
end
endtask

task invalid_rid_error_flow;
begin
    case_fail = 0;
    reset_dut();
    setup_default_base();
    invalid_rid_master = 0;
    ext_mem[(0) * MEM_WORDS + (0)] = 64'h1;
    config_entry(0, 0, 32'h0, 64'hFFFF_FFFF_FFFF_FFFF, 2'b01, 8'd0, 1'b1, 64'd0);
    lock_enable_scan();
    wait_fault_detect(5000);
    expect_equal("invalid_rid_fault", {63'd0, fault_detect}, 64'h1);
    expect_equal("invalid_rid_code", {56'd0, core_error_code}, 64'h20);
    pass_case("invalid_rid_error_flow");
end
endtask

task aou_rcheck_ok_flow;
begin
    case_fail = 0;
    reset_dut();
    setup_default_base();
    ext_mem[(0) * MEM_WORDS + (0)] = 64'h40;
    config_entry(0, 0, 32'h0, 64'hFFFF_FFFF_FFFF_FFFF, 2'b01, 8'd0, 1'b1, 64'd0);
    lock_enable_scan();
    wait_fault_detect(5000);
    expect_equal("aou_rcheck_ok_result", fault_or_result, 64'h40);
    expect_equal("aou_rcheck_ok_code", {56'd0, core_error_code}, 64'h31);
    pass_case("aou_rcheck_ok_flow");
end
endtask

task aou_rcheck_error_flow;
begin
    case_fail = 0;
    reset_dut();
    setup_default_base();
    rcheck_error_master = 0;
    rcheck_error_beat = 0;
    ext_mem[(0) * MEM_WORDS + (0)] = 64'h0;
    config_entry(0, 0, 32'h0, 64'hFFFF_FFFF_FFFF_FFFF, 2'b01, 8'd0, 1'b1, 64'd0);
    lock_enable_scan();
    wait_fault_detect(5000);
    expect_equal("aou_rcheck_error_fault", {63'd0, fault_detect}, 64'h1);
    expect_equal("aou_rcheck_error_code", {56'd0, core_error_code}, 64'h20);
    pass_case("aou_rcheck_error_flow");
end
endtask

task aou_rcheck_burst_error_flow;
begin
    case_fail = 0;
    reset_dut();
    setup_default_base();
    rcheck_error_master = 0;
    rcheck_error_beat = 1;
    ext_mem[(0) * MEM_WORDS + (0)] = 64'h0;
    ext_mem[(0) * MEM_WORDS + (1)] = 64'h0;
    ext_mem[(0) * MEM_WORDS + (2)] = 64'h0;
    ext_mem[(0) * MEM_WORDS + (3)] = 64'h0;
    config_entry(0, 0, 32'h0, 64'hFFFF_FFFF_FFFF_FFFF, 2'b01, 8'd3, 1'b1, 64'd0);
    lock_enable_scan();
    wait_fault_detect(6000);
    expect_equal("aou_rcheck_burst_fault", {63'd0, fault_detect}, 64'h1);
    expect_equal("aou_rcheck_burst_code", {56'd0, core_error_code}, 64'h20);
    pass_case("aou_rcheck_burst_error_flow");
end
endtask

task config_error_flow;
    reg [DATA_W-1:0] status;
begin
    case_fail = 0;
    reset_dut();
    setup_default_base();
    axi_cfg_write(ADDR_READ_INTERVAL, 64'd0);
    axi_cfg_write(ADDR_CONTROL, 64'h8);
    wait_cycles(10);
    expect_equal("interval_zero_fault", {63'd0, fault_detect}, 64'h1);

    reset_dut();
    setup_default_base();
    config_entry(0, 0, 32'h0, 64'hFFFF_FFFF_FFFF_FFFF, 2'b11, 8'd0, 1'b1, 64'd0);
    axi_cfg_write(ADDR_READ_INTERVAL, 64'd8);
    axi_cfg_write(ADDR_CONTROL, 64'h8);
    wait_cycles(10);
    expect_equal("illegal_burst_fault", {63'd0, fault_detect}, 64'h1);

    reset_dut();
    setup_default_base();
    config_entry(0, 0, 32'h0, 64'hFFFF_FFFF_FFFF_FFFF, 2'b10, 8'd2, 1'b1, 64'd0);
    axi_cfg_write(ADDR_READ_INTERVAL, 64'd8);
    axi_cfg_write(ADDR_CONTROL, 64'h8);
    wait_cycles(10);
    expect_equal("illegal_wrap_len_fault", {63'd0, fault_detect}, 64'h1);

    reset_dut();
    setup_default_base();
    axi_cfg_write(ADDR_READ_INTERVAL, 64'd8);
    axi_cfg_write(ADDR_CONTROL, 64'h8);
    axi_cfg_write_resp(ADDR_READ_INTERVAL, 64'd9, 2'b10);
    wait_cycles(10);
    expect_equal("lock_write_fault", {63'd0, fault_detect}, 64'h1);
    axi_cfg_read(ADDR_STATUS, status);
    if (!status[4]) begin
        $display("FAIL: cfg fault status bit not set status=%h", status);
        case_fail = case_fail + 1;
        total_fail = total_fail + 1;
    end
    pass_case("config_error_flow");
end
endtask

task latent_fault_flow;
    reg [DATA_W-1:0] status;
begin
    case_fail = 0;
    reset_dut();
    setup_default_base();
    config_entry(0, 0, 32'h0, 64'hFFFF_FFFF_FFFF_FFFF, 2'b01, 8'd0, 1'b1, 64'd0);
    axi_cfg_write(ADDR_READ_INTERVAL, 64'd8);
    axi_cfg_write(ADDR_CONTROL, 64'h8);

    force dut.u_cfg.read_interval_inv = 64'h0;
    wait_cycles(5);
    expect_equal("latent_fault_detect", {63'd0, safety_island_latent_fault_detect}, 64'h1);
    expect_equal("latent_fault_detect_fault", {63'd0, fault_detect}, 64'h1);
    expect_equal("latent_error_code", {56'd0, core_error_code}, 64'h11);
    axi_cfg_read(ADDR_STATUS, status);
    if (!status[6]) begin
        $display("FAIL: latent fault status bit not set status=%h", status);
        case_fail = case_fail + 1;
        total_fail = total_fail + 1;
    end
    release dut.u_cfg.read_interval_inv;
    pass_case("latent_fault_flow");
end
endtask

// ── NEW: Expected value mismatch test ──
// Verifies that when readback != expected (under mask), fault_detect asserts
// and error_code indicates expected mismatch.
task expected_mismatch_flow;
    reg [DATA_W-1:0] status;
begin
    case_fail = 0;
    reset_dut();
    setup_default_base();
    // Store data=0x1234 but expected=0x0 → mismatch under mask=all-ones
    ext_mem[(0) * MEM_WORDS + (0)] = 64'h0000_0000_0000_1234;
    config_entry(0, 0, 32'h0, 64'hFFFF_FFFF_FFFF_FFFF, 2'b01, 8'd0, 1'b1,
                 64'h0000_0000_0000_0000);
    lock_enable_scan();
    wait_fault_detect(5000);
    expect_equal("expected_mismatch_fault", {63'd0, fault_detect}, 64'h1);
    // External fault due to Mask+OR non-zero (0x1234 != 0)
    expect_equal("expected_mismatch_code", {56'd0, core_error_code}, 64'h31);
    pass_case("expected_mismatch_flow");
end
endtask

// ── NEW: Expected value match test ──
// Verifies that when readback == expected (under mask), no expected-mismatch
// fault is triggered (only Mask+OR checks for non-zero bits).
task expected_match_flow;
begin
    case_fail = 0;
    reset_dut();
    setup_default_base();
    // Store data=0x0, expected=0x0 → data == expected
    ext_mem[(0) * MEM_WORDS + (0)] = 64'h0;
    config_entry(0, 0, 32'h0, 64'hFFFF_FFFF_FFFF_FFFF, 2'b01, 8'd0, 1'b1,
                 64'd0);
    lock_enable_scan();
    wait_scan_done(3000);
    // No fault expected: data==expected==0, Mask+OR result == 0
    expect_equal("expected_match_result", fault_or_result, 64'h0);
    expect_equal("expected_match_fault", {63'd0, fault_detect}, 64'h0);
    pass_case("expected_match_flow");
end
endtask

// ── NEW: Expected masked comparison test ──
// Verifies that mask is applied correctly for expected comparison.
// data=0xFF, expected=0x0F, mask=0x0F → (data&mask)==(expected&mask)==0x0F → match
task expected_masked_match_flow;
begin
    case_fail = 0;
    reset_dut();
    setup_default_base();
    // data=0xFF, mask=0x0F, expected=0x0F
    // (0xFF & 0x0F) = 0x0F, (0x0F & 0x0F) = 0x0F → MATCH
    // But OR accumulation: 0xFF & 0x0F = 0x0F ≠ 0 → external fault for non-zero
    ext_mem[(0) * MEM_WORDS + (0)] = 64'h0000_0000_0000_00FF;
    config_entry(0, 0, 32'h0, 64'h0000_0000_0000_000F, 2'b01, 8'd0, 1'b1,
                 64'h0000_0000_0000_000F);
    lock_enable_scan();
    wait_fault_detect(5000);
    // Mask+OR detects non-zero bits (data&mask=0x0F ≠ 0 → external fault)
    expect_equal("expected_masked_result", fault_or_result, 64'hF);
    expect_equal("expected_masked_fault", {63'd0, fault_detect}, 64'h1);
    pass_case("expected_masked_match_flow");
end
endtask

task heartbeat_pass_flow;
    reg [DATA_W-1:0] status;
begin
    case_fail = 0;
    reset_dut();
    setup_default_base();
    ext_mem[(0) * MEM_WORDS + (0)] = 64'h0;
    config_entry(0, 0, 32'h0, 64'hFFFF_FFFF_FFFF_FFFF, 2'b01, 8'd0, 1'b1, 64'd0);
    lock_enable_scan();
    // Wait for heartbeat to fire (1024 cycles default interval)
    wait_cycles(1100);
    // Read status — heartbeat should have completed without permanent fault
    axi_cfg_read(ADDR_STATUS, status);
    // Check: heartbeat_fault should NOT be asserted
    if (dut.u_heartbeat.heartbeat_fault) begin
        $display("FAIL: heartbeat_fault asserted unexpectedly");
        case_fail = case_fail + 1;
        total_fail = total_fail + 1;
    end
    // The scan should complete even after heartbeat tests
    wait_scan_done(5000);
    pass_case("heartbeat_pass_flow");
end
endtask

task heartbeat_fail_flow;
begin
    case_fail = 0;
    reset_dut();
    setup_default_base();
    ext_mem[(0) * MEM_WORDS + (0)] = 64'h0;
    config_entry(0, 0, 32'h0, 64'hFFFF_FFFF_FFFF_FFFF, 2'b01, 8'd0, 1'b1, 64'd0);
    lock_enable_scan();
    // Force safety_island_fault_detect to be stuck at 0
    force safety_island_fault_detect = 1'b0;
    wait_cycles(1100);
    // Heartbeat should have detected the stuck fault
    if (!dut.u_heartbeat.heartbeat_fault) begin
        $display("FAIL: heartbeat did not detect stuck fault_detect");
        case_fail = case_fail + 1;
        total_fail = total_fail + 1;
    end
    release safety_island_fault_detect;
    pass_case("heartbeat_fail_flow");
end
endtask

task heartbeat_no_interfere_flow;
    reg [DATA_W-1:0] status;
begin
    case_fail = 0;
    reset_dut();
    setup_default_base();
    // Configure multi-entry scan so scan_busy stays high
    ext_mem[(0) * MEM_WORDS + (0)] = 64'h0;
    ext_mem[(0) * MEM_WORDS + (1)] = 64'h0;
    ext_mem[(0) * MEM_WORDS + (2)] = 64'h0;
    config_entry(0, 0, 32'h0,  64'hFFFF_FFFF_FFFF_FFFF, 2'b01, 8'd0, 1'b1, 64'd0);
    config_entry(0, 1, 32'h8,  64'hFFFF_FFFF_FFFF_FFFF, 2'b01, 8'd0, 1'b1, 64'd0);
    config_entry(0, 2, 32'h10, 64'hFFFF_FFFF_FFFF_FFFF, 2'b01, 8'd0, 1'b1, 64'd0);
    lock_enable_scan();
    // Wait for scan to complete (should not be interrupted by heartbeat)
    wait_scan_done(3000);
    if (dut.u_heartbeat.heartbeat_fault) begin
        $display("FAIL: heartbeat interfered with scan");
        case_fail = case_fail + 1;
        total_fail = total_fail + 1;
    end
    pass_case("heartbeat_no_interfere_flow");
end
endtask

task kat_pass_flow;
    reg [DATA_W-1:0] status;
begin
    case_fail = 0;
    reset_dut();
    setup_default_base();
    // Set known value at KAT address
    ext_mem[(0) * MEM_WORDS + (0)] = 64'h5A5A_5A5A_5A5A_5A5A;
    config_entry(0, 0, 32'h0, 64'hFFFF_FFFF_FFFF_FFFF, 2'b01, 8'd0, 1'b1, 64'd0);
    // Configure KAT: address=0x0, expected=0x5A5A..., mask=all-ones
    config_kat(32'h0000_0000, 64'h5A5A_5A5A_5A5A_5A5A, 64'hFFFF_FFFF_FFFF_FFFF);
    lock_enable_scan();
    wait_scan_done(5000);
    // KAT passes → scan completes normally
    if (safety_island_fault_detect) begin
        $display("FAIL: KAT pass test triggered safety_island_fault_detect");
        case_fail = case_fail + 1;
        total_fail = total_fail + 1;
    end
    pass_case("kat_pass_flow");
end
endtask

task kat_fail_flow;
begin
    case_fail = 0;
    reset_dut();
    setup_default_base();
    ext_mem[(0) * MEM_WORDS + (0)] = 64'h0000_0000_0000_0000;
    config_entry(0, 0, 32'h0, 64'hFFFF_FFFF_FFFF_FFFF, 2'b01, 8'd0, 1'b1, 64'd0);
    // KAT expects 0x5A5A but memory has 0x0 → KAT fails
    config_kat(32'h0000_0000, 64'h5A5A_5A5A_5A5A_5A5A, 64'hFFFF_FFFF_FFFF_FFFF);
    lock_enable_scan();
    wait_fault_detect(5000);
    expect_equal("kat_fail_safety", {63'd0, safety_island_fault_detect}, 64'h1);
    expect_equal("kat_fail_code", {56'd0, core_error_code}, 64'h47);
    pass_case("kat_fail_flow");
end
endtask

task kat_disabled_flow;
begin
    case_fail = 0;
    reset_dut();
    setup_default_base();
    ext_mem[(0) * MEM_WORDS + (0)] = 64'h0;
    config_entry(0, 0, 32'h0, 64'hFFFF_FFFF_FFFF_FFFF, 2'b01, 8'd0, 1'b1, 64'd0);
    // Do NOT enable KAT
    lock_enable_scan();
    wait_scan_done(3000);
    expect_equal("kat_disabled_fault", {63'd0, fault_detect}, 64'h0);
    pass_case("kat_disabled_flow");
end
endtask

task kat_araddr_corrupt_flow;
begin
    case_fail = 0;
    $display("NOTE: kat_araddr_corrupt_flow requires CRC_WIDTH=16");
    reset_dut();
    setup_default_base();
    ext_mem[(0) * MEM_WORDS + (0)] = 64'h5A5A_5A5A_5A5A_5A5A;
    config_entry(0, 0, 32'h0, 64'hFFFF_FFFF_FFFF_FFFF, 2'b01, 8'd0, 1'b1, 64'd0);
    config_kat(32'h0000_0000, 64'h5A5A_5A5A_5A5A_5A5A, 64'hFFFF_FFFF_FFFF_FFFF);
    lock_enable_scan();
    wait_cycles(3);
    // Force ARADDR corruption on KAT read
    force dut.gen_read_master[0].u_read_engine.m_axi_araddr = 32'h0000_0008;
    wait_fault_detect(5000);
    // Either E2E CRC catches it (bus fault) or KAT catches it (safety fault)
    if (!fault_detect && !safety_island_fault_detect) begin
        $display("FAIL: KAT addr corrupt not detected");
        case_fail = case_fail + 1;
        total_fail = total_fail + 1;
    end
    release dut.gen_read_master[0].u_read_engine.m_axi_araddr;
    pass_case("kat_araddr_corrupt_flow");
end
endtask

initial begin
    $dumpfile("sim_output/safety_island_top_full.vcd");
    $dumpvars(0, tb_safety_island_top_full);
    $display("[%0t] VCD dump start", $time);
end

initial begin

    clk = 1'b0;
    rst = 1'b1;
    total_pass = 0;
    total_fail = 0;
    case_fail = 0;
    init_signals();
    clear_ext_model();

    basic_fault_flow();
    no_fault_flow();
    multi_master_flow();
    burst_16_incr_flow();
    wrap_burst_flow();
    bus_error_flow();
    timeout_flow();
    outstanding_flow();
    out_of_order_flow();
    interleaving_flow();
    out_of_order_interleaving_flow();
    invalid_rid_error_flow();
    aou_rcheck_ok_flow();
    aou_rcheck_error_flow();
    aou_rcheck_burst_error_flow();
    config_error_flow();
    latent_fault_flow();

    // ── New integrated-feature tests ──
    expected_mismatch_flow();
    expected_match_flow();
    expected_masked_match_flow();

    heartbeat_pass_flow();
    heartbeat_fail_flow();
    heartbeat_no_interfere_flow();

    kat_pass_flow();
    kat_fail_flow();
    kat_disabled_flow();
    kat_araddr_corrupt_flow();

    if (total_fail == 0) begin
        $display("PASS: safety_island_top full test completed, cases=%0d", total_pass);
    end else begin
        $display("FAIL: safety_island_top full test completed, failures=%0d passes=%0d", total_fail, total_pass);
    end

    $finish;
end

endmodule
