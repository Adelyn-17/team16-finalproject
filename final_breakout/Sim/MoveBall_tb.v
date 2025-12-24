`timescale 1ns / 1ps

module MoveBall_tb;

    parameter VGA_CLK_PERIOD = 40;
   
    parameter H_VALID = 640;
    parameter V_VALID = 480;
    parameter BALL_RADIUS = 5;
    parameter RACKET_WIDTH = 80;

    parameter S_IDLE = 2'b00;
    parameter S_PLAY = 2'b01;
    parameter S_WIN  = 2'b10;
    parameter S_END  = 2'b11;
  
    parameter FRAC_BITS = 7;
    parameter FRAC_ONE = 1 << FRAC_BITS;
    parameter BALL_MOVE_DIV = 5000;

    reg vga_clk;
    reg sys_rst_n;

    reg [9:0] pix_x;
    reg [9:0] pix_y;
    reg left;
    reg right;
    reg [49:0] brick_collision;
    reg [1:0] game_state;
    reg game_reset;

    wire [15:0] pix_data;
    wire [9:0] ball_x;
    wire [9:0] ball_y;
    wire [9:0] racket_x;
    wire [9:0] racket_y;
    wire lose_sig;

    MoveBall_logic DUT (
        .vga_clk(vga_clk),
        .sys_rst_n(sys_rst_n),
        .pix_x(pix_x),
        .pix_y(pix_y),
        .left(left),
        .right(right),
        .brick_collision(brick_collision),
        .game_state(game_state),
        .game_reset(game_reset),
        
        .pix_data(pix_data),
        .ball_x(ball_x),
        .ball_y(ball_y),
        .racket_x(racket_x),
        .racket_y(racket_y),
        .lose_sig(lose_sig)
    );

    initial begin
        vga_clk = 0;
        forever #(VGA_CLK_PERIOD / 2) vga_clk = ~vga_clk;
    end
    
    initial begin
        sys_rst_n = 1'b0;
        game_state = S_IDLE;
        game_reset = 1'b0;
        left = 1'b1;
        right = 1'b1;
        brick_collision = 50'd0;
    
        pix_x = H_VALID / 2;
        pix_y = V_VALID / 2;
        
        $display("-----------------------------------------------------");
        $display("--- MoveBall_logic Testbench 开始仿真 ---");
        $dumpfile("MoveBall_logic.vcd");
        $dumpvars(0, MoveBall_tb); 

        # (VGA_CLK_PERIOD * 5);
        sys_rst_n = 1'b1;
        $display("@%0t: 释放系统复位. 进入 IDLE 状态.", $time);
   
        # (VGA_CLK_PERIOD * 5);
        if (ball_x == 10'd320 && racket_x == 10'd280 && lose_sig == 1'b0) begin
            $display("@%0t: 成功: IDLE 状态初始化正确. 球:(%0d) 拍子:(%0d).", $time, ball_x, racket_x);
        end else begin
            $display("@%0t: 失败: IDLE 状态初始化错误. 球:(%0d) 拍子:(%0d).", $time, ball_x, racket_x);
        end
   
        game_state = S_PLAY;
        $display("@%0t: 进入 PLAY 状态，开始测试挡板移动.", $time);

        left = 1'b0;
        # (VGA_CLK_PERIOD * 3500 * 2);
        
        if (racket_x == (RACKET_WIDTH/2)) begin
            $display("@%0t: 成功: 挡板撞击左墙边界. 最终X: %0d.", $time, racket_x);
        end else begin
            $display("@%0t: 失败: 挡板左移后未撞击边界或位置错误. 最终X: %0d.", $time, racket_x);
        end
        
        left = 1'b1;
   
        right = 1'b0;
        # (VGA_CLK_PERIOD * 3500 * 4);
        
        if (racket_x == (H_VALID - RACKET_WIDTH/2)) begin
            $display("@%0t: 成功: 挡板撞击右墙边界. 最终X: %0d.", $time, racket_x);
        end else begin
            $display("@%0t: 失败: 挡板右移后未撞击边界或位置错误. 最终X: %0d.", $time, racket_x);
        end
        
        right = 1'b1;

        $display("@%0t: 准备测试顶部墙壁反弹.", $time);
        force DUT.ball_y_fp = (BALL_RADIUS + 1) << FRAC_BITS; 
        force DUT.ball_dy = 1'b1; 
        
        # (VGA_CLK_PERIOD * BALL_MOVE_DIV * 2);

        if (DUT.ball_dy == 1'b0) begin
            $display("@%0t: 成功: 顶部墙壁碰撞，ball_dy 成功翻转 (1->0).", $time);
        end else begin
            $display("@%0t: 失败: 顶部墙壁碰撞，ball_dy 未翻转. 当前 ball_dy: %0d.", $time, DUT.ball_dy);
        end

        release DUT.ball_y_fp; 
        release DUT.ball_dy; 

        $display("@%0t: 准备测试砖块碰撞反弹.", $time);

        force DUT.ball_dy = 1'b0; 
        
        @(posedge vga_clk);
        brick_collision = 50'd1;
        
        # (VGA_CLK_PERIOD * BALL_MOVE_DIV * 2);
     
        if (DUT.ball_dy == 1'b1) begin
            $display("@%0t: 成功: 砖块碰撞触发，ball_dy 成功翻转 (0->1).", $time);
        end else begin
            $display("@%0t: 失败: 砖块碰撞触发，ball_dy 未翻转. 当前 ball_dy: %0d.", $time, DUT.ball_dy);
        end

        brick_collision = 50'd0;
        release DUT.ball_dy;
  
        $display("@%0t: 准备测试失败条件 (球低于底部).", $time);
     
        force DUT.ball_y_fp = (V_VALID - 1) << FRAC_BITS; 
        force DUT.ball_dy = 1'b0; 
        
        # (VGA_CLK_PERIOD * BALL_MOVE_DIV * 2);
        
        if (lose_sig == 1'b1) begin
            $display("@%0t: 成功: 球移出底部，lose_sig 置位.", $time);
        end else begin
            $display("@%0t: 失败: 球移出底部，但 lose_sig 未置位. 当前 ball_y: %0d.", $time, ball_y);
        end

        release DUT.ball_y_fp;
        release DUT.ball_dy;

        # (VGA_CLK_PERIOD * 20); 
        $display("-----------------------------------------------------");
        $display("--- MoveBall_logic Testbench 仿真结束 ---");
        $display("-----------------------------------------------------");
        $finish; 
    end


endmodule
