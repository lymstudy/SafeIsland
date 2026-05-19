//------------------------------------------------------------------------------
// safety_island_core_logic.v
//
// AXI Safety Island core control logic.
//
// This module does not implement AXI4 protocol channels.  It talks to external
// AXI slave configuration logic through decoded configuration buses, and talks
// to external AXI master read engines through an abstract read-request/read-done
// interface.
//
// Main functions:
//   1. Periodic or one-shot scan scheduling.
//   2. Traversal of NUM_MASTERS masters and NUM_ENTRIES entries per master.
//   3. Read address generation: base_addr[master] + offset[master][entry].
//   4. Burst type/length forwarding and basic burst legality checks.
//   5. Mask + OR accumulation of returned safety register bits.
//   6. Fault classification:
//        - external_fault_event: external monitored register bits are set.
//        - bus_fault_event     : read response error or timeout.
//        - cfg_fault_event     : illegal configuration or shadow mismatch.
//        - safety_island_fault_event: internal core logic protection failure.
//
// Read request convention:
//   m_read_req is asserted for the selected master and held until that master's
//   m_read_accept is observed.  The address, burst type, and burst length lanes
//   for that master remain valid while m_read_req is asserted.
//
// Outstanding convention:
//   SUPPORT_OUTSTANDING=0 keeps the conservative one-request-at-a-time mode.
//   SUPPORT_OUTSTANDING=1 enables a small in-order FIFO framework.  The core can
//   issue multiple requests within one master up to MAX_OUTSTANDING, but it
//   drains all outstanding requests before moving to the next master.  The
//   external read engine is therefore expected to return completions in issue
//   order for a given master; no AXI ID reorder/interleaving is implemented here.
//------------------------------------------------------------------------------

module safety_island_core_logic
#(
    parameter NUM_MASTERS         = 5,
    parameter NUM_ENTRIES         = 64,
    parameter ADDR_W              = 32,
    parameter DATA_W              = 64,
    parameter BURST_TYPE_W        = 2,
    parameter BURST_LEN_W         = 8,
    parameter SUPPORT_OUTSTANDING = 0,
    parameter MAX_OUTSTANDING     = 1
)
(
    input  wire                                      clk,
    input  wire                                      rst,

    input  wire                                      enable,
    input  wire                                      scan_once,
    input  wire                                      clear_core_status,
    input  wire [63:0]                               read_interval,

    input  wire [NUM_MASTERS*ADDR_W-1:0]             base_addr_flat,
    input  wire [NUM_MASTERS*NUM_ENTRIES*ADDR_W-1:0] offset_flat,
    input  wire [NUM_MASTERS*NUM_ENTRIES*DATA_W-1:0] mask_flat,
    input  wire [NUM_MASTERS*NUM_ENTRIES*BURST_TYPE_W-1:0]
                                                     burst_type_flat,
    input  wire [NUM_MASTERS*NUM_ENTRIES*BURST_LEN_W-1:0]
                                                     burst_len_flat,
    input  wire [NUM_MASTERS*NUM_ENTRIES-1:0]        entry_valid_flat,

    input  wire                                      cfg_valid,
    input  wire                                      cfg_locked,
    input  wire                                      cfg_illegal,
    input  wire                                      cfg_shadow_error,

    output reg  [NUM_MASTERS-1:0]                    m_read_req,
    output reg  [NUM_MASTERS*ADDR_W-1:0]             m_read_addr_flat,
    output reg  [NUM_MASTERS*BURST_TYPE_W-1:0]       m_burst_type_flat,
    output reg  [NUM_MASTERS*BURST_LEN_W-1:0]        m_burst_len_flat,

    input  wire [NUM_MASTERS-1:0]                    m_read_accept,
    input  wire [NUM_MASTERS-1:0]                    m_read_done,
    input  wire [NUM_MASTERS*DATA_W-1:0]             m_read_data_flat,
    input  wire [NUM_MASTERS-1:0]                    m_resp_error,
    input  wire [NUM_MASTERS-1:0]                    m_timeout,

    output reg                                       scan_busy,
    output reg                                       scan_done_pulse,
    output reg  [31:0]                               current_master_idx,
    output reg  [31:0]                               current_entry_idx,
    output reg  [DATA_W-1:0]                         fault_or_result,
    output reg                                       external_fault_event,
    output reg                                       bus_fault_event,
    output reg                                       cfg_fault_event,
    output reg                                       safety_island_fault_event,
    output reg  [7:0]                                core_error_code,
    output reg  [31:0]                               outstanding_count
);

//------------------------------------------------------------------------------
// FSM encoding and error codes
//------------------------------------------------------------------------------

localparam [3:0] ST_IDLE          = 4'h1;
localparam [3:0] ST_WAIT_INTERVAL = 4'h2;
localparam [3:0] ST_PREP_SCAN     = 4'h3;
localparam [3:0] ST_FIND_ENTRY    = 4'h4;
localparam [3:0] ST_ISSUE_REQ     = 4'h5;
localparam [3:0] ST_WAIT_DONE     = 4'h6;
localparam [3:0] ST_WAIT_SLOT     = 4'h7;
localparam [3:0] ST_ADVANCE       = 4'h8;
localparam [3:0] ST_DRAIN_MASTER  = 4'h9;
localparam [3:0] ST_SCAN_DONE     = 4'hA;
localparam [3:0] ST_SAFE_ERROR    = 4'hF;

localparam [7:0] ERR_NONE              = 8'h00;
localparam [7:0] ERR_CFG_ILLEGAL       = 8'h10;
localparam [7:0] ERR_CFG_SHADOW        = 8'h11;
localparam [7:0] ERR_CFG_INTERVAL_ZERO = 8'h12;
localparam [7:0] ERR_CFG_BURST_TYPE    = 8'h13;
localparam [7:0] ERR_CFG_BURST_LEN     = 8'h14;
localparam [7:0] ERR_CFG_PARAMETER     = 8'h15;
localparam [7:0] ERR_BUS_RESP          = 8'h20;
localparam [7:0] ERR_BUS_TIMEOUT       = 8'h21;
localparam [7:0] ERR_EXTERNAL_FAULT    = 8'h30;
localparam [7:0] ERR_FSM_ILLEGAL       = 8'h40;
localparam [7:0] ERR_FSM_INV_MISMATCH  = 8'h41;
localparam [7:0] ERR_INDEX_RANGE       = 8'h42;
localparam [7:0] ERR_ACCUM_SHADOW      = 8'h43;
localparam [7:0] ERR_OUTSTANDING       = 8'h44;
localparam [7:0] ERR_PENDING_FIFO      = 8'h45;

localparam [BURST_TYPE_W-1:0] BURST_TYPE_INCR = 2'b01;
localparam [BURST_TYPE_W-1:0] BURST_TYPE_WRAP = 2'b10;

// AXI-style ARLEN values for WRAP bursts: 2, 4, 8, and 16 beats.
// INCR is intentionally not limited to 16 beats so the 8-bit length field can
// support 16-beat and larger bursts when the external read engine supports them.
localparam [BURST_LEN_W-1:0] WRAP_ARLEN_2_BEATS  = 8'd1;
localparam [BURST_LEN_W-1:0] WRAP_ARLEN_4_BEATS  = 8'd3;
localparam [BURST_LEN_W-1:0] WRAP_ARLEN_8_BEATS  = 8'd7;
localparam [BURST_LEN_W-1:0] WRAP_ARLEN_16_BEATS = 8'd15;

//------------------------------------------------------------------------------
// Registers and pending request FIFO for simple outstanding support
//------------------------------------------------------------------------------

reg [3:0]        state;
reg [3:0]        state_inv;
reg [3:0]        state_next;
reg [63:0]       interval_counter;
reg              scan_once_d;
reg              scan_once_pending;

reg [DATA_W-1:0] fault_or_accum;
reg [DATA_W-1:0] fault_or_accum_inv;

reg [DATA_W-1:0] pending_mask_q   [0:MAX_OUTSTANDING-1];
reg [31:0]       pending_master_q [0:MAX_OUTSTANDING-1];
reg [31:0]       pending_entry_q  [0:MAX_OUTSTANDING-1];
reg              pending_valid_q  [0:MAX_OUTSTANDING-1];
reg [31:0]       pending_wr_ptr;
reg [31:0]       pending_rd_ptr;

integer cfg_m;
integer cfg_e;
integer seq_i;
integer seq_m;

//------------------------------------------------------------------------------
// Flat bus access functions
//------------------------------------------------------------------------------

function [ADDR_W-1:0] get_base_addr;
    input integer master;
    integer bit_base;
begin
    bit_base = master * ADDR_W;
    if ((master >= 0) && (master < NUM_MASTERS))
        get_base_addr = base_addr_flat[bit_base +: ADDR_W];
    else
        get_base_addr = {ADDR_W{1'b0}};
end
endfunction

function [ADDR_W-1:0] get_offset;
    input integer master;
    input integer entry;
    integer bit_base;
begin
    bit_base = ((master * NUM_ENTRIES) + entry) * ADDR_W;
    if ((master >= 0) && (master < NUM_MASTERS) &&
        (entry  >= 0) && (entry  < NUM_ENTRIES))
        get_offset = offset_flat[bit_base +: ADDR_W];
    else
        get_offset = {ADDR_W{1'b0}};
end
endfunction

function [DATA_W-1:0] get_mask;
    input integer master;
    input integer entry;
    integer bit_base;
begin
    bit_base = ((master * NUM_ENTRIES) + entry) * DATA_W;
    if ((master >= 0) && (master < NUM_MASTERS) &&
        (entry  >= 0) && (entry  < NUM_ENTRIES))
        get_mask = mask_flat[bit_base +: DATA_W];
    else
        get_mask = {DATA_W{1'b0}};
end
endfunction

function [BURST_TYPE_W-1:0] get_burst_type;
    input integer master;
    input integer entry;
    integer bit_base;
begin
    bit_base = ((master * NUM_ENTRIES) + entry) * BURST_TYPE_W;
    if ((master >= 0) && (master < NUM_MASTERS) &&
        (entry  >= 0) && (entry  < NUM_ENTRIES))
        get_burst_type = burst_type_flat[bit_base +: BURST_TYPE_W];
    else
        get_burst_type = {BURST_TYPE_W{1'b0}};
end
endfunction

function [BURST_LEN_W-1:0] get_burst_len;
    input integer master;
    input integer entry;
    integer bit_base;
begin
    bit_base = ((master * NUM_ENTRIES) + entry) * BURST_LEN_W;
    if ((master >= 0) && (master < NUM_MASTERS) &&
        (entry  >= 0) && (entry  < NUM_ENTRIES))
        get_burst_len = burst_len_flat[bit_base +: BURST_LEN_W];
    else
        get_burst_len = {BURST_LEN_W{1'b0}};
end
endfunction

function get_entry_valid;
    input integer master;
    input integer entry;
    integer bit_index;
begin
    bit_index = (master * NUM_ENTRIES) + entry;
    if ((master >= 0) && (master < NUM_MASTERS) &&
        (entry  >= 0) && (entry  < NUM_ENTRIES))
        get_entry_valid = entry_valid_flat[bit_index];
    else
        get_entry_valid = 1'b0;
end
endfunction

function [DATA_W-1:0] get_read_data;
    input integer master;
    integer bit_base;
begin
    bit_base = master * DATA_W;
    if ((master >= 0) && (master < NUM_MASTERS))
        get_read_data = m_read_data_flat[bit_base +: DATA_W];
    else
        get_read_data = {DATA_W{1'b0}};
end
endfunction

function get_master_flag;
    input [NUM_MASTERS-1:0] flag_vec;
    input integer master;
begin
    if ((master >= 0) && (master < NUM_MASTERS))
        get_master_flag = flag_vec[master];
    else
        get_master_flag = 1'b0;
end
endfunction

function is_burst_type_legal;
    input [BURST_TYPE_W-1:0] burst_type;
begin
    is_burst_type_legal =
        ((burst_type == BURST_TYPE_INCR) || (burst_type == BURST_TYPE_WRAP));
end
endfunction

function is_burst_len_legal;
    input [BURST_TYPE_W-1:0] burst_type;
    input [BURST_LEN_W-1:0]  burst_len;
begin
    if (burst_type == BURST_TYPE_INCR) begin
        is_burst_len_legal = 1'b1;
    end else if (burst_type == BURST_TYPE_WRAP) begin
        is_burst_len_legal =
            ((burst_len == WRAP_ARLEN_2_BEATS)  ||
             (burst_len == WRAP_ARLEN_4_BEATS)  ||
             (burst_len == WRAP_ARLEN_8_BEATS)  ||
             (burst_len == WRAP_ARLEN_16_BEATS));
    end else begin
        is_burst_len_legal = 1'b0;
    end
end
endfunction

function [31:0] inc_pending_ptr;
    input [31:0] ptr;
begin
    if (ptr >= (MAX_OUTSTANDING - 1))
        inc_pending_ptr = 32'd0;
    else
        inc_pending_ptr = ptr + 32'd1;
end
endfunction

//------------------------------------------------------------------------------
// Current entry decode and configuration checking
//------------------------------------------------------------------------------

wire [ADDR_W-1:0]        current_base_addr;
wire [ADDR_W-1:0]        current_offset;
wire [ADDR_W-1:0]        current_read_addr;
wire [DATA_W-1:0]        current_mask;
wire [BURST_TYPE_W-1:0]  current_burst_type;
wire [BURST_LEN_W-1:0]   current_burst_len;
wire                     current_entry_valid;
wire                     current_burst_type_legal;
wire                     current_burst_len_legal;
wire                     current_burst_cfg_legal;

assign current_base_addr        = get_base_addr(current_master_idx);
assign current_offset           = get_offset(current_master_idx, current_entry_idx);
assign current_read_addr        = current_base_addr + current_offset;
assign current_mask             = get_mask(current_master_idx, current_entry_idx);
assign current_burst_type       = get_burst_type(current_master_idx, current_entry_idx);
assign current_burst_len        = get_burst_len(current_master_idx, current_entry_idx);
assign current_entry_valid      = get_entry_valid(current_master_idx, current_entry_idx);
assign current_burst_type_legal = is_burst_type_legal(current_burst_type);
assign current_burst_len_legal  = is_burst_len_legal(current_burst_type,
                                                     current_burst_len);
assign current_burst_cfg_legal  = current_burst_type_legal &
                                  current_burst_len_legal;

wire at_last_master;
wire at_last_entry;

assign at_last_master = (current_master_idx == (NUM_MASTERS - 1));
assign at_last_entry  = (current_entry_idx  == (NUM_ENTRIES - 1));

reg cfg_burst_type_fault_comb;
reg cfg_burst_len_fault_comb;
reg [7:0] cfg_error_code_comb;

wire cfg_parameter_fault_comb;
wire cfg_interval_fault_comb;
wire cfg_table_fault_comb;
wire cfg_fault_comb;
wire cfg_operational;

assign cfg_parameter_fault_comb =
    ((NUM_MASTERS < 1) || (NUM_ENTRIES < 1) ||
     (ADDR_W < 1) || (DATA_W < 1) ||
     (BURST_TYPE_W < 2) || (BURST_LEN_W < 4) ||
     (MAX_OUTSTANDING < 1));

assign cfg_interval_fault_comb = cfg_valid & cfg_locked &
                                 (read_interval == 64'd0);
assign cfg_table_fault_comb    = cfg_burst_type_fault_comb |
                                 cfg_burst_len_fault_comb;
assign cfg_fault_comb          = cfg_illegal | cfg_shadow_error |
                                 cfg_interval_fault_comb |
                                 cfg_table_fault_comb |
                                 (cfg_valid & cfg_locked &
                                  cfg_parameter_fault_comb);
assign cfg_operational         = cfg_valid & cfg_locked & ~cfg_fault_comb;

always @* begin
    cfg_burst_type_fault_comb = 1'b0;
    cfg_burst_len_fault_comb  = 1'b0;

    if (cfg_valid && cfg_locked) begin
        for (cfg_m = 0; cfg_m < NUM_MASTERS; cfg_m = cfg_m + 1) begin
            for (cfg_e = 0; cfg_e < NUM_ENTRIES; cfg_e = cfg_e + 1) begin
                if (get_entry_valid(cfg_m, cfg_e)) begin
                    if (!is_burst_type_legal(get_burst_type(cfg_m, cfg_e))) begin
                        cfg_burst_type_fault_comb = 1'b1;
                    end else if (!is_burst_len_legal(get_burst_type(cfg_m, cfg_e),
                                                     get_burst_len(cfg_m, cfg_e))) begin
                        cfg_burst_len_fault_comb = 1'b1;
                    end
                end
            end
        end
    end
end

always @* begin
    cfg_error_code_comb = ERR_NONE;
    if (cfg_illegal)
        cfg_error_code_comb = ERR_CFG_ILLEGAL;
    else if (cfg_shadow_error)
        cfg_error_code_comb = ERR_CFG_SHADOW;
    else if (cfg_interval_fault_comb)
        cfg_error_code_comb = ERR_CFG_INTERVAL_ZERO;
    else if (cfg_burst_type_fault_comb)
        cfg_error_code_comb = ERR_CFG_BURST_TYPE;
    else if (cfg_burst_len_fault_comb)
        cfg_error_code_comb = ERR_CFG_BURST_LEN;
    else if (cfg_valid && cfg_locked && cfg_parameter_fault_comb)
        cfg_error_code_comb = ERR_CFG_PARAMETER;
end

//------------------------------------------------------------------------------
// Outstanding response decode
//------------------------------------------------------------------------------

wire [31:0]       response_master_idx;
wire [31:0]       response_entry_idx;
wire              response_master_in_range;
wire              response_fifo_valid;
wire              response_done_flag;
wire              response_error_flag;
wire              response_timeout_flag;
wire              response_seen_comb;
wire              response_bus_fault_comb;
wire [DATA_W-1:0] response_read_data;
wire [DATA_W-1:0] response_masked_data;
wire [DATA_W-1:0] response_accum_next;

assign response_master_idx      = pending_master_q[pending_rd_ptr];
assign response_entry_idx       = pending_entry_q[pending_rd_ptr];
assign response_master_in_range = (response_master_idx < NUM_MASTERS);
assign response_fifo_valid      = (outstanding_count != 32'd0) &&
                                  pending_valid_q[pending_rd_ptr];
assign response_done_flag       = get_master_flag(m_read_done,
                                                  response_master_idx);
assign response_error_flag      = get_master_flag(m_resp_error,
                                                  response_master_idx);
assign response_timeout_flag    = get_master_flag(m_timeout,
                                                  response_master_idx);
assign response_seen_comb       = response_fifo_valid &&
                                  response_master_in_range &&
                                  (response_done_flag ||
                                   response_error_flag ||
                                   response_timeout_flag);
assign response_bus_fault_comb  = response_seen_comb &&
                                  (response_error_flag ||
                                   response_timeout_flag);
assign response_read_data       = get_read_data(response_master_idx);
assign response_masked_data     = response_read_data &
                                  pending_mask_q[pending_rd_ptr];
assign response_accum_next      = fault_or_accum | response_masked_data;

wire current_read_accept;
wire current_read_req_active;
wire request_handshake_comb;
wire issue_slot_available;
wire push_request_comb;
wire pop_response_comb;

assign current_read_accept = get_master_flag(m_read_accept,
                                             current_master_idx);
assign current_read_req_active = get_master_flag(m_read_req,
                                                 current_master_idx);
assign request_handshake_comb = current_read_req_active & current_read_accept;
assign issue_slot_available =
    (SUPPORT_OUTSTANDING == 0) ? (outstanding_count == 32'd0) :
                                 (outstanding_count < MAX_OUTSTANDING);
assign push_request_comb =
    (state == ST_ISSUE_REQ) &&
    request_handshake_comb &&
    current_entry_valid &&
    current_burst_cfg_legal &&
    issue_slot_available &&
    !cfg_fault_comb;
assign pop_response_comb = response_seen_comb;

//------------------------------------------------------------------------------
// Functional safety protection checks
//------------------------------------------------------------------------------

wire fsm_state_legal_comb;
wire fsm_state_illegal_comb;
wire state_inv_mismatch_comb;
wire current_index_fault_comb;
wire pending_index_fault_comb;
wire pending_ptr_fault_comb;
wire pending_valid_fault_comb;
wire accum_shadow_fault_comb;
wire outstanding_fault_comb;
wire safety_fault_comb;
reg  [7:0] safety_error_code_comb;

assign fsm_state_legal_comb =
    ((state == ST_IDLE)          ||
     (state == ST_WAIT_INTERVAL) ||
     (state == ST_PREP_SCAN)     ||
     (state == ST_FIND_ENTRY)    ||
     (state == ST_ISSUE_REQ)     ||
     (state == ST_WAIT_DONE)     ||
     (state == ST_WAIT_SLOT)     ||
     (state == ST_ADVANCE)       ||
     (state == ST_DRAIN_MASTER)  ||
     (state == ST_SCAN_DONE)     ||
     (state == ST_SAFE_ERROR));

assign fsm_state_illegal_comb  = !fsm_state_legal_comb;
assign state_inv_mismatch_comb = (state_inv != ~state);

assign current_index_fault_comb =
    (current_master_idx >= NUM_MASTERS) ||
    (current_entry_idx  >= NUM_ENTRIES);

assign pending_index_fault_comb =
    (outstanding_count != 32'd0) &&
    ((response_master_idx >= NUM_MASTERS) ||
     (response_entry_idx  >= NUM_ENTRIES));

assign pending_ptr_fault_comb =
    (pending_wr_ptr >= MAX_OUTSTANDING) ||
    (pending_rd_ptr >= MAX_OUTSTANDING);

assign pending_valid_fault_comb =
    (outstanding_count != 32'd0) &&
    !pending_valid_q[pending_rd_ptr];

assign accum_shadow_fault_comb = (fault_or_accum_inv != ~fault_or_accum);

assign outstanding_fault_comb =
    (SUPPORT_OUTSTANDING == 0) ? (outstanding_count > 32'd1) :
                                 (outstanding_count > MAX_OUTSTANDING);

assign safety_fault_comb =
    fsm_state_illegal_comb      |
    state_inv_mismatch_comb     |
    current_index_fault_comb    |
    pending_index_fault_comb    |
    pending_ptr_fault_comb      |
    pending_valid_fault_comb    |
    accum_shadow_fault_comb     |
    outstanding_fault_comb;

always @* begin
    safety_error_code_comb = ERR_NONE;
    if (fsm_state_illegal_comb)
        safety_error_code_comb = ERR_FSM_ILLEGAL;
    else if (state_inv_mismatch_comb)
        safety_error_code_comb = ERR_FSM_INV_MISMATCH;
    else if (current_index_fault_comb || pending_index_fault_comb)
        safety_error_code_comb = ERR_INDEX_RANGE;
    else if (accum_shadow_fault_comb)
        safety_error_code_comb = ERR_ACCUM_SHADOW;
    else if (outstanding_fault_comb)
        safety_error_code_comb = ERR_OUTSTANDING;
    else if (pending_ptr_fault_comb || pending_valid_fault_comb)
        safety_error_code_comb = ERR_PENDING_FIFO;
end

//------------------------------------------------------------------------------
// Scan trigger and FSM next-state logic
//------------------------------------------------------------------------------

wire scan_once_re;
wire scan_once_req_comb;
wire interval_expired_comb;
wire scan_start_comb;
reg  scan_busy_next_comb;

assign scan_once_re        = scan_once & ~scan_once_d;
assign scan_once_req_comb  = scan_once_pending | scan_once_re;
assign interval_expired_comb =
    (read_interval != 64'd0) && (interval_counter >= (read_interval - 64'd1));
assign scan_start_comb =
    cfg_operational &&
    (scan_once_req_comb || (enable && interval_expired_comb));

always @* begin
    state_next = state;

    case (state)
        ST_IDLE: begin
            if (cfg_fault_comb)
                state_next = ST_IDLE;
            else if (scan_start_comb)
                state_next = ST_PREP_SCAN;
            else if (enable && cfg_operational)
                state_next = ST_WAIT_INTERVAL;
            else
                state_next = ST_IDLE;
        end

        ST_WAIT_INTERVAL: begin
            if (cfg_fault_comb)
                state_next = ST_IDLE;
            else if (scan_start_comb)
                state_next = ST_PREP_SCAN;
            else if (enable && cfg_operational)
                state_next = ST_WAIT_INTERVAL;
            else if (scan_once_req_comb && cfg_operational)
                state_next = ST_PREP_SCAN;
            else
                state_next = ST_IDLE;
        end

        ST_PREP_SCAN: begin
            if (cfg_fault_comb)
                state_next = ST_IDLE;
            else
                state_next = ST_FIND_ENTRY;
        end

        ST_FIND_ENTRY: begin
            if (cfg_fault_comb) begin
                state_next = ST_IDLE;
            end else if (!current_entry_valid) begin
                state_next = ST_ADVANCE;
            end else if (!current_burst_cfg_legal) begin
                state_next = ST_IDLE;
            end else if (issue_slot_available) begin
                state_next = ST_ISSUE_REQ;
            end else begin
                state_next = ST_WAIT_SLOT;
            end
        end

        ST_ISSUE_REQ: begin
            if (cfg_fault_comb) begin
                state_next = ST_IDLE;
            end else if (!issue_slot_available) begin
                state_next = ST_WAIT_SLOT;
            end else if (request_handshake_comb) begin
                if (SUPPORT_OUTSTANDING == 0)
                    state_next = ST_WAIT_DONE;
                else
                    state_next = ST_ADVANCE;
            end else begin
                state_next = ST_ISSUE_REQ;
            end
        end

        ST_WAIT_DONE: begin
            if (cfg_fault_comb)
                state_next = ST_IDLE;
            else if ((outstanding_count == 32'd0) || response_seen_comb)
                state_next = ST_ADVANCE;
            else
                state_next = ST_WAIT_DONE;
        end

        ST_WAIT_SLOT: begin
            if (cfg_fault_comb)
                state_next = ST_IDLE;
            else if (SUPPORT_OUTSTANDING == 0)
                state_next = ST_WAIT_DONE;
            else if (outstanding_count < MAX_OUTSTANDING)
                state_next = ST_FIND_ENTRY;
            else if (response_seen_comb)
                state_next = ST_FIND_ENTRY;
            else
                state_next = ST_WAIT_SLOT;
        end

        ST_ADVANCE: begin
            if (cfg_fault_comb) begin
                state_next = ST_IDLE;
            end else if (at_last_entry && (outstanding_count != 32'd0)) begin
                state_next = ST_DRAIN_MASTER;
            end else if (at_last_entry && at_last_master) begin
                state_next = ST_SCAN_DONE;
            end else begin
                state_next = ST_FIND_ENTRY;
            end
        end

        ST_DRAIN_MASTER: begin
            if (cfg_fault_comb)
                state_next = ST_IDLE;
            else if (outstanding_count == 32'd0)
                state_next = ST_ADVANCE;
            else if (response_seen_comb && (outstanding_count <= 32'd1))
                state_next = ST_ADVANCE;
            else
                state_next = ST_DRAIN_MASTER;
        end

        ST_SCAN_DONE: begin
            if (cfg_fault_comb)
                state_next = ST_IDLE;
            else if (scan_start_comb)
                state_next = ST_PREP_SCAN;
            else if (enable && cfg_operational)
                state_next = ST_WAIT_INTERVAL;
            else
                state_next = ST_IDLE;
        end

        ST_SAFE_ERROR: begin
            state_next = ST_SAFE_ERROR;
        end

        default: begin
            state_next = ST_SAFE_ERROR;
        end
    endcase

    if (safety_fault_comb)
        state_next = ST_SAFE_ERROR;
end

always @* begin
    scan_busy_next_comb = 1'b0;
    case (state_next)
        ST_PREP_SCAN,
        ST_FIND_ENTRY,
        ST_ISSUE_REQ,
        ST_WAIT_DONE,
        ST_WAIT_SLOT,
        ST_ADVANCE,
        ST_DRAIN_MASTER: begin
            scan_busy_next_comb = 1'b1;
        end
        default: begin
            scan_busy_next_comb = 1'b0;
        end
    endcase
end

//------------------------------------------------------------------------------
// Sequential logic
//------------------------------------------------------------------------------

always @(posedge clk) begin
    if (rst) begin
        state                     <= ST_IDLE;
        state_inv                 <= ~ST_IDLE;
        interval_counter          <= 64'd0;
        scan_once_d               <= 1'b0;
        scan_once_pending         <= 1'b0;
        fault_or_accum            <= {DATA_W{1'b0}};
        fault_or_accum_inv        <= {DATA_W{1'b1}};
        pending_wr_ptr            <= 32'd0;
        pending_rd_ptr            <= 32'd0;
        outstanding_count         <= 32'd0;

        m_read_req                <= {NUM_MASTERS{1'b0}};
        m_read_addr_flat          <= {(NUM_MASTERS*ADDR_W){1'b0}};
        m_burst_type_flat         <= {(NUM_MASTERS*BURST_TYPE_W){1'b0}};
        m_burst_len_flat          <= {(NUM_MASTERS*BURST_LEN_W){1'b0}};

        scan_busy                 <= 1'b0;
        scan_done_pulse           <= 1'b0;
        current_master_idx        <= 32'd0;
        current_entry_idx         <= 32'd0;
        fault_or_result           <= {DATA_W{1'b0}};
        external_fault_event      <= 1'b0;
        bus_fault_event           <= 1'b0;
        cfg_fault_event           <= 1'b0;
        safety_island_fault_event <= 1'b0;
        core_error_code           <= ERR_NONE;

        for (seq_i = 0; seq_i < MAX_OUTSTANDING; seq_i = seq_i + 1) begin
            pending_mask_q[seq_i]   <= {DATA_W{1'b0}};
            pending_master_q[seq_i] <= 32'd0;
            pending_entry_q[seq_i]  <= 32'd0;
            pending_valid_q[seq_i]  <= 1'b0;
        end
    end else begin
        scan_once_d     <= scan_once;
        scan_done_pulse <= 1'b0;
        m_read_req      <= {NUM_MASTERS{1'b0}};

        if (clear_core_status) begin
            state                     <= ST_IDLE;
            state_inv                 <= ~ST_IDLE;
            interval_counter          <= 64'd0;
            scan_once_pending         <= 1'b0;
            fault_or_accum            <= {DATA_W{1'b0}};
            fault_or_accum_inv        <= {DATA_W{1'b1}};
            pending_wr_ptr            <= 32'd0;
            pending_rd_ptr            <= 32'd0;
            outstanding_count         <= 32'd0;
            m_read_addr_flat          <= {(NUM_MASTERS*ADDR_W){1'b0}};
            m_burst_type_flat         <= {(NUM_MASTERS*BURST_TYPE_W){1'b0}};
            m_burst_len_flat          <= {(NUM_MASTERS*BURST_LEN_W){1'b0}};
            scan_busy                 <= 1'b0;
            current_master_idx        <= 32'd0;
            current_entry_idx         <= 32'd0;
            fault_or_result           <= {DATA_W{1'b0}};
            external_fault_event      <= 1'b0;
            bus_fault_event           <= 1'b0;
            cfg_fault_event           <= 1'b0;
            safety_island_fault_event <= 1'b0;
            core_error_code           <= ERR_NONE;

            for (seq_i = 0; seq_i < MAX_OUTSTANDING; seq_i = seq_i + 1) begin
                pending_mask_q[seq_i]   <= {DATA_W{1'b0}};
                pending_master_q[seq_i] <= 32'd0;
                pending_entry_q[seq_i]  <= 32'd0;
                pending_valid_q[seq_i]  <= 1'b0;
            end
        end else begin
            state     <= state_next;
            state_inv <= ~state_next;
            scan_busy <= scan_busy_next_comb;

            if (scan_once_re)
                scan_once_pending <= 1'b1;
            if (state_next == ST_PREP_SCAN)
                scan_once_pending <= 1'b0;

            if (state_next == ST_PREP_SCAN) begin
                interval_counter <= 64'd0;
            end else if (state == ST_WAIT_INTERVAL && enable && cfg_operational) begin
                if (!interval_expired_comb)
                    interval_counter <= interval_counter + 64'd1;
            end else if (!enable || !cfg_operational) begin
                interval_counter <= 64'd0;
            end

            if (safety_fault_comb) begin
                safety_island_fault_event <= 1'b1;
                if (core_error_code == ERR_NONE)
                    core_error_code <= safety_error_code_comb;
            end

            if (cfg_fault_comb) begin
                cfg_fault_event <= 1'b1;
                if (core_error_code == ERR_NONE)
                    core_error_code <= cfg_error_code_comb;
            end

            // Pop one completed read from the in-order pending FIFO.  Normal
            // data contributes to Mask+OR; response errors and timeouts are
            // classified as bus faults and do not update the external fault OR.
            if (pop_response_comb) begin
                pending_valid_q[pending_rd_ptr] <= 1'b0;
                pending_rd_ptr <= inc_pending_ptr(pending_rd_ptr);

                if (response_bus_fault_comb) begin
                    bus_fault_event <= 1'b1;
                    if (core_error_code == ERR_NONE) begin
                        if (response_timeout_flag)
                            core_error_code <= ERR_BUS_TIMEOUT;
                        else
                            core_error_code <= ERR_BUS_RESP;
                    end
                end else begin
                    fault_or_accum     <= response_accum_next;
                    fault_or_accum_inv <= ~response_accum_next;
                end
            end

            // Push a newly accepted request into the pending FIFO.  The stored
            // mask is later paired with the returned data for Mask+OR.
            if (push_request_comb) begin
                pending_mask_q[pending_wr_ptr]   <= current_mask;
                pending_master_q[pending_wr_ptr] <= current_master_idx;
                pending_entry_q[pending_wr_ptr]  <= current_entry_idx;
                pending_valid_q[pending_wr_ptr]  <= 1'b1;
                pending_wr_ptr                   <= inc_pending_ptr(pending_wr_ptr);
            end

            if (push_request_comb && !pop_response_comb) begin
                outstanding_count <= outstanding_count + 32'd1;
            end else if (!push_request_comb && pop_response_comb) begin
                outstanding_count <= outstanding_count - 32'd1;
            end

            case (state)
                ST_IDLE: begin
                    current_master_idx <= 32'd0;
                    current_entry_idx  <= 32'd0;
                end

                ST_PREP_SCAN: begin
                    current_master_idx <= 32'd0;
                    current_entry_idx  <= 32'd0;
                    fault_or_accum     <= {DATA_W{1'b0}};
                    fault_or_accum_inv <= {DATA_W{1'b1}};
                    pending_wr_ptr     <= 32'd0;
                    pending_rd_ptr     <= 32'd0;
                    outstanding_count  <= 32'd0;

                    for (seq_i = 0; seq_i < MAX_OUTSTANDING; seq_i = seq_i + 1) begin
                        pending_mask_q[seq_i]   <= {DATA_W{1'b0}};
                        pending_master_q[seq_i] <= 32'd0;
                        pending_entry_q[seq_i]  <= 32'd0;
                        pending_valid_q[seq_i]  <= 1'b0;
                    end
                end

                ST_ISSUE_REQ: begin
                    // Hold request valid until the selected read engine accepts.
                    if (!cfg_fault_comb && !safety_fault_comb &&
                        issue_slot_available && current_burst_cfg_legal) begin
                        for (seq_m = 0; seq_m < NUM_MASTERS; seq_m = seq_m + 1) begin
                            if (seq_m == current_master_idx) begin
                                if (!request_handshake_comb)
                                    m_read_req[seq_m] <= 1'b1;
                                m_read_addr_flat[seq_m*ADDR_W +: ADDR_W]
                                    <= current_read_addr;
                                m_burst_type_flat[seq_m*BURST_TYPE_W +: BURST_TYPE_W]
                                    <= current_burst_type;
                                m_burst_len_flat[seq_m*BURST_LEN_W +: BURST_LEN_W]
                                    <= current_burst_len;
                            end
                        end
                    end
                end

                ST_ADVANCE: begin
                    // Traversal order is master 0 entry 0..63, master 1 entry
                    // 0..63, and so on.  In outstanding mode, the core drains
                    // the current master before moving to the next one.
                    if (!(at_last_entry && (outstanding_count != 32'd0))) begin
                        if (at_last_entry) begin
                            if (!at_last_master) begin
                                current_master_idx <= current_master_idx + 32'd1;
                                current_entry_idx  <= 32'd0;
                            end
                        end else begin
                            current_entry_idx <= current_entry_idx + 32'd1;
                        end
                    end
                end

                ST_SCAN_DONE: begin
                    scan_done_pulse <= 1'b1;
                    fault_or_result <= fault_or_accum;

                    if (fault_or_accum != {DATA_W{1'b0}}) begin
                        external_fault_event <= 1'b1;
                        if (core_error_code == ERR_NONE)
                            core_error_code <= ERR_EXTERNAL_FAULT;
                    end
                end

                ST_SAFE_ERROR: begin
                    safety_island_fault_event <= 1'b1;
                    if (core_error_code == ERR_NONE)
                        core_error_code <= ERR_FSM_ILLEGAL;
                end

                default: begin
                    safety_island_fault_event <= 1'b1;
                    if (core_error_code == ERR_NONE)
                        core_error_code <= ERR_FSM_ILLEGAL;
                end
            endcase
        end
    end
end

endmodule
