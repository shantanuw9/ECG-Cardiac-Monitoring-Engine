`default_nettype none

module derivative_filter(
    input wire clk,
    input wire rst_n,
    input wire sample_valid,
    input wire signed [15:0] x_in,
    output reg signed [15:0] y_out
);

    reg signed [15:0] delay [1:4];
    integer i;

    always @(posedge clk) begin
        if(!rst_n) begin
            for(i = 1; i < 5; i=i+1)
                delay[i] <= 16'sd0;
            y_out <= 16'sd0;
        end else if(sample_valid) begin
            for(i = 4; i > 1; i=i-1)
                delay[i] <= delay[i-1];
            delay[1] <= x_in;
            y_out <= ((x_in <<< 1) + delay[1] - delay[3] - (delay[4] <<< 1)) >>> 3;
        end
    end

endmodule