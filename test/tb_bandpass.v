`default_nettype none
`timescale 1ns / 1ps

module tb_bandpass;

    reg clk;
    reg rst_n;
    reg sample_valid;
    reg signed [15:0] x_in;
    wire signed [15:0] y_out;

    bandpass_filter dut (
        .clk(clk),
        .rst_n(rst_n),
        .sample_valid(sample_valid),
        .x_in(x_in),
        .y_out(y_out)
    );

    integer k;
    integer fail_count;
    initial begin
        clk = 0;
        fail_count = 0;
    end

    always begin
        #5 clk = ~clk;
    end

    task automatic send_sample(input signed [15:0] x);
    begin
        @(posedge clk);
        #1
        x_in = x;
        sample_valid = 1'b1;
        @(posedge clk);
        #1
        sample_valid = 1'b0;
        @(posedge clk);
    end
    endtask

    initial begin
        $dumpfile("tb_bandpass_filter.vcd");
        $dumpvars(0, tb_bandpass);

        rst_n = 0;
        sample_valid = 0;
        x_in = 0;

        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(2) @(posedge clk);

        // Test 1: All zeros, output stays 0
        for (k = 0; k < 50; k = k + 1)
            send_sample(16'sd0);
        if (y_out !== 16'sd0) begin
            $display("FAIL test 1: zero input gave nonzero output %0d", $signed(y_out));
            fail_count++;
        end else begin
            $display("PASS test 1: zero input gives zero output, %0d", $signed(y_out));
        end

        // Test 2: DC constant input highpass should reject it
        // After enough samples, output should decay toward 0
        for (k = 0; k < 100; k = k + 1)
            send_sample(16'sd10000);
        if ($signed(y_out) > 500 || $signed(y_out) < -500) begin
            $display("FAIL test 2: DC not rejected, y_out=%0d", $signed(y_out));
            fail_count++;
        end else begin
            $display("PASS test 2: DC input rejected (y_out=%0d)", $signed(y_out));
        end

        // Test 3: Impulse, output should eventually return to 0
        send_sample(16'sd32767);
        for (k = 0; k < 80; k = k + 1)
            send_sample(16'sd0);
        if ($signed(y_out) > 100 || $signed(y_out) < -100) begin
            $display("FAIL test 3: impulse response did not settle, y_out=%0d", $signed(y_out));
            fail_count++;
        end else begin
            $display("PASS test 3: impulse response settled to 0");
        end

        // Test 4: Reset works
        rst_n = 0;
        repeat(3) @(posedge clk);
        rst_n = 1;
        repeat(2) @(posedge clk);
        if (y_out !== 16'sd0) begin
            $display("FAIL test 4: reset did not clear output");
            fail_count++;
        end else begin
            $display("PASS test 4: reset clears state");
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