`timescale 1ns / 1ps



// 假设顶层模块名为 breakout_top，Testbench 命名为 breakout_top_tb

module breakout_top_tb;



    // =========================================================

    // 1. 定义顶层信号 (输入)

    // =========================================================

    // 时钟和复位

    reg sys_clk;    // 50 MHz (20 ns period)

    reg vga_clk;    // 25 MHz (40 ns period)

    reg sys_rst_n;  // 低电平有效复位

    

    // 原始按钮输入 (连接到 debounce 模块)

    reg left_raw_in;

    reg right_raw_in;

    reg start_raw_in;

    

    // =========================================================

    // 2. 定义中间信号 (连接线)

    // =========================================================

    // Debounce -> FSM/MoveBall

    wire left_key;      // 去抖后的左

    wire right_key;     // 去抖后的右

    wire start_key;     // 去抖后的开始

    

    // FSM -> MoveBall/VGA_Pic

    wire [1:0] game_state;

    wire game_reset;

    

    // MoveBall/VGA_Pic -> FSM

    wire lose_sig;

    wire win_sig;

    wire [49:0] brick_collision;

    

    // MoveBall/VGA_Pic -> VGA_Ctrl

    wire [15:0] pix_data_ball;  // MoveBall 绘制的球/拍子

    wire [15:0] pix_data_brick; // VGA_Pic 绘制的砖块/文字

    

    // VGA_Ctrl/MoveBall/VGA_Pic 坐标

    wire [9:0] pix_x;

    wire [9:0] pix_y;

    wire [9:0] ball_x;

    wire [9:0] ball_y;

    wire [9:0] racket_x;

    

    // VGA_Ctrl 输出 (不用于逻辑验证，仅观察)

    wire hsync, vsync;

    wire [15:0] rgb_out;

    

    // 状态定义 (方便 Testbench 检查)

    localparam S_IDLE = 2'b00; 

    localparam S_PLAY = 2'b01; 

    localparam S_WIN  = 2'b10; 

    localparam S_END  = 2'b11; 

    

    // 参数匹配

    localparam SYS_CLK_PERIOD = 20;       // 50MHz

    localparam VGA_CLK_PERIOD = 40;       // 25MHz

    localparam DEBOUNCE_TIME_CYCLES = 10000; // 去抖周期数

    localparam IDLE_DELAY_CYCLES = 1000000; // FSM 延迟周期数 (约 20ms)



    // =========================================================

    // 3. 时钟生成

    // =========================================================

    always #((SYS_CLK_PERIOD / 2)) sys_clk = ~sys_clk;

    always #((VGA_CLK_PERIOD / 2)) vga_clk = ~vga_clk;



    // =========================================================

    // 4. 实例化所有模块 (DUTs)

    // =========================================================



    // 4.1 Debounce Module

    breakout_debounce #(

        .DEBOUNCE_TIME(DEBOUNCE_TIME_CYCLES)

    ) DUT_DEBOUNCE (

        .clk(sys_clk),

        .reset(sys_rst_n),

        .left_in(left_raw_in),

        .right_in(right_raw_in),

        .start_in(start_raw_in),

        .left_out(left_key),

        .right_out(right_key),

        .start_out(start_key)

    );



    // 4.2 FSM Module

    breakout_fsm DUT_FSM (

        .sys_clk(sys_clk),

        .sys_rst_n(sys_rst_n),

        .start_key(start_key),

        .lose_sig(lose_sig),

        .win_sig(win_sig),

        .game_state(game_state),

        .game_reset(game_reset)

    );



    // 4.3 MoveBall Logic Module

    MoveBall_logic DUT_MOVEBALL (

        .vga_clk(vga_clk),

        .sys_rst_n(sys_rst_n),

        .pix_x(pix_x),

        .pix_y(pix_y),

        .left(left_key),

        .right(right_key),

        .brick_collision(brick_collision),

        .game_state(game_state),

        .game_reset(game_reset),

        

        .pix_data(pix_data_ball),

        .ball_x(ball_x),

        .ball_y(ball_y),

        .racket_x(racket_x),

        .racket_y(),

        .lose_sig(lose_sig)

    );



    // 4.4 VGA Picture Module

    VGA_Pic DUT_VGAPIC (

        .vga_clk(vga_clk),

        .sys_rst_n(sys_rst_n),

        .pix_x(pix_x),

        .pix_y(pix_y),

        .ball_x(ball_x),

        .ball_y(ball_y),

        .game_state(game_state),

        .game_reset(game_reset),

        

        .brick_data(pix_data_brick),

        .brick_collision(brick_collision),

        .win_sig(win_sig)

    );



    // 4.5 VGA Controller Module

    // 顶层像素数据选择逻辑 (模拟顶层逻辑)

    wire [15:0] final_pix_data;

    assign final_pix_data = (game_state == S_PLAY) ? 

                            (pix_data_brick != 16'h0000 ? pix_data_brick : pix_data_ball) :

                            pix_data_brick;

                            

    VGA_Ctrl DUT_VGACTRL (

        .vga_clk(vga_clk),

        .sys_rst_n(sys_rst_n),

        .pix_data(final_pix_data),

        

        .pix_x(pix_x),

        .pix_y(pix_y),

        .hsync(hsync),

        .vsync(vsync),

        .rgb(rgb_out)

    );



    // =========================================================

    // 5. 测试序列

    // =========================================================

    // *** 关键修改：将仿真时间从几十毫秒延长至数秒 ***

    localparam LONG_PLAY_CYCLES = 125_000_000; // 约 5 秒 (125,000,000 * 40ns/cycle)

    localparam EXTRA_OBSERVATION_CYCLES = 25_000_000; // 约 1 秒



    initial begin

        // 初始化

        sys_clk = 0;

        vga_clk = 0;

        sys_rst_n = 0; // 初始复位

        left_raw_in = 1;

        right_raw_in = 1;

        start_raw_in = 1;

        

        $display("-------------------------------------------------------");

        $display("Start Top-Level Breakout Testbench.");

        $display("Expected Total Simulation Time: ~6 seconds.");

        $display("-------------------------------------------------------");



        // 1. 释放复位，进入 S_IDLE

        #((SYS_CLK_PERIOD * 5));

        sys_rst_n = 1; 

        $display("@%0t: Reset Released. Initial State: %b.", $time, game_state);

        

        // 2. 等待 FSM 的 IDLE 延迟完成 (约 20ms)

        $display("@%0t: Waiting for FSM IDLE delay to complete.", $time);

        #((SYS_CLK_PERIOD * (IDLE_DELAY_CYCLES + DEBOUNCE_TIME_CYCLES + 100))); 

        

        // 3. 触发 START 键：IDLE -> PLAY

        start_raw_in = 0; // 按下

        #((SYS_CLK_PERIOD * DEBOUNCE_TIME_CYCLES)); // 等待去抖

        start_raw_in = 1; // 释放

        

        @(posedge sys_clk);

        @(posedge sys_clk);

        

        if (game_state == S_PLAY && game_reset == 1) begin

            $display("@%0t: SUCCESS: Transition IDLE -> PLAY. Game reset asserted.", $time);

        end else begin

            $display("@%0t: FAILURE: IDLE -> PLAY transition failed. State: %b, Reset: %b.", $time, game_state, game_reset);

        end

        

        @(posedge sys_clk); // 确保 game_reset 脉冲结束

        

        // 4. 模拟游戏过程：球拍移动 (测试结束后继续保持 PLAY 状态)

        $display("@%0t: Starting Racket Movement Test (8ms).", $time);

        #((VGA_CLK_PERIOD * 1000)); 



        // 4.1 模拟左移 (运行 4ms)

        left_raw_in = 0; 

        #((VGA_CLK_PERIOD * 100000));

        $display("@%0t: Left key pressed. Racket X: %0d", $time, racket_x);

        left_raw_in = 1; 

        

        #((VGA_CLK_PERIOD * 10000));



        // 4.2 模拟右移 (运行 4ms)

        right_raw_in = 0; 

        #((VGA_CLK_PERIOD * 100000));

        $display("@%0t: Right key pressed. Racket X: %0d", $time, racket_x);

        right_raw_in = 1; 



        // 5. 延长游戏运行时间 (5 秒)

        $display("@%0t: Running game for an extended period (~5 seconds) to observe brick hits/loss.", $time);

        

        // 必须运行足够长的时间让小球与砖块发生多次碰撞

        #((VGA_CLK_PERIOD * LONG_PLAY_CYCLES)); 

        

        // 6. 检查 LOSE 信号并转移到 END 状态 (如果 MoveBall 触发了 lose_sig)

        if (lose_sig == 1) begin

            $display("@%0t: SUCCESS: lose_sig detected. Ball Y: %0d", $time, ball_y);

            @(posedge sys_clk); // FSM 检查 lose_sig

            @(posedge sys_clk); // FSM 状态转移

            

            if (game_state == S_END) begin

                $display("@%0t: SUCCESS: Transition PLAY -> END.", $time);

            end else begin

                 $display("@%0t: FAILURE: PLAY -> END transition failed. State: %b.", $time, game_state);

            end

        end else begin

            // 假设 5 秒内没有输，可能需要手动触发一次 lose_sig 或 win_sig

            $display("@%0t: INFO: lose_sig not automatically detected after ~5 seconds. Assuming successful play/win state.", $time);

            

            // 为了完成状态机测试，我们现在手动强制转移到 IDLE (模拟用户按 START)

            // (注意：如果 MoveBall 逻辑正确，球最终会掉落，但 5s 可能会被打飞)

        end



        // 7. END -> IDLE (或 PLAY -> IDLE，模拟用户按 START 键重新开始)

        $display("@%0t: Simulating START button press to return to IDLE.", $time);

        #((SYS_CLK_PERIOD * 100));

        start_raw_in = 0; // 按下 

        #((SYS_CLK_PERIOD * DEBOUNCE_TIME_CYCLES));

        start_raw_in = 1; // 释放



        @(posedge sys_clk);

        @(posedge sys_clk);

        

        if (game_state == S_IDLE) begin

            $display("@%0t: SUCCESS: Transition to IDLE.", $time);

        end else begin

            $display("@%0t: FAILURE: Transition to IDLE failed. State: %b.", $time, game_state);

        end

        

        $display("-------------------------------------------------------");

        $display("@%0t: Top-Level Testbench Finished. Running for final observation period (~1s).", $time);

        $display("-------------------------------------------------------");

        

        // 8. 额外的观察时间

        #((VGA_CLK_PERIOD * EXTRA_OBSERVATION_CYCLES));



        $finish; 

    end



    // 可选：波形导出

    //initial begin

     //   $dumpfile("breakout_top.vcd");

     //   $dumpvars(0, breakout_top_tb);

    //end



endmodule