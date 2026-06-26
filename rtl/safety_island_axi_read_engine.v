`timescale 1ns/1ps

module safety_island_axi_read_engine #(
    parameter ADDR_WIDTH      = 32,
    parameter DATA_WIDTH      = 64,
    parameter ID_WIDTH        = 4,
    parameter TIMEOUT_CYCLES  = 1024,
    parameter MAX_OUTSTANDING = 4,
    parameter CRC_WIDTH = 16
) (
    input  wire                   clk,
    input  wire                   rst,

    input  wire                   cmd_valid,
    output wire                   cmd_ready,
    input  wire [ID_WIDTH-1:0]    cmd_id,
    input  wire [ADDR_WIDTH-1:0]  cmd_addr,
    input  wire [7:0]             cmd_len,
    input  wire [2:0]             cmd_size,
    input  wire [1:0]             cmd_burst,

    output reg                    done,
    output reg                    error,
    output reg                    timeout,
    output reg  [DATA_WIDTH-1:0]  read_data,

    output reg  [ID_WIDTH-1:0]    m_axi_arid,
    output reg  [ADDR_WIDTH-1:0]  m_axi_araddr,
    output reg  [7:0]             m_axi_arlen,
    output reg  [2:0]             m_axi_arsize,
    output reg  [1:0]             m_axi_arburst,
    output wire                   m_axi_arlock,
    output wire [3:0]             m_axi_arcache,
    output wire [2:0]             m_axi_arprot,
    output wire [3:0]             m_axi_arqos,
    output reg                    m_axi_arvalid,
    input  wire                   m_axi_arready,

    input  wire [ID_WIDTH-1:0]    m_axi_rid,
    input  wire [DATA_WIDTH-1:0]  m_axi_rdata,
    input  wire [1:0]             m_axi_rresp,
    input  wire                   m_axi_rlast,
    input  wire                   m_axi_rvalid,
    input  wire [CRC_WIDTH-1:0]   m_axi_rcheck,
    output wire                   m_axi_rready,

    output wire                   internal_safety_fault
);

localparam [1:0] RESP_OKAY = 2'b00;
localparam [31:0] ID_CAPACITY = (32'd1 << ID_WIDTH);

assign m_axi_arlock  = 1'b0;
assign m_axi_arcache = 4'b0011;
assign m_axi_arprot  = 3'b000;
assign m_axi_arqos   = 4'b0000;

reg [ID_WIDTH-1:0]    slot_id_q       [0:MAX_OUTSTANDING-1];
reg [7:0]             slot_len_q      [0:MAX_OUTSTANDING-1];
reg [7:0]             slot_beat_q     [0:MAX_OUTSTANDING-1];
reg [31:0]            slot_age_q      [0:MAX_OUTSTANDING-1];
reg [DATA_WIDTH-1:0]  slot_accum_q    [0:MAX_OUTSTANDING-1];
reg                   slot_error_q    [0:MAX_OUTSTANDING-1];
reg                   slot_timeout_q  [0:MAX_OUTSTANDING-1];
reg                   slot_valid_q    [0:MAX_OUTSTANDING-1];
reg                   slot_done_q     [0:MAX_OUTSTANDING-1];
reg [CRC_WIDTH-1:0]  slot_ar_sig_q   [0:MAX_OUTSTANDING-1];

reg [ID_WIDTH-1:0]    slot_id_inv_q       [0:MAX_OUTSTANDING-1];
reg [7:0]             slot_len_inv_q      [0:MAX_OUTSTANDING-1];
reg [7:0]             slot_beat_inv_q     [0:MAX_OUTSTANDING-1];
reg [31:0]            slot_age_inv_q      [0:MAX_OUTSTANDING-1];
reg [DATA_WIDTH-1:0]  slot_accum_inv_q    [0:MAX_OUTSTANDING-1];
reg                   slot_error_inv_q    [0:MAX_OUTSTANDING-1];
reg                   slot_timeout_inv_q  [0:MAX_OUTSTANDING-1];
reg                   slot_valid_inv_q    [0:MAX_OUTSTANDING-1];
reg                   slot_done_inv_q     [0:MAX_OUTSTANDING-1];
reg [CRC_WIDTH-1:0]   slot_ar_sig_inv_q   [0:MAX_OUTSTANDING-1];

reg [31:0] wr_ptr;
reg [31:0] rd_ptr;
reg [31:0] outstanding_count;
reg [31:0] ar_timeout_count;

reg [31:0] wr_ptr_inv;
reg [31:0] rd_ptr_inv;
reg [31:0] outstanding_count_inv;
reg [31:0] ar_timeout_count_inv;
reg        done_inv;
reg        error_inv;
reg        timeout_inv;
reg [DATA_WIDTH-1:0] read_data_inv;

wire ar_fire;
wire r_fire;
wire request_fire;
wire id_capacity_ok;

reg rid_match_found;
reg [31:0] rid_match_idx;
reg [DATA_WIDTH-1:0] r_accum_next;
reg r_error_next;
reg r_last_expected;

wire [CRC_WIDTH-1:0] ar_signature;
wire [CRC_WIDTH-1:0] ar_signature_dup;
wire [ID_WIDTH+ADDR_WIDTH+8+3+2-1:0] ar_payload;
assign ar_payload = {m_axi_arid, m_axi_araddr, m_axi_arlen, m_axi_arsize, m_axi_arburst};
assign ar_signature = crc_n(ar_payload, ID_WIDTH + ADDR_WIDTH + 8 + 3 + 2);
assign ar_signature_dup = crc_n_dup(ar_payload, ID_WIDTH + ADDR_WIDTH + 8 + 3 + 2);

reg [CRC_WIDTH-1:0] r_crc_expected;
reg [CRC_WIDTH-1:0] r_crc_expected_dup;
reg [31:0] scan_i;
reg [31:0] fault_i;
reg        slot_shadow_error_comb;
wire       ptr_shadow_error_comb;
wire       output_shadow_error_comb;
wire       crc_calc_mismatch_comb;

assign ar_fire = m_axi_arvalid && m_axi_arready;
assign r_fire = m_axi_rvalid && m_axi_rready;
assign request_fire = cmd_valid && cmd_ready;
assign id_capacity_ok = (MAX_OUTSTANDING <= ID_CAPACITY);
assign cmd_ready = id_capacity_ok &&
                   (outstanding_count < MAX_OUTSTANDING) &&
                   !m_axi_arvalid;
assign m_axi_rready = (outstanding_count != 32'd0);
assign ptr_shadow_error_comb =
    (wr_ptr_inv != ~wr_ptr) ||
    (rd_ptr_inv != ~rd_ptr) ||
    (outstanding_count_inv != ~outstanding_count) ||
    (ar_timeout_count_inv != ~ar_timeout_count);
assign output_shadow_error_comb =
    (done_inv != ~done) ||
    (error_inv != ~error) ||
    (timeout_inv != ~timeout) ||
    (read_data_inv != ~read_data);
assign crc_calc_mismatch_comb =
    (ar_signature_dup != ar_signature) ||
    (r_crc_expected_dup != r_crc_expected);
assign internal_safety_fault =
    slot_shadow_error_comb ||
    ptr_shadow_error_comb ||
    output_shadow_error_comb ||
    crc_calc_mismatch_comb ||
    (wr_ptr >= MAX_OUTSTANDING) ||
    (rd_ptr >= MAX_OUTSTANDING) ||
    (outstanding_count > MAX_OUTSTANDING);

function [31:0] inc_ptr;
    input [31:0] ptr;
begin
    if (ptr >= (MAX_OUTSTANDING - 1))
        inc_ptr = 32'd0;
    else
        inc_ptr = ptr + 32'd1;
end
endfunction

function [ID_WIDTH-1:0] slot_id;
    input [31:0] ptr;
begin
    slot_id = ptr[ID_WIDTH-1:0] ^ cmd_id;
end
endfunction

// Parameterized CRC: CRC_WIDTH=8 uses poly 0x07 init 0x00, CRC_WIDTH=16 uses poly 0x1021 init 0xFFFF
function [CRC_WIDTH-1:0] crc_n;
    input [ID_WIDTH+ADDR_WIDTH+8+3+2+DATA_WIDTH+2+1-1:0] payload;
    input integer payload_bits;
    reg [CRC_WIDTH-1:0] crc;
    reg feedback;
    integer bit_i;
begin
    if (CRC_WIDTH == 8) begin
        crc = 8'h00;
        for (bit_i = payload_bits - 1; bit_i >= 0; bit_i = bit_i - 1) begin
            feedback = crc[7] ^ payload[bit_i];
            crc = {crc[6:0], 1'b0};
            if (feedback)
                crc = crc ^ 8'h07;
        end
        crc_n = crc;
    end else begin
        crc = 16'hFFFF;
        for (bit_i = payload_bits - 1; bit_i >= 0; bit_i = bit_i - 1) begin
            feedback = crc[15] ^ payload[bit_i];
            crc = {crc[14:0], 1'b0};
            if (feedback)
                crc = crc ^ 16'h1021;
        end
        crc_n = crc;
    end
end
endfunction

function [CRC_WIDTH-1:0] crc_n_dup;
    input [ID_WIDTH+ADDR_WIDTH+8+3+2+DATA_WIDTH+2+1-1:0] payload;
    input integer payload_bits;
    reg [CRC_WIDTH-1:0] crc;
    reg feedback;
    integer bit_i;
begin
    if (CRC_WIDTH == 8) begin
        crc = 8'h00;
        for (bit_i = payload_bits - 1; bit_i >= 0; bit_i = bit_i - 1) begin
            feedback = crc[7] ^ payload[bit_i];
            crc = {crc[6:0], 1'b0};
            if (feedback)
                crc = crc ^ 8'h07;
        end
        crc_n_dup = crc;
    end else begin
        crc = 16'hFFFF;
        for (bit_i = payload_bits - 1; bit_i >= 0; bit_i = bit_i - 1) begin
            feedback = crc[15] ^ payload[bit_i];
            crc = {crc[14:0], 1'b0};
            if (feedback)
                crc = crc ^ 16'h1021;
        end
        crc_n_dup = crc;
    end
end
endfunction

integer i;

always @* begin
    slot_shadow_error_comb = 1'b0;
    for (fault_i = 0; fault_i < MAX_OUTSTANDING; fault_i = fault_i + 1) begin
        if ((slot_id_inv_q[fault_i] != ~slot_id_q[fault_i]) ||
            (slot_len_inv_q[fault_i] != ~slot_len_q[fault_i]) ||
            (slot_beat_inv_q[fault_i] != ~slot_beat_q[fault_i]) ||
            (slot_age_inv_q[fault_i] != ~slot_age_q[fault_i]) ||
            (slot_accum_inv_q[fault_i] != ~slot_accum_q[fault_i]) ||
            (slot_error_inv_q[fault_i] != ~slot_error_q[fault_i]) ||
            (slot_timeout_inv_q[fault_i] != ~slot_timeout_q[fault_i]) ||
            (slot_valid_inv_q[fault_i] != ~slot_valid_q[fault_i]) ||
            (slot_done_inv_q[fault_i] != ~slot_done_q[fault_i]) ||
            (slot_ar_sig_inv_q[fault_i] != ~slot_ar_sig_q[fault_i]))
            slot_shadow_error_comb = 1'b1;
    end

    rid_match_found = 1'b0;
    rid_match_idx = 32'd0;
    for (scan_i = 0; scan_i < MAX_OUTSTANDING; scan_i = scan_i + 1) begin
        if (!rid_match_found &&
            slot_valid_q[scan_i] &&
            !slot_done_q[scan_i] &&
            (slot_id_q[scan_i] == m_axi_rid)) begin
            rid_match_found = 1'b1;
            rid_match_idx = scan_i;
        end
    end

    r_accum_next = {DATA_WIDTH{1'b0}};
    r_error_next = 1'b1;
    r_last_expected = 1'b0;
    if (rid_match_found) begin
        r_crc_expected = crc_n(
            {slot_ar_sig_q[rid_match_idx], m_axi_rid, m_axi_rdata, m_axi_rresp, m_axi_rlast},
            CRC_WIDTH + ID_WIDTH + DATA_WIDTH + 2 + 1
        );
        r_crc_expected_dup = crc_n_dup(
            {slot_ar_sig_q[rid_match_idx], m_axi_rid, m_axi_rdata, m_axi_rresp, m_axi_rlast},
            CRC_WIDTH + ID_WIDTH + DATA_WIDTH + 2 + 1
        );
    end else begin
        r_crc_expected = {CRC_WIDTH{1'b0}};
        r_crc_expected_dup = {CRC_WIDTH{1'b0}};
    end
    if (rid_match_found) begin
        r_accum_next = slot_accum_q[rid_match_idx] | m_axi_rdata;
        r_last_expected = (slot_beat_q[rid_match_idx] == slot_len_q[rid_match_idx]);
        r_error_next = slot_error_q[rid_match_idx] |
                       (m_axi_rresp != RESP_OKAY) |
                       (m_axi_rlast != r_last_expected) |
                       (m_axi_rcheck != r_crc_expected);
    end
end

always @(posedge clk) begin
    if (rst) begin
        done              <= 1'b0;
        error             <= 1'b0;
        timeout           <= 1'b0;
        read_data         <= {DATA_WIDTH{1'b0}};
        done_inv          <= 1'b1;
        error_inv         <= 1'b1;
        timeout_inv       <= 1'b1;
        read_data_inv     <= {DATA_WIDTH{1'b1}};
        m_axi_arid        <= {ID_WIDTH{1'b0}};
        m_axi_araddr      <= {ADDR_WIDTH{1'b0}};
        m_axi_arlen       <= 8'd0;
        m_axi_arsize      <= 3'd0;
        m_axi_arburst     <= 2'b01;
        m_axi_arvalid     <= 1'b0;
        wr_ptr            <= 32'd0;
        rd_ptr            <= 32'd0;
        outstanding_count <= 32'd0;
        ar_timeout_count  <= 32'd0;
        wr_ptr_inv            <= {32{1'b1}};
        rd_ptr_inv            <= {32{1'b1}};
        outstanding_count_inv <= {32{1'b1}};
        ar_timeout_count_inv  <= {32{1'b1}};

        for (i = 0; i < MAX_OUTSTANDING; i = i + 1) begin
            slot_id_q[i]      <= {ID_WIDTH{1'b0}};
            slot_len_q[i]     <= 8'd0;
            slot_beat_q[i]    <= 8'd0;
            slot_age_q[i]     <= 32'd0;
            slot_accum_q[i]   <= {DATA_WIDTH{1'b0}};
            slot_error_q[i]   <= 1'b0;
            slot_timeout_q[i] <= 1'b0;
            slot_valid_q[i]   <= 1'b0;
            slot_done_q[i]    <= 1'b0;
            slot_ar_sig_q[i]   <= {CRC_WIDTH{1'b0}};
            slot_id_inv_q[i]      <= {ID_WIDTH{1'b1}};
            slot_len_inv_q[i]     <= {8{1'b1}};
            slot_beat_inv_q[i]    <= {8{1'b1}};
            slot_age_inv_q[i]     <= {32{1'b1}};
            slot_accum_inv_q[i]   <= {DATA_WIDTH{1'b1}};
            slot_error_inv_q[i]   <= 1'b1;
            slot_timeout_inv_q[i] <= 1'b1;
            slot_valid_inv_q[i]   <= 1'b1;
            slot_done_inv_q[i]    <= 1'b1;
            slot_ar_sig_inv_q[i]  <= {CRC_WIDTH{1'b1}};
        end
    end else begin
        done    <= 1'b0;
        error   <= 1'b0;
        timeout <= 1'b0;
        done_inv    <= 1'b1;
        error_inv   <= 1'b1;
        timeout_inv <= 1'b1;

        if (request_fire) begin
            m_axi_arid    <= slot_id(wr_ptr);
            m_axi_araddr  <= cmd_addr;
            m_axi_arlen   <= cmd_len;
            m_axi_arsize  <= cmd_size;
            m_axi_arburst <= cmd_burst;
            m_axi_arvalid <= 1'b1;
            ar_timeout_count <= 32'd0;
            ar_timeout_count_inv <= {32{1'b1}};
        end else if (ar_fire) begin
            m_axi_arvalid <= 1'b0;
            ar_timeout_count <= 32'd0;
            ar_timeout_count_inv <= {32{1'b1}};
        end else if (m_axi_arvalid && !m_axi_arready) begin
            if (ar_timeout_count >= (TIMEOUT_CYCLES - 1)) begin
                done             <= 1'b1;
                error            <= 1'b1;
                timeout          <= 1'b1;
                read_data        <= {DATA_WIDTH{1'b0}};
                done_inv         <= 1'b0;
                error_inv        <= 1'b0;
                timeout_inv      <= 1'b0;
                read_data_inv    <= {DATA_WIDTH{1'b1}};
                m_axi_arvalid    <= 1'b0;
                ar_timeout_count <= 32'd0;
                ar_timeout_count_inv <= {32{1'b1}};
            end else begin
                ar_timeout_count <= ar_timeout_count + 32'd1;
                ar_timeout_count_inv <= ~(ar_timeout_count + 32'd1);
            end
        end

        if (ar_fire) begin
            slot_id_q[wr_ptr]      <= m_axi_arid;
            slot_len_q[wr_ptr]     <= m_axi_arlen;
            slot_beat_q[wr_ptr]    <= 8'd0;
            slot_age_q[wr_ptr]     <= 32'd0;
            slot_accum_q[wr_ptr]   <= {DATA_WIDTH{1'b0}};
            slot_error_q[wr_ptr]   <= 1'b0;
            slot_timeout_q[wr_ptr] <= 1'b0;
            slot_valid_q[wr_ptr]   <= 1'b1;
            slot_done_q[wr_ptr]    <= 1'b0;
            slot_ar_sig_q[wr_ptr]  <= ar_signature;
            slot_id_inv_q[wr_ptr]      <= ~m_axi_arid;
            slot_len_inv_q[wr_ptr]     <= ~m_axi_arlen;
            slot_beat_inv_q[wr_ptr]    <= ~8'd0;
            slot_age_inv_q[wr_ptr]     <= ~32'd0;
            slot_accum_inv_q[wr_ptr]   <= {DATA_WIDTH{1'b1}};
            slot_error_inv_q[wr_ptr]   <= ~1'b0;
            slot_timeout_inv_q[wr_ptr] <= ~1'b0;
            slot_valid_inv_q[wr_ptr]   <= ~1'b1;
            slot_done_inv_q[wr_ptr]    <= ~1'b0;
            slot_ar_sig_inv_q[wr_ptr]  <= ~ar_signature;
            wr_ptr                 <= inc_ptr(wr_ptr);
            outstanding_count      <= outstanding_count + 32'd1;
            wr_ptr_inv             <= ~inc_ptr(wr_ptr);
            outstanding_count_inv  <= ~(outstanding_count + 32'd1);
        end

        for (i = 0; i < MAX_OUTSTANDING; i = i + 1) begin
            if (slot_valid_q[i] && !slot_done_q[i]) begin
                if (slot_age_q[i] < TIMEOUT_CYCLES) begin
                    slot_age_q[i] <= slot_age_q[i] + 32'd1;
                    slot_age_inv_q[i] <= ~(slot_age_q[i] + 32'd1);
                end
            end
        end

        if (r_fire) begin
            if (rid_match_found) begin
                slot_accum_q[rid_match_idx] <= r_accum_next;
                slot_error_q[rid_match_idx] <= r_error_next;
                slot_age_q[rid_match_idx]   <= 32'd0;
                slot_accum_inv_q[rid_match_idx] <= ~r_accum_next;
                slot_error_inv_q[rid_match_idx] <= ~r_error_next;
                slot_age_inv_q[rid_match_idx]   <= ~32'd0;

                if (m_axi_rlast || r_last_expected) begin
                    slot_done_q[rid_match_idx] <= 1'b1;
                    slot_done_inv_q[rid_match_idx] <= ~1'b1;
                end else begin
                    slot_beat_q[rid_match_idx] <= slot_beat_q[rid_match_idx] + 8'd1;
                    slot_beat_inv_q[rid_match_idx] <= ~(slot_beat_q[rid_match_idx] + 8'd1);
                end
            end else if (slot_valid_q[rd_ptr] && !slot_done_q[rd_ptr]) begin
                slot_accum_q[rd_ptr] <= {DATA_WIDTH{1'b0}};
                slot_error_q[rd_ptr] <= 1'b1;
                slot_done_q[rd_ptr]  <= 1'b1;
                slot_age_q[rd_ptr]   <= 32'd0;
                slot_accum_inv_q[rd_ptr] <= {DATA_WIDTH{1'b1}};
                slot_error_inv_q[rd_ptr] <= ~1'b1;
                slot_done_inv_q[rd_ptr]  <= ~1'b1;
                slot_age_inv_q[rd_ptr]   <= ~32'd0;
            end
        end

        if (slot_valid_q[rd_ptr] &&
            !slot_done_q[rd_ptr] &&
            (slot_age_q[rd_ptr] >= (TIMEOUT_CYCLES - 1))) begin
            slot_accum_q[rd_ptr]   <= {DATA_WIDTH{1'b0}};
            slot_error_q[rd_ptr]   <= 1'b1;
            slot_timeout_q[rd_ptr] <= 1'b1;
            slot_done_q[rd_ptr]    <= 1'b1;
            slot_accum_inv_q[rd_ptr]   <= {DATA_WIDTH{1'b1}};
            slot_error_inv_q[rd_ptr]   <= ~1'b1;
            slot_timeout_inv_q[rd_ptr] <= ~1'b1;
            slot_done_inv_q[rd_ptr]    <= ~1'b1;
        end

        if (slot_valid_q[rd_ptr] && slot_done_q[rd_ptr]) begin
            done      <= 1'b1;
            error     <= slot_error_q[rd_ptr] | slot_timeout_q[rd_ptr];
            timeout   <= slot_timeout_q[rd_ptr];
            read_data <= slot_accum_q[rd_ptr];
            done_inv      <= ~1'b1;
            error_inv     <= ~(slot_error_q[rd_ptr] | slot_timeout_q[rd_ptr]);
            timeout_inv   <= ~slot_timeout_q[rd_ptr];
            read_data_inv <= ~slot_accum_q[rd_ptr];

            slot_valid_q[rd_ptr]   <= 1'b0;
            slot_done_q[rd_ptr]    <= 1'b0;
            slot_ar_sig_q[rd_ptr]   <= {CRC_WIDTH{1'b0}};
            slot_error_q[rd_ptr]   <= 1'b0;
            slot_timeout_q[rd_ptr] <= 1'b0;
            slot_accum_q[rd_ptr]   <= {DATA_WIDTH{1'b0}};
            slot_age_q[rd_ptr]     <= 32'd0;
            slot_beat_q[rd_ptr]    <= 8'd0;
            slot_valid_inv_q[rd_ptr]   <= ~1'b0;
            slot_done_inv_q[rd_ptr]    <= ~1'b0;
            slot_ar_sig_inv_q[rd_ptr]  <= {CRC_WIDTH{1'b1}};
            slot_error_inv_q[rd_ptr]   <= ~1'b0;
            slot_timeout_inv_q[rd_ptr] <= ~1'b0;
            slot_accum_inv_q[rd_ptr]   <= {DATA_WIDTH{1'b1}};
            slot_age_inv_q[rd_ptr]     <= ~32'd0;
            slot_beat_inv_q[rd_ptr]    <= ~8'd0;

            rd_ptr <= inc_ptr(rd_ptr);
            rd_ptr_inv <= ~inc_ptr(rd_ptr);
            if (outstanding_count != 32'd0) begin
                outstanding_count <= outstanding_count - 32'd1;
                outstanding_count_inv <= ~(outstanding_count - 32'd1);
            end
        end
    end
end

endmodule
