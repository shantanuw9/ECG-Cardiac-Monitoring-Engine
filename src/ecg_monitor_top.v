`default_nettype none

module ecg_monitor_top (
    input wire clk,
    input wire rst_n,
    input wire signed [15:0] ecg_sample,
    input wire sample_valid,

    output wire beat_detected,
    output wire sample_ready,
    //Cardiomyopathy feature flags
    output wire wide_qrs, // QRS duration > 120ms
    output wire tachy_flag, // HR > 100 BPM
    output wire brady_flag, // HR < 60 BPM
    output wire low_hrv, // SDNN < threshold over 32-beat window
    output wire anomaly_flag, // any cardiomyopathy flag asserted

    output wire [95:0] nn_feature_vec,   // packed: 6 × 16-bit features per beat
    output wire nn_feature_valid  // one-cycle strobe when nn_feature_vec is valid
);

    wire [15:0] bp_out;
    wire [15:0] df_out;
    wire [15:0] su_out;
    wire [15:0] mw_out;
    wire [15:0] rr_interval;
    wire [15:0] beat_amplitude;
    wire [15:0] qrs_start_time;
    wire [15:0] qrs_peak_time;
    wire [15:0] qrs_width;
    wire [15:0] hrv_sdnn;
    wire [15:0] heart_rate;
    wire [15:0] last_rr;

    /*
    nn_feature_vec[15:0]   = qrs_width[15:0]
    nn_feature_vec[31:16]  = rr_interval[15:0]
    nn_feature_vec[47:32]  = hrv_sdnn[15:0]
    nn_feature_vec[63:48]  = heart_rate[15:0]
    nn_feature_vec[79:64]  = beat_amplitude[15:0]
    nn_feature_vec[95:80]  = last_rr[15:0]
    */

    assign sample_ready = sample_valid;
    assign nn_feature_vec = {beat_amplitude, hrv_sdnn, last_rr, 16'b0, rr_interval, qrs_width};
    assign nn_feature_valid = beat_detected;

    bandpass_filter bpf(
        .clk(clk),
        .rst_n(rst_n),
        .sample_valid(sample_valid),
        .x_in(ecg_sample),
        .y_out(bp_out)
    );

    derivative_filter df (
        .clk(clk),
        .rst_n(rst_n),
        .sample_valid(sample_valid),
        .x_in(bp_out),
        .y_out(df_out)
    );

    squaring_unit su (
        .clk(clk),
        .rst_n(rst_n),
        .sample_valid(sample_valid),
        .x_in(df_out),
        .y_out(su_out)
    );

    moving_window mw (
        .clk(clk),
        .rst_n(rst_n),
        .sample_valid(sample_valid),
        .x_in(su_out),
        .y_out(mw_out)
    );

    qrs_detector qrs (
        .clk(clk),
        .rst_n(rst_n),
        .sample_valid(sample_valid),
        .mwi_in(mw_out),
        .beat_detected(beat_detected),
        .rr_interval(rr_interval),
        .beat_amplitude(beat_amplitude),
        .qrs_start_time(qrs_start_time),
        .qrs_peak_time(qrs_peak_time)
    );

    feature_extractor feature (
        .clk(clk),
        .rst_n(rst_n),
        .beat_detected(beat_detected),
        .rr_interval(rr_interval),
        .beat_amplitude(beat_amplitude),
        .qrs_start_time(qrs_start_time),
        .qrs_peak_time(qrs_peak_time),
        .qrs_width(qrs_width),
        .hrv_sdnn(hrv_sdnn),
        .heart_rate(heart_rate),
        .last_rr(last_rr)
    );

    flag_aggregator flags (
        .clk(clk),
        .rst_n(rst_n),
        .beat_detected(beat_detected),
        .qrs_width(qrs_width),
        .heart_rate(heart_rate),
        .hrv_sdnn(hrv_sdnn),
        .beat_amplitude(beat_amplitude),
        .rr_interval(rr_interval),
        .wide_qrs(wide_qrs),
        .tachy_flag(tachy_flag),
        .brady_flag(brady_flag),
        .low_hrv(low_hrv),
        .anomaly_flag(anomaly_flag)
    );


endmodule