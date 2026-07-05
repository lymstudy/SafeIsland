`timescale 1ns/1ps

module safety_island_axi_config_slave #(
    parameter NUM_MASTERS = 5,
    parameter NUM_ENTRIES = 64,
    parameter ADDR_W      = 32,
    parameter DATA_W      = 64,
    parameter ID_W        = 4
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
    output reg                                       s_axi_awready,

    input  wire [DATA_W-1:0]                         s_axi_wdata,
    input  wire [(DATA_W/8)-1:0]                     s_axi_wstrb,
    input  wire                                      s_axi_wlast,
    input  wire                                      s_axi_wvalid,
    output reg                                       s_axi_wready,

    output reg  [ID_W-1:0]                           s_axi_bid,
    output reg  [1:0]                                s_axi_bresp,
    output reg                                       s_axi_bvalid,
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
    output reg                                       s_axi_arready,

    output reg  [ID_W-1:0]                           s_axi_rid,
    output reg  [DATA_W-1:0]                         s_axi_rdata,
    output reg  [1:0]                                s_axi_rresp,
    output reg                                       s_axi_rlast,
    output reg                                       s_axi_rvalid,
    input  wire                                      s_axi_rready,

    output reg                                       enable,
    output reg                                       scan_once,
    output reg                                       clear_core_status,
    output reg  [63:0]                               read_interval,
    output reg  [NUM_MASTERS*ADDR_W-1:0]             base_addr_flat,
    output reg  [NUM_MASTERS*NUM_ENTRIES*ADDR_W-1:0] offset_flat,
    output reg  [NUM_MASTERS*NUM_ENTRIES*DATA_W-1:0] mask_flat,
    output reg  [NUM_MASTERS*NUM_ENTRIES*2-1:0]      burst_type_flat,
    output reg  [NUM_MASTERS*NUM_ENTRIES*8-1:0]      burst_len_flat,
    output reg  [NUM_MASTERS*NUM_ENTRIES-1:0]        entry_valid_flat,
    output reg  [NUM_MASTERS*NUM_ENTRIES*DATA_W-1:0] expected_flat,
    output wire                                      cfg_valid,
    output wire                                      cfg_locked,
    output wire                                      cfg_illegal,
    output wire                                      cfg_shadow_error,
    output reg                                       kat_enable_out,
    output reg  [ADDR_W-1:0]                         kat_addr_out,
    output reg  [DATA_W-1:0]                         kat_expected_out,
    output reg  [DATA_W-1:0]                         kat_mask_out,

    input  wire                                      scan_busy,
    input  wire                                      scan_done_pulse,
    input  wire [31:0]                               current_master_idx,
    input  wire [31:0]                               current_entry_idx,
    input  wire [DATA_W-1:0]                         fault_or_result,
    input  wire                                      external_fault_event,
    input  wire                                      bus_fault_event,
    input  wire                                      cfg_fault_event,
    input  wire                                      safety_island_fault_event,
    input  wire                                      safety_island_latent_fault_event,
    input  wire [7:0]                                core_error_code,
    input  wire [31:0]                               outstanding_count
);

localparam [1:0] RESP_OKAY   = 2'b00;
localparam [1:0] RESP_SLVERR = 2'b10;

localparam [ADDR_W-1:0] ADDR_CONTROL       = 32'h0000_0000;
localparam [ADDR_W-1:0] ADDR_READ_INTERVAL = 32'h0000_0008;
localparam [ADDR_W-1:0] ADDR_STATUS        = 32'h0000_0010;
localparam [ADDR_W-1:0] ADDR_FAULT_RESULT  = 32'h0000_0018;
localparam [ADDR_W-1:0] ADDR_ERROR_CODE    = 32'h0000_0020;
localparam [ADDR_W-1:0] ADDR_INDEX_STATUS  = 32'h0000_0028;
localparam [ADDR_W-1:0] ADDR_OUTSTANDING   = 32'h0000_0030;
localparam [ADDR_W-1:0] ADDR_BASE_REGION   = 32'h0000_0100;
localparam [ADDR_W-1:0] ADDR_ENTRY_REGION  = 32'h0000_1000;
localparam [ADDR_W-1:0] BASE_STRIDE        = 32'h0000_0008;
localparam [ADDR_W-1:0] ENTRY_MASTER_STRIDE= 32'h0000_1000;
localparam [ADDR_W-1:0] ENTRY_STRIDE       = 32'h0000_0020;
localparam [ADDR_W-1:0] ENTRY_OFFSET_OFF   = 32'h0000_0000;
localparam [ADDR_W-1:0] ENTRY_MASK_OFF     = 32'h0000_0008;
localparam [ADDR_W-1:0] ENTRY_BURST_OFF    = 32'h0000_0010;
localparam [ADDR_W-1:0] ENTRY_EXPECTED_OFF = 32'h0000_0018;
localparam [ADDR_W-1:0] ADDR_KAT_CTRL     = 32'h0000_0038;
localparam [ADDR_W-1:0] ADDR_KAT_ADDR     = 32'h0000_0040;
localparam [ADDR_W-1:0] ADDR_KAT_EXPECTED = 32'h0000_0048;
localparam [ADDR_W-1:0] ADDR_KAT_MASK     = 32'h0000_0050;

localparam integer TOTAL_ENTRIES = NUM_MASTERS * NUM_ENTRIES;
localparam integer SCRUB_IDX_W   = (TOTAL_ENTRIES <= 256) ? 9 : 10;

reg [ADDR_W-1:0] awaddr_q;
reg [ID_W-1:0]   awid_q;
reg [7:0]        awlen_q;
reg [2:0]        awsize_q;
reg [1:0]        awburst_q;
reg              aw_seen_q;
reg [DATA_W-1:0] wdata_q;
reg [(DATA_W/8)-1:0] wstrb_q;
reg              wlast_q;
reg              w_seen_q;

// ─── Control TMR replicas ───
reg enable_a, enable_b, enable_c;
wire enable_voted;
wire enable_tmr_mismatch;

assign enable_voted = (enable_a & enable_b) | (enable_b & enable_c) | (enable_a & enable_c);
assign enable_tmr_mismatch = (enable_a ^ enable_b) | (enable_a ^ enable_c) | (enable_b ^ enable_c);

reg cfg_locked_r_a, cfg_locked_r_b, cfg_locked_r_c;
wire cfg_locked_r;
wire cfg_locked_tmr_mismatch;

assign cfg_locked_r = (cfg_locked_r_a & cfg_locked_r_b) |
                      (cfg_locked_r_b & cfg_locked_r_c) |
                      (cfg_locked_r_a & cfg_locked_r_c);
assign cfg_locked_tmr_mismatch = (cfg_locked_r_a ^ cfg_locked_r_b) |
                                 (cfg_locked_r_a ^ cfg_locked_r_c) |
                                 (cfg_locked_r_b ^ cfg_locked_r_c);

reg cfg_illegal_r_a, cfg_illegal_r_b, cfg_illegal_r_c;
wire cfg_illegal_r;
wire cfg_illegal_tmr_mismatch;

assign cfg_illegal_r = (cfg_illegal_r_a & cfg_illegal_r_b) |
                       (cfg_illegal_r_b & cfg_illegal_r_c) |
                       (cfg_illegal_r_a & cfg_illegal_r_c);
assign cfg_illegal_tmr_mismatch = (cfg_illegal_r_a ^ cfg_illegal_r_b) |
                                  (cfg_illegal_r_a ^ cfg_illegal_r_c) |
                                  (cfg_illegal_r_b ^ cfg_illegal_r_c);

reg scan_done_sticky_a, scan_done_sticky_b, scan_done_sticky_c;
wire scan_done_sticky_voted;
wire scan_done_sticky_tmr_mismatch;

assign scan_done_sticky_voted = (scan_done_sticky_a & scan_done_sticky_b) |
                                (scan_done_sticky_b & scan_done_sticky_c) |
                                (scan_done_sticky_a & scan_done_sticky_c);
assign scan_done_sticky_tmr_mismatch = (scan_done_sticky_a ^ scan_done_sticky_b) |
                                       (scan_done_sticky_a ^ scan_done_sticky_c) |
                                       (scan_done_sticky_b ^ scan_done_sticky_c);

reg write_verify_pending;

reg enable_inv;
reg cfg_locked_inv;
reg cfg_illegal_inv;

// ─── read_interval TMR ───
reg [63:0] read_interval_a, read_interval_b, read_interval_c;
wire [63:0] read_interval_voted;
wire read_interval_tmr_mismatch;

assign read_interval_voted = (read_interval_a & read_interval_b) |
                             (read_interval_b & read_interval_c) |
                             (read_interval_a & read_interval_c);
assign read_interval_tmr_mismatch = (read_interval_a ^ read_interval_b) |
                                    (read_interval_a ^ read_interval_c) |
                                    (read_interval_b ^ read_interval_c);
reg [63:0] read_interval_inv;
reg        read_interval_sig;

// ─── Config table TMR ───
(* DONT_TOUCH = "TRUE" *) reg [ADDR_W-1:0] base_addr_q_a     [0:NUM_MASTERS-1];
(* DONT_TOUCH = "TRUE" *) reg [ADDR_W-1:0] base_addr_q_b     [0:NUM_MASTERS-1];
(* DONT_TOUCH = "TRUE" *) reg [ADDR_W-1:0] base_addr_q_c     [0:NUM_MASTERS-1];
reg [ADDR_W-1:0] base_addr_inv_q [0:NUM_MASTERS-1];
reg              base_addr_sig_q [0:NUM_MASTERS-1];

(* DONT_TOUCH = "TRUE" *) reg [ADDR_W-1:0] offset_q_a        [0:TOTAL_ENTRIES-1];
(* DONT_TOUCH = "TRUE" *) reg [ADDR_W-1:0] offset_q_b        [0:TOTAL_ENTRIES-1];
(* DONT_TOUCH = "TRUE" *) reg [ADDR_W-1:0] offset_q_c        [0:TOTAL_ENTRIES-1];
reg [ADDR_W-1:0] offset_inv_q    [0:TOTAL_ENTRIES-1];
reg              offset_sig_q    [0:TOTAL_ENTRIES-1];

(* DONT_TOUCH = "TRUE" *) reg [DATA_W-1:0] mask_q_a          [0:TOTAL_ENTRIES-1];
(* DONT_TOUCH = "TRUE" *) reg [DATA_W-1:0] mask_q_b          [0:TOTAL_ENTRIES-1];
(* DONT_TOUCH = "TRUE" *) reg [DATA_W-1:0] mask_q_c          [0:TOTAL_ENTRIES-1];
reg [DATA_W-1:0] mask_inv_q      [0:TOTAL_ENTRIES-1];
reg              mask_sig_q      [0:TOTAL_ENTRIES-1];

(* DONT_TOUCH = "TRUE" *) reg [DATA_W-1:0] expected_q_a      [0:TOTAL_ENTRIES-1];
(* DONT_TOUCH = "TRUE" *) reg [DATA_W-1:0] expected_q_b      [0:TOTAL_ENTRIES-1];
(* DONT_TOUCH = "TRUE" *) reg [DATA_W-1:0] expected_q_c      [0:TOTAL_ENTRIES-1];
reg [DATA_W-1:0] expected_inv_q  [0:TOTAL_ENTRIES-1];
reg              expected_sig_q  [0:TOTAL_ENTRIES-1];

(* DONT_TOUCH = "TRUE" *) reg [1:0] burst_type_q_a    [0:TOTAL_ENTRIES-1];
(* DONT_TOUCH = "TRUE" *) reg [1:0] burst_type_q_b    [0:TOTAL_ENTRIES-1];
(* DONT_TOUCH = "TRUE" *) reg [1:0] burst_type_q_c    [0:TOTAL_ENTRIES-1];
reg [1:0]        burst_type_inv_q[0:TOTAL_ENTRIES-1];

(* DONT_TOUCH = "TRUE" *) reg [7:0] burst_len_q_a     [0:TOTAL_ENTRIES-1];
(* DONT_TOUCH = "TRUE" *) reg [7:0] burst_len_q_b     [0:TOTAL_ENTRIES-1];
(* DONT_TOUCH = "TRUE" *) reg [7:0] burst_len_q_c     [0:TOTAL_ENTRIES-1];
reg [7:0]        burst_len_inv_q [0:TOTAL_ENTRIES-1];

(* DONT_TOUCH = "TRUE" *) reg entry_valid_q_a   [0:TOTAL_ENTRIES-1];
(* DONT_TOUCH = "TRUE" *) reg entry_valid_q_b   [0:TOTAL_ENTRIES-1];
(* DONT_TOUCH = "TRUE" *) reg entry_valid_q_c   [0:TOTAL_ENTRIES-1];
reg              entry_valid_inv_q[0:TOTAL_ENTRIES-1];

// ─── KAT TMR ───
reg kat_enable_a, kat_enable_b, kat_enable_c;
wire kat_enable_voted;
wire kat_enable_tmr_mismatch;

assign kat_enable_voted = (kat_enable_a & kat_enable_b) | (kat_enable_b & kat_enable_c) |
                          (kat_enable_a & kat_enable_c);
assign kat_enable_tmr_mismatch = (kat_enable_a ^ kat_enable_b) | (kat_enable_a ^ kat_enable_c) |
                                 (kat_enable_b ^ kat_enable_c);
reg kat_enable_inv;

reg [ADDR_W-1:0] kat_addr_a, kat_addr_b, kat_addr_c;
wire [ADDR_W-1:0] kat_addr_voted;
wire kat_addr_tmr_mismatch;

assign kat_addr_voted = (kat_addr_a & kat_addr_b) | (kat_addr_b & kat_addr_c) |
                        (kat_addr_a & kat_addr_c);
assign kat_addr_tmr_mismatch = (kat_addr_a ^ kat_addr_b) | (kat_addr_a ^ kat_addr_c) |
                               (kat_addr_b ^ kat_addr_c);
reg [ADDR_W-1:0] kat_addr_inv;
reg              kat_addr_sig;

reg [DATA_W-1:0] kat_expected_a, kat_expected_b, kat_expected_c;
wire [DATA_W-1:0] kat_expected_voted;
wire kat_expected_tmr_mismatch;

assign kat_expected_voted = (kat_expected_a & kat_expected_b) | (kat_expected_b & kat_expected_c) |
                            (kat_expected_a & kat_expected_c);
assign kat_expected_tmr_mismatch = (kat_expected_a ^ kat_expected_b) |
                                  (kat_expected_a ^ kat_expected_c) |
                                  (kat_expected_b ^ kat_expected_c);
reg [DATA_W-1:0] kat_expected_inv;
reg              kat_expected_sig;

reg [DATA_W-1:0] kat_mask_a, kat_mask_b, kat_mask_c;
wire [DATA_W-1:0] kat_mask_voted;
wire kat_mask_tmr_mismatch;

assign kat_mask_voted = (kat_mask_a & kat_mask_b) | (kat_mask_b & kat_mask_c) |
                        (kat_mask_a & kat_mask_c);
assign kat_mask_tmr_mismatch = (kat_mask_a ^ kat_mask_b) | (kat_mask_a ^ kat_mask_c) |
                               (kat_mask_b ^ kat_mask_c);
reg [DATA_W-1:0] kat_mask_inv;
reg              kat_mask_sig;

// ─── Scrub pointer ───
reg [SCRUB_IDX_W-1:0] cfg_scrub_idx;

wire cfg_ctrl_tmr_mismatch;
assign cfg_ctrl_tmr_mismatch = enable_tmr_mismatch | cfg_locked_tmr_mismatch |
                               cfg_illegal_tmr_mismatch | scan_done_sticky_tmr_mismatch |
                               read_interval_tmr_mismatch | kat_enable_tmr_mismatch |
                               kat_addr_tmr_mismatch | kat_expected_tmr_mismatch |
                               kat_mask_tmr_mismatch;

integer flat_m;
integer flat_idx;
integer shadow_m_a;
integer shadow_idx_a;
integer shadow_m_b;
integer shadow_idx_b;
integer shadow_m_c;
integer shadow_idx_c;
integer read_m;
integer read_e;
integer read_idx;
integer seq_m;
integer seq_e;
integer seq_idx;
integer scrub_i;

wire aw_fire;
wire w_fire;
wire ar_fire;
wire write_ready_comb;
wire [ADDR_W-1:0] write_addr_comb;
wire [ID_W-1:0]   write_id_comb;
wire [7:0]        write_len_comb;
wire [2:0]        write_size_comb;
wire [1:0]        write_burst_comb;
wire [DATA_W-1:0] write_data_comb;
wire [(DATA_W/8)-1:0] write_strb_comb;
wire write_last_comb;

(* DONT_TOUCH = "TRUE" *) reg shadow_error_comb_a;
(* DONT_TOUCH = "TRUE" *) reg shadow_error_comb_b;
(* DONT_TOUCH = "TRUE" *) reg shadow_error_comb_c;
wire shadow_error_comb;
reg [DATA_W-1:0] read_data_comb;
reg [1:0] read_resp_comb;
reg [1:0] write_resp_comb;
reg [DATA_W-1:0] merged_write;

// Per-entry voted scratch (combinational)
reg [ADDR_W-1:0] offset_voted_local;
reg [DATA_W-1:0] mask_voted_local;
reg [DATA_W-1:0] expected_voted_local;
reg [1:0]        burst_type_voted_local;
reg [7:0]        burst_len_voted_local;
reg              entry_valid_voted_local;
reg [ADDR_W-1:0] base_addr_voted_local;

wire entry_tmr_mismatch_scrub;
wire entry_parity_fault_scrub;
reg  entry_tmr_mismatch_local;
reg  entry_parity_fault_local;

assign cfg_valid        = cfg_locked_r;
assign cfg_locked       = cfg_locked_r;
assign cfg_illegal      = cfg_illegal_r;

wire cfg_shadow_error_voted;
wire cfg_shadow_error_tmr_err;

tmr_voter #(1) u_cfg_shadow_tmr (
    .a(shadow_error_comb_a), .b(shadow_error_comb_b), .c(shadow_error_comb_c),
    .voted(cfg_shadow_error_voted), .mismatch(cfg_shadow_error_tmr_err)
);
assign shadow_error_comb = cfg_shadow_error_voted | cfg_shadow_error_tmr_err |
                           cfg_ctrl_tmr_mismatch;
assign cfg_shadow_error = shadow_error_comb;

assign aw_fire = s_axi_awvalid & s_axi_awready;
assign w_fire  = s_axi_wvalid  & s_axi_wready;
assign ar_fire = s_axi_arvalid & s_axi_arready;

assign write_ready_comb = (aw_seen_q | aw_fire) & (w_seen_q | w_fire) & !s_axi_bvalid;
assign write_addr_comb  = aw_fire ? s_axi_awaddr : awaddr_q;
assign write_id_comb    = aw_fire ? s_axi_awid   : awid_q;
assign write_len_comb   = aw_fire ? s_axi_awlen   : awlen_q;
assign write_size_comb  = aw_fire ? s_axi_awsize  : awsize_q;
assign write_burst_comb = aw_fire ? s_axi_awburst : awburst_q;
assign write_data_comb  = w_fire  ? s_axi_wdata  : wdata_q;
assign write_strb_comb  = w_fire  ? s_axi_wstrb  : wstrb_q;
assign write_last_comb  = w_fire  ? s_axi_wlast  : wlast_q;

function [DATA_W-1:0] apply_wstrb;
    input [DATA_W-1:0] old_value;
    input [DATA_W-1:0] new_value;
    input [(DATA_W/8)-1:0] strb;
    integer b;
begin
    apply_wstrb = old_value;
    for (b = 0; b < (DATA_W/8); b = b + 1) begin
        if (strb[b])
            apply_wstrb[8*b +: 8] = new_value[8*b +: 8];
    end
end
endfunction

function [DATA_W-1:0] control_read_value;
    input dummy;
begin
    control_read_value = {DATA_W{1'b0}};
    control_read_value[0] = enable_voted;
    control_read_value[3] = cfg_locked_r;
    control_read_value[8] = cfg_illegal_r;
end
endfunction

function [DATA_W-1:0] burst_read_value_voted;
    input integer entry_index;
    input [1:0]  bt_v;
    input [7:0]  bl_v;
    input        ev_v;
begin
    burst_read_value_voted = {DATA_W{1'b0}};
    burst_read_value_voted[1:0]  = bt_v;
    burst_read_value_voted[15:8] = bl_v;
    burst_read_value_voted[16]   = ev_v;
end
endfunction

function entry_has_tmr_mismatch;
    input integer idx;
    reg [ADDR_W-1:0] off_v;
    reg [DATA_W-1:0] msk_v;
    reg [DATA_W-1:0] exp_v;
    reg [1:0]        bt_v;
    reg [7:0]        bl_v;
    reg              ev_v;
begin
    off_v = (offset_q_a[idx] & offset_q_b[idx]) | (offset_q_b[idx] & offset_q_c[idx]) |
            (offset_q_a[idx] & offset_q_c[idx]);
    msk_v = (mask_q_a[idx] & mask_q_b[idx]) | (mask_q_b[idx] & mask_q_c[idx]) |
            (mask_q_a[idx] & mask_q_c[idx]);
    exp_v = (expected_q_a[idx] & expected_q_b[idx]) | (expected_q_b[idx] & expected_q_c[idx]) |
            (expected_q_a[idx] & expected_q_c[idx]);
    bt_v  = (burst_type_q_a[idx] & burst_type_q_b[idx]) | (burst_type_q_b[idx] & burst_type_q_c[idx]) |
            (burst_type_q_a[idx] & burst_type_q_c[idx]);
    bl_v  = (burst_len_q_a[idx] & burst_len_q_b[idx]) | (burst_len_q_b[idx] & burst_len_q_c[idx]) |
            (burst_len_q_a[idx] & burst_len_q_c[idx]);
    ev_v  = (entry_valid_q_a[idx] & entry_valid_q_b[idx]) | (entry_valid_q_b[idx] & entry_valid_q_c[idx]) |
            (entry_valid_q_a[idx] & entry_valid_q_c[idx]);
    entry_has_tmr_mismatch =
        (offset_q_a[idx] ^ offset_q_b[idx]) | (offset_q_a[idx] ^ offset_q_c[idx]) |
        (offset_q_b[idx] ^ offset_q_c[idx]) |
        (mask_q_a[idx] ^ mask_q_b[idx]) | (mask_q_a[idx] ^ mask_q_c[idx]) |
        (mask_q_b[idx] ^ mask_q_c[idx]) |
        (expected_q_a[idx] ^ expected_q_b[idx]) | (expected_q_a[idx] ^ expected_q_c[idx]) |
        (expected_q_b[idx] ^ expected_q_c[idx]) |
        (burst_type_q_a[idx] ^ burst_type_q_b[idx]) | (burst_type_q_a[idx] ^ burst_type_q_c[idx]) |
        (burst_type_q_b[idx] ^ burst_type_q_c[idx]) |
        (burst_len_q_a[idx] ^ burst_len_q_b[idx]) | (burst_len_q_a[idx] ^ burst_len_q_c[idx]) |
        (burst_len_q_b[idx] ^ burst_len_q_c[idx]) |
        (entry_valid_q_a[idx] ^ entry_valid_q_b[idx]) | (entry_valid_q_a[idx] ^ entry_valid_q_c[idx]) |
        (entry_valid_q_b[idx] ^ entry_valid_q_c[idx]);
end
endfunction

function entry_has_parity_fault;
    input integer idx;
    reg [ADDR_W-1:0] off_v;
    reg [DATA_W-1:0] msk_v;
    reg [DATA_W-1:0] exp_v;
begin
    off_v = (offset_q_a[idx] & offset_q_b[idx]) | (offset_q_b[idx] & offset_q_c[idx]) |
            (offset_q_a[idx] & offset_q_c[idx]);
    msk_v = (mask_q_a[idx] & mask_q_b[idx]) | (mask_q_b[idx] & mask_q_c[idx]) |
            (mask_q_a[idx] & mask_q_c[idx]);
    exp_v = (expected_q_a[idx] & expected_q_b[idx]) | (expected_q_b[idx] & expected_q_c[idx]) |
            (expected_q_a[idx] & expected_q_c[idx]);
    entry_has_parity_fault =
        (offset_sig_q[idx] != ^off_v) |
        (mask_sig_q[idx] != ^msk_v) |
        (expected_sig_q[idx] != ^exp_v);
end
endfunction

always @* begin
    for (flat_m = 0; flat_m < NUM_MASTERS; flat_m = flat_m + 1) begin
        base_addr_voted_local = (base_addr_q_a[flat_m] & base_addr_q_b[flat_m]) |
                                (base_addr_q_b[flat_m] & base_addr_q_c[flat_m]) |
                                (base_addr_q_a[flat_m] & base_addr_q_c[flat_m]);
        base_addr_flat[flat_m*ADDR_W +: ADDR_W] = base_addr_voted_local;
    end

    for (flat_idx = 0; flat_idx < TOTAL_ENTRIES; flat_idx = flat_idx + 1) begin
        offset_voted_local = (offset_q_a[flat_idx] & offset_q_b[flat_idx]) |
                             (offset_q_b[flat_idx] & offset_q_c[flat_idx]) |
                             (offset_q_a[flat_idx] & offset_q_c[flat_idx]);
        mask_voted_local = (mask_q_a[flat_idx] & mask_q_b[flat_idx]) |
                           (mask_q_b[flat_idx] & mask_q_c[flat_idx]) |
                           (mask_q_a[flat_idx] & mask_q_c[flat_idx]);
        expected_voted_local = (expected_q_a[flat_idx] & expected_q_b[flat_idx]) |
                               (expected_q_b[flat_idx] & expected_q_c[flat_idx]) |
                               (expected_q_a[flat_idx] & expected_q_c[flat_idx]);
        burst_type_voted_local = (burst_type_q_a[flat_idx] & burst_type_q_b[flat_idx]) |
                                 (burst_type_q_b[flat_idx] & burst_type_q_c[flat_idx]) |
                                 (burst_type_q_a[flat_idx] & burst_type_q_c[flat_idx]);
        burst_len_voted_local = (burst_len_q_a[flat_idx] & burst_len_q_b[flat_idx]) |
                                (burst_len_q_b[flat_idx] & burst_len_q_c[flat_idx]) |
                                (burst_len_q_a[flat_idx] & burst_len_q_c[flat_idx]);
        entry_valid_voted_local = (entry_valid_q_a[flat_idx] & entry_valid_q_b[flat_idx]) |
                                  (entry_valid_q_b[flat_idx] & entry_valid_q_c[flat_idx]) |
                                  (entry_valid_q_a[flat_idx] & entry_valid_q_c[flat_idx]);

        offset_flat[flat_idx*ADDR_W +: ADDR_W] = offset_voted_local;
        mask_flat[flat_idx*DATA_W +: DATA_W] = mask_voted_local;
        burst_type_flat[flat_idx*2 +: 2] = burst_type_voted_local;
        burst_len_flat[flat_idx*8 +: 8] = burst_len_voted_local;
        entry_valid_flat[flat_idx] = entry_valid_voted_local;
        expected_flat[flat_idx*DATA_W +: DATA_W] = expected_voted_local;
    end

    kat_enable_out   = kat_enable_voted;
    kat_addr_out     = kat_addr_voted;
    kat_expected_out = kat_expected_voted;
    kat_mask_out     = kat_mask_voted;
end

always @* begin
    entry_tmr_mismatch_local = entry_has_tmr_mismatch(cfg_scrub_idx);
    entry_parity_fault_local = entry_has_parity_fault(cfg_scrub_idx);
end
assign entry_tmr_mismatch_scrub = entry_tmr_mismatch_local;
assign entry_parity_fault_scrub = entry_parity_fault_local;

always @* begin
    shadow_error_comb_a = (enable_inv != ~enable_voted) |
                        (cfg_locked_inv != ~cfg_locked_r) |
                        (cfg_illegal_inv != ~cfg_illegal_r) |
                        (read_interval_inv != ~read_interval_voted) |
                        (read_interval_sig != ^read_interval_voted);

    if (cfg_ctrl_tmr_mismatch)
        shadow_error_comb_a = 1'b1;

    for (shadow_m_a = 0; shadow_m_a < NUM_MASTERS; shadow_m_a = shadow_m_a + 1) begin
        base_addr_voted_local = (base_addr_q_a[shadow_m_a] & base_addr_q_b[shadow_m_a]) |
                                (base_addr_q_b[shadow_m_a] & base_addr_q_c[shadow_m_a]) |
                                (base_addr_q_a[shadow_m_a] & base_addr_q_c[shadow_m_a]);
        if (base_addr_inv_q[shadow_m_a] != ~base_addr_voted_local)
            shadow_error_comb_a = 1'b1;
        if (base_addr_sig_q[shadow_m_a] != ^base_addr_voted_local)
            shadow_error_comb_a = 1'b1;
    end

    for (shadow_idx_a = 0; shadow_idx_a < TOTAL_ENTRIES; shadow_idx_a = shadow_idx_a + 1) begin
        offset_voted_local = (offset_q_a[shadow_idx_a] & offset_q_b[shadow_idx_a]) |
                             (offset_q_b[shadow_idx_a] & offset_q_c[shadow_idx_a]) |
                             (offset_q_a[shadow_idx_a] & offset_q_c[shadow_idx_a]);
        mask_voted_local = (mask_q_a[shadow_idx_a] & mask_q_b[shadow_idx_a]) |
                           (mask_q_b[shadow_idx_a] & mask_q_c[shadow_idx_a]) |
                           (mask_q_a[shadow_idx_a] & mask_q_c[shadow_idx_a]);
        expected_voted_local = (expected_q_a[shadow_idx_a] & expected_q_b[shadow_idx_a]) |
                               (expected_q_b[shadow_idx_a] & expected_q_c[shadow_idx_a]) |
                               (expected_q_a[shadow_idx_a] & expected_q_c[shadow_idx_a]);
        burst_type_voted_local = (burst_type_q_a[shadow_idx_a] & burst_type_q_b[shadow_idx_a]) |
                                 (burst_type_q_b[shadow_idx_a] & burst_type_q_c[shadow_idx_a]) |
                                 (burst_type_q_a[shadow_idx_a] & burst_type_q_c[shadow_idx_a]);
        burst_len_voted_local = (burst_len_q_a[shadow_idx_a] & burst_len_q_b[shadow_idx_a]) |
                                (burst_len_q_b[shadow_idx_a] & burst_len_q_c[shadow_idx_a]) |
                                (burst_len_q_a[shadow_idx_a] & burst_len_q_c[shadow_idx_a]);
        entry_valid_voted_local = (entry_valid_q_a[shadow_idx_a] & entry_valid_q_b[shadow_idx_a]) |
                                  (entry_valid_q_b[shadow_idx_a] & entry_valid_q_c[shadow_idx_a]) |
                                  (entry_valid_q_a[shadow_idx_a] & entry_valid_q_c[shadow_idx_a]);

        if ((offset_inv_q[shadow_idx_a] != ~offset_voted_local) ||
            (mask_inv_q[shadow_idx_a] != ~mask_voted_local) ||
            (burst_type_inv_q[shadow_idx_a] != ~burst_type_voted_local) ||
            (burst_len_inv_q[shadow_idx_a] != ~burst_len_voted_local) ||
            (entry_valid_inv_q[shadow_idx_a] != ~entry_valid_voted_local) ||
            (expected_inv_q[shadow_idx_a] != ~expected_voted_local))
            shadow_error_comb_a = 1'b1;
        if ((offset_sig_q[shadow_idx_a] != ^offset_voted_local) ||
            (mask_sig_q[shadow_idx_a] != ^mask_voted_local) ||
            (expected_sig_q[shadow_idx_a] != ^expected_voted_local))
            shadow_error_comb_a = 1'b1;
    end

    if ((kat_enable_inv != ~kat_enable_voted) ||
        (kat_addr_inv != ~kat_addr_voted) ||
        (kat_expected_inv != ~kat_expected_voted) ||
        (kat_mask_inv != ~kat_mask_voted) ||
        (kat_addr_sig != ^kat_addr_voted) ||
        (kat_expected_sig != ^kat_expected_voted) ||
        (kat_mask_sig != ^kat_mask_voted))
        shadow_error_comb_a = 1'b1;
end

always @* begin
    shadow_error_comb_b = shadow_error_comb_a;
end

always @* begin
    shadow_error_comb_c = shadow_error_comb_a;
end

always @* begin
    read_data_comb = {DATA_W{1'b0}};
    read_resp_comb = RESP_OKAY;

    if (s_axi_arlen != 8'd0 || s_axi_arsize != 3'd3 || s_axi_arburst != 2'b01) begin
        read_resp_comb = RESP_SLVERR;
    end else if (s_axi_araddr[ADDR_W-1:0] == ADDR_CONTROL) begin
        read_data_comb = control_read_value(1'b0);
    end else if (s_axi_araddr[ADDR_W-1:0] == ADDR_READ_INTERVAL) begin
        read_data_comb = read_interval_voted;
    end else if (s_axi_araddr[ADDR_W-1:0] == ADDR_STATUS) begin
        read_data_comb = {DATA_W{1'b0}};
        read_data_comb[0] = scan_busy;
        read_data_comb[1] = scan_done_sticky_voted | scan_done_pulse;
        read_data_comb[2] = external_fault_event;
        read_data_comb[3] = bus_fault_event;
        read_data_comb[4] = cfg_fault_event;
        read_data_comb[5] = safety_island_fault_event;
        read_data_comb[6] = safety_island_latent_fault_event;
    end else if (s_axi_araddr[ADDR_W-1:0] == ADDR_FAULT_RESULT) begin
        read_data_comb = fault_or_result;
    end else if (s_axi_araddr[ADDR_W-1:0] == ADDR_ERROR_CODE) begin
        read_data_comb = {{(DATA_W-8){1'b0}}, core_error_code};
    end else if (s_axi_araddr[ADDR_W-1:0] == ADDR_INDEX_STATUS) begin
        read_data_comb = {current_master_idx, current_entry_idx};
    end else if (s_axi_araddr[ADDR_W-1:0] == ADDR_OUTSTANDING) begin
        read_data_comb = {{(DATA_W-32){1'b0}}, outstanding_count};
    end else if (s_axi_araddr[ADDR_W-1:0] == ADDR_KAT_CTRL) begin
        read_data_comb = {{(DATA_W-1){1'b0}}, kat_enable_voted};
    end else if ((s_axi_araddr[ADDR_W-1:0] >= ADDR_BASE_REGION) &&
                 (s_axi_araddr[ADDR_W-1:0] < (ADDR_BASE_REGION + NUM_MASTERS*BASE_STRIDE))) begin
        read_m = (s_axi_araddr[ADDR_W-1:0] - ADDR_BASE_REGION) / BASE_STRIDE;
        base_addr_voted_local = (base_addr_q_a[read_m] & base_addr_q_b[read_m]) |
                                (base_addr_q_b[read_m] & base_addr_q_c[read_m]) |
                                (base_addr_q_a[read_m] & base_addr_q_c[read_m]);
        read_data_comb = {{(DATA_W-ADDR_W){1'b0}}, base_addr_voted_local};
    end else if ((s_axi_araddr[ADDR_W-1:0] >= ADDR_ENTRY_REGION) &&
                 (s_axi_araddr[ADDR_W-1:0] < (ADDR_ENTRY_REGION + NUM_MASTERS*ENTRY_MASTER_STRIDE))) begin
        read_m = (s_axi_araddr[ADDR_W-1:0] - ADDR_ENTRY_REGION) / ENTRY_MASTER_STRIDE;
        read_e = ((s_axi_araddr[ADDR_W-1:0] - ADDR_ENTRY_REGION) % ENTRY_MASTER_STRIDE) / ENTRY_STRIDE;
        read_idx = (read_m * NUM_ENTRIES) + read_e;

        if ((read_m < NUM_MASTERS) && (read_e < NUM_ENTRIES)) begin
            offset_voted_local = (offset_q_a[read_idx] & offset_q_b[read_idx]) |
                                 (offset_q_b[read_idx] & offset_q_c[read_idx]) |
                                 (offset_q_a[read_idx] & offset_q_c[read_idx]);
            mask_voted_local = (mask_q_a[read_idx] & mask_q_b[read_idx]) |
                               (mask_q_b[read_idx] & mask_q_c[read_idx]) |
                               (mask_q_a[read_idx] & mask_q_c[read_idx]);
            expected_voted_local = (expected_q_a[read_idx] & expected_q_b[read_idx]) |
                                   (expected_q_b[read_idx] & expected_q_c[read_idx]) |
                                   (expected_q_a[read_idx] & expected_q_c[read_idx]);
            burst_type_voted_local = (burst_type_q_a[read_idx] & burst_type_q_b[read_idx]) |
                                     (burst_type_q_b[read_idx] & burst_type_q_c[read_idx]) |
                                     (burst_type_q_a[read_idx] & burst_type_q_c[read_idx]);
            burst_len_voted_local = (burst_len_q_a[read_idx] & burst_len_q_b[read_idx]) |
                                    (burst_len_q_b[read_idx] & burst_len_q_c[read_idx]) |
                                    (burst_len_q_a[read_idx] & burst_len_q_c[read_idx]);
            entry_valid_voted_local = (entry_valid_q_a[read_idx] & entry_valid_q_b[read_idx]) |
                                      (entry_valid_q_b[read_idx] & entry_valid_q_c[read_idx]) |
                                      (entry_valid_q_a[read_idx] & entry_valid_q_c[read_idx]);

            case (((s_axi_araddr[ADDR_W-1:0] - ADDR_ENTRY_REGION) % ENTRY_MASTER_STRIDE) % ENTRY_STRIDE)
                ENTRY_OFFSET_OFF: read_data_comb = {{(DATA_W-ADDR_W){1'b0}}, offset_voted_local};
                ENTRY_MASK_OFF:   read_data_comb = mask_voted_local;
                ENTRY_BURST_OFF:  read_data_comb = burst_read_value_voted(read_idx,
                    burst_type_voted_local, burst_len_voted_local, entry_valid_voted_local);
                ENTRY_EXPECTED_OFF: read_data_comb = expected_voted_local;
                default: begin
                    read_data_comb = {DATA_W{1'b0}};
                    read_resp_comb = RESP_SLVERR;
                end
            endcase
        end else begin
            read_resp_comb = RESP_SLVERR;
        end
    end else if (s_axi_araddr[ADDR_W-1:0] == ADDR_KAT_ADDR) begin
        read_data_comb = {{(DATA_W-ADDR_W){1'b0}}, kat_addr_voted};
    end else if (s_axi_araddr[ADDR_W-1:0] == ADDR_KAT_EXPECTED) begin
        read_data_comb = kat_expected_voted;
    end else if (s_axi_araddr[ADDR_W-1:0] == ADDR_KAT_MASK) begin
        read_data_comb = kat_mask_voted;
    end else begin
        read_resp_comb = RESP_SLVERR;
    end
end

always @(posedge clk) begin
    if (rst) begin
        s_axi_awready     <= 1'b1;
        s_axi_wready      <= 1'b1;
        s_axi_bvalid      <= 1'b0;
        s_axi_bresp       <= RESP_OKAY;
        s_axi_bid         <= {ID_W{1'b0}};
        s_axi_arready     <= 1'b1;
        s_axi_rvalid      <= 1'b0;
        s_axi_rdata       <= {DATA_W{1'b0}};
        s_axi_rresp       <= RESP_OKAY;
        s_axi_rid         <= {ID_W{1'b0}};
        s_axi_rlast       <= 1'b0;
        awaddr_q          <= {ADDR_W{1'b0}};
        awid_q            <= {ID_W{1'b0}};
        awlen_q           <= 8'd0;
        awsize_q          <= 3'd0;
        awburst_q         <= 2'b01;
        aw_seen_q         <= 1'b0;
        wdata_q           <= {DATA_W{1'b0}};
        wstrb_q           <= {(DATA_W/8){1'b0}};
        wlast_q           <= 1'b0;
        w_seen_q          <= 1'b0;
        enable            <= 1'b0;
        enable_a          <= 1'b0;
        enable_b          <= 1'b0;
        enable_c          <= 1'b0;
        enable_inv        <= 1'b1;
        scan_once         <= 1'b0;
        clear_core_status <= 1'b0;
        read_interval     <= 64'd0;
        read_interval_a   <= 64'd0;
        read_interval_b   <= 64'd0;
        read_interval_c   <= 64'd0;
        read_interval_inv <= {64{1'b1}};
        read_interval_sig <= 1'b0;
        cfg_locked_r_a    <= 1'b0;
        cfg_locked_r_b    <= 1'b0;
        cfg_locked_r_c    <= 1'b0;
        cfg_locked_inv    <= 1'b1;
        cfg_illegal_r_a   <= 1'b0;
        cfg_illegal_r_b   <= 1'b0;
        cfg_illegal_r_c   <= 1'b0;
        cfg_illegal_inv   <= 1'b1;
        scan_done_sticky_a <= 1'b0;
        scan_done_sticky_b <= 1'b0;
        scan_done_sticky_c <= 1'b0;
        write_verify_pending <= 1'b0;
        cfg_scrub_idx     <= {SCRUB_IDX_W{1'b0}};

        for (seq_m = 0; seq_m < NUM_MASTERS; seq_m = seq_m + 1) begin
            base_addr_q_a[seq_m]     <= {ADDR_W{1'b0}};
            base_addr_q_b[seq_m]     <= {ADDR_W{1'b0}};
            base_addr_q_c[seq_m]     <= {ADDR_W{1'b0}};
            base_addr_inv_q[seq_m]   <= {ADDR_W{1'b1}};
            base_addr_sig_q[seq_m]   <= 1'b0;
        end

        for (seq_idx = 0; seq_idx < TOTAL_ENTRIES; seq_idx = seq_idx + 1) begin
            offset_q_a[seq_idx]         <= {ADDR_W{1'b0}};
            offset_q_b[seq_idx]         <= {ADDR_W{1'b0}};
            offset_q_c[seq_idx]         <= {ADDR_W{1'b0}};
            offset_inv_q[seq_idx]       <= {ADDR_W{1'b1}};
            offset_sig_q[seq_idx]       <= 1'b0;
            mask_q_a[seq_idx]           <= {DATA_W{1'b0}};
            mask_q_b[seq_idx]           <= {DATA_W{1'b0}};
            mask_q_c[seq_idx]           <= {DATA_W{1'b0}};
            mask_inv_q[seq_idx]         <= {DATA_W{1'b1}};
            mask_sig_q[seq_idx]         <= 1'b0;
            burst_type_q_a[seq_idx]     <= 2'b01;
            burst_type_q_b[seq_idx]     <= 2'b01;
            burst_type_q_c[seq_idx]     <= 2'b01;
            burst_type_inv_q[seq_idx]   <= ~2'b01;
            burst_len_q_a[seq_idx]      <= 8'd0;
            burst_len_q_b[seq_idx]      <= 8'd0;
            burst_len_q_c[seq_idx]      <= 8'd0;
            burst_len_inv_q[seq_idx]    <= {8{1'b1}};
            entry_valid_q_a[seq_idx]    <= 1'b0;
            entry_valid_q_b[seq_idx]    <= 1'b0;
            entry_valid_q_c[seq_idx]    <= 1'b0;
            entry_valid_inv_q[seq_idx]  <= 1'b1;
            expected_q_a[seq_idx]       <= {DATA_W{1'b0}};
            expected_q_b[seq_idx]       <= {DATA_W{1'b0}};
            expected_q_c[seq_idx]       <= {DATA_W{1'b0}};
            expected_inv_q[seq_idx]     <= {DATA_W{1'b1}};
            expected_sig_q[seq_idx]     <= 1'b0;
        end

        kat_enable_a      <= 1'b0;
        kat_enable_b      <= 1'b0;
        kat_enable_c      <= 1'b0;
        kat_enable_inv    <= 1'b1;
        kat_addr_a        <= {ADDR_W{1'b0}};
        kat_addr_b        <= {ADDR_W{1'b0}};
        kat_addr_c        <= {ADDR_W{1'b0}};
        kat_addr_inv      <= {ADDR_W{1'b1}};
        kat_addr_sig      <= 1'b0;
        kat_expected_a    <= {DATA_W{1'b0}};
        kat_expected_b    <= {DATA_W{1'b0}};
        kat_expected_c    <= {DATA_W{1'b0}};
        kat_expected_inv  <= {DATA_W{1'b1}};
        kat_expected_sig  <= 1'b0;
        kat_mask_a        <= {DATA_W{1'b0}};
        kat_mask_b        <= {DATA_W{1'b0}};
        kat_mask_c        <= {DATA_W{1'b0}};
        kat_mask_inv      <= {DATA_W{1'b1}};
        kat_mask_sig      <= 1'b0;
    end else begin
        scan_once         <= 1'b0;
        clear_core_status <= 1'b0;

        // Drive functional outputs from voted values
        enable        <= enable_voted;
        read_interval <= read_interval_voted;

        if (scan_done_pulse) begin
            scan_done_sticky_a <= 1'b1;
            scan_done_sticky_b <= 1'b1;
            scan_done_sticky_c <= 1'b1;
        end

        // ─── TMR feedback repair: control bits ───
        if (enable_tmr_mismatch) begin
            enable_a   <= enable_voted;
            enable_b   <= enable_voted;
            enable_c   <= enable_voted;
            enable_inv <= ~enable_voted;
        end
        if (cfg_locked_tmr_mismatch) begin
            cfg_locked_r_a <= cfg_locked_r;
            cfg_locked_r_b <= cfg_locked_r;
            cfg_locked_r_c <= cfg_locked_r;
            cfg_locked_inv <= ~cfg_locked_r;
        end
        if (cfg_illegal_tmr_mismatch) begin
            cfg_illegal_r_a <= cfg_illegal_r;
            cfg_illegal_r_b <= cfg_illegal_r;
            cfg_illegal_r_c <= cfg_illegal_r;
            cfg_illegal_inv <= ~cfg_illegal_r;
        end
        if (scan_done_sticky_tmr_mismatch) begin
            scan_done_sticky_a <= scan_done_sticky_voted;
            scan_done_sticky_b <= scan_done_sticky_voted;
            scan_done_sticky_c <= scan_done_sticky_voted;
        end
        if (read_interval_tmr_mismatch) begin
            read_interval_a   <= read_interval_voted;
            read_interval_b   <= read_interval_voted;
            read_interval_c   <= read_interval_voted;
            read_interval_inv <= ~read_interval_voted;
            read_interval_sig <= ^read_interval_voted;
        end
        if (kat_enable_tmr_mismatch) begin
            kat_enable_a   <= kat_enable_voted;
            kat_enable_b   <= kat_enable_voted;
            kat_enable_c   <= kat_enable_voted;
            kat_enable_inv <= ~kat_enable_voted;
        end
        if (kat_addr_tmr_mismatch) begin
            kat_addr_a   <= kat_addr_voted;
            kat_addr_b   <= kat_addr_voted;
            kat_addr_c   <= kat_addr_voted;
            kat_addr_inv <= ~kat_addr_voted;
            kat_addr_sig <= ^kat_addr_voted;
        end
        if (kat_expected_tmr_mismatch) begin
            kat_expected_a   <= kat_expected_voted;
            kat_expected_b   <= kat_expected_voted;
            kat_expected_c   <= kat_expected_voted;
            kat_expected_inv <= ~kat_expected_voted;
            kat_expected_sig <= ^kat_expected_voted;
        end
        if (kat_mask_tmr_mismatch) begin
            kat_mask_a   <= kat_mask_voted;
            kat_mask_b   <= kat_mask_voted;
            kat_mask_c   <= kat_mask_voted;
            kat_mask_inv <= ~kat_mask_voted;
            kat_mask_sig <= ^kat_mask_voted;
        end

        // ─── Scrub repair: one entry per cycle ───
        if (entry_tmr_mismatch_scrub || entry_parity_fault_scrub) begin
            scrub_i = cfg_scrub_idx;
            offset_voted_local = (offset_q_a[scrub_i] & offset_q_b[scrub_i]) |
                                 (offset_q_b[scrub_i] & offset_q_c[scrub_i]) |
                                 (offset_q_a[scrub_i] & offset_q_c[scrub_i]);
            mask_voted_local = (mask_q_a[scrub_i] & mask_q_b[scrub_i]) |
                               (mask_q_b[scrub_i] & mask_q_c[scrub_i]) |
                               (mask_q_a[scrub_i] & mask_q_c[scrub_i]);
            expected_voted_local = (expected_q_a[scrub_i] & expected_q_b[scrub_i]) |
                                   (expected_q_b[scrub_i] & expected_q_c[scrub_i]) |
                                   (expected_q_a[scrub_i] & expected_q_c[scrub_i]);
            burst_type_voted_local = (burst_type_q_a[scrub_i] & burst_type_q_b[scrub_i]) |
                                     (burst_type_q_b[scrub_i] & burst_type_q_c[scrub_i]) |
                                     (burst_type_q_a[scrub_i] & burst_type_q_c[scrub_i]);
            burst_len_voted_local = (burst_len_q_a[scrub_i] & burst_len_q_b[scrub_i]) |
                                    (burst_len_q_b[scrub_i] & burst_len_q_c[scrub_i]) |
                                    (burst_len_q_a[scrub_i] & burst_len_q_c[scrub_i]);
            entry_valid_voted_local = (entry_valid_q_a[scrub_i] & entry_valid_q_b[scrub_i]) |
                                      (entry_valid_q_b[scrub_i] & entry_valid_q_c[scrub_i]) |
                                      (entry_valid_q_a[scrub_i] & entry_valid_q_c[scrub_i]);

            offset_q_a[scrub_i]      <= offset_voted_local;
            offset_q_b[scrub_i]      <= offset_voted_local;
            offset_q_c[scrub_i]      <= offset_voted_local;
            offset_inv_q[scrub_i]    <= ~offset_voted_local;
            offset_sig_q[scrub_i]    <= ^offset_voted_local;
            mask_q_a[scrub_i]        <= mask_voted_local;
            mask_q_b[scrub_i]        <= mask_voted_local;
            mask_q_c[scrub_i]        <= mask_voted_local;
            mask_inv_q[scrub_i]      <= ~mask_voted_local;
            mask_sig_q[scrub_i]      <= ^mask_voted_local;
            expected_q_a[scrub_i]    <= expected_voted_local;
            expected_q_b[scrub_i]    <= expected_voted_local;
            expected_q_c[scrub_i]    <= expected_voted_local;
            expected_inv_q[scrub_i]  <= ~expected_voted_local;
            expected_sig_q[scrub_i]  <= ^expected_voted_local;
            burst_type_q_a[scrub_i]  <= burst_type_voted_local;
            burst_type_q_b[scrub_i]  <= burst_type_voted_local;
            burst_type_q_c[scrub_i]  <= burst_type_voted_local;
            burst_type_inv_q[scrub_i]<= ~burst_type_voted_local;
            burst_len_q_a[scrub_i]   <= burst_len_voted_local;
            burst_len_q_b[scrub_i]   <= burst_len_voted_local;
            burst_len_q_c[scrub_i]   <= burst_len_voted_local;
            burst_len_inv_q[scrub_i] <= ~burst_len_voted_local;
            entry_valid_q_a[scrub_i] <= entry_valid_voted_local;
            entry_valid_q_b[scrub_i] <= entry_valid_voted_local;
            entry_valid_q_c[scrub_i] <= entry_valid_voted_local;
            entry_valid_inv_q[scrub_i] <= ~entry_valid_voted_local;
        end

        if (cfg_scrub_idx >= (TOTAL_ENTRIES - 1))
            cfg_scrub_idx <= {SCRUB_IDX_W{1'b0}};
        else
            cfg_scrub_idx <= cfg_scrub_idx + 1'b1;

        if (aw_fire) begin
            awaddr_q  <= s_axi_awaddr;
            awid_q    <= s_axi_awid;
            awlen_q   <= s_axi_awlen;
            awsize_q  <= s_axi_awsize;
            awburst_q <= s_axi_awburst;
            aw_seen_q <= 1'b1;
        end

        if (w_fire) begin
            wdata_q  <= s_axi_wdata;
            wstrb_q  <= s_axi_wstrb;
            wlast_q  <= s_axi_wlast;
            w_seen_q <= 1'b1;
        end

        if (write_ready_comb) begin
            write_resp_comb = RESP_OKAY;

            if (write_len_comb != 8'd0 || write_size_comb != 3'd3 ||
                write_burst_comb != 2'b01 || !write_last_comb) begin
                write_resp_comb  = RESP_SLVERR;
                cfg_illegal_r_a  <= 1'b1;
                cfg_illegal_r_b  <= 1'b1;
                cfg_illegal_r_c  <= 1'b1;
                cfg_illegal_inv  <= 1'b0;
            end else if (write_addr_comb == ADDR_CONTROL) begin
                merged_write = apply_wstrb(control_read_value(1'b0), write_data_comb, write_strb_comb);
                if (merged_write[0] != enable_voted) begin
                    enable_a   <= merged_write[0];
                    enable_b   <= merged_write[0];
                    enable_c   <= merged_write[0];
                    enable_inv <= ~merged_write[0];
                end
                if (merged_write[1])
                    scan_once <= 1'b1;
                if (merged_write[2]) begin
                    clear_core_status <= 1'b1;
                    cfg_illegal_r_a   <= 1'b0;
                    cfg_illegal_r_b   <= 1'b0;
                    cfg_illegal_r_c   <= 1'b0;
                    cfg_illegal_inv   <= 1'b1;
                    scan_done_sticky_a <= 1'b0;
                    scan_done_sticky_b <= 1'b0;
                    scan_done_sticky_c <= 1'b0;
                end
                if (merged_write[3]) begin
                    cfg_locked_r_a <= 1'b1;
                    cfg_locked_r_b <= 1'b1;
                    cfg_locked_r_c <= 1'b1;
                    cfg_locked_inv <= 1'b0;
                end
            end else if (cfg_locked_r) begin
                write_resp_comb  = RESP_SLVERR;
                cfg_illegal_r_a  <= 1'b1;
                cfg_illegal_r_b  <= 1'b1;
                cfg_illegal_r_c  <= 1'b1;
                cfg_illegal_inv  <= 1'b0;
            end else if (write_addr_comb == ADDR_READ_INTERVAL) begin
                merged_write        = apply_wstrb(read_interval_voted, write_data_comb, write_strb_comb);
                read_interval_a     <= merged_write;
                read_interval_b     <= merged_write;
                read_interval_c     <= merged_write;
                read_interval_inv   <= ~merged_write;
                read_interval_sig   <= ^merged_write;
            end else if (write_addr_comb == ADDR_KAT_CTRL) begin
                merged_write = apply_wstrb({{(DATA_W-1){1'b0}}, kat_enable_voted},
                                           write_data_comb, write_strb_comb);
                kat_enable_a   <= merged_write[0];
                kat_enable_b   <= merged_write[0];
                kat_enable_c   <= merged_write[0];
                kat_enable_inv <= ~merged_write[0];
            end else if (write_addr_comb == ADDR_KAT_ADDR) begin
                merged_write = apply_wstrb({{(DATA_W-ADDR_W){1'b0}}, kat_addr_voted},
                                           write_data_comb, write_strb_comb);
                kat_addr_a   <= merged_write[ADDR_W-1:0];
                kat_addr_b   <= merged_write[ADDR_W-1:0];
                kat_addr_c   <= merged_write[ADDR_W-1:0];
                kat_addr_inv <= ~merged_write[ADDR_W-1:0];
                kat_addr_sig <= ^merged_write[ADDR_W-1:0];
            end else if (write_addr_comb == ADDR_KAT_EXPECTED) begin
                merged_write = apply_wstrb(kat_expected_voted, write_data_comb, write_strb_comb);
                kat_expected_a   <= merged_write;
                kat_expected_b   <= merged_write;
                kat_expected_c   <= merged_write;
                kat_expected_inv <= ~merged_write;
                kat_expected_sig <= ^merged_write;
            end else if (write_addr_comb == ADDR_KAT_MASK) begin
                merged_write = apply_wstrb(kat_mask_voted, write_data_comb, write_strb_comb);
                kat_mask_a   <= merged_write;
                kat_mask_b   <= merged_write;
                kat_mask_c   <= merged_write;
                kat_mask_inv <= ~merged_write;
                kat_mask_sig <= ^merged_write;
            end else if ((write_addr_comb >= ADDR_BASE_REGION) &&
                         (write_addr_comb < (ADDR_BASE_REGION + NUM_MASTERS*BASE_STRIDE))) begin
                seq_m = (write_addr_comb - ADDR_BASE_REGION) / BASE_STRIDE;
                base_addr_voted_local = (base_addr_q_a[seq_m] & base_addr_q_b[seq_m]) |
                                        (base_addr_q_b[seq_m] & base_addr_q_c[seq_m]) |
                                        (base_addr_q_a[seq_m] & base_addr_q_c[seq_m]);
                merged_write = apply_wstrb({{(DATA_W-ADDR_W){1'b0}}, base_addr_voted_local},
                                           write_data_comb, write_strb_comb);
                base_addr_q_a[seq_m]     <= merged_write[ADDR_W-1:0];
                base_addr_q_b[seq_m]     <= merged_write[ADDR_W-1:0];
                base_addr_q_c[seq_m]     <= merged_write[ADDR_W-1:0];
                base_addr_inv_q[seq_m]   <= ~merged_write[ADDR_W-1:0];
                base_addr_sig_q[seq_m]   <= ^merged_write[ADDR_W-1:0];
            end else if ((write_addr_comb >= ADDR_ENTRY_REGION) &&
                         (write_addr_comb < (ADDR_ENTRY_REGION + NUM_MASTERS*ENTRY_MASTER_STRIDE))) begin
                seq_m = (write_addr_comb - ADDR_ENTRY_REGION) / ENTRY_MASTER_STRIDE;
                seq_e = ((write_addr_comb - ADDR_ENTRY_REGION) % ENTRY_MASTER_STRIDE) / ENTRY_STRIDE;
                seq_idx = (seq_m * NUM_ENTRIES) + seq_e;

                if ((seq_m < NUM_MASTERS) && (seq_e < NUM_ENTRIES)) begin
                    offset_voted_local = (offset_q_a[seq_idx] & offset_q_b[seq_idx]) |
                                         (offset_q_b[seq_idx] & offset_q_c[seq_idx]) |
                                         (offset_q_a[seq_idx] & offset_q_c[seq_idx]);
                    mask_voted_local = (mask_q_a[seq_idx] & mask_q_b[seq_idx]) |
                                       (mask_q_b[seq_idx] & mask_q_c[seq_idx]) |
                                       (mask_q_a[seq_idx] & mask_q_c[seq_idx]);
                    expected_voted_local = (expected_q_a[seq_idx] & expected_q_b[seq_idx]) |
                                           (expected_q_b[seq_idx] & expected_q_c[seq_idx]) |
                                           (expected_q_a[seq_idx] & expected_q_c[seq_idx]);
                    burst_type_voted_local = (burst_type_q_a[seq_idx] & burst_type_q_b[seq_idx]) |
                                             (burst_type_q_b[seq_idx] & burst_type_q_c[seq_idx]) |
                                             (burst_type_q_a[seq_idx] & burst_type_q_c[seq_idx]);
                    burst_len_voted_local = (burst_len_q_a[seq_idx] & burst_len_q_b[seq_idx]) |
                                            (burst_len_q_b[seq_idx] & burst_len_q_c[seq_idx]) |
                                            (burst_len_q_a[seq_idx] & burst_len_q_c[seq_idx]);
                    entry_valid_voted_local = (entry_valid_q_a[seq_idx] & entry_valid_q_b[seq_idx]) |
                                              (entry_valid_q_b[seq_idx] & entry_valid_q_c[seq_idx]) |
                                              (entry_valid_q_a[seq_idx] & entry_valid_q_c[seq_idx]);

                    case (((write_addr_comb - ADDR_ENTRY_REGION) % ENTRY_MASTER_STRIDE) % ENTRY_STRIDE)
                        ENTRY_OFFSET_OFF: begin
                            merged_write = apply_wstrb({{(DATA_W-ADDR_W){1'b0}}, offset_voted_local},
                                                       write_data_comb, write_strb_comb);
                            offset_q_a[seq_idx]   <= merged_write[ADDR_W-1:0];
                            offset_q_b[seq_idx]   <= merged_write[ADDR_W-1:0];
                            offset_q_c[seq_idx]   <= merged_write[ADDR_W-1:0];
                            offset_inv_q[seq_idx] <= ~merged_write[ADDR_W-1:0];
                            offset_sig_q[seq_idx] <= ^merged_write[ADDR_W-1:0];
                        end
                        ENTRY_MASK_OFF: begin
                            merged_write = apply_wstrb(mask_voted_local, write_data_comb, write_strb_comb);
                            mask_q_a[seq_idx]   <= merged_write;
                            mask_q_b[seq_idx]   <= merged_write;
                            mask_q_c[seq_idx]   <= merged_write;
                            mask_inv_q[seq_idx] <= ~merged_write;
                            mask_sig_q[seq_idx] <= ^merged_write;
                        end
                        ENTRY_BURST_OFF: begin
                            merged_write = apply_wstrb(
                                burst_read_value_voted(seq_idx, burst_type_voted_local,
                                    burst_len_voted_local, entry_valid_voted_local),
                                write_data_comb, write_strb_comb);
                            burst_type_q_a[seq_idx]   <= merged_write[1:0];
                            burst_type_q_b[seq_idx]   <= merged_write[1:0];
                            burst_type_q_c[seq_idx]   <= merged_write[1:0];
                            burst_type_inv_q[seq_idx] <= ~merged_write[1:0];
                            burst_len_q_a[seq_idx]    <= merged_write[15:8];
                            burst_len_q_b[seq_idx]    <= merged_write[15:8];
                            burst_len_q_c[seq_idx]    <= merged_write[15:8];
                            burst_len_inv_q[seq_idx]  <= ~merged_write[15:8];
                            entry_valid_q_a[seq_idx]  <= merged_write[16];
                            entry_valid_q_b[seq_idx]  <= merged_write[16];
                            entry_valid_q_c[seq_idx]  <= merged_write[16];
                            entry_valid_inv_q[seq_idx]<= ~merged_write[16];
                        end
                        ENTRY_EXPECTED_OFF: begin
                            merged_write = apply_wstrb(expected_voted_local, write_data_comb, write_strb_comb);
                            expected_q_a[seq_idx]   <= merged_write;
                            expected_q_b[seq_idx]   <= merged_write;
                            expected_q_c[seq_idx]   <= merged_write;
                            expected_inv_q[seq_idx] <= ~merged_write;
                            expected_sig_q[seq_idx] <= ^merged_write;
                        end
                        default: begin
                            write_resp_comb  = RESP_SLVERR;
                            cfg_illegal_r_a  <= 1'b1;
                            cfg_illegal_r_b  <= 1'b1;
                            cfg_illegal_r_c  <= 1'b1;
                            cfg_illegal_inv  <= 1'b0;
                        end
                    endcase
                end else begin
                    write_resp_comb  = RESP_SLVERR;
                    cfg_illegal_r_a  <= 1'b1;
                    cfg_illegal_r_b  <= 1'b1;
                    cfg_illegal_r_c  <= 1'b1;
                    cfg_illegal_inv  <= 1'b0;
                end
            end else begin
                write_resp_comb  = RESP_SLVERR;
                cfg_illegal_r_a  <= 1'b1;
                cfg_illegal_r_b  <= 1'b1;
                cfg_illegal_r_c  <= 1'b1;
                cfg_illegal_inv  <= 1'b0;
            end

            if (shadow_error_comb && write_resp_comb == RESP_OKAY) begin
                write_resp_comb = RESP_SLVERR;
                cfg_illegal_r_a <= 1'b1;
                cfg_illegal_r_b <= 1'b1;
                cfg_illegal_r_c <= 1'b1;
                cfg_illegal_inv <= 1'b0;
            end

            s_axi_bid     <= write_id_comb;
            s_axi_bresp   <= write_resp_comb;
            s_axi_bvalid  <= 1'b1;
            s_axi_awready <= 1'b0;
            s_axi_wready  <= 1'b0;
            aw_seen_q     <= 1'b0;
            w_seen_q      <= 1'b0;
        end else if (s_axi_bvalid && s_axi_bready) begin
            s_axi_bvalid  <= 1'b0;
            s_axi_awready <= 1'b1;
            s_axi_wready  <= 1'b1;
        end else if (!s_axi_bvalid) begin
            s_axi_awready <= !(aw_seen_q | aw_fire);
            s_axi_wready  <= !(w_seen_q | w_fire);
        end

        if (ar_fire) begin
            s_axi_rid    <= s_axi_arid;
            s_axi_rdata  <= read_data_comb;
            s_axi_rresp  <= read_resp_comb;
            s_axi_rlast  <= 1'b1;
            s_axi_rvalid <= 1'b1;
            s_axi_arready<= 1'b0;
        end else if (s_axi_rvalid && s_axi_rready) begin
            s_axi_rvalid <= 1'b0;
            s_axi_rlast  <= 1'b0;
            s_axi_arready<= 1'b1;
        end else if (!s_axi_rvalid) begin
            s_axi_arready<= 1'b1;
        end
    end
end

endmodule
