`timescale 1ns/1ps

module axi_slave_mem_model #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter ID_WIDTH   = 4,
    parameter MEM_WORDS  = 256
) (
    input  wire                   aclk,
    input  wire                   aresetn,

    input  wire [ID_WIDTH-1:0]    s_axi_awid,
    input  wire [ADDR_WIDTH-1:0]  s_axi_awaddr,
    input  wire [7:0]             s_axi_awlen,
    input  wire [2:0]             s_axi_awsize,
    input  wire [1:0]             s_axi_awburst,
    input  wire                   s_axi_awvalid,
    output reg                    s_axi_awready,

    input  wire [DATA_WIDTH-1:0]  s_axi_wdata,
    input  wire [(DATA_WIDTH/8)-1:0] s_axi_wstrb,
    input  wire                   s_axi_wlast,
    input  wire                   s_axi_wvalid,
    output reg                    s_axi_wready,

    output reg  [ID_WIDTH-1:0]    s_axi_bid,
    output reg  [1:0]             s_axi_bresp,
    output reg                    s_axi_bvalid,
    input  wire                   s_axi_bready,

    input  wire [ID_WIDTH-1:0]    s_axi_arid,
    input  wire [ADDR_WIDTH-1:0]  s_axi_araddr,
    input  wire [7:0]             s_axi_arlen,
    input  wire [2:0]             s_axi_arsize,
    input  wire [1:0]             s_axi_arburst,
    input  wire                   s_axi_arvalid,
    output reg                    s_axi_arready,

    output reg  [ID_WIDTH-1:0]    s_axi_rid,
    output reg  [DATA_WIDTH-1:0]  s_axi_rdata,
    output reg  [1:0]             s_axi_rresp,
    output reg                    s_axi_rlast,
    output reg                    s_axi_rvalid,
    input  wire                   s_axi_rready,

    input  wire                   inject_bresp_error,
    input  wire                   inject_rresp_error,
    input  wire                   stall_all_channels
);

function integer clog2;
    input integer value;
    integer i;
    begin
        value = value - 1;
        for (i = 0; value > 0; i = i + 1)
            value = value >> 1;
        clog2 = i;
    end
endfunction

localparam STRB_WIDTH     = DATA_WIDTH / 8;
localparam ADDR_LSB       = clog2(STRB_WIDTH);
localparam MEM_ADDR_WIDTH = clog2(MEM_WORDS);

localparam ST_IDLE       = 2'd0;
localparam ST_WRITE_DATA = 2'd1;
localparam ST_WRITE_RESP = 2'd2;
localparam ST_READ_DATA  = 2'd3;

reg [1:0] state;

reg [DATA_WIDTH-1:0] mem [0:MEM_WORDS-1];

reg [ID_WIDTH-1:0]        wr_id;
reg [MEM_ADDR_WIDTH-1:0]  wr_base_index;
reg [7:0]                 wr_len;
reg [1:0]                 wr_burst;
reg [7:0]                 wr_count;

reg [ID_WIDTH-1:0]        rd_id;
reg [MEM_ADDR_WIDTH-1:0]  rd_base_index;
reg [7:0]                 rd_len;
reg [1:0]                 rd_burst;
reg [7:0]                 rd_count;

integer byte_idx;
integer init_idx;

function [MEM_ADDR_WIDTH-1:0] burst_index;
    input [MEM_ADDR_WIDTH-1:0] base_index;
    input [7:0] beat_count;
    input [1:0] burst_type;
    begin
        if (burst_type == 2'b00)
            burst_index = base_index;
        else
            burst_index = base_index + beat_count[MEM_ADDR_WIDTH-1:0];
    end
endfunction

initial begin
    for (init_idx = 0; init_idx < MEM_WORDS; init_idx = init_idx + 1)
        mem[init_idx] = {DATA_WIDTH{1'b0}};
end

always @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
        state         <= ST_IDLE;
        s_axi_awready <= 1'b0;
        s_axi_wready  <= 1'b0;
        s_axi_bvalid  <= 1'b0;
        s_axi_bresp   <= 2'b00;
        s_axi_bid     <= {ID_WIDTH{1'b0}};
        s_axi_arready <= 1'b0;
        s_axi_rvalid  <= 1'b0;
        s_axi_rresp   <= 2'b00;
        s_axi_rdata   <= {DATA_WIDTH{1'b0}};
        s_axi_rid     <= {ID_WIDTH{1'b0}};
        s_axi_rlast   <= 1'b0;
        wr_id         <= {ID_WIDTH{1'b0}};
        wr_base_index <= {MEM_ADDR_WIDTH{1'b0}};
        wr_len        <= 8'd0;
        wr_burst      <= 2'b01;
        wr_count      <= 8'd0;
        rd_id         <= {ID_WIDTH{1'b0}};
        rd_base_index <= {MEM_ADDR_WIDTH{1'b0}};
        rd_len        <= 8'd0;
        rd_burst      <= 2'b01;
        rd_count      <= 8'd0;
    end else if (stall_all_channels) begin
        s_axi_awready <= 1'b0;
        s_axi_wready  <= 1'b0;
        s_axi_arready <= 1'b0;
        if (state == ST_IDLE) begin
            s_axi_bvalid <= 1'b0;
            s_axi_rvalid <= 1'b0;
        end
    end else begin
        case (state)
            ST_IDLE: begin
                s_axi_awready <= 1'b1;
                s_axi_arready <= !s_axi_awvalid;
                s_axi_wready  <= 1'b0;
                s_axi_bvalid  <= 1'b0;
                s_axi_rvalid  <= 1'b0;
                s_axi_rlast   <= 1'b0;

                if (s_axi_awvalid && s_axi_awready) begin
                    wr_id         <= s_axi_awid;
                    wr_base_index <= s_axi_awaddr[ADDR_LSB +: MEM_ADDR_WIDTH];
                    wr_len        <= s_axi_awlen;
                    wr_burst      <= s_axi_awburst;
                    wr_count      <= 8'd0;
                    s_axi_awready <= 1'b0;
                    s_axi_arready <= 1'b0;
                    s_axi_wready  <= 1'b1;
                    state         <= ST_WRITE_DATA;
                end else if (s_axi_arvalid && s_axi_arready) begin
                    rd_id         <= s_axi_arid;
                    rd_base_index <= s_axi_araddr[ADDR_LSB +: MEM_ADDR_WIDTH];
                    rd_len        <= s_axi_arlen;
                    rd_burst      <= s_axi_arburst;
                    rd_count      <= 8'd0;
                    s_axi_awready <= 1'b0;
                    s_axi_arready <= 1'b0;
                    state         <= ST_READ_DATA;
                end
            end

            ST_WRITE_DATA: begin
                s_axi_awready <= 1'b0;
                s_axi_arready <= 1'b0;
                s_axi_wready  <= 1'b1;

                if (s_axi_wvalid && s_axi_wready) begin
                    for (byte_idx = 0; byte_idx < STRB_WIDTH; byte_idx = byte_idx + 1) begin
                        if (s_axi_wstrb[byte_idx]) begin
                            mem[burst_index(wr_base_index, wr_count, wr_burst)][8*byte_idx +: 8]
                                <= s_axi_wdata[8*byte_idx +: 8];
                        end
                    end

                    if (s_axi_wlast || (wr_count == wr_len)) begin
                        s_axi_wready <= 1'b0;
                        s_axi_bid    <= wr_id;
                        s_axi_bresp  <= inject_bresp_error ? 2'b10 : 2'b00;
                        s_axi_bvalid <= 1'b1;
                        state        <= ST_WRITE_RESP;
                    end else begin
                        wr_count <= wr_count + 8'd1;
                    end
                end
            end

            ST_WRITE_RESP: begin
                s_axi_awready <= 1'b0;
                s_axi_arready <= 1'b0;
                s_axi_wready  <= 1'b0;

                if (s_axi_bvalid && s_axi_bready) begin
                    s_axi_bvalid <= 1'b0;
                    state        <= ST_IDLE;
                end
            end

            ST_READ_DATA: begin
                s_axi_awready <= 1'b0;
                s_axi_arready <= 1'b0;
                s_axi_wready  <= 1'b0;

                if (s_axi_rvalid && s_axi_rready) begin
                    if (s_axi_rlast) begin
                        s_axi_rvalid <= 1'b0;
                        s_axi_rlast  <= 1'b0;
                        state        <= ST_IDLE;
                    end else begin
                        s_axi_rvalid <= 1'b0;
                        rd_count     <= rd_count + 8'd1;
                    end
                end else if (!s_axi_rvalid) begin
                    s_axi_rid    <= rd_id;
                    s_axi_rdata  <= mem[burst_index(rd_base_index, rd_count, rd_burst)];
                    s_axi_rresp  <= inject_rresp_error ? 2'b10 : 2'b00;
                    s_axi_rlast  <= (rd_count == rd_len);
                    s_axi_rvalid <= 1'b1;
                end
            end

            default: begin
                state <= ST_IDLE;
            end
        endcase
    end
end

endmodule
