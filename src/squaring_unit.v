`default_nettype none

module squaring_unit(
    input wire clk,
    input wire rst_n,
    input wire sample_valid,
    input wire signed [15:0] x_in,
    output reg [15:0] y_out
);

    wire signed [31:0] product;

    assign product = x_in * x_in;

    always @(posedge clk) begin
        if(!rst_n) begin
            y_out <= 16'd0;
        end else if(sample_valid) begin
            y_out <= product[30:15];
        end
    end

endmodule