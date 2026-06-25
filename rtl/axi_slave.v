`timescale 1ns/1ps

module axi_slave #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 64,
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
    input  wire                   s_axi_awlock,
    input  wire [3:0]             s_axi_awcache,
    input  wire [2:0]             s_axi_awprot,
    input  wire [3:0]             s_axi_awqos,
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
    input  wire                   s_axi_arlock,
    input  wire [3:0]             s_axi_arcache,
    input  wire [2:0]             s_axi_arprot,
    input  wire [3:0]             s_axi_arqos,
    input  wire                   s_axi_arvalid,
    output reg                    s_axi_arready,

    output reg  [ID_WIDTH-1:0]    s_axi_rid,
    output reg  [DATA_WIDTH-1:0]  s_axi_rdata,
    output reg  [1:0]             s_axi_rresp,
    output reg                    s_axi_rlast,
    output reg                    s_axi_rvalid,
    input  wire                   s_axi_rready
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
localparam ADDR_LSB       = 3;  // clog2(STRB_WIDTH) = clog2(8) = 3
localparam MEM_ADDR_WIDTH = 8;  // clog2(MEM_WORDS)  = clog2(256) = 8

localparam ST_IDLE       = 2'd0;
localparam ST_WRITE_DATA = 2'd1;
localparam ST_WRITE_RESP = 2'd2;
localparam ST_READ_DATA  = 2'd3;

localparam RESP_OKAY  = 2'b00;
localparam RESP_SLVERR = 2'b10;

reg [1:0] state;

reg [DATA_WIDTH-1:0] mem [0:MEM_WORDS-1];

reg [ID_WIDTH-1:0]   wr_id;
reg [ADDR_WIDTH-1:0] wr_addr;
reg [7:0]            wr_len;
reg [2:0]            wr_size;
reg [1:0]            wr_burst;
reg [7:0]            wr_count;
reg                  wr_error;

reg [ID_WIDTH-1:0]   rd_id;
reg [ADDR_WIDTH-1:0] rd_addr;
reg [7:0]            rd_len;
reg [2:0]            rd_size;
reg [1:0]            rd_burst;
reg [7:0]            rd_count;
reg                  rd_error;

integer init_idx;
integer byte_idx;

function burst_is_supported;
    input [1:0] burst_type;
    begin
        burst_is_supported = (burst_type == 2'b00) || (burst_type == 2'b01) || (burst_type == 2'b10);
    end
endfunction

function size_is_supported;
    input [2:0] size_value;
    begin
        size_is_supported = (size_value <= ADDR_LSB[2:0]);
    end
endfunction

function [ADDR_WIDTH-1:0] burst_addr;
    input [ADDR_WIDTH-1:0] base_addr;
    input [7:0] beat_count;
    input [7:0] burst_len;
    input [2:0] burst_size;
    input [1:0] burst_type;
    integer beat_bytes;
    integer wrap_bytes;
    integer wrap_base;
    integer wrap_offset;
    integer base_int;
    begin
        beat_bytes = (1 << burst_size);
        base_int   = base_addr;

        if (burst_type == 2'b00) begin
            burst_addr = base_addr;
        end else if (burst_type == 2'b10) begin
            wrap_bytes  = beat_bytes * (burst_len + 1);
            wrap_base   = (base_int / wrap_bytes) * wrap_bytes;
            wrap_offset = (base_int - wrap_base + beat_count * beat_bytes) % wrap_bytes;
            burst_addr  = wrap_base + wrap_offset;
        end else begin
            burst_addr = base_addr + beat_count * beat_bytes;
        end
    end
endfunction

function [MEM_ADDR_WIDTH-1:0] addr_to_index;
    input [ADDR_WIDTH-1:0] byte_addr;
    begin
        addr_to_index = byte_addr[ADDR_LSB +: MEM_ADDR_WIDTH];
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
        s_axi_bresp   <= RESP_OKAY;
        s_axi_bid     <= {ID_WIDTH{1'b0}};
        s_axi_arready <= 1'b0;
        s_axi_rvalid  <= 1'b0;
        s_axi_rdata   <= {DATA_WIDTH{1'b0}};
        s_axi_rresp   <= RESP_OKAY;
        s_axi_rid     <= {ID_WIDTH{1'b0}};
        s_axi_rlast   <= 1'b0;
        wr_id         <= {ID_WIDTH{1'b0}};
        wr_addr       <= {ADDR_WIDTH{1'b0}};
        wr_len        <= 8'd0;
        wr_size       <= 3'd0;
        wr_burst      <= 2'b01;
        wr_count      <= 8'd0;
        wr_error      <= 1'b0;
        rd_id         <= {ID_WIDTH{1'b0}};
        rd_addr       <= {ADDR_WIDTH{1'b0}};
        rd_len        <= 8'd0;
        rd_size       <= 3'd0;
        rd_burst      <= 2'b01;
        rd_count      <= 8'd0;
        rd_error      <= 1'b0;
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
                    wr_addr       <= s_axi_awaddr;
                    wr_len        <= s_axi_awlen;
                    wr_size       <= s_axi_awsize;
                    wr_burst      <= s_axi_awburst;
                    wr_count      <= 8'd0;
                    wr_error      <= !size_is_supported(s_axi_awsize) || !burst_is_supported(s_axi_awburst);
                    s_axi_awready <= 1'b0;
                    s_axi_arready <= 1'b0;
                    s_axi_wready  <= 1'b1;
                    state         <= ST_WRITE_DATA;
                end else if (s_axi_arvalid && s_axi_arready) begin
                    rd_id         <= s_axi_arid;
                    rd_addr       <= s_axi_araddr;
                    rd_len        <= s_axi_arlen;
                    rd_size       <= s_axi_arsize;
                    rd_burst      <= s_axi_arburst;
                    rd_count      <= 8'd0;
                    rd_error      <= !size_is_supported(s_axi_arsize) || !burst_is_supported(s_axi_arburst);
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
                    if (!wr_error) begin
                        for (byte_idx = 0; byte_idx < STRB_WIDTH; byte_idx = byte_idx + 1) begin
                            if (s_axi_wstrb[byte_idx]) begin
                                mem[addr_to_index(burst_addr(wr_addr, wr_count, wr_len, wr_size, wr_burst))][8*byte_idx +: 8]
                                    <= s_axi_wdata[8*byte_idx +: 8];
                            end
                        end
                    end

                    if (s_axi_wlast || (wr_count == wr_len)) begin
                        s_axi_wready <= 1'b0;
                        s_axi_bid    <= wr_id;
                        s_axi_bresp  <= (wr_error || (s_axi_wlast != (wr_count == wr_len))) ? RESP_SLVERR : RESP_OKAY;
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
                    s_axi_rdata  <= rd_error ? {DATA_WIDTH{1'b0}}
                                             : mem[addr_to_index(burst_addr(rd_addr, rd_count, rd_len, rd_size, rd_burst))];
                    s_axi_rresp  <= rd_error ? RESP_SLVERR : RESP_OKAY;
                    s_axi_rlast  <= (rd_count == rd_len);
                    s_axi_rvalid <= 1'b1;
                end
            end

            default: begin
                state         <= ST_IDLE;
                s_axi_awready <= 1'b0;
                s_axi_wready  <= 1'b0;
                s_axi_bvalid  <= 1'b0;
                s_axi_arready <= 1'b0;
                s_axi_rvalid  <= 1'b0;
                s_axi_rlast   <= 1'b0;
            end
        endcase
    end
end

endmodule
