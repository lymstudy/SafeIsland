`timescale 1ns/1ps

module tb_safety_island_top_basic;

localparam NUM_MASTERS = 5;
localparam ADDR_W      = 32;
localparam DATA_W      = 64;
localparam ID_W        = 4;

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

reg pending_read0;
integer timeout_guard;
integer ar_count0;
integer r_count0;
integer done_count0;
reg [ADDR_W-1:0] last_araddr0;
reg last_safe_fault;

safety_island_top #(
    .NUM_MASTERS(NUM_MASTERS),
    .ADDR_W(ADDR_W),
    .DATA_W(DATA_W),
    .ID_W(ID_W),
    .TIMEOUT_CYCLES(32)
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

task axi_cfg_write;
    input [ADDR_W-1:0] addr;
    input [DATA_W-1:0] data;
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
        if (s_axi_bresp != 2'b00) begin
            $display("FAIL: config write addr=%h resp=%b", addr, s_axi_bresp);
            $finish;
        end
        @(negedge clk);
        s_axi_bready = 1'b0;
    end
endtask

always @(posedge clk) begin
    if (rst) begin
        pending_read0      <= 1'b0;
        ar_count0          <= 0;
        r_count0           <= 0;
        done_count0        <= 0;
        last_araddr0       <= {ADDR_W{1'b0}};
        last_safe_fault    <= 1'b0;
        m_axi_arready_flat <= {NUM_MASTERS{1'b0}};
        m_axi_rvalid_flat  <= {NUM_MASTERS{1'b0}};
        m_axi_rlast_flat   <= {NUM_MASTERS{1'b0}};
        m_axi_rresp_flat   <= {(NUM_MASTERS*2){1'b0}};
        m_axi_rdata_flat   <= {(NUM_MASTERS*DATA_W){1'b0}};
        m_axi_rid_flat     <= {(NUM_MASTERS*ID_W){1'b0}};
    end else begin
        m_axi_arready_flat <= {NUM_MASTERS{1'b0}};
        m_axi_rvalid_flat  <= {NUM_MASTERS{1'b0}};
        m_axi_rlast_flat   <= {NUM_MASTERS{1'b0}};

        if (m_axi_arvalid_flat[0]) begin
            m_axi_arready_flat[0] <= 1'b1;
            pending_read0 <= 1'b1;
            if (m_axi_arready_flat[0]) begin
                ar_count0    <= ar_count0 + 1;
                last_araddr0 <= m_axi_araddr_flat[ADDR_W-1:0];
            end
        end else if (pending_read0) begin
            m_axi_rvalid_flat[0] <= 1'b1;
            m_axi_rlast_flat[0]  <= 1'b1;
            m_axi_rresp_flat[1:0] <= 2'b00;
            m_axi_rid_flat[ID_W-1:0] <= m_axi_arid_flat[ID_W-1:0];
            m_axi_rdata_flat[DATA_W-1:0] <= 64'h0000_0000_0000_0004;
            if (m_axi_rready_flat[0]) begin
                r_count0 <= r_count0 + 1;
                pending_read0 <= 1'b0;
            end
        end

        if (dut.core_read_done[0])
            done_count0 <= done_count0 + 1;

        if (safety_island_fault_detect && !last_safe_fault) begin
            $display("DBG safe_fault_rise t=%0t state=%h state_inv=%h safety_fault=%b safety_q=%b safety_stable=%b safety_code_q=%h fsm_legal=%b inv_mismatch=%b cur_idx=%b pend_idx=%b ptr=%b valid=%b accum=%b out=%b err=%h",
                     $time,
                     dut.u_core.state,
                     dut.u_core.state_inv,
                     dut.u_core.safety_fault_comb,
                     dut.u_core.safety_fault_q,
                     dut.u_core.safety_fault_stable_comb,
                     dut.u_core.safety_error_code_q,
                     dut.u_core.fsm_state_legal_comb,
                     dut.u_core.state_inv_mismatch_comb,
                     dut.u_core.current_index_fault_comb,
                     dut.u_core.pending_index_fault_comb,
                     dut.u_core.pending_ptr_fault_comb,
                     dut.u_core.pending_valid_fault_comb,
                     dut.u_core.accum_shadow_fault_comb,
                     dut.u_core.outstanding_fault_comb,
                     core_error_code);
        end
        last_safe_fault <= safety_island_fault_detect;
    end
end

initial begin
    clk = 1'b0;
    rst = 1'b1;
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

    repeat (5) @(posedge clk);
    rst = 1'b0;
    repeat (2) @(posedge clk);

    axi_cfg_write(32'h0000_0008, 64'd4);
    axi_cfg_write(32'h0000_0100, 64'h0000_0000_0000_0000);
    axi_cfg_write(32'h0000_1000, 64'h0000_0000_0000_0000);
    axi_cfg_write(32'h0000_1008, 64'hFFFF_FFFF_FFFF_FFFF);
    axi_cfg_write(32'h0000_1010, 64'h0000_0000_0001_0001);
    axi_cfg_write(32'h0000_0000, 64'h0000_0000_0000_000B);

    timeout_guard = 0;
    while (!fault_detect && timeout_guard < 2000) begin
        timeout_guard = timeout_guard + 1;
        @(posedge clk);
    end

    if (!fault_detect) begin
        $display("FAIL: fault_detect did not assert");
        $display("DBG state=%h master=%0d entry=%0d busy=%b done=%b ext=%b bus=%b cfg=%b safe=%b err=%h fault_or=%h",
                 dut.u_core.state,
                 dut.current_master_idx,
                 dut.current_entry_idx,
                 dut.scan_busy,
                 dut.scan_done_pulse,
                 dut.external_fault_event,
                 dut.bus_fault_event,
                 dut.cfg_fault_event,
                 dut.safety_island_fault_event,
                 core_error_code,
                 fault_or_result);
        $display("DBG req=%b accept=%b done=%b arvalid=%b arready=%b rvalid=%b rready=%b",
                 dut.core_read_req,
                 dut.core_read_accept,
                 dut.core_read_done,
                 m_axi_arvalid_flat,
                 m_axi_arready_flat,
                 m_axi_rvalid_flat,
                 m_axi_rready_flat);
        $display("DBG safety fsm_legal=%b state_inv_mismatch=%b cur_idx_fault=%b pending_idx_fault=%b ptr_fault=%b valid_fault=%b accum_fault=%b outstanding_fault=%b safety_fault=%b state_inv=%h",
                 dut.u_core.fsm_state_legal_comb,
                 dut.u_core.state_inv_mismatch_comb,
                 dut.u_core.current_index_fault_comb,
                 dut.u_core.pending_index_fault_comb,
                 dut.u_core.pending_ptr_fault_comb,
                 dut.u_core.pending_valid_fault_comb,
                 dut.u_core.accum_shadow_fault_comb,
                 dut.u_core.outstanding_fault_comb,
                 dut.u_core.safety_fault_comb,
                 dut.u_core.state_inv);
        $display("DBG cfg enable=%b valid=%b locked=%b illegal=%b shadow=%b operational=%b interval=%0d counter=%0d scan_start=%b once_pending=%b once_re=%b",
                 dut.cfg_enable,
                 dut.cfg_valid,
                 dut.cfg_locked,
                 dut.cfg_illegal,
                 dut.cfg_shadow_error,
                 dut.u_core.cfg_operational,
                 dut.cfg_read_interval,
                 dut.u_core.interval_counter,
                 dut.u_core.scan_start_comb,
                 dut.u_core.scan_once_pending,
                 dut.u_core.scan_once_re);
        $display("DBG entry0 valid=%b burst_type=%b burst_len=%0d base=%h offset=%h mask=%h curr_valid=%b curr_burst_ok=%b",
                 dut.cfg_entry_valid_flat[0],
                 dut.cfg_burst_type_flat[1:0],
                 dut.cfg_burst_len_flat[7:0],
                 dut.cfg_base_addr_flat[31:0],
                 dut.cfg_offset_flat[31:0],
                 dut.cfg_mask_flat[63:0],
                 dut.u_core.current_entry_valid,
                 dut.u_core.current_burst_cfg_legal);
        $display("DBG core_idx master_h=%h entry_h=%h curr_type=%b curr_len=%h curr_base=%h curr_offset=%h curr_addr=%h curr_mask=%h",
                 dut.u_core.current_master_idx,
                 dut.u_core.current_entry_idx,
                 dut.u_core.current_burst_type,
                 dut.u_core.current_burst_len,
                 dut.u_core.current_base_addr,
                 dut.u_core.current_offset,
                 dut.u_core.current_read_addr,
                 dut.u_core.current_mask);
        $display("DBG core_ports base0=%h offset0=%h mask0=%h type0=%b len0=%h valid0=%b",
                 dut.u_core.base_addr_flat[31:0],
                 dut.u_core.offset_flat[31:0],
                 dut.u_core.mask_flat[63:0],
                 dut.u_core.burst_type_flat[1:0],
                 dut.u_core.burst_len_flat[7:0],
                 dut.u_core.entry_valid_flat[0]);
        $display("DBG axi_counts ar=%0d r=%0d done=%0d last_araddr=%h core_data0=%h",
                 ar_count0,
                 r_count0,
                 done_count0,
                 last_araddr0,
                 dut.core_read_data_flat[63:0]);
        $finish;
    end

    if (fault_or_result !== 64'h0000_0000_0000_0004) begin
        $display("FAIL: fault_or_result=%h", fault_or_result);
        $finish;
    end

    if (safety_island_fault_detect) begin
        $display("FAIL: safety_island_fault_detect asserted, code=%h", core_error_code);
        $finish;
    end

    $display("PASS: safety_island_top basic config/read/fault flow");
    $finish;
end

endmodule
