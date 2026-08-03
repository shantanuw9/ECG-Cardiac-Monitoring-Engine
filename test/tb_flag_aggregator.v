`default_nettype none
`timescale 1ns / 1ps

module tb_flag_aggregator;

    reg clk;
    reg rst_n;
    reg beat_detected;
    reg [15:0] qrs_width;
    reg [15:0] heart_rate;
    reg [15:0] hrv_sdnn;
    reg [15:0] beat_amplitude;
    reg [15:0] rr_interval;
    wire wide_qrs;
    wire tachy_flag;
    wire brady_flag;
    wire low_hrv;
    wire anomaly_flag;

    flag_aggregator dut (
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

    integer fail_count;
    initial begin
        clk = 0;
        fail_count = 0;
    end
    always begin
        #5 clk = ~clk;
    end

    task automatic check_flags(input exp_width, input exp_tachy, input exp_brady, input exp_hrv, input exp_anomaly, input integer test_id);
    begin
        if(wide_qrs !== exp_width || tachy_flag !== exp_tachy || brady_flag !== exp_brady || low_hrv !== exp_hrv || anomaly_flag !== exp_anomaly) begin
            $display("FAIL test %0d: got wide=%b tachy=%b brady=%b hrv=%b anomaly=%b", test_id, wide_qrs, tachy_flag, brady_flag, low_hrv, anomaly_flag);
            fail_count++;
        end else begin
            $display("PASS test %0d", test_id);
        end
    end
    endtask

    task automatic send_beat(input [15:0] rr, input [15:0] qrsw, input [15:0] hrv, input [15:0] hr);
    begin
        @(posedge clk);
        rr_interval <= rr;
        qrs_width <= qrsw;
        hrv_sdnn <= hrv;
        heart_rate <= hr;
        beat_amplitude <= 16'd500;
        beat_detected <= 1'b1;
        @(posedge clk);
        beat_detected <= 1'b0;
        @(posedge clk);
    end
    endtask

    initial begin
        $dumpfile("tb_flag_aggregator.vcd");
        $dumpvars(0, tb_flag_aggregator);

        rst_n = 0;
        beat_detected = 0;
        rr_interval = 0;
        qrs_width = 0;
        hrv_sdnn = 0;
        heart_rate = 0;
        beat_amplitude = 0;

        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(2) @(posedge clk);
        
        
        // Test 1: Normal sinus rhythm — no flags
        // rr=320 (HR~67), qrs_width=30 (<43), hrv=50 (>20)
        send_beat(16'd320, 16'd30, 16'd50, 16'd67);
        check_flags(0, 0, 0, 0, 0, 1);

        // Test 2: Tachycardia — rr < 216
        send_beat(16'd200, 16'd30, 16'd50, 16'd108);
        check_flags(0, 1, 0, 0, 1, 2);

        // Test 3: Bradycardia — rr > 360
        send_beat(16'd400, 16'd30, 16'd50, 16'd54);
        check_flags(0, 0, 1, 0, 0, 3);

        // Test 4: Wide QRS — qrs_width > 43
        send_beat(16'd320, 16'd50, 16'd50, 16'd67);
        check_flags(1, 0, 0, 0, 1, 4);

        // Test 5: Low HRV — hrv_sdnn < 20
        send_beat(16'd320, 16'd30, 16'd10, 16'd67);
        check_flags(0, 0, 0, 1, 1, 5);

        // Test 6: Multiple flags — tachy + wide QRS
        send_beat(16'd200, 16'd50, 16'd50, 16'd108);
        check_flags(1, 1, 0, 0, 1, 6);

        // Test 7: Reset clears flags
        rst_n = 0;
        repeat(3) @(posedge clk);
        rst_n = 1;
        repeat(2) @(posedge clk);
        if (wide_qrs || tachy_flag || brady_flag || low_hrv || anomaly_flag) begin
            $display("FAIL test 7: flags not cleared after reset");
            fail_count++;
        end else begin
            $display("PASS test 7");
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