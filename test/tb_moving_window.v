`default_nettype none
`timescale 1ns / 1ps

module tb_moving_window;

    reg clk;
    reg rst_n;
    reg sample_valid;
    reg signed [15:0] x_in;
    wire signed [15:0] y_out;

    moving_window dut (
        .clk(clk),
        .rst_n(rst_n),
        .sample_valid(sample_valid),
        .x_in(x_in),
        .y_out(y_out)
    );

    integer fail_count;
    initial begin
        clk = 0;
        fail_count = 0;
    end
    always begin
        #5 clk = ~clk;
    end

    task automatic check_val(input [15:0] exp_y, input integer test_id);
    begin
        if(exp_y !== y_out) begin
            $display("FAIL test %0d: got y_out=%b", test_id, y_out);
            fail_count++;
        end else begin
            $display("PASS test %0d", test_id);
        end
    end
    endtask

    task automatic send_signal(input [15:0] x);
    begin
        @(posedge clk);
        x_in <= x;
        sample_valid <= 1'b1;
        @(posedge clk);
        sample_valid <= 1'b0;
        @(posedge clk);
    end
    endtask

    integer k;

    initial begin
        $dumpfile("tb_moving_window.vcd");
        $dumpvars(0, tb_moving_window);

        rst_n = 0;
        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(2) @(posedge clk);
        

        // Test 1: Constant input
        for (k = 0; k < 54; k = k + 1)
            send_signal(16'd1000);
        check_val(16'd843, 1);

        // Reset window
        for (k = 0; k < 54; k = k + 1)
            send_signal(16'd0);

        // Test 2: All zeros — output stays 0
        for (k = 0; k < 10; k = k + 1)
            send_signal(16'd0);
        check_val(16'd0, 2);

        // Test 3: Impulse then zeros — output returns to 0 after 5 samples
        send_signal(16'd32767);
        for (k = 0; k < 54; k = k + 1)
            send_signal(16'd0);
        check_val(16'd0, 3);

        // Test 4: Known single-sample check

        // Test 5: Reset clears state
        rst_n = 0;
        repeat(3) @(posedge clk);
        rst_n = 1;
        repeat(2) @(posedge clk);
        check_val(16'd0, 5);


        $display("-----------------------------");
        if (fail_count == 0)
            $display("ALL TESTS PASSED");
        else
            $display("%0d TEST(S) FAILED", fail_count);
        $display("-----------------------------");
        $finish;


    end

endmodule