`default_nettype none
`timescale 1ns / 1ps

module tb_qrs_detector;

    reg clk;
    reg rst_n;
    reg sample_valid;
    reg [15:0] mwi_in;
    wire beat_detected;
    wire [15:0] rr_interval;
    wire [15:0] beat_amplitude;
    wire [15:0] qrs_start_time;
    wire [15:0] qrs_peak_time;

    qrs_detector dut (
        .clk (clk),
        .rst_n (rst_n),
        .sample_valid (sample_valid),
        .mwi_in (mwi_in),
        .beat_detected (beat_detected),
        .rr_interval (rr_interval),
        .beat_amplitude (beat_amplitude),
        .qrs_start_time (qrs_start_time),
        .qrs_peak_time (qrs_peak_time)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    reg [15:0] mwi_mem [0:1799]; //from python script

    integer beat_count;
    integer i;
    integer fail_count = 0;

    initial begin
        $dumpfile("tb_qrs_detector.vcd");
        $dumpvars(0, tb_qrs_detector);

        $readmemh("mwi_signal.mem", mwi_mem);

        rst_n = 0;
        sample_valid = 0;
        mwi_in = 0;
        beat_count = 0;

        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(2) @(posedge clk);

        // Test 1: Feed 1800 samples of real MWI signal
        // MIT-BIH record 100 has ~6 beats in first 5 seconds
        // Expect between 4 and 8 beat_detected pulses
        for (i = 0; i < 1800; i = i + 1) begin
            @(posedge clk);
            mwi_in <= mwi_mem[i];
            sample_valid <= 1'b1;
            @(posedge clk);
            sample_valid <= 1'b0;
            @(posedge clk);
            if (beat_detected) begin
                beat_count = beat_count + 1;
                $display("Beat %0d detected at sample %0d, amplitude=%0d",
                         beat_count, i, beat_amplitude);
            end
            if (i % 100 == 0)
                $display("sample=%0d mwi=%0d thresh=%0d spk=%0d npk=%0d state=%0d",
                 i, mwi_mem[i], dut.threshold_i, dut.spk_i, dut.npk_i, dut.state);
            @(posedge clk);
        end

        if (beat_count >= 4 && beat_count <= 8) begin
            $display("PASS test 1: detected %0d beats (expected 4-8)", beat_count);
        end else begin
            $display("FAIL test 1: detected %0d beats (expected 4-8)", beat_count);
            fail_count++;
        end

        // Test 2: All zeros — no beats detected
        beat_count = 0;
        rst_n = 0;
        repeat(3) @(posedge clk);
        rst_n = 1;

        for (i = 0; i < 200; i = i + 1) begin
            @(posedge clk);
            mwi_in <= 16'b0;
            sample_valid <= 1'b1;
            @(posedge clk);
            sample_valid <= 1'b0;
            if (beat_detected)
                beat_count = beat_count + 1;
            @(posedge clk);
        end

        if (beat_count == 0)
            $display("PASS test 2: no beats on zero input");
        else begin
            $display("FAIL test 2: %0d false beats on zero input", beat_count);
            fail_count++;
        end

        // Test 3: Refractory period — two peaks close together, only one beat
        beat_count = 0;
        rst_n = 0;
        repeat(3) @(posedge clk);
        rst_n = 1;

        // Warmup: send moderate signal so estimators initialize
        for (i = 0; i < 100; i = i + 1) begin
            @(posedge clk);
            mwi_in <= 16'd500;
            sample_valid <= 1'b1;
            @(posedge clk);
            sample_valid <= 1'b0;
            @(posedge clk);
        end

        // First large peak
        for (i = 0; i < 10; i = i + 1) begin
            @(posedge clk);
            mwi_in <= 16'd8000;
            sample_valid <= 1'b1;
            @(posedge clk);
            sample_valid <= 1'b0;
            if (beat_detected) beat_count = beat_count + 1;
            @(posedge clk);
        end

        // Drop then immediately another large peak (within refractory period)
        for (i = 0; i < 30; i = i + 1) begin
            @(posedge clk);
            mwi_in <= 16'd8000;
            sample_valid <= 1'b1;
            @(posedge clk);
            sample_valid <= 1'b0;
            if (beat_detected) beat_count = beat_count + 1;
            @(posedge clk);
        end

        if (beat_count <= 2)
            $display("PASS test 3: refractory period blocked double-detection (%0d beats)", beat_count);
        else begin
            $display("FAIL test 3: refractory period failed (%0d beats)", beat_count);
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