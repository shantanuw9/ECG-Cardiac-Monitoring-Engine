`default_nettype none

module feature_extractor (
    input wire clk,
    input wire rst_n,
    input wire beat_detected,
    input wire [15:0] rr_interval,
    input wire [15:0] beat_amplitude,
    input wire [15:0] qrs_start_time,
    input wire [15:0] qrs_peak_time,
    output reg [15:0] qrs_width,
    output reg [15:0] hrv_sdnn,
    output reg [15:0] heart_rate,
    output reg [15:0] last_rr
);

    localparam HR_WINDOW = 32;
    reg [15:0] rr_buffer [0:HRV_WINDOW-1];
    reg [4:0] rr_buffer_index;
    reg [4:0] beat_count;

    integer i;
    reg [20:0] rr_sum;
    reg [15:0] rr_mean;
    reg [20:0] mad_sum;
    reg [15:0] diff;

    always @(posedge clk) begin
        if(!rst_n) begin
            qrs_width <= 0;
            hrv_sdnn <= 0;
            heart_rate <= 0;
            last_rr <= 0;
            for(i = 0; i < HRV_WINDOW; i = i + 1)
                rr_buffer[i] <= 16'b0;
        end else if(beat_detected) begin
            qrs_width <= (qrs_peak_time - qrs_start_time) << 1;
            heart_rate <= 15'd21600 / rr_interval;

            last_rr <= rr_interval;
            rr_buffer[rr_buffer_index] <= rr_interval;
            rr_buffer_index <= rr_buffer_index + 1'b1;
            if(beat_count < HRV_WINDOW)
                beat_count <= beat_count + 1'b1;

            if(beat_count >= 4) begin
                rr_sum = 21'b0;
                for(i = 0; i < HRV_WINDOW; i = i + 1)
                    rr_sum = rr_sum + rr_buffer[i];

                rr_mean = rr_sum[20:5];
                mad_sum = 21'b0;
                for(i = 0; i < HRV_WINDOW; i = i + 1) begin
                    diff = (rr_buffer[i] > rr_mean) ? (rr_buffer[i] - rr_mean) : (rr_mean - rr_buffer[i]);
                    mad_sum = mad_sum + diff;
                end
                hrv_sdnn <= mad_sum[20:5];
            end

        end
    end


endmodule