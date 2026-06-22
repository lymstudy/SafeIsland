`timescale 1ns/1ps

module safety_island_axi_read_engine #(
    parameter ADDR_WIDTH      = 32,
    parameter DATA_WIDTH      = 64,
    parameter ID_WIDTH        = 4,
    parameter TIMEOUT_CYCLES  = 1024,
    parameter MAX_OUTSTANDING = 4
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
    output wire                   m_axi_rready
);

localparam [1:0] RESP_OKAY = 2'b00;

assign m_axi_arlock  = 1'b0;
assign m_axi_arcache = 4'b0011;
assign m_axi_arprot  = 3'b000;
assign m_axi_arqos   = 4'b0000;

reg [ID_WIDTH-1:0] expected_id_q [0:MAX_OUTSTANDING-1];
reg [7:0]          expected_len_q[0:MAX_OUTSTANDING-1];
reg                valid_q       [0:MAX_OUTSTANDING-1];
reg [31:0]         wr_ptr;
reg [31:0]         rd_ptr;
reg [31:0]         outstanding_count;
reg [31:0]         timeout_count;
reg                timeout_pending;
reg                done_holdoff;
reg [DATA_WIDTH-1:0] accum_data;
reg                accum_error;
reg [7:0]          beat_count;

wire ar_fire;
wire r_fire;
wire request_fire;
wire current_valid;
wire [ID_WIDTH-1:0] current_id;
wire [7:0] current_len;

assign ar_fire = m_axi_arvalid && m_axi_arready;
assign r_fire = m_axi_rvalid && m_axi_rready;
assign request_fire = cmd_valid && cmd_ready;
assign current_valid = (outstanding_count != 32'd0) && valid_q[rd_ptr];
assign current_id = expected_id_q[rd_ptr];
assign current_len = expected_len_q[rd_ptr];
assign cmd_ready = (outstanding_count < MAX_OUTSTANDING) && !m_axi_arvalid && !timeout_pending;
assign m_axi_rready = (outstanding_count != 32'd0) && !timeout_pending && !done_holdoff;

function [31:0] inc_ptr;
    input [31:0] ptr;
begin
    if (ptr >= (MAX_OUTSTANDING - 1))
        inc_ptr = 32'd0;
    else
        inc_ptr = ptr + 32'd1;
end
endfunction

integer i;

always @(posedge clk) begin
    if (rst) begin
        done              <= 1'b0;
        error             <= 1'b0;
        timeout           <= 1'b0;
        read_data         <= {DATA_WIDTH{1'b0}};
        m_axi_arid        <= {ID_WIDTH{1'b0}};
        m_axi_araddr      <= {ADDR_WIDTH{1'b0}};
        m_axi_arlen       <= 8'd0;
        m_axi_arsize      <= 3'd0;
        m_axi_arburst     <= 2'b01;
        m_axi_arvalid     <= 1'b0;
        wr_ptr            <= 32'd0;
        rd_ptr            <= 32'd0;
        outstanding_count <= 32'd0;
        timeout_count     <= 32'd0;
        timeout_pending   <= 1'b0;
        done_holdoff      <= 1'b0;
        accum_data        <= {DATA_WIDTH{1'b0}};
        accum_error       <= 1'b0;
        beat_count        <= 8'd0;

        for (i = 0; i < MAX_OUTSTANDING; i = i + 1) begin
            expected_id_q[i]  <= {ID_WIDTH{1'b0}};
            expected_len_q[i] <= 8'd0;
            valid_q[i]        <= 1'b0;
        end
    end else begin
        done    <= 1'b0;
        error   <= 1'b0;
        timeout <= 1'b0;
        if (done_holdoff)
            done_holdoff <= 1'b0;

        if (request_fire) begin
            m_axi_arid    <= cmd_id;
            m_axi_araddr  <= cmd_addr;
            m_axi_arlen   <= cmd_len;
            m_axi_arsize  <= cmd_size;
            m_axi_arburst <= cmd_burst;
            m_axi_arvalid <= 1'b1;
        end else if (ar_fire) begin
            m_axi_arvalid <= 1'b0;
        end

        if (ar_fire) begin
            expected_id_q[wr_ptr]  <= m_axi_arid;
            expected_len_q[wr_ptr] <= m_axi_arlen;
            valid_q[wr_ptr]        <= 1'b1;
            wr_ptr                 <= inc_ptr(wr_ptr);
            outstanding_count      <= outstanding_count + 32'd1;
            timeout_count          <= 32'd0;
        end

        if ((m_axi_arvalid && !m_axi_arready) ||
            ((outstanding_count != 32'd0) && !m_axi_rvalid)) begin
            if (timeout_count >= (TIMEOUT_CYCLES - 1)) begin
                timeout         <= 1'b1;
                error           <= 1'b1;
                done            <= 1'b1;
                timeout_pending <= 1'b1;
                read_data       <= {DATA_WIDTH{1'b0}};
            end else begin
                timeout_count <= timeout_count + 32'd1;
            end
        end else if (ar_fire || r_fire || request_fire) begin
            timeout_count <= 32'd0;
        end

        if (timeout_pending) begin
            m_axi_arvalid     <= 1'b0;
            wr_ptr            <= 32'd0;
            rd_ptr            <= 32'd0;
            outstanding_count <= 32'd0;
            timeout_count     <= 32'd0;
            accum_data        <= {DATA_WIDTH{1'b0}};
            accum_error       <= 1'b0;
            beat_count        <= 8'd0;
            done_holdoff      <= 1'b0;
            for (i = 0; i < MAX_OUTSTANDING; i = i + 1)
                valid_q[i] <= 1'b0;
            timeout_pending <= 1'b0;
        end else if (r_fire && current_valid) begin
            accum_data <= accum_data | m_axi_rdata;
            accum_error <= accum_error |
                           (m_axi_rresp != RESP_OKAY) |
                           (m_axi_rid != current_id);

            if (m_axi_rlast || (beat_count == current_len)) begin
                done      <= 1'b1;
                done_holdoff <= 1'b1;
                error     <= accum_error |
                             (m_axi_rresp != RESP_OKAY) |
                             (m_axi_rid != current_id) |
                             (m_axi_rlast != (beat_count == current_len));
                read_data <= accum_data | m_axi_rdata;

                valid_q[rd_ptr] <= 1'b0;
                rd_ptr <= inc_ptr(rd_ptr);
                outstanding_count <= outstanding_count - 32'd1;
                accum_data <= {DATA_WIDTH{1'b0}};
                accum_error <= 1'b0;
                beat_count <= 8'd0;
            end else begin
                beat_count <= beat_count + 8'd1;
            end
        end
    end
end

endmodule
