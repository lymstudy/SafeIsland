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
    output wire                                      cfg_valid,
    output wire                                      cfg_locked,
    output wire                                      cfg_illegal,
    output wire                                      cfg_shadow_error,

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

reg cfg_locked_r;
reg cfg_illegal_r;
reg scan_done_sticky;

reg enable_inv;
reg cfg_locked_inv;
reg cfg_illegal_inv;
reg [63:0] read_interval_inv;

reg [ADDR_W-1:0] base_addr_q     [0:NUM_MASTERS-1];
reg [ADDR_W-1:0] base_addr_inv_q [0:NUM_MASTERS-1];

reg [ADDR_W-1:0] offset_q        [0:NUM_MASTERS*NUM_ENTRIES-1];
reg [ADDR_W-1:0] offset_inv_q    [0:NUM_MASTERS*NUM_ENTRIES-1];
reg [DATA_W-1:0] mask_q          [0:NUM_MASTERS*NUM_ENTRIES-1];
reg [DATA_W-1:0] mask_inv_q      [0:NUM_MASTERS*NUM_ENTRIES-1];
reg [1:0]        burst_type_q    [0:NUM_MASTERS*NUM_ENTRIES-1];
reg [1:0]        burst_type_inv_q[0:NUM_MASTERS*NUM_ENTRIES-1];
reg [7:0]        burst_len_q     [0:NUM_MASTERS*NUM_ENTRIES-1];
reg [7:0]        burst_len_inv_q [0:NUM_MASTERS*NUM_ENTRIES-1];
reg              entry_valid_q   [0:NUM_MASTERS*NUM_ENTRIES-1];
reg              entry_valid_inv_q[0:NUM_MASTERS*NUM_ENTRIES-1];

integer flat_m;
integer flat_idx;
integer shadow_m;
integer shadow_idx;
integer read_m;
integer read_e;
integer read_idx;
integer seq_m;
integer seq_e;
integer seq_idx;

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

reg shadow_error_comb;
reg [DATA_W-1:0] read_data_comb;
reg [1:0] read_resp_comb;
reg [1:0] write_resp_comb;
reg [DATA_W-1:0] merged_write;

assign cfg_valid        = cfg_locked_r;
assign cfg_locked       = cfg_locked_r;
assign cfg_illegal      = cfg_illegal_r;
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
    control_read_value[0] = enable;
    control_read_value[3] = cfg_locked_r;
    control_read_value[8] = cfg_illegal_r;
end
endfunction

function [DATA_W-1:0] burst_read_value;
    input integer entry_index;
begin
    burst_read_value = {DATA_W{1'b0}};
    burst_read_value[1:0]  = burst_type_q[entry_index];
    burst_read_value[15:8] = burst_len_q[entry_index];
    burst_read_value[16]   = entry_valid_q[entry_index];
end
endfunction

always @* begin
    for (flat_m = 0; flat_m < NUM_MASTERS; flat_m = flat_m + 1) begin
        base_addr_flat[flat_m*ADDR_W +: ADDR_W] = base_addr_q[flat_m];
    end

    for (flat_idx = 0; flat_idx < NUM_MASTERS*NUM_ENTRIES; flat_idx = flat_idx + 1) begin
        offset_flat[flat_idx*ADDR_W +: ADDR_W] = offset_q[flat_idx];
        mask_flat[flat_idx*DATA_W +: DATA_W] = mask_q[flat_idx];
        burst_type_flat[flat_idx*2 +: 2] = burst_type_q[flat_idx];
        burst_len_flat[flat_idx*8 +: 8] = burst_len_q[flat_idx];
        entry_valid_flat[flat_idx] = entry_valid_q[flat_idx];
    end
end

always @* begin
    shadow_error_comb = (enable_inv != ~enable) |
                        (cfg_locked_inv != ~cfg_locked_r) |
                        (cfg_illegal_inv != ~cfg_illegal_r) |
                        (read_interval_inv != ~read_interval);

    for (shadow_m = 0; shadow_m < NUM_MASTERS; shadow_m = shadow_m + 1) begin
        if (base_addr_inv_q[shadow_m] != ~base_addr_q[shadow_m])
            shadow_error_comb = 1'b1;
    end

    for (shadow_idx = 0; shadow_idx < NUM_MASTERS*NUM_ENTRIES; shadow_idx = shadow_idx + 1) begin
        if ((offset_inv_q[shadow_idx] != ~offset_q[shadow_idx]) ||
            (mask_inv_q[shadow_idx] != ~mask_q[shadow_idx]) ||
            (burst_type_inv_q[shadow_idx] != ~burst_type_q[shadow_idx]) ||
            (burst_len_inv_q[shadow_idx] != ~burst_len_q[shadow_idx]) ||
            (entry_valid_inv_q[shadow_idx] != ~entry_valid_q[shadow_idx]))
            shadow_error_comb = 1'b1;
    end
end

always @* begin
    read_data_comb = {DATA_W{1'b0}};
    read_resp_comb = RESP_OKAY;

    if (s_axi_arlen != 8'd0 || s_axi_arsize != 3'd3 || s_axi_arburst != 2'b01) begin
        read_resp_comb = RESP_SLVERR;
    end else if (s_axi_araddr[ADDR_W-1:0] == ADDR_CONTROL) begin
        read_data_comb = control_read_value(1'b0);
    end else if (s_axi_araddr[ADDR_W-1:0] == ADDR_READ_INTERVAL) begin
        read_data_comb = read_interval;
    end else if (s_axi_araddr[ADDR_W-1:0] == ADDR_STATUS) begin
        read_data_comb = {DATA_W{1'b0}};
        read_data_comb[0] = scan_busy;
        read_data_comb[1] = scan_done_sticky | scan_done_pulse;
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
    end else if ((s_axi_araddr[ADDR_W-1:0] >= ADDR_BASE_REGION) &&
                 (s_axi_araddr[ADDR_W-1:0] < (ADDR_BASE_REGION + NUM_MASTERS*BASE_STRIDE))) begin
        read_m = (s_axi_araddr[ADDR_W-1:0] - ADDR_BASE_REGION) / BASE_STRIDE;
        read_data_comb = {{(DATA_W-ADDR_W){1'b0}}, base_addr_q[read_m]};
    end else if ((s_axi_araddr[ADDR_W-1:0] >= ADDR_ENTRY_REGION) &&
                 (s_axi_araddr[ADDR_W-1:0] < (ADDR_ENTRY_REGION + NUM_MASTERS*ENTRY_MASTER_STRIDE))) begin
        read_m = (s_axi_araddr[ADDR_W-1:0] - ADDR_ENTRY_REGION) / ENTRY_MASTER_STRIDE;
        read_e = ((s_axi_araddr[ADDR_W-1:0] - ADDR_ENTRY_REGION) % ENTRY_MASTER_STRIDE) / ENTRY_STRIDE;
        read_idx = (read_m * NUM_ENTRIES) + read_e;

        if ((read_m < NUM_MASTERS) && (read_e < NUM_ENTRIES)) begin
            case (((s_axi_araddr[ADDR_W-1:0] - ADDR_ENTRY_REGION) % ENTRY_MASTER_STRIDE) % ENTRY_STRIDE)
                ENTRY_OFFSET_OFF: read_data_comb = {{(DATA_W-ADDR_W){1'b0}}, offset_q[read_idx]};
                ENTRY_MASK_OFF:   read_data_comb = mask_q[read_idx];
                ENTRY_BURST_OFF:  read_data_comb = burst_read_value(read_idx);
                default: begin
                    read_data_comb = {DATA_W{1'b0}};
                    read_resp_comb = RESP_SLVERR;
                end
            endcase
        end else begin
            read_resp_comb = RESP_SLVERR;
        end
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
        enable_inv        <= 1'b1;
        scan_once         <= 1'b0;
        clear_core_status <= 1'b0;
        read_interval     <= 64'd0;
        read_interval_inv <= {64{1'b1}};
        cfg_locked_r      <= 1'b0;
        cfg_locked_inv    <= 1'b1;
        cfg_illegal_r     <= 1'b0;
        cfg_illegal_inv   <= 1'b1;
        scan_done_sticky  <= 1'b0;

        for (seq_m = 0; seq_m < NUM_MASTERS; seq_m = seq_m + 1) begin
            base_addr_q[seq_m]     <= {ADDR_W{1'b0}};
            base_addr_inv_q[seq_m] <= {ADDR_W{1'b1}};
        end

        for (seq_idx = 0; seq_idx < NUM_MASTERS*NUM_ENTRIES; seq_idx = seq_idx + 1) begin
            offset_q[seq_idx]         <= {ADDR_W{1'b0}};
            offset_inv_q[seq_idx]     <= {ADDR_W{1'b1}};
            mask_q[seq_idx]           <= {DATA_W{1'b0}};
            mask_inv_q[seq_idx]       <= {DATA_W{1'b1}};
            burst_type_q[seq_idx]     <= 2'b01;
            burst_type_inv_q[seq_idx] <= ~2'b01;
            burst_len_q[seq_idx]      <= 8'd0;
            burst_len_inv_q[seq_idx]  <= {8{1'b1}};
            entry_valid_q[seq_idx]    <= 1'b0;
            entry_valid_inv_q[seq_idx]<= 1'b1;
        end
    end else begin
        scan_once         <= 1'b0;
        clear_core_status <= 1'b0;

        if (scan_done_pulse)
            scan_done_sticky <= 1'b1;

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
                write_resp_comb = RESP_SLVERR;
                cfg_illegal_r   <= 1'b1;
                cfg_illegal_inv <= 1'b0;
            end else if (write_addr_comb == ADDR_CONTROL) begin
                merged_write = apply_wstrb(control_read_value(1'b0), write_data_comb, write_strb_comb);
                if (merged_write[0] != enable) begin
                    enable     <= merged_write[0];
                    enable_inv <= ~merged_write[0];
                end
                if (merged_write[1])
                    scan_once <= 1'b1;
                if (merged_write[2]) begin
                    clear_core_status <= 1'b1;
                    cfg_illegal_r     <= 1'b0;
                    cfg_illegal_inv   <= 1'b1;
                    scan_done_sticky  <= 1'b0;
                end
                if (merged_write[3]) begin
                    cfg_locked_r   <= 1'b1;
                    cfg_locked_inv <= 1'b0;
                end
            end else if (cfg_locked_r) begin
                write_resp_comb = RESP_SLVERR;
                cfg_illegal_r   <= 1'b1;
                cfg_illegal_inv <= 1'b0;
            end else if (write_addr_comb == ADDR_READ_INTERVAL) begin
                merged_write      = apply_wstrb(read_interval, write_data_comb, write_strb_comb);
                read_interval     <= merged_write;
                read_interval_inv <= ~merged_write;
            end else if ((write_addr_comb >= ADDR_BASE_REGION) &&
                         (write_addr_comb < (ADDR_BASE_REGION + NUM_MASTERS*BASE_STRIDE))) begin
                seq_m = (write_addr_comb - ADDR_BASE_REGION) / BASE_STRIDE;
                merged_write           = apply_wstrb({{(DATA_W-ADDR_W){1'b0}}, base_addr_q[seq_m]}, write_data_comb, write_strb_comb);
                base_addr_q[seq_m]     <= merged_write[ADDR_W-1:0];
                base_addr_inv_q[seq_m] <= ~merged_write[ADDR_W-1:0];
            end else if ((write_addr_comb >= ADDR_ENTRY_REGION) &&
                         (write_addr_comb < (ADDR_ENTRY_REGION + NUM_MASTERS*ENTRY_MASTER_STRIDE))) begin
                seq_m = (write_addr_comb - ADDR_ENTRY_REGION) / ENTRY_MASTER_STRIDE;
                seq_e = ((write_addr_comb - ADDR_ENTRY_REGION) % ENTRY_MASTER_STRIDE) / ENTRY_STRIDE;
                seq_idx = (seq_m * NUM_ENTRIES) + seq_e;

                if ((seq_m < NUM_MASTERS) && (seq_e < NUM_ENTRIES)) begin
                    case (((write_addr_comb - ADDR_ENTRY_REGION) % ENTRY_MASTER_STRIDE) % ENTRY_STRIDE)
                        ENTRY_OFFSET_OFF: begin
                            merged_write           = apply_wstrb({{(DATA_W-ADDR_W){1'b0}}, offset_q[seq_idx]}, write_data_comb, write_strb_comb);
                            offset_q[seq_idx]      <= merged_write[ADDR_W-1:0];
                            offset_inv_q[seq_idx]  <= ~merged_write[ADDR_W-1:0];
                        end
                        ENTRY_MASK_OFF: begin
                            merged_write           = apply_wstrb(mask_q[seq_idx], write_data_comb, write_strb_comb);
                            mask_q[seq_idx]        <= merged_write;
                            mask_inv_q[seq_idx]    <= ~merged_write;
                        end
                        ENTRY_BURST_OFF: begin
                            merged_write                = apply_wstrb(burst_read_value(seq_idx), write_data_comb, write_strb_comb);
                            burst_type_q[seq_idx]      <= merged_write[1:0];
                            burst_type_inv_q[seq_idx]  <= ~merged_write[1:0];
                            burst_len_q[seq_idx]       <= merged_write[15:8];
                            burst_len_inv_q[seq_idx]   <= ~merged_write[15:8];
                            entry_valid_q[seq_idx]     <= merged_write[16];
                            entry_valid_inv_q[seq_idx] <= ~merged_write[16];
                        end
                        default: begin
                            write_resp_comb = RESP_SLVERR;
                            cfg_illegal_r   <= 1'b1;
                            cfg_illegal_inv <= 1'b0;
                        end
                    endcase
                end else begin
                    write_resp_comb = RESP_SLVERR;
                    cfg_illegal_r   <= 1'b1;
                    cfg_illegal_inv <= 1'b0;
                end
            end else begin
                write_resp_comb = RESP_SLVERR;
                cfg_illegal_r   <= 1'b1;
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
