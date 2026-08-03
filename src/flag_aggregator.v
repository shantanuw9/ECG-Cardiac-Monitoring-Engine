`default_nettype none

module flag_aggregator(
    input wire clk,
    input wire rst_n,
    input wire beat_detected,
    input wire [15:0] qrs_width,
    input wire [15:0] heart_rate,
    input wire [15:0] hrv_sdnn,
    input wire [15:0] beat_amplitude,
    input wire [15:0] rr_interval,
    output reg wide_qrs,
    output reg tachy_flag,
    output reg brady_flag,
    output reg low_hrv,
    output reg anomaly_flag
);

    localparam WIDE_QRS_THRESH = 16'd43; // 43 samples = 120ms
    localparam TACHY_THRESH = 16'd216; // rr < 216 = HR > 100
    localparam BRADY_THRESH = 16'd360; // rr > 360 = HR < 60
    localparam LOW_HRV_THRESH = 16'd20; // MAD < 20 samples

    always @(posedge clk) begin
        if(!rst_n) begin
            wide_qrs <= 0;
            tachy_flag <= 0;
            brady_flag <= 0;
            low_hrv <= 0;
            anomaly_flag <= 0;
        end else if(beat_detected) begin
            wide_qrs <= (qrs_width > WIDE_QRS_THRESH);
            tachy_flag <= (rr_interval < TACHY_THRESH);
            brady_flag <= (rr_interval > BRADY_THRESH);
            low_hrv <= (hrv_sdnn < LOW_HRV_THRESH);
            anomaly_flag <= (qrs_width > WIDE_QRS_THRESH) | (hrv_sdnn < LOW_HRV_THRESH) | (rr_interval < TACHY_THRESH);
        end
    end

endmodule