`default_nettype none

module moving_window(
    input wire clk,
    input wire rst_n,
    input wire sample_valid,
    input wire [15:0] x_in,
    output reg [15:0] y_out
);

    localparam N = 54;
    reg [15:0] window [0: N - 1];
    reg signed [21:0] new_sum;
    reg signed [21:0] running_sum; //22 bits to fit max sum
    integer i;

    always @(posedge clk) begin
        if(!rst_n) begin
            running_sum <= 22'b0;
            y_out <= 16'b0;
            for (i = 0; i < N; i = i + 1)
                window[i] <= 16'd0;
        end else if(sample_valid) begin
            new_sum = running_sum + x_in - window[N-1];
            running_sum <= new_sum;
            for (i = N-1; i > 0; i = i - 1)
                window[i] <= window[i-1];
            window[0] <= x_in;
            y_out <= new_sum[21:6];
        end

    end
endmodule