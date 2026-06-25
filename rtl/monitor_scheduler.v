//=============================================================================
// monitor_scheduler.v — 5通道监控调度器
// 按 READ_INTERVAL 周期触发5路Master读取任务
//=============================================================================
`include "axi_safety_island_pkg.vh"

module monitor_scheduler (
    input  wire clk, rst_n,
    input  wire cfg_enable,
    input  wire [31:0] read_interval,
    input  wire [31:0] base_addr_0, base_addr_1, base_addr_2, base_addr_3, base_addr_4,

    // 5路Master启动信号
    output reg  start_ch0, start_ch1, start_ch2, start_ch3, start_ch4,
    output reg  [31:0] addr_ch0, addr_ch1, addr_ch2, addr_ch3, addr_ch4,
    output reg  [7:0]  len_ch0,  len_ch1,  len_ch2,  len_ch3,  len_ch4,
    output reg  [1:0]  type_ch0, type_ch1, type_ch2, type_ch3, type_ch4,

    // Master完成信号
    input  wire done_ch0, done_ch1, done_ch2, done_ch3, done_ch4,

    // 调度状态
    output reg  [2:0]  sched_state,
    output reg  [5:0]  current_offset
);

reg [31:0] interval_cnt;
reg [2:0]  state;
localparam S_IDLE=3'd0, S_TRIGGER=3'd1, S_WAIT=3'd2, S_INTERVAL=3'd3;

wire all_done;
assign all_done = done_ch0 && done_ch1 && done_ch2 && done_ch3 && done_ch4;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= S_IDLE;
        start_ch0<=0; start_ch1<=0; start_ch2<=0; start_ch3<=0; start_ch4<=0;
        addr_ch0<=0; addr_ch1<=0; addr_ch2<=0; addr_ch3<=0; addr_ch4<=0;
        len_ch0<=0; len_ch1<=0; len_ch2<=0; len_ch3<=0; len_ch4<=0;
        type_ch0<=2'b01; type_ch1<=2'b01; type_ch2<=2'b01; type_ch3<=2'b01; type_ch4<=2'b01;
        interval_cnt<=0; current_offset<=0; sched_state<=S_IDLE;
    end else begin
        start_ch0<=0; start_ch1<=0; start_ch2<=0; start_ch3<=0; start_ch4<=0;
        sched_state <= state;

        case (state)
            S_IDLE: begin
                interval_cnt <= 0;
                current_offset <= 0;
                if (cfg_enable) state <= S_TRIGGER;
            end

            S_TRIGGER: begin
                // 启动所有5路Master
                start_ch0<=1; addr_ch0<=base_addr_0; len_ch0<=8'd0; type_ch0<=2'b01;
                start_ch1<=1; addr_ch1<=base_addr_1; len_ch1<=8'd0; type_ch1<=2'b01;
                start_ch2<=1; addr_ch2<=base_addr_2; len_ch2<=8'd0; type_ch2<=2'b01;
                start_ch3<=1; addr_ch3<=base_addr_3; len_ch3<=8'd0; type_ch3<=2'b01;
                start_ch4<=1; addr_ch4<=base_addr_4; len_ch4<=8'd0; type_ch4<=2'b01;
                current_offset <= 0;
                state <= S_WAIT;
            end

            S_WAIT: begin
                if (all_done) begin
                    interval_cnt <= 0;
                    if (current_offset < 63) begin
                        current_offset <= current_offset + 1;
                        state <= S_TRIGGER;  // 下一组offset
                    end else begin
                        state <= S_INTERVAL;  // 所有offset完成
                    end
                end
            end

            S_INTERVAL: begin
                if (interval_cnt < read_interval)
                    interval_cnt <= interval_cnt + 1;
                else begin
                    current_offset <= 0;
                    state <= S_TRIGGER;
                end
                if (!cfg_enable) state <= S_IDLE;
            end

            default: state <= S_IDLE;
        endcase
    end
end

endmodule
