`default_nettype none

module iir_highpass (
    input wire clk,
    input wire rst_n,
    input wire sample_valid,
    input wire signed [15:0] x_in,
    output reg signed [15:0] y_out
);

    //y[n] = 32x[n-16] - y[n-1] - x[n] + x[n-32]
    reg signed [15:0] x_delay [1:32];
    reg signed [15:0] y_delay_1;
    reg signed [31:0] acc;
    integer i;

    always @(posedge clk) begin
        if(!rst_n) begin
            for(i = 1; i <= 32; i = i + 1)
                x_delay[i] <= 16'sd0;
            y_delay_1 <= 16'sd0;
            y_out <= 16'sd0;
        end else if (sample_valid) begin
            for (i = 32; i > 1; i = i - 1)
                x_delay[i] <= x_delay[i-1];
            x_delay[1] <= x_in;
            acc = (x_delay[16] <<< 5) - y_delay_1 - x_in + x_delay[32];
            y_delay_1 <= acc[24:9];
            y_out <= acc[24:9];
        end
    end

endmodule