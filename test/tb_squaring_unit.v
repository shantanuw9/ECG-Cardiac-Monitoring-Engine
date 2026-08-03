`default_nettype none
`timescale 1ns / 1ps

module tb_squaring_unit;

    reg clk;
    reg rst_n;
    reg sample_valid;
    reg signed [15:0] x_in;
    wire [15:0] y_out;

    squaring_unit dut (
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

    task automatic check_square(input [15:0] exp_y, input integer test_id);
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

    initial begin
        $dumpfile("tb_squaring_unit.vcd");
        $dumpvars(0, tb_squaring_unit);

        rst_n = 0;
        

        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(2) @(posedge clk);
        
        
        // Test 1: x = 0, y = 0
        send_signal(16'd0);
        check_square(16'd0, 1);

        // Test 2: x = 100
        send_signal(16'd100);
        check_square(16'd0, 2);

        // Test 3: x = 1000
        send_signal(16'd1000);
        check_square(16'd30, 3);

        // Test 4: x = 32767
        send_signal(16'd32767);
        check_square(16'd32766, 4);

        // Test 5: x = -1
        send_signal(16'hFFFF);
        check_square(16'd0, 5);

        // Test 6: x = -32767
        send_signal(16'h8001);
        check_square(16'd32766, 6);

        $display("-----------------------------");
        if (fail_count == 0)
            $display("ALL TESTS PASSED");
        else
            $display("%0d TEST(S) FAILED", fail_count);
        $display("-----------------------------");
        $finish;


    end

endmodule