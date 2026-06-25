`timescale 1ns/1ps

module axi_master #(
    parameter ADDR_WIDTH     = 32,
    parameter DATA_WIDTH     = 64,
    parameter ID_WIDTH       = 4,
    parameter TIMEOUT_CYCLES = 1024
) (
    input  wire                   aclk,
    input  wire                   aresetn,

    input  wire                   cmd_valid,
    output wire                   cmd_ready,
    input  wire                   cmd_write,
    input  wire [ID_WIDTH-1:0]    cmd_id,
    input  wire [ADDR_WIDTH-1:0]  cmd_addr,
    input  wire [7:0]             cmd_len,
    input  wire [2:0]             cmd_size,
    input  wire [1:0]             cmd_burst,
    output reg                    busy,
    output reg                    done,
    output reg                    error,
    output reg                    timeout,

    input  wire                   wr_valid,
    output wire                   wr_ready,
    input  wire [DATA_WIDTH-1:0]  wr_data,
    input  wire [(DATA_WIDTH/8)-1:0] wr_strb,

    output reg                    rd_valid,
    input  wire                   rd_ready,
    output reg  [DATA_WIDTH-1:0]  rd_data,
    output reg  [1:0]             rd_resp,
    output reg                    rd_last,

    output reg  [ID_WIDTH-1:0]    m_axi_awid,
    output reg  [ADDR_WIDTH-1:0]  m_axi_awaddr,
    output reg  [7:0]             m_axi_awlen,
    output reg  [2:0]             m_axi_awsize,
    output reg  [1:0]             m_axi_awburst,
    output wire                   m_axi_awlock,
    output wire [3:0]             m_axi_awcache,
    output wire [2:0]             m_axi_awprot,
    output wire [3:0]             m_axi_awqos,
    output reg                    m_axi_awvalid,
    input  wire                   m_axi_awready,

    output wire [DATA_WIDTH-1:0]  m_axi_wdata,
    output wire [(DATA_WIDTH/8)-1:0] m_axi_wstrb,
    output wire                   m_axi_wlast,
    output wire                   m_axi_wvalid,
    input  wire                   m_axi_wready,

    input  wire [ID_WIDTH-1:0]    m_axi_bid,
    input  wire [1:0]             m_axi_bresp,
    input  wire                   m_axi_bvalid,
    output reg                    m_axi_bready,

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

localparam ST_IDLE       = 3'd0;
localparam ST_WRITE_ADDR = 3'd1;
localparam ST_WRITE_DATA = 3'd2;
localparam ST_WRITE_RESP = 3'd3;
localparam ST_READ_ADDR  = 3'd4;
localparam ST_READ_DATA  = 3'd5;

reg [2:0]            state;
reg [ID_WIDTH-1:0]   active_id;
reg [7:0]            active_len;
reg [7:0]            wr_count;
reg [31:0]           timeout_count;
reg                  sticky_error;
reg                  read_last_buffered;

wire aw_handshake;
wire w_handshake;
wire b_handshake;
wire ar_handshake;
wire r_handshake;
wire any_axi_handshake;
wire read_buffer_accept;

assign cmd_ready      = (state == ST_IDLE);
assign wr_ready       = (state == ST_WRITE_DATA) && m_axi_wready;
assign m_axi_wvalid   = (state == ST_WRITE_DATA) && wr_valid;
assign m_axi_wdata    = wr_data;
assign m_axi_wstrb    = wr_strb;
assign m_axi_wlast    = (state == ST_WRITE_DATA) && (wr_count == active_len);
assign m_axi_rready   = (state == ST_READ_DATA) && (!rd_valid || rd_ready) && !read_last_buffered;

assign m_axi_awlock   = 1'b0;
assign m_axi_awcache  = 4'b0011;
assign m_axi_awprot   = 3'b000;
assign m_axi_awqos    = 4'b0000;
assign m_axi_arlock   = 1'b0;
assign m_axi_arcache  = 4'b0011;
assign m_axi_arprot   = 3'b000;
assign m_axi_arqos    = 4'b0000;

assign aw_handshake       = m_axi_awvalid && m_axi_awready;
assign w_handshake        = m_axi_wvalid && m_axi_wready;
assign b_handshake        = m_axi_bvalid && m_axi_bready;
assign ar_handshake       = m_axi_arvalid && m_axi_arready;
assign r_handshake        = m_axi_rvalid && m_axi_rready;
assign any_axi_handshake  = aw_handshake || w_handshake || b_handshake || ar_handshake || r_handshake;
assign read_buffer_accept = rd_valid && rd_ready;

always @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
        state              <= ST_IDLE;
        active_id          <= {ID_WIDTH{1'b0}};
        active_len         <= 8'd0;
        wr_count           <= 8'd0;
        timeout_count      <= 32'd0;
        sticky_error       <= 1'b0;
        read_last_buffered <= 1'b0;
        busy               <= 1'b0;
        done               <= 1'b0;
        error              <= 1'b0;
        timeout            <= 1'b0;
        rd_valid           <= 1'b0;
        rd_data            <= {DATA_WIDTH{1'b0}};
        rd_resp            <= 2'b00;
        rd_last            <= 1'b0;
        m_axi_awid         <= {ID_WIDTH{1'b0}};
        m_axi_awaddr       <= {ADDR_WIDTH{1'b0}};
        m_axi_awlen        <= 8'd0;
        m_axi_awsize       <= 3'd0;
        m_axi_awburst      <= 2'b01;
        m_axi_awvalid      <= 1'b0;
        m_axi_bready       <= 1'b0;
        m_axi_arid         <= {ID_WIDTH{1'b0}};
        m_axi_araddr       <= {ADDR_WIDTH{1'b0}};
        m_axi_arlen        <= 8'd0;
        m_axi_arsize       <= 3'd0;
        m_axi_arburst      <= 2'b01;
        m_axi_arvalid      <= 1'b0;
    end else begin
        done    <= 1'b0;
        error   <= 1'b0;
        timeout <= 1'b0;

        if (busy && !any_axi_handshake && (timeout_count >= (TIMEOUT_CYCLES - 1))) begin
            state              <= ST_IDLE;
            busy               <= 1'b0;
            done               <= 1'b1;
            error              <= 1'b1;
            timeout            <= 1'b1;
            timeout_count      <= 32'd0;
            sticky_error       <= 1'b0;
            read_last_buffered <= 1'b0;
            rd_valid           <= 1'b0;
            rd_last            <= 1'b0;
            m_axi_awvalid      <= 1'b0;
            m_axi_arvalid      <= 1'b0;
            m_axi_bready       <= 1'b0;
        end else begin
            if (busy && !any_axi_handshake)
                timeout_count <= timeout_count + 32'd1;
            else
                timeout_count <= 32'd0;

            case (state)
                ST_IDLE: begin
                    busy               <= 1'b0;
                    sticky_error       <= 1'b0;
                    read_last_buffered <= 1'b0;
                    rd_valid           <= 1'b0;
                    rd_last            <= 1'b0;
                    m_axi_awvalid      <= 1'b0;
                    m_axi_arvalid      <= 1'b0;
                    m_axi_bready       <= 1'b0;

                    if (cmd_valid && cmd_ready) begin
                        active_id     <= cmd_id;
                        active_len    <= cmd_len;
                        wr_count      <= 8'd0;
                        busy          <= 1'b1;
                        sticky_error  <= 1'b0;
                        timeout_count <= 32'd0;

                        if (cmd_write) begin
                            m_axi_awid    <= cmd_id;
                            m_axi_awaddr  <= cmd_addr;
                            m_axi_awlen   <= cmd_len;
                            m_axi_awsize  <= cmd_size;
                            m_axi_awburst <= cmd_burst;
                            m_axi_awvalid <= 1'b1;
                            state         <= ST_WRITE_ADDR;
                        end else begin
                            m_axi_arid    <= cmd_id;
                            m_axi_araddr  <= cmd_addr;
                            m_axi_arlen   <= cmd_len;
                            m_axi_arsize  <= cmd_size;
                            m_axi_arburst <= cmd_burst;
                            m_axi_arvalid <= 1'b1;
                            state         <= ST_READ_ADDR;
                        end
                    end
                end

                ST_WRITE_ADDR: begin
                    busy <= 1'b1;
                    if (aw_handshake) begin
                        m_axi_awvalid <= 1'b0;
                        wr_count      <= 8'd0;
                        state         <= ST_WRITE_DATA;
                    end
                end

                ST_WRITE_DATA: begin
                    busy <= 1'b1;
                    if (w_handshake) begin
                        if (wr_count == active_len) begin
                            m_axi_bready <= 1'b1;
                            state        <= ST_WRITE_RESP;
                        end else begin
                            wr_count <= wr_count + 8'd1;
                        end
                    end
                end

                ST_WRITE_RESP: begin
                    busy <= 1'b1;
                    if (b_handshake) begin
                        m_axi_bready <= 1'b0;
                        busy         <= 1'b0;
                        done         <= 1'b1;
                        error        <= (m_axi_bresp != 2'b00) || (m_axi_bid != active_id);
                        state        <= ST_IDLE;
                    end
                end

                ST_READ_ADDR: begin
                    busy <= 1'b1;
                    if (ar_handshake) begin
                        m_axi_arvalid <= 1'b0;
                        state         <= ST_READ_DATA;
                    end
                end

                ST_READ_DATA: begin
                    busy <= 1'b1;

                    if (read_buffer_accept) begin
                        rd_valid <= 1'b0;
                        if (rd_last) begin
                            busy               <= 1'b0;
                            done               <= 1'b1;
                            error              <= sticky_error || (rd_resp != 2'b00);
                            read_last_buffered <= 1'b0;
                            state              <= ST_IDLE;
                        end
                    end

                    if (r_handshake) begin
                        rd_valid <= 1'b1;
                        rd_data  <= m_axi_rdata;
                        rd_resp  <= m_axi_rresp;
                        rd_last  <= m_axi_rlast;
                        if ((m_axi_rresp != 2'b00) || (m_axi_rid != active_id))
                            sticky_error <= 1'b1;
                        if (m_axi_rlast)
                            read_last_buffered <= 1'b1;
                    end
                end

                default: begin
                    state              <= ST_IDLE;
                    busy               <= 1'b0;
                    sticky_error       <= 1'b0;
                    read_last_buffered <= 1'b0;
                    rd_valid           <= 1'b0;
                    rd_last            <= 1'b0;
                    m_axi_awvalid      <= 1'b0;
                    m_axi_arvalid      <= 1'b0;
                    m_axi_bready       <= 1'b0;
                end
            endcase
        end
    end
end

endmodule
