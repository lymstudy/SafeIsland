//=============================================================================
// config_checker.v — 配置合法性检查模块
//=============================================================================
`include "axi_safety_island_pkg.vh"

module config_checker (
    input  wire clk, rst_n,
    input  wire cfg_enable, cfg_write_protect, cfg_aou_enable,
    input  wire [31:0] cfg_read_interval, cfg_timeout_threshold,
    input  wire [7:0]  cfg_max_outstanding,
    input  wire [31:0] cfg_base_addr_0, cfg_base_addr_1, cfg_base_addr_2,
    input  wire [31:0] cfg_base_addr_3, cfg_base_addr_4,
    input  wire check_trigger,
    input  wire [2:0]  check_ch,
    input  wire [5:0]  check_off,
    input  wire [1:0]  check_burst_type,
    input  wire [7:0]  check_burst_len,
    input  wire [`AXI_DATA_WIDTH-1:0] check_mask, check_expected,
    input  wire [31:0] check_offset_addr,
    output reg  check_done, check_pass,
    output reg  [3:0] check_error_code
);

localparam ERR_NONE = 4'h0;
localparam ERR_BASE_ADDR_ALIGN = 4'h1;
localparam ERR_OFFSET_ALIGN = 4'h3;
localparam ERR_BURST_TYPE = 4'h5;
localparam ERR_BURST_LEN_ZERO = 4'h6;
localparam ERR_MASK_ALL_ZERO = 4'h8;
localparam ERR_READ_INTERVAL_MIN = 4'h9;
localparam ERR_AOU_MASK_CONFLICT = 4'hA;

reg [3:0] state;
localparam IDLE = 4'd0, CHECK = 4'd1, DONE = 4'd2;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        check_done <= 1'b0; check_pass <= 1'b1;
        check_error_code <= ERR_NONE; state <= IDLE;
    end else begin
        case (state)
            IDLE: begin
                check_done <= 1'b0;
                if (check_trigger) state <= CHECK;
            end

            CHECK: begin
                // Use blocking for internal computation
                check_pass = 1'b1;
                check_error_code = ERR_NONE;

                if (check_pass && check_ch < 5) begin
                    case (check_ch)
                        0: if (cfg_base_addr_0[2:0] != 3'd0) begin check_pass=0; check_error_code=ERR_BASE_ADDR_ALIGN; end
                        1: if (cfg_base_addr_1[2:0] != 3'd0) begin check_pass=0; check_error_code=ERR_BASE_ADDR_ALIGN; end
                        2: if (cfg_base_addr_2[2:0] != 3'd0) begin check_pass=0; check_error_code=ERR_BASE_ADDR_ALIGN; end
                        3: if (cfg_base_addr_3[2:0] != 3'd0) begin check_pass=0; check_error_code=ERR_BASE_ADDR_ALIGN; end
                        4: if (cfg_base_addr_4[2:0] != 3'd0) begin check_pass=0; check_error_code=ERR_BASE_ADDR_ALIGN; end
                    endcase
                end
                if (check_pass && check_offset_addr[2:0] != 3'd0) begin
                    check_pass=0; check_error_code=ERR_OFFSET_ALIGN; end
                if (check_pass && check_burst_type != 2'b01 && check_burst_type != 2'b10) begin
                    check_pass=0; check_error_code=ERR_BURST_TYPE; end
                if (check_pass && check_burst_len == 8'd0) begin
                    check_pass=0; check_error_code=ERR_BURST_LEN_ZERO; end
                if (check_pass && check_mask == 64'd0) begin
                    check_pass=0; check_error_code=ERR_MASK_ALL_ZERO; end
                if (check_pass && cfg_read_interval < 32'd10) begin
                    check_pass=0; check_error_code=ERR_READ_INTERVAL_MIN; end
                if (check_pass && cfg_aou_enable && check_mask == 64'hFFFFFFFF_FFFFFFFF) begin
                    check_pass=0; check_error_code=ERR_AOU_MASK_CONFLICT; end

                state <= DONE;
            end

            DONE: begin
                check_done <= 1'b1;
                state <= IDLE;
            end

            default: state <= IDLE;
        endcase
    end
end

endmodule
