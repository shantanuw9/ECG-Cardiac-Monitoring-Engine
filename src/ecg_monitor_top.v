module ecg_monitor_top (
    input wire clk,
    input wire rst_n,
    input wire signed [15:0] ecg_sample,
    input wire sample_valid,
    output wire beat_detected, //cycles per detected QRS
    output wire sample_ready,  //sync
    //Cardiomyopathy feature flags
    output wire wide_qrs, // QRS duration > 120ms
    output wire tachy_flag, // HR > 100 BPM
    output wire brady_flag, // HR < 60 BPM
    output wire long_qt, // QT interval > 440ms (basic threshold)
    output wire low_hrv, // SDNN < threshold over 30-beat window
    output wire anomaly_flag, // any cardiomyopathy flag asserted

    // Neural network extension outlet — connect nn_inference_engine here in fall
    output wire [95:0] nn_feature_vec,   // packed: 6 × 16-bit features per beat
    output wire        nn_feature_valid  // one-cycle strobe when nn_feature_vec is valid
);









endmodule