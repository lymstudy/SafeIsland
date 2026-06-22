`timescale 1ns/1ps

module tb_safety_island_fault_injection;

localparam NUM_MASTERS     = 5;
localparam NUM_ENTRIES     = 64;
localparam ADDR_W          = 32;
localparam DATA_W          = 64;
localparam ID_W            = 4;
localparam MAX_OUTSTANDING = 4;

localparam [31:0] ADDR_CONTROL       = 32'h0000_0000;
localparam [31:0] ADDR_READ_INTERVAL = 32'h0000_0008;
localparam [31:0] ADDR_BASE_REGION   = 32'h0000_0100;
localparam [31:0] ADDR_ENTRY_REGION  = 32'h0000_1000;
localparam [31:0] ENTRY_OFFSET_OFF   = 32'h0000_0000;
localparam [31:0] ENTRY_MASK_OFF     = 32'h0000_0008;
localparam [31:0] ENTRY_BURST_OFF    = 32'h0000_0010;

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

safety_island_top #(
    .NUM_MASTERS(NUM_MASTERS),
    .NUM_ENTRIES(NUM_ENTRIES),
    .ADDR_W(ADDR_W),
    .DATA_W(DATA_W),
    .ID_W(ID_W),
    .MAX_OUTSTANDING(MAX_OUTSTANDING)
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
    .m_axi_rready_flat(m_axi_rready_flat),
    .fault_detect(fault_detect),
    .safety_island_fault_detect(safety_island_fault_detect),
    .safety_island_latent_fault_detect(safety_island_latent_fault_detect),
    .fault_or_result(fault_or_result),
    .core_error_code(core_error_code)
);

always #5 clk = ~clk;

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
        m_axi_rid_flat[ID_W-1:0] <= m_axi_arid_flat[ID_W-1:0];
        m_axi_rdata_flat[DATA_W-1:0] <= 64'd0;
        m_axi_rresp_flat[1:0] <= 2'b00;
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

task report_detected;
    input [8*48-1:0] name;
    input integer cycles;
begin
    total_cases = total_cases + 1;
    detected_cases = detected_cases + 1;
    $display("FI_DETECTED: %0s cycles=%0d code=%h fault=%b safety=%b latent=%b",
             name, cycles, core_error_code, fault_detect,
             safety_island_fault_detect, safety_island_latent_fault_detect);
end
endtask

task report_undetected;
    input [8*48-1:0] name;
begin
    total_cases = total_cases + 1;
    undetected_cases = undetected_cases + 1;
    $display("FI_UNDETECTED: %0s code=%h fault=%b safety=%b latent=%b",
             name, core_error_code, fault_detect,
             safety_island_fault_detect, safety_island_latent_fault_detect);
end
endtask

task expect_fault_within_10;
    input [8*48-1:0] name;
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
        report_detected(name, c);
    else
        report_undetected(name);
end
endtask

task run_cfg_shadow_stuck;
begin
    reset_dut();
    config_minimal();
    force dut.u_cfg.read_interval_inv = 64'h0;
    expect_fault_within_10("cfg_shadow_read_interval_stuck", 1'b1, 1'b0, 1'b1);
    release dut.u_cfg.read_interval_inv;
end
endtask

task run_core_state_inv_stuck;
begin
    reset_dut();
    config_minimal();
    force dut.u_core.state_inv = 4'h0;
    expect_fault_within_10("core_state_inv_stuck", 1'b0, 1'b1, 1'b1);
    release dut.u_core.state_inv;
end
endtask

task run_core_accum_inv_stuck;
begin
    reset_dut();
    config_minimal();
    force dut.u_core.fault_or_accum_inv = 64'h0;
    expect_fault_within_10("core_accum_inv_stuck", 1'b0, 1'b1, 1'b1);
    release dut.u_core.fault_or_accum_inv;
end
endtask

task run_pending_ptr_stuck;
begin
    reset_dut();
    config_minimal();
    force dut.u_core.pending_wr_ptr = 32'hFFFF_FFFF;
    expect_fault_within_10("pending_wr_ptr_stuck", 1'b0, 1'b1, 1'b1);
    release dut.u_core.pending_wr_ptr;
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
    expect_fault_within_10("transient_state_inv_flip", 1'b0, 1'b1, 1'b1);
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
        $display("FI_DETECTED: axi_timeout cycles=timeout_window code=%h", core_error_code);
    end else begin
        report_undetected("axi_timeout");
    end
    release m_axi_arready_flat[0];
    release m_axi_rvalid_flat[0];
end
endtask

initial begin
    clk = 1'b0;
    rst = 1'b1;
    total_cases = 0;
    corrected_cases = 0;
    detected_cases = 0;
    undetected_cases = 0;

    run_cfg_shadow_stuck();
    run_core_state_inv_stuck();
    run_core_accum_inv_stuck();
    run_pending_ptr_stuck();
    run_transient_state_inv_flip();
    run_axi_timeout_fault();

    $display("FI_SUMMARY: total=%0d corrected=%0d detected=%0d undetected=%0d",
             total_cases, corrected_cases, detected_cases, undetected_cases);

    if (undetected_cases == 0)
        $display("PASS: safety_island fault injection campaign completed");
    else
        $display("FAIL: safety_island fault injection campaign undetected=%0d", undetected_cases);
    $finish;
end

endmodule
