`timescale 1ns/1ps

module safety_island_top #(
    parameter NUM_MASTERS         = 5,
    parameter NUM_ENTRIES         = 64,
    parameter ADDR_W              = 32,
    parameter DATA_W              = 64,
    parameter ID_W                = 4,
    parameter TIMEOUT_CYCLES      = 1024,
    parameter SUPPORT_OUTSTANDING = 1,
    parameter MAX_OUTSTANDING     = 4
) (
    input  wire                                      clk,
    input  wire                                      rst,

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
    output wire [NUM_MASTERS-1:0]                    m_axi_rready_flat,

    output wire                                      fault_detect,
    output wire                                      safety_island_fault_detect,
    output wire                                      safety_island_latent_fault_detect,
    output wire [DATA_W-1:0]                         fault_or_result,
    output wire [7:0]                                core_error_code
);

localparam [2:0] AXI_SIZE = (DATA_W == 64) ? 3'd3 : 3'd2;

wire                                      cfg_enable;
wire                                      cfg_scan_once;
wire                                      cfg_clear_core_status;
wire [63:0]                               cfg_read_interval;
wire [NUM_MASTERS*ADDR_W-1:0]             cfg_base_addr_flat;
wire [NUM_MASTERS*NUM_ENTRIES*ADDR_W-1:0] cfg_offset_flat;
wire [NUM_MASTERS*NUM_ENTRIES*DATA_W-1:0] cfg_mask_flat;
wire [NUM_MASTERS*NUM_ENTRIES*2-1:0]      cfg_burst_type_flat;
wire [NUM_MASTERS*NUM_ENTRIES*8-1:0]      cfg_burst_len_flat;
wire [NUM_MASTERS*NUM_ENTRIES-1:0]        cfg_entry_valid_flat;
wire                                      cfg_valid;
wire                                      cfg_locked;
wire                                      cfg_illegal;
wire                                      cfg_shadow_error;

wire [NUM_MASTERS-1:0]                    core_read_req;
wire [NUM_MASTERS*ADDR_W-1:0]             core_read_addr_flat;
wire [NUM_MASTERS*2-1:0]                  core_burst_type_flat;
wire [NUM_MASTERS*8-1:0]                  core_burst_len_flat;
wire [NUM_MASTERS-1:0]                    core_read_accept;
wire [NUM_MASTERS-1:0]                    core_read_done;
wire [NUM_MASTERS*DATA_W-1:0]             core_read_data_flat;
wire [NUM_MASTERS-1:0]                    core_resp_error;
wire [NUM_MASTERS-1:0]                    core_timeout;

wire                                      scan_busy;
wire                                      scan_done_pulse;
wire [31:0]                               current_master_idx;
wire [31:0]                               current_entry_idx;
wire                                      external_fault_event;
wire                                      bus_fault_event;
wire                                      cfg_fault_event;
wire                                      safety_island_fault_event;
wire                                      safety_island_latent_fault_event;
wire [31:0]                               outstanding_count;

wire [NUM_MASTERS-1:0]                    cmd_ready_flat;
wire [NUM_MASTERS-1:0]                    axi_done_flat;
wire [NUM_MASTERS-1:0]                    axi_error_flat;
wire [NUM_MASTERS-1:0]                    axi_timeout_flat;
wire [NUM_MASTERS*DATA_W-1:0]             axi_read_data_flat;

assign fault_detect = external_fault_event | bus_fault_event | cfg_fault_event;
assign safety_island_fault_detect = safety_island_fault_event;
assign safety_island_latent_fault_event = cfg_shadow_error |
                                          safety_island_fault_event;
assign safety_island_latent_fault_detect = safety_island_latent_fault_event;

safety_island_axi_config_slave #(
    .NUM_MASTERS(NUM_MASTERS),
    .NUM_ENTRIES(NUM_ENTRIES),
    .ADDR_W(ADDR_W),
    .DATA_W(DATA_W),
    .ID_W(ID_W)
) u_cfg (
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
    .enable(cfg_enable),
    .scan_once(cfg_scan_once),
    .clear_core_status(cfg_clear_core_status),
    .read_interval(cfg_read_interval),
    .base_addr_flat(cfg_base_addr_flat),
    .offset_flat(cfg_offset_flat),
    .mask_flat(cfg_mask_flat),
    .burst_type_flat(cfg_burst_type_flat),
    .burst_len_flat(cfg_burst_len_flat),
    .entry_valid_flat(cfg_entry_valid_flat),
    .cfg_valid(cfg_valid),
    .cfg_locked(cfg_locked),
    .cfg_illegal(cfg_illegal),
    .cfg_shadow_error(cfg_shadow_error),
    .scan_busy(scan_busy),
    .scan_done_pulse(scan_done_pulse),
    .current_master_idx(current_master_idx),
    .current_entry_idx(current_entry_idx),
    .fault_or_result(fault_or_result),
    .external_fault_event(external_fault_event),
    .bus_fault_event(bus_fault_event),
    .cfg_fault_event(cfg_fault_event),
    .safety_island_fault_event(safety_island_fault_event),
    .safety_island_latent_fault_event(safety_island_latent_fault_event),
    .core_error_code(core_error_code),
    .outstanding_count(outstanding_count)
);

safety_island_core_logic #(
    .NUM_MASTERS(NUM_MASTERS),
    .NUM_ENTRIES(NUM_ENTRIES),
    .ADDR_W(ADDR_W),
    .DATA_W(DATA_W),
    .BURST_TYPE_W(2),
    .BURST_LEN_W(8),
    .SUPPORT_OUTSTANDING(SUPPORT_OUTSTANDING),
    .MAX_OUTSTANDING(MAX_OUTSTANDING)
) u_core (
    .clk(clk),
    .rst(rst),
    .enable(cfg_enable),
    .scan_once(cfg_scan_once),
    .clear_core_status(cfg_clear_core_status),
    .read_interval(cfg_read_interval),
    .base_addr_flat(cfg_base_addr_flat),
    .offset_flat(cfg_offset_flat),
    .mask_flat(cfg_mask_flat),
    .burst_type_flat(cfg_burst_type_flat),
    .burst_len_flat(cfg_burst_len_flat),
    .entry_valid_flat(cfg_entry_valid_flat),
    .cfg_valid(cfg_valid),
    .cfg_locked(cfg_locked),
    .cfg_illegal(cfg_illegal),
    .cfg_shadow_error(cfg_shadow_error),
    .m_read_req(core_read_req),
    .m_read_addr_flat(core_read_addr_flat),
    .m_burst_type_flat(core_burst_type_flat),
    .m_burst_len_flat(core_burst_len_flat),
    .m_read_accept(core_read_accept),
    .m_read_done(core_read_done),
    .m_read_data_flat(core_read_data_flat),
    .m_resp_error(core_resp_error),
    .m_timeout(core_timeout),
    .scan_busy(scan_busy),
    .scan_done_pulse(scan_done_pulse),
    .current_master_idx(current_master_idx),
    .current_entry_idx(current_entry_idx),
    .fault_or_result(fault_or_result),
    .external_fault_event(external_fault_event),
    .bus_fault_event(bus_fault_event),
    .cfg_fault_event(cfg_fault_event),
    .safety_island_fault_event(safety_island_fault_event),
    .core_error_code(core_error_code),
    .outstanding_count(outstanding_count)
);

genvar mi;
generate
    for (mi = 0; mi < NUM_MASTERS; mi = mi + 1) begin : gen_read_master
        localparam [ID_W-1:0] MASTER_ID = mi;

        reg [DATA_W-1:0] rsp_data_q    [0:MAX_OUTSTANDING-1];
        reg              rsp_error_q   [0:MAX_OUTSTANDING-1];
        reg              rsp_timeout_q [0:MAX_OUTSTANDING-1];
        reg [31:0]       rsp_wr_ptr;
        reg [31:0]       rsp_rd_ptr;
        reg [31:0]       rsp_count;
        reg              rsp_valid_out;
        reg [DATA_W-1:0] rsp_data_out;
        reg              rsp_error_out;
        reg              rsp_timeout_out;
        integer          rsp_i;

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
                rsp_valid_out   <= 1'b0;
                rsp_data_out    <= {DATA_W{1'b0}};
                rsp_error_out   <= 1'b0;
                rsp_timeout_out <= 1'b0;

                for (rsp_i = 0; rsp_i < MAX_OUTSTANDING; rsp_i = rsp_i + 1) begin
                    rsp_data_q[rsp_i]    <= {DATA_W{1'b0}};
                    rsp_error_q[rsp_i]   <= 1'b0;
                    rsp_timeout_q[rsp_i] <= 1'b0;
                end
            end else begin
                rsp_valid_out <= 1'b0;

                if (rsp_count != 32'd0) begin
                    rsp_valid_out   <= 1'b1;
                    rsp_data_out    <= rsp_data_q[rsp_rd_ptr];
                    rsp_error_out   <= rsp_error_q[rsp_rd_ptr];
                    rsp_timeout_out <= rsp_timeout_q[rsp_rd_ptr];

                    if (rsp_rd_ptr >= (MAX_OUTSTANDING - 1))
                        rsp_rd_ptr <= 32'd0;
                    else
                        rsp_rd_ptr <= rsp_rd_ptr + 32'd1;
                end

                if (axi_done_flat[mi] || axi_error_flat[mi] || axi_timeout_flat[mi]) begin
                    rsp_data_q[rsp_wr_ptr]    <= axi_read_data_flat[mi*DATA_W +: DATA_W];
                    rsp_error_q[rsp_wr_ptr]   <= axi_error_flat[mi] & ~axi_timeout_flat[mi];
                    rsp_timeout_q[rsp_wr_ptr] <= axi_timeout_flat[mi];

                    if (rsp_wr_ptr >= (MAX_OUTSTANDING - 1))
                        rsp_wr_ptr <= 32'd0;
                    else
                        rsp_wr_ptr <= rsp_wr_ptr + 32'd1;
                end

                if ((rsp_count != 32'd0) &&
                    (axi_done_flat[mi] || axi_error_flat[mi] || axi_timeout_flat[mi])) begin
                    rsp_count <= rsp_count;
                end else if (rsp_count != 32'd0) begin
                    rsp_count <= rsp_count - 32'd1;
                end else if (axi_done_flat[mi] || axi_error_flat[mi] || axi_timeout_flat[mi]) begin
                    rsp_count <= rsp_count + 32'd1;
                end
            end
        end

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
            .ADDR_WIDTH(ADDR_W),
            .DATA_WIDTH(DATA_W),
            .ID_WIDTH(ID_W),
            .TIMEOUT_CYCLES(TIMEOUT_CYCLES),
            .MAX_OUTSTANDING(MAX_OUTSTANDING)
        ) u_read_engine (
            .clk(clk),
            .rst(rst),
            .cmd_valid(core_read_req[mi]),
            .cmd_ready(cmd_ready_flat[mi]),
            .cmd_id(MASTER_ID),
            .cmd_addr(core_read_addr_flat[mi*ADDR_W +: ADDR_W]),
            .cmd_len(core_burst_len_flat[mi*8 +: 8]),
            .cmd_size(AXI_SIZE),
            .cmd_burst(core_burst_type_flat[mi*2 +: 2]),
            .done(axi_done_flat[mi]),
            .error(axi_error_flat[mi]),
            .timeout(axi_timeout_flat[mi]),
            .read_data(axi_read_data_flat[mi*DATA_W +: DATA_W]),
            .m_axi_arid(m_axi_arid_flat[mi*ID_W +: ID_W]),
            .m_axi_araddr(m_axi_araddr_flat[mi*ADDR_W +: ADDR_W]),
            .m_axi_arlen(m_axi_arlen_flat[mi*8 +: 8]),
            .m_axi_arsize(m_axi_arsize_flat[mi*3 +: 3]),
            .m_axi_arburst(m_axi_arburst_flat[mi*2 +: 2]),
            .m_axi_arlock(m_axi_arlock_flat[mi]),
            .m_axi_arcache(m_axi_arcache_flat[mi*4 +: 4]),
            .m_axi_arprot(m_axi_arprot_flat[mi*3 +: 3]),
            .m_axi_arqos(m_axi_arqos_flat[mi*4 +: 4]),
            .m_axi_arvalid(m_axi_arvalid_flat[mi]),
            .m_axi_arready(m_axi_arready_flat[mi]),
            .m_axi_rid(m_axi_rid_flat[mi*ID_W +: ID_W]),
            .m_axi_rdata(m_axi_rdata_flat[mi*DATA_W +: DATA_W]),
            .m_axi_rresp(m_axi_rresp_flat[mi*2 +: 2]),
            .m_axi_rlast(m_axi_rlast_flat[mi]),
            .m_axi_rvalid(m_axi_rvalid_flat[mi]),
            .m_axi_rready(m_axi_rready_flat[mi])
        );
    end
endgenerate

endmodule
