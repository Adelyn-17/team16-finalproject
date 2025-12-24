`timescale 1ns/1ps

module breakout_fsm_tb;

    parameter CLK_PERIOD = 20; 
    parameter IDLE_TIME  = 20000000; 

    reg sys_clk;
    reg sys_rst_n;
    reg start_key;
    reg lose_sig;
    reg win_sig;

    wire [1:0] game_state;
    wire game_reset;

    localparam S_IDLE = 2'b00;
    localparam S_PLAY = 2'b01;
    localparam S_WIN  = 2'b10;
    localparam S_END  = 2'b11;

    breakout_fsm DUT (
        .sys_clk(sys_clk),
        .sys_rst_n(sys_rst_n),
        .start_key(start_key),
        .lose_sig(lose_sig),
        .win_sig(win_sig),
        .game_state(game_state),
        .game_reset(game_reset)
    );

    initial begin
        sys_clk = 0;
        forever #(CLK_PERIOD / 2) sys_clk = ~sys_clk;
    end

    initial begin
        sys_rst_n = 1'b0;
        start_key = 1'b0;
        lose_sig  = 1'b0;
        win_sig   = 1'b0;

        $display("-------------------------------------------");
        $display("--- 弹球游戏FSM Testbench 开始仿真 ---");
        $display("--- 时钟周期: %0dns (50MHz) ---", CLK_PERIOD);
        $display("--- 延迟时间: %0dns (20ms) ---", IDLE_TIME);
        $display("-------------------------------------------");
        $dumpfile("breakout_fsm.vcd");
        $dumpvars(0, breakout_fsm_tb);

        @(posedge sys_clk);
        #100;
        sys_rst_n = 1'b1;
        $display("@%0t: 复位释放. 当前状态: %b (S_IDLE)", $time, game_state);

        $display("@%0t: 正在等待 IDLE 延迟 (%0dns) 完成...", $time, IDLE_TIME);
        #(IDLE_TIME + CLK_PERIOD * 2); 

        start_key = 1'b1;
        @(posedge sys_clk);
        #1;
        $display("@%0t: 触发 START_KEY 信号.", $time);
        
        @(negedge sys_clk);
        start_key = 1'b0;
        @(posedge sys_clk);
        
        #10;
        if (game_state == S_PLAY && game_reset == 1'b1) begin
            $display("-> 成功: 状态从 IDLE 跳转到 PLAY. game_reset 触发.");
        end else begin
            $display("-> 失败: 状态未跳转到 PLAY.");
        end

        # (CLK_PERIOD * 10);

        lose_sig = 1'b1;
        @(posedge sys_clk);
        #1;
        $display("@%0t: 触发 LOSE_SIG (游戏失败).", $time);
        
        @(negedge sys_clk);
        lose_sig = 1'b0;
        @(posedge sys_clk);
        
        #10;
        if (game_state == S_END) begin
            $display("-> 成功: 状态从 PLAY 跳转到 END (游戏结束).");
        end else begin
            $display("-> 失败: 状态未跳转到 END.");
        end

        # (CLK_PERIOD * 10);
  
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
 
        $display("@%0t: 正在等待第二次 IDLE 延迟 (%0dns) 完成...", $time, IDLE_TIME);
        #(IDLE_TIME + CLK_PERIOD * 2); 

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

        # (CLK_PERIOD * 10);

        win_sig = 1'b1;
        @(posedge sys_clk);
        #1;
        $display("@%0t: 触发 WIN_SIG (游戏胜利).", $time);
        
        @(negedge sys_clk);
        win_sig = 1'b0;
        @(posedge sys_clk);
        
        #10;
        if (game_state == S_WIN) begin
            $display("-> 成功: 状态从 PLAY 跳转到 WIN (游戏胜利).");
        end else begin
            $display("-> 失败: 状态未跳转到 WIN.");
        end

        # (CLK_PERIOD * 10);
   
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
        
        $finish;
    end


endmodule
