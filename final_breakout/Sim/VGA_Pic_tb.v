`timescale 1ns / 1ps

module VGA_Pic_tb;

    // ===================================
    // 1. 定义参数
    // ===================================
    parameter VGA_CLK_PERIOD = 40; // 25MHz 时钟周期 = 40ns
    
    // 砖块 ID 定义 (Row * Cols + Col)
    parameter BRICK_ID_00 = 0; // R=0, C=0
    parameter BRICK_ID_15 = 15; // R=1, C=5
    parameter BRICK_ID_49 = 49; // R=4, C=9 (最后一个)

    // 小球碰撞中心点 (以 R=0, C=0 砖块为例)
    // 砖块范围 X: [10, 70), Y: [30, 50)
    // 小球中心 (Ball_Radius=8)
    parameter COLLISION_BALL_X = 40; // 10 + 60/2 = 40
    parameter COLLISION_BALL_Y = 40; // 30 + 20/2 = 40
    
    // 状态定义
    parameter S_IDLE = 2'b00; // START 屏幕
    parameter S_PLAY = 2'b01; // 游戏进行中
    parameter S_WIN  = 2'b10; // 胜利屏幕
    parameter S_END  = 2'b11; // 失败屏幕
    
    // ===================================
    // 2. 信号定义
    // ===================================
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
    
    // 内部信号用于检查
    wire [49:0] brick_status_check; // DUT 内部的 brick_status 信号

    // ===================================
    // 3. 实例化 DUT
    // ===================================
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
    
    // 接入内部信号用于 Testbench 检查
    defparam DUT.BRICK_ROWS = 5;
    defparam DUT.BRICK_COLS = 10;
    assign brick_status_check = DUT.brick_status; // 假设此信号可被 Testbench 访问

    // ===================================
    // 4. 时钟生成
    // ===================================
    initial begin
        vga_clk = 0;
        forever #(VGA_CLK_PERIOD / 2) vga_clk = ~vga_clk;
    end

    // ===================================
    // 5. 激励生成
    // ===================================
    initial begin
        // 初始化信号
        sys_rst_n = 1'b0; // 保持复位
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

        // ----------------------------------------------------
        // 1. 系统复位
        // ----------------------------------------------------
        #100;
        sys_rst_n = 1'b1; // 释放复位
        @(posedge vga_clk);
        @(posedge vga_clk);
        if (brick_status_check == 50'h3FFFFFFFFFFFF) begin
            $display("@%0t: 成功: 复位后 brick_status 初始化为全 1.", $time);
        end else begin
            $display("@%0t: 失败: brick_status 初始化错误: %h.", $time, brick_status_check);
        end
        
        // ----------------------------------------------------
        // 2. 渲染验证 (IDLE 状态 - START 文本)
        // ----------------------------------------------------
        game_state = S_IDLE;
        #100;
        
        // 验证 S 字母的左上角 (185, 205)
        pix_x = 185; 
        pix_y = 205; 
        #100;
        if (brick_data == 16'h07E0) begin // 绿色
            $display("@%0t: 成功: IDLE 状态下，在文本区域 (%0d, %0d) 输出绿色 (START).", $time, pix_x, pix_y);
        end else begin
            $display("@%0t: 失败: IDLE 状态下，在文本区域输出颜色错误: %h.", $time, brick_data);
        end

        // ----------------------------------------------------
        // 3. 碰撞检测 (PLAY 状态)
        // ----------------------------------------------------
        game_state = S_PLAY;
        $display("@%0t: 进入 PLAY 状态，开始碰撞测试.", $time);
        
        // 3.1 碰撞测试 Brick 0 (R=0, C=0)
        ball_x = COLLISION_BALL_X;
        ball_y = COLLISION_BALL_Y;
        #10;
        
        // 检查组合逻辑的输出
        if (brick_collision[BRICK_ID_00] == 1'b1) begin
            $display("@%0t: 成功: Ball 撞击 Brick ID %0d (R0, C0) 成功检测到碰撞.", $time, BRICK_ID_00);
        end else begin
            $display("@%0t: 失败: Ball 撞击 Brick ID %0d 未能检测到碰撞.", $time, BRICK_ID_00);
        end

        // ----------------------------------------------------
        // 4. 砖块消除 (需要时钟上升沿触发)
        // ----------------------------------------------------
        // 保持碰撞信号为 1 一个时钟周期，使其在下一个时钟沿更新 brick_status
        @(posedge vga_clk); 
        
        // 消除完成后，小球移开
        ball_x = 10'd500;
        ball_y = 10'd500;
        
        @(posedge vga_clk); 
        
        if (brick_status_check[BRICK_ID_00] == 1'b0) begin
            $display("@%0t: 成功: Brick ID %0d 状态更新为 0 (已消除).", $time, BRICK_ID_00);
        end else begin
            $display("@%0t: 失败: Brick ID %0d 未能消除.", $time, BRICK_ID_00);
        end
        
        // ----------------------------------------------------
        // 5. 胜利条件测试
        // ----------------------------------------------------
        $display("@%0t: 模拟所有砖块被消除...", $time);
        
        // 5.1 模拟碰撞信号瞬间置位 (需要 50'b1)
        // 注意：在实际硬件中，这是通过 FSM 逐次碰撞的结果。这里直接强制清除 brick_status
        @(posedge vga_clk);
        // 为了强制测试 win_sig，我们设置一个碰撞信号，用于清除所有剩余的砖块状态
        // 假设我们设置一个碰撞，导致所有砖块被清除
        
        // 我们直接设置 brick_status_check 的所有位为 0，然后检查 win_sig
        // 警告：直接操作内部信号通常不好，但在 Testbench 中用于强制测试边界条件是可以接受的
        // 假设我们在一个时刻同时发生 49 次碰撞（清除 BRICK_ID_00 以外的砖块）
        DUT.brick_status = 50'd1 << BRICK_ID_00; // 仅 Brick 0 仍然存在
        @(posedge vga_clk); 
        
        // 消除 Brick ID 0
        ball_x = COLLISION_BALL_X;
        ball_y = COLLISION_BALL_Y;
        @(posedge vga_clk); // 碰撞信号置位
        @(posedge vga_clk); // 消除 Brick ID 0
        ball_x = 10'd500; // 移开小球
        
        // 检查 win_sig
        if (win_sig == 1'b1) begin
            $display("@%0t: 成功: 所有砖块消除，win_sig 置位.", $time);
        end else begin
            $display("@%0t: 失败: 所有砖块已消除，但 win_sig 未置位.", $time);
        end
        
        // ----------------------------------------------------
        // 6. WIN 状态渲染验证
        // ----------------------------------------------------
        game_state = S_WIN;
        #100;
        if (brick_data == 16'h001F) begin // 蓝色
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