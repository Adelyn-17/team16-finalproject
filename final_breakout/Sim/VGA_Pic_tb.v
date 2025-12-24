`timescale 1ns / 1ps

module VGA_Pic_tb;

    parameter VGA_CLK_PERIOD = 40;
  
    parameter BRICK_ID_00 = 0;
    parameter BRICK_ID_15 = 15;
    parameter BRICK_ID_49 = 49;

    parameter COLLISION_BALL_X = 40;
    parameter COLLISION_BALL_Y = 40;

    parameter S_IDLE = 2'b00;
    parameter S_PLAY = 2'b01;
    parameter S_WIN  = 2'b10;
    parameter S_END  = 2'b11;
 
    reg vga_clk;
    reg sys_rst_n;
    reg [9:0] pix_x;
    reg [9:0] pix_y;
    reg [9:0] ball_x;
    reg [9:0] ball_y;
    reg [1:0] game_state;
    reg game_reset;

    wire [15:0] brick_data;
    wire [49:0] brick_collision;
    wire win_sig;

    wire [49:0] brick_status_check;

    VGA_Pic DUT (
        .vga_clk(vga_clk),
        .sys_rst_n(sys_rst_n),
        .pix_x(pix_x),
        .pix_y(pix_y),
        .ball_x(ball_x),
        .ball_y(ball_y),
        .game_state(game_state),
        .game_reset(game_reset),
        .brick_data(brick_data),
        .brick_collision(brick_collision),
        .win_sig(win_sig)
    );

    defparam DUT.BRICK_ROWS = 5;
    defparam DUT.BRICK_COLS = 10;
    assign brick_status_check = DUT.brick_status;

    initial begin
        vga_clk = 0;
        forever #(VGA_CLK_PERIOD / 2) vga_clk = ~vga_clk;
    end

    initial begin
        sys_rst_n = 1'b0;
        pix_x = 10'd0;
        pix_y = 10'd0;
        ball_x = 10'd0;
        ball_y = 10'd0;
        game_state = S_IDLE;
        game_reset = 1'b0;

        $display("-----------------------------------------------------");
        $display("--- VGA_Pic Testbench 开始仿真 ---");
        $dumpfile("VGA_Pic.vcd");
        $dumpvars(0, VGA_Pic_tb); 

        #100;
        sys_rst_n = 1'b1;
        @(posedge vga_clk);
        @(posedge vga_clk);
        if (brick_status_check == 50'h3FFFFFFFFFFFF) begin
            $display("@%0t: 成功: 复位后 brick_status 初始化为全 1.", $time);
        end else begin
            $display("@%0t: 失败: brick_status 初始化错误: %h.", $time, brick_status_check);
        end

        game_state = S_IDLE;
        #100;
     
        pix_x = 185; 
        pix_y = 205; 
        #100;
        if (brick_data == 16'h07E0) begin 
            $display("@%0t: 成功: IDLE 状态下，在文本区域 (%0d, %0d) 输出绿色 (START).", $time, pix_x, pix_y);
        end else begin
            $display("@%0t: 失败: IDLE 状态下，在文本区域输出颜色错误: %h.", $time, brick_data);
        end

        game_state = S_PLAY;
        $display("@%0t: 进入 PLAY 状态，开始碰撞测试.", $time);

        ball_x = COLLISION_BALL_X;
        ball_y = COLLISION_BALL_Y;
        #10;

        if (brick_collision[BRICK_ID_00] == 1'b1) begin
            $display("@%0t: 成功: Ball 撞击 Brick ID %0d (R0, C0) 成功检测到碰撞.", $time, BRICK_ID_00);
        end else begin
            $display("@%0t: 失败: Ball 撞击 Brick ID %0d 未能检测到碰撞.", $time, BRICK_ID_00);
        end

        @(posedge vga_clk); 
   
        ball_x = 10'd500;
        ball_y = 10'd500;
        
        @(posedge vga_clk); 
        
        if (brick_status_check[BRICK_ID_00] == 1'b0) begin
            $display("@%0t: 成功: Brick ID %0d 状态更新为 0 (已消除).", $time, BRICK_ID_00);
        end else begin
            $display("@%0t: 失败: Brick ID %0d 未能消除.", $time, BRICK_ID_00);
        end

        $display("@%0t: 模拟所有砖块被消除...", $time);
 
        @(posedge vga_clk);
        DUT.brick_status = 50'd1 << BRICK_ID_00;
        @(posedge vga_clk); 
    
        ball_x = COLLISION_BALL_X;
        ball_y = COLLISION_BALL_Y;
        @(posedge vga_clk);
        @(posedge vga_clk);
        ball_x = 10'd500;
        
        if (win_sig == 1'b1) begin
            $display("@%0t: 成功: 所有砖块消除，win_sig 置位.", $time);
        end else begin
            $display("@%0t: 失败: 所有砖块已消除，但 win_sig 未置位.", $time);
        end

        game_state = S_WIN;
        #100;
        if (brick_data == 16'h001F) begin
            $display("@%0t: 成功: WIN 状态下，在文本区域输出蓝色.", $time);
        end else begin
            $display("@%0t: 失败: WIN 状态下，在文本区域输出颜色错误: %h.", $time, brick_data);
        end


        # (VGA_CLK_PERIOD * 10);
        $display("-----------------------------------------------------");
        $display("--- VGA_Pic Testbench 仿真结束 ---");
        $display("-----------------------------------------------------");
        $finish; 
    end


endmodule
