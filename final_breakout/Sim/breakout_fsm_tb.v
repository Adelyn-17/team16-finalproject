`timescale 1ns/1ps

module breakout_fsm_tb;

    // ===================================
    // 1. 定义信号与时钟参数
    // ===================================
    parameter CLK_PERIOD = 20; // 50MHz时钟周期 = 20ns
    // IDLE 延迟时间 = 1,000,000 个周期 * 20ns/周期 = 20,000,000ns (20ms)
    parameter IDLE_TIME  = 20000000; 

    // Testbench 内部信号
    reg sys_clk;
    reg sys_rst_n;
    reg start_key;
    reg lose_sig;
    reg win_sig;

    // DUT 输出信号
    wire [1:0] game_state;
    wire game_reset;

    // 状态定义 (方便打印)
    localparam S_IDLE = 2'b00;
    localparam S_PLAY = 2'b01;
    localparam S_WIN  = 2'b10;
    localparam S_END  = 2'b11;

    // ===================================
    // 2. 实例化 FSM 模块 (DUT)
    // ===================================
    // 假设您的 FSM 文件名为 breakout_fsm.v
    breakout_fsm DUT (
        .sys_clk(sys_clk),
        .sys_rst_n(sys_rst_n),
        .start_key(start_key),
        .lose_sig(lose_sig),
        .win_sig(win_sig),
        .game_state(game_state),
        .game_reset(game_reset)
    );

    // ===================================
    // 3. 时钟生成
    // ===================================
    initial begin
        sys_clk = 0;
        forever #(CLK_PERIOD / 2) sys_clk = ~sys_clk;
    end

    // ===================================
    // 4. 激励生成 (Test Vector)
    // ===================================
    initial begin
        // 初始化所有信号
        sys_rst_n = 1'b0; // 保持复位
        start_key = 1'b0;
        lose_sig  = 1'b0;
        win_sig   = 1'b0;

        $display("-------------------------------------------");
        $display("--- 弹球游戏FSM Testbench 开始仿真 ---");
        $display("--- 时钟周期: %0dns (50MHz) ---", CLK_PERIOD);
        $display("--- 延迟时间: %0dns (20ms) ---", IDLE_TIME);
        $display("-------------------------------------------");
        $dumpfile("breakout_fsm.vcd"); // 设置波形文件
        $dumpvars(0, breakout_fsm_tb); // 倾倒所有变量

        // ----------------------------------------------------
        // 1. 系统复位
        // ----------------------------------------------------
        @(posedge sys_clk);
        #100;
        sys_rst_n = 1'b1; // 释放复位
        $display("@%0t: 复位释放. 当前状态: %b (S_IDLE)", $time, game_state);

        // ----------------------------------------------------
        // 2. IDLE 到 PLAY (游戏启动)
        // ----------------------------------------------------
        // 等待 FSM IDLE 延迟完成 (20ms)
        $display("@%0t: 正在等待 IDLE 延迟 (%0dns) 完成...", $time, IDLE_TIME);
        // 确保等待时间足够，略微超过 IDLE_TIME
        #(IDLE_TIME + CLK_PERIOD * 2); 

        // 触发 start_key (脉冲信号)
        start_key = 1'b1;
        @(posedge sys_clk);
        #1;
        $display("@%0t: 触发 START_KEY 信号.", $time);
        
        @(negedge sys_clk);
        start_key = 1'b0; // 释放按键
        @(posedge sys_clk);
        
        #10;
        if (game_state == S_PLAY && game_reset == 1'b1) begin
            $display("-> 成功: 状态从 IDLE 跳转到 PLAY. game_reset 触发.");
        end else begin
            $display("-> 失败: 状态未跳转到 PLAY.");
        end
        
        // ----------------------------------------------------
        // 3. PLAY 到 END (游戏失败)
        // ----------------------------------------------------
        # (CLK_PERIOD * 10); // 运行 10 个时钟周期
        
        // 触发 lose_sig
        lose_sig = 1'b1;
        @(posedge sys_clk);
        #1;
        $display("@%0t: 触发 LOSE_SIG (游戏失败).", $time);
        
        @(negedge sys_clk);
        lose_sig = 1'b0; // 释放信号
        @(posedge sys_clk);
        
        #10;
        if (game_state == S_END) begin
            $display("-> 成功: 状态从 PLAY 跳转到 END (游戏结束).");
        end else begin
            $display("-> 失败: 状态未跳转到 END.");
        end

        // ----------------------------------------------------
        // 4. END 到 IDLE (重新开始)
        // ----------------------------------------------------
        # (CLK_PERIOD * 10); // 停留在 END 画面
        
        // 触发 start_key 重新开始
        start_key = 1'b1;
        @(posedge sys_clk);
        #1;
        $display("@%0t: 触发 START_KEY (重新开始).", $time);
        
        @(negedge sys_clk);
        start_key = 1'b0;
        @(posedge sys_clk);
        
        #10;
        if (game_state == S_IDLE) begin
            $display("-> 成功: 状态从 END 跳转回 IDLE.");
        end else begin
            $display("-> 失败: 状态未跳转回 IDLE.");
        end
        
        // ----------------------------------------------------
        // 5. IDLE 到 PLAY (再次启动，验证第二次计时)
        // ----------------------------------------------------
        // FSM 回到了 IDLE，会再次开始 20ms 计时。
        $display("@%0t: 正在等待第二次 IDLE 延迟 (%0dns) 完成...", $time, IDLE_TIME);
        #(IDLE_TIME + CLK_PERIOD * 2); 

        // 再次触发 start_key
        start_key = 1'b1;
        @(posedge sys_clk);
        #1;
        $display("@%0t: 再次触发 START_KEY 信号.", $time);
        
        @(negedge sys_clk);
        start_key = 1'b0;
        @(posedge sys_clk);
        
        #10;
        if (game_state == S_PLAY) begin
            $display("-> 成功: 状态再次跳转到 PLAY.");
        end else begin
            $display("-> 失败: 状态未跳转到 PLAY.");
        end
        
        // ----------------------------------------------------
        // 6. PLAY 到 WIN (游戏胜利)
        // ----------------------------------------------------
        # (CLK_PERIOD * 10); // 运行 10 个时钟周期
        
        // 触发 win_sig
        win_sig = 1'b1;
        @(posedge sys_clk);
        #1;
        $display("@%0t: 触发 WIN_SIG (游戏胜利).", $time);
        
        @(negedge sys_clk);
        win_sig = 1'b0; // 释放信号
        @(posedge sys_clk);
        
        #10;
        if (game_state == S_WIN) begin
            $display("-> 成功: 状态从 PLAY 跳转到 WIN (游戏胜利).");
        end else begin
            $display("-> 失败: 状态未跳转到 WIN.");
        end

        // ----------------------------------------------------
        // 7. WIN 到 IDLE (重新开始)
        // ----------------------------------------------------
        # (CLK_PERIOD * 10); // 停留在 WIN 画面
        
        // 触发 start_key 重新开始
        start_key = 1'b1;
        @(posedge sys_clk);
        #1;
        $display("@%0t: 触发 START_KEY (重新开始).", $time);
        
        @(negedge sys_clk);
        start_key = 1'b0;
        @(posedge sys_clk);
        
        #10;
        if (game_state == S_IDLE) begin
            $display("-> 成功: 状态从 WIN 跳转回 IDLE.");
        end else begin
            $display("-> 失败: 状态未跳转回 IDLE.");
        end
        
        # (CLK_PERIOD * 10);
        $display("-------------------------------------------");
        $display("--- FSM Testbench 仿真结束 ---");
        $display("-------------------------------------------");
        
        $finish; // 结束仿真
    end

endmodule