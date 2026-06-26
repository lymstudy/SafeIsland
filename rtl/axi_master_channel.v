//=============================================================================
// axi_master_channel.v — AXI4 Master 读通道 (流式数据输出)
//=============================================================================
`include "axi_safety_island_pkg.vh"

module axi_master_channel (
    input  wire clk, rst_n,
    // Control
    input  wire                        start,
    input  wire [`AXI_ADDR_WIDTH-1:0]  read_addr,
    input  wire [7:0]                  burst_len,
    input  wire [1:0]                  burst_type,
    input  wire [7:0]                  channel_id,
    input  wire [31:0]                 timeout_cycles,
    output reg                         done,
    output reg                         error,
    output reg  [3:0]                  error_type,
    // Streaming data output
    output reg                         data_valid,
    output reg  [`AXI_DATA_WIDTH-1:0]  data_out,
    output reg                         data_last,
    output reg  [7:0]                  beat_num,

    // AXI4 Master Read
    output reg  [`AXI_ID_WIDTH-1:0]    m_arid,
    output reg  [`AXI_ADDR_WIDTH-1:0]  m_araddr,
    output reg  [7:0]                  m_arlen,
    output reg  [2:0]                  m_arsize,
    output reg  [1:0]                  m_arburst,
    output reg                         m_arvalid,
    input  wire                        m_arready,
    input  wire [`AXI_ID_WIDTH-1:0]    m_rid,
    input  wire [`AXI_DATA_WIDTH-1:0]  m_rdata,
    input  wire [1:0]                  m_rresp,
    input  wire                        m_rlast,
    input  wire                        m_rvalid,
    output reg                         m_rready
);

reg [2:0] state;
localparam S_IDLE=3'd0, S_ADDR=3'd1, S_DATA=3'd2, S_DONE=3'd3, S_ERR=3'd4;

reg [31:0] tcnt;
reg [7:0]  bcnt;
reg        to;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state<=S_IDLE; m_arvalid<=0; m_rready<=0;
        done<=0; error<=0; error_type<=0;
        data_valid<=0; data_out<=0; data_last<=0; beat_num<=0;
        tcnt<=0; bcnt<=0; to<=0;
    end else begin
        case (state)
            S_IDLE: begin
                done<=0; error<=0; data_valid<=0;
                if(start) begin
                    m_arid<={1'b0,channel_id[6:0]};
                    m_araddr<=read_addr; m_arlen<=burst_len;
                    m_arsize<=3'd3; m_arburst<=burst_type;
                    m_arvalid<=1; bcnt<=0; tcnt<=0; to<=0;
                    state<=S_ADDR;
                end
            end

            S_ADDR: begin
                if(m_arvalid && m_arready) begin
                    m_arvalid<=0; m_rready<=1; state<=S_DATA;
                end
                tcnt<=tcnt+1;
                if(tcnt>=timeout_cycles) begin to<=1; state<=S_ERR; end
            end

            S_DATA: begin
                if(m_rvalid && m_rready) begin
                    data_out<=m_rdata; data_valid<=1;
                    beat_num<=bcnt; data_last<=m_rlast;
                    if(m_rresp!=2'b00) begin
                        error<=1; error_type<=4'd2; state<=S_ERR;
                    end else if(m_rlast) begin
                        m_rready<=0; state<=S_DONE;
                    end else bcnt<=bcnt+1;
                    tcnt<=0;
                end else begin
                    tcnt<=tcnt+1;
                    if(tcnt>=timeout_cycles) begin
                        to<=1; error<=1; error_type<=4'd1; state<=S_ERR;
                    end
                end
            end

            S_DONE: begin done<=1; data_valid<=0; state<=S_IDLE; end
            S_ERR:  begin done<=1; error<=1; if(to) error_type<=4'd1;
                           data_valid<=0; m_rready<=0; state<=S_IDLE; end
            default: state<=S_IDLE;
        endcase
    end
end

endmodule
