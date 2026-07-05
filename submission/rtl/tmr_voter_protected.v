//------------------------------------------------------------------------------
// tmr_voter_protected.v — Self-protected triple modular redundancy voter
//
// Three independent majority expressions (v0/v1/v2) vote again to protect
// against voter logic becoming a single point of failure.
//------------------------------------------------------------------------------

`timescale 1ns/1ps

module tmr_voter_protected #(
    parameter WIDTH = 1
) (
    input  wire [WIDTH-1:0] a,
    input  wire [WIDTH-1:0] b,
    input  wire [WIDTH-1:0] c,

    output wire [WIDTH-1:0] voted,
    output wire             mismatch,
    output wire             voter_self_fault
);

    (* DONT_TOUCH = "TRUE" *) wire [WIDTH-1:0] v0;
    (* DONT_TOUCH = "TRUE" *) wire [WIDTH-1:0] v1;
    (* DONT_TOUCH = "TRUE" *) wire [WIDTH-1:0] v2;

    assign v0 = (a & b) | (b & c) | (a & c);
    assign v1 = (a & b) | (b & c) | (a & c);
    assign v2 = (a & b) | (b & c) | (a & c);

    assign voted = (v0 & v1) | (v1 & v2) | (v0 & v2);

    assign mismatch = |((a ^ b) | (a ^ c) | (b ^ c));
    assign voter_self_fault = |((v0 ^ v1) | (v0 ^ v2) | (v1 ^ v2));

endmodule
