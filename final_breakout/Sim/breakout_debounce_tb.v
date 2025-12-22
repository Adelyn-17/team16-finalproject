`timescale 1ns / 1ps

module breakout_debounce_tb;

    // ===================================
    // 1. 定义信号与时钟参数
    // ===================================
    parameter CLK_PERIOD = 20; // 50MHz时钟周期 = 20ns
    parameter DEBOUNCE_DELAY = 200000; // 200 us (10000 cycles * 20ns)
    
    // Testbench 内部信号
    reg clk;
    reg reset; // 对应 DUT 中的 reset (低电平有效)
    reg left_in;
    reg right_in;
    reg start_in;

    // DUT 输出信号
    wire left_out;
    wire right_out;
    wire start_out;
    
    // 仿真时长参数
    parameter SIMULATION_TIME = 1000000; // 1 ms

    // ===================================
    // 2. 实例化 Debounce 模块 (DUT)
    // ===================================
    // 注意：默认 DEBOUNCE_TIME=10000
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

    // ===================================
    // 3. 时钟生成
    // ===================================
    initial begin
        clk = 0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    // ===================================
    // 4. 激励生成 (Test Vector)
    // ===================================
    initial begin
        // 初始化所有信号
        reset = 0; // 保持复位
        left_in = 0;
        right_in = 0;
        start_in = 0;

        $display("-------------------------------------------");
        $display("--- Debounce Testbench 开始仿真 ---");
        $display("--- 消抖时间: %0d ns (%0d us) ---", DEBOUNCE_DELAY, DEBOUNCE_DELAY/1000);
        $display("-------------------------------------------");
        $dumpfile("breakout_debounce.vcd");
        $dumpvars(0, breakout_debounce_tb); 

        // ----------------------------------------------------
        // 1. 系统复位
        // ----------------------------------------------------
        @(posedge clk);
        #100;
        reset = 1; // 释放复位 (高电平有效)
        $display("@%0t: 复位释放.", $time);
        
        // ----------------------------------------------------
        // 2. 左按钮：稳定输入验证 (保持稳定高电平)
        // ----------------------------------------------------
        # (CLK_PERIOD * 5); 
        left_in = 1;
        $display("@%0t: 触发 LEFT_IN 为 1.", $time);
        
        // 等待消抖时间
        # (DEBOUNCE_DELAY + CLK_PERIOD * 2);
        if (left_out == 1) begin
            $display("-> 成功: LEFT_OUT 在 %0d us 后跟随输入变为 1.", DEBOUNCE_DELAY/1000);
        end else begin
            $display("-> 失败: LEFT_OUT 未在预期时间跟随输入.");
        end

        // ----------------------------------------------------
        // 3. 右按钮：完美按键验证 (稳定低电平，然后稳定高电平)
        // ----------------------------------------------------
        # (DEBOUNCE_DELAY * 2); // 保持一段时间
        right_in = 1;
        $display("@%0t: 触发 RIGHT_IN 为 1 (完美按键).", $time);
        
        // 等待消抖时间
        # (DEBOUNCE_DELAY + CLK_PERIOD * 2);
        if (right_out == 1) begin
            $display("-> 成功: RIGHT_OUT 在 %0d us 后跟随输入变为 1.", DEBOUNCE_DELAY/1000);
        end else begin
            $display("-> 失败: RIGHT_OUT 未在预期时间跟随输入.");
        end
        
        // ----------------------------------------------------
        // 4. 开始按钮：抖动验证 (最关键的测试)
        // ----------------------------------------------------
        # (DEBOUNCE_DELAY * 2); // 保持一段时间
        
        // 4.1 模拟按下，并开始抖动 (持续 100 us)
        start_in = 1;
        $display("@%0t: 触发 START_IN (开始抖动).", $time);
        # 10000; // 10 us 后抖动
        
        // 模拟多次跳变，总时长小于 200 us
        repeat(5) begin
            start_in = ~start_in;
            # 15000; // 15 us
        end 
        
        // 在抖动过程中，start_out 不应该改变
        # (DEBOUNCE_DELAY / 4); 
        if (start_out == 0) begin
            $display("-> 成功: START_OUT 在抖动期间保持稳定输出 0.");
        end else begin
            $display("-> 失败: START_OUT 在抖动期间错误地改变了输出.");
        end

        // 4.2 抖动停止，保持稳定高电平
        start_in = 1; // 保持稳定高电平
        $display("@%0t: 抖动停止，输入保持稳定 1.", $time);
        
        // 再次等待完整的消抖时间
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