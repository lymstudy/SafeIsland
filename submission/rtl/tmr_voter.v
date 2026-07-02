//------------------------------------------------------------------------------
// tmr_voter.v — Triple Modular Redundancy majority voter
//
// Takes three identical copies of a signal and outputs the majority vote.
// mismatch is asserted when any replica differs from the others. The voted
// output still corrects a single-copy fault, while mismatch provides detection.
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

    assign mismatch = |((a ^ b) | (a ^ c) | (b ^ c));

endmodule
