//------------------------------------------------------------------------------
// tmr_voter.v — Triple Modular Redundancy majority voter
//
// Takes three identical copies of a signal and outputs the majority vote.
// mismatch is asserted when all three inputs differ (two-out-of-three
// cannot determine a winner).
//------------------------------------------------------------------------------

`timescale 1ns/1ps

module tmr_voter #(
    parameter WIDTH = 4
) (
    input  wire [WIDTH-1:0] a,
    input  wire [WIDTH-1:0] b,
    input  wire [WIDTH-1:0] c,

    output wire [WIDTH-1:0] voted,
    output wire             mismatch
);

    // Majority vote per bit: a&b | b&c | a&c
    assign voted = (a & b) | (b & c) | (a & c);

    // mismatch: all three inputs differ (a!=b) and (b!=c)
    assign mismatch = |((a ^ b) & (b ^ c));

endmodule
