`default_nettype none
`timescale 1ns / 1ps

module tb_feature_extractor;

    reg clk;
    reg rst_n;
    reg beat_detected;
    reg [15:0] rr_interval;
    reg [15:0] beat_amplitude;
    reg [15:0] qrs_start_time;
    reg [15:0] qrs_peak_time;
    wire [15:0] qrs_width;
    wire [15:0] hrv_sdnn;
    wire [15:0] heart_rate;
    wire [15:0] last_rr;

    feature_extractor dut (
        .clk (clk),
        .rst_n (rst_n),
        .beat_detected (beat_detected),
        .rr_interval (rr_interval),
        .beat_amplitude (beat_amplitude),
        .qrs_start_time (qrs_start_time),
        .qrs_peak_time (qrs_peak_time),
        .qrs_width (qrs_width),
        .hrv_sdnn (hrv_sdnn),
        .heart_rate (heart_rate),
        .last_rr (last_rr)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    integer fail_count = 0;
    integer k;

    task automatic send_beat(
        input [15:0] rr,
        input [15:0] amp,
        input [15:0] start_t,
        input [15:0] peak_t
    );
        begin
            @(posedge clk);
            rr_interval <= rr;
            beat_amplitude <= amp;
            qrs_start_time <= start_t;
            qrs_peak_time <= peak_t;
            beat_detected <= 1'b1;
            @(posedge clk);
            beat_detected <= 1'b0;
            @(posedge clk);
        end
    endtask

    initial begin
        $dumpfile("tb_feature_extractor.vcd");
        $dumpvars(0, tb_feature_extractor);

        rst_n = 0;
        beat_detected = 0;
        rr_interval = 0;
        beat_amplitude = 0;
        qrs_start_time = 0;
        qrs_peak_time = 0;

        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(2) @(posedge clk);

        // Test 1: Heart rate at 60 BPM — rr=360
        send_beat(16'd360, 16'd1000, 16'd100, 16'd110);
        @(posedge clk);
        if (heart_rate == 16'd60)
            $display("PASS test 1: heart_rate=60 BPM");
        else begin
            $display("FAIL test 1: expected 60 BPM got %0d", heart_rate);
            fail_count++;
        end

        // Test 2: Heart rate at 100 BPM — rr=216
        send_beat(16'd216, 16'd1000, 16'd100, 16'd110);
        @(posedge clk);
        if (heart_rate == 16'd100)
            $display("PASS test 2: heart_rate=100 BPM");
        else begin
            $display("FAIL test 2: expected 100 BPM got %0d", heart_rate);
            fail_count++;
        end

        // Test 3: QRS width — start=100, peak=121 → width=42
        send_beat(16'd360, 16'd1000, 16'd100, 16'd121);
        @(posedge clk);
        if (qrs_width == 16'd42)
            $display("PASS test 3: qrs_width=42");
        else begin
            $display("FAIL test 3: expected 42 got %0d", qrs_width);
            fail_count++;
        end

        // Test 4: last_rr mirrors rr_interval
        send_beat(16'd300, 16'd1000, 16'd100, 16'd110);
        @(posedge clk);
        if (last_rr == 16'd300)
            $display("PASS test 4: last_rr=300");
        else begin
            $display("FAIL test 4: expected 300 got %0d", last_rr);
            fail_count++;
        end

        // Test 5: HRV = 0 when all RR intervals identical
        // Send 32 beats with rr=360, hrv_sdnn should be 0
        for (k = 0; k < 33; k = k + 1)
            send_beat(16'd360, 16'd1000, 16'd100, 16'd110);
        repeat(1) @(posedge clk);
        if (hrv_sdnn == 16'd0)
            $display("PASS test 5: hrv_sdnn=0 for constant RR");
        else begin
            $display("FAIL test 5: expected hrv_sdnn=0 got %0d", hrv_sdnn);
            fail_count++;
        end

        // Test 6: HRV > 0 when RR intervals vary
        // Alternating 340/380 — mean=360, deviation=20, MAD=20
        for (k = 0; k < 32; k = k + 1) begin
            if (k % 2 == 0)
                send_beat(16'd340, 16'd1000, 16'd100, 16'd110);
            else
                send_beat(16'd380, 16'd1000, 16'd100, 16'd110);
        end
        repeat(2) @(posedge clk);
        if (hrv_sdnn > 0)
            $display("PASS test 6: hrv_sdnn=%0d (>0 for variable RR)", hrv_sdnn);
        else begin
            $display("FAIL test 6: expected hrv_sdnn > 0, got %0d", hrv_sdnn);
            fail_count++;
        end

        // Test 7: Reset clears state
        rst_n = 0;
        repeat(3) @(posedge clk);
        rst_n = 1;
        repeat(2) @(posedge clk);
        if (heart_rate == 0 && qrs_width == 0)
            $display("PASS test 7: reset clears state");
        else begin
            $display("FAIL test 7: state not cleared after reset");
            fail_count++;
        end

        $display("-----------------------------");
        if (fail_count == 0)
            $display("ALL TESTS PASSED");
        else
            $display("%0d TEST(S) FAILED", fail_count);
        $display("-----------------------------");
        $finish;
    end

endmodule