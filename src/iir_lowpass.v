`default_nettype none

module iir_lowpass(
    input wire clk,
    input wire rst_n,
    input wire sample_valid,
    input wire signed [15:0] x_in,
    output reg signed [15:0] y_out
);

    //y[n] = 2y[n-1] - y[n-2] + x[n] - 2x[n-6] + x[n-12]
    reg signed [15:0] x_delay [1:12];
    reg signed [15:0] y_delay [1:2];
    wire signed [31:0] acc;
    integer i;

    assign acc = (y_delay[1] <<< 1) - y_delay[2] + x_in - (x_delay[6] <<< 1) + x_delay[12];

    always @(posedge clk) begin
        if(!rst_n) begin
            for (i = 1; i <= 12; i = i + 1)
                x_delay[i] <= 16'sd0;
            y_delay[1] <= 16'sd0;
            y_delay[2] <= 16'sd0;
            y_out <= 16'sd0;
        end else begin
            if(sample_valid) begin
                for (i = 12; i > 1; i = i - 1)
                    x_delay[i] <= x_delay[i-1];
                x_delay[1] <= x_in;
                
                y_delay[2] <= y_delay[1];
                y_delay[1] <= acc[20:5];
                y_out <= acc[20:5];

            end
        end
    end

endmodule