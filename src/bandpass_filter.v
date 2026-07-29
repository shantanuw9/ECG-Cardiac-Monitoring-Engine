`default_nettype none

module bandpass_filter(
    input wire clk,
    input wire rst_n,
    input wire sample_valid,
    input wire signed [15:0] x_in,
    output reg signed [15:0] y_out
);

    wire signed [15:0] lowpass_out;

    iir_lowpass lp (
        .clk(clk),
        .rst_n(rst_n),
        .sample_valid(sample_valid),
        .x_in(x_in),
        .y_out(lowpass_out)
    );

    iir_highpass hp (
        .clk(clk),
        .rst_n(rst_n),
        .sample_valid(sample_valid),
        .x_in(lowpass_out),
        .y_out(y_out)
    );

endmodule