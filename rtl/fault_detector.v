//=============================================================================
// fault_detector.v — 故障检测与汇总
//=============================================================================
`include "axi_safety_island_pkg.vh"

module fault_detector (
    input  wire clk, rst_n,
    // Data mismatch inputs
    input  wire mismatch_ch0, mismatch_ch1, mismatch_ch2, mismatch_ch3, mismatch_ch4,
    // AXI error inputs
    input  wire error_ch0, error_ch1, error_ch2, error_ch3, error_ch4,
    input  wire [3:0] errtype_ch0, errtype_ch1, errtype_ch2, errtype_ch3, errtype_ch4,
    // Config error
    input  wire config_error,
    input  wire [3:0] config_error_code,
    // Internal fault (from self-check)
    input  wire internal_stuck_at,
    input  wire internal_transient,
    input  wire latent_fault_detect,
    // Fault outputs
    output reg  fault_detect,
    output reg  safety_island_fault_detect,
    output reg  safety_island_latent_fault_detect,
    // Detailed status
    output reg  [3:0] fault_type,
    output reg  [2:0] fault_channel
);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        fault_detect <= 0;
        safety_island_fault_detect <= 0;
        safety_island_latent_fault_detect <= 0;
        fault_type <= 0;
        fault_channel <= 0;
    end else begin
        fault_detect <= 0;
        safety_island_fault_detect <= 0;
        safety_island_latent_fault_detect <= 0;

        // External faults
        if (mismatch_ch0) begin fault_detect<=1; fault_type<=4'h0; fault_channel<=0; end
        if (mismatch_ch1) begin fault_detect<=1; fault_type<=4'h0; fault_channel<=1; end
        if (mismatch_ch2) begin fault_detect<=1; fault_type<=4'h0; fault_channel<=2; end
        if (mismatch_ch3) begin fault_detect<=1; fault_type<=4'h0; fault_channel<=3; end
        if (mismatch_ch4) begin fault_detect<=1; fault_type<=4'h0; fault_channel<=4; end

        // AXI timeout
        if (error_ch0 && errtype_ch0==4'd1) begin fault_detect<=1; fault_type<=4'h1; fault_channel<=0; end
        if (error_ch1 && errtype_ch1==4'd1) begin fault_detect<=1; fault_type<=4'h1; fault_channel<=1; end
        if (error_ch2 && errtype_ch2==4'd1) begin fault_detect<=1; fault_type<=4'h1; fault_channel<=2; end
        if (error_ch3 && errtype_ch3==4'd1) begin fault_detect<=1; fault_type<=4'h1; fault_channel<=3; end
        if (error_ch4 && errtype_ch4==4'd1) begin fault_detect<=1; fault_type<=4'h1; fault_channel<=4; end

        // AXI error response
        if (error_ch0 && errtype_ch0==4'd2) begin fault_detect<=1; fault_type<=4'h2; fault_channel<=0; end
        if (error_ch1 && errtype_ch1==4'd2) begin fault_detect<=1; fault_type<=4'h2; fault_channel<=1; end
        if (error_ch2 && errtype_ch2==4'd2) begin fault_detect<=1; fault_type<=4'h2; fault_channel<=2; end
        if (error_ch3 && errtype_ch3==4'd2) begin fault_detect<=1; fault_type<=4'h2; fault_channel<=3; end
        if (error_ch4 && errtype_ch4==4'd2) begin fault_detect<=1; fault_type<=4'h2; fault_channel<=4; end

        // Config error
        if (config_error) begin fault_detect<=1; fault_type<=4'h3; end

        // Internal stuck-at
        if (internal_stuck_at) begin safety_island_fault_detect<=1; fault_type<=4'h4; end
        // Internal transient
        if (internal_transient) begin safety_island_fault_detect<=1; fault_type<=4'h5; end
        // Latent fault
        if (latent_fault_detect) begin safety_island_latent_fault_detect<=1; fault_type<=4'h7; end
    end
end

endmodule
