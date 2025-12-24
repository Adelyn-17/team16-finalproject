`timescale 1ns / 1ps

module breakout_debounce_tb;

    parameter CLK_PERIOD = 20;
    parameter DEBOUNCE_DELAY = 200000; // 200 us (10000 cycles * 20ns)

    reg clk;
    reg reset;
    reg left_in;
    reg right_in;
    reg start_in;

    wire left_out;
    wire right_out;
    wire start_out;

    parameter SIMULATION_TIME = 1000000;
    breakout_debounce DUT (
        .clk(clk),
        .reset(reset),
        .left_in(left_in),
        .right_in(right_in),
        .start_in(start_in),
        .left_out(left_out),
        .right_out(right_out),
        .start_out(start_out)
    );

    initial begin
        clk = 0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    initial begin
        reset = 0;
        left_in = 0;
        right_in = 0;
        start_in = 0;

        $display("-------------------------------------------");
        $display("--- Debounce Testbench 开始仿真 ---");
        $display("--- 消抖时间: %0d ns (%0d us) ---", DEBOUNCE_DELAY, DEBOUNCE_DELAY/1000);
        $display("-------------------------------------------");
        $dumpfile("breakout_debounce.vcd");
        $dumpvars(0, breakout_debounce_tb); 

        @(posedge clk);
        #100;
        reset = 1;
        $display("@%0t: 复位释放.", $time);

        # (CLK_PERIOD * 5); 
        left_in = 1;
        $display("@%0t: 触发 LEFT_IN 为 1.", $time);

        # (DEBOUNCE_DELAY + CLK_PERIOD * 2);
        if (left_out == 1) begin
            $display("-> 成功: LEFT_OUT 在 %0d us 后跟随输入变为 1.", DEBOUNCE_DELAY/1000);
        end else begin
            $display("-> 失败: LEFT_OUT 未在预期时间跟随输入.");
        end

        # (DEBOUNCE_DELAY * 2);
        right_in = 1;
        $display("@%0t: 触发 RIGHT_IN 为 1 (完美按键).", $time);

        # (DEBOUNCE_DELAY + CLK_PERIOD * 2);
        if (right_out == 1) begin
            $display("-> 成功: RIGHT_OUT 在 %0d us 后跟随输入变为 1.", DEBOUNCE_DELAY/1000);
        end else begin
            $display("-> 失败: RIGHT_OUT 未在预期时间跟随输入.");
        end
 
        # (DEBOUNCE_DELAY * 2);
  
        start_in = 1;
        $display("@%0t: 触发 START_IN (开始抖动).", $time);
        # 10000;

        repeat(5) begin
            start_in = ~start_in;
            # 15000;
        end 

        # (DEBOUNCE_DELAY / 4); 
        if (start_out == 0) begin
            $display("-> 成功: START_OUT 在抖动期间保持稳定输出 0.");
        end else begin
            $display("-> 失败: START_OUT 在抖动期间错误地改变了输出.");
        end

        start_in = 1;
        $display("@%0t: 抖动停止，输入保持稳定 1.", $time);

        # (DEBOUNCE_DELAY + CLK_PERIOD * 2);
        
        if (start_out == 1) begin
            $display("-> 成功: START_OUT 在稳定后 %0d us 正确变为 1.", DEBOUNCE_DELAY/1000);
        end else begin
            $display("-> 失败: START_OUT 未在稳定后跟随输入.");
        end
        
        # (DEBOUNCE_DELAY * 2);

        $display("-------------------------------------------");
        $display("--- Debounce Testbench 仿真结束 ---");
        $display("-------------------------------------------");
        
        $finish; 
    end


endmodule
