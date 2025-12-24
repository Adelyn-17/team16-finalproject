`timescale 1ns/1ps
module MoveBall (
    input wire vga_clk,
    input wire sys_rst_n,
    input wire [9:0] pix_x,
    input wire [9:0] pix_y,
    input wire left,
    input wire right,
    input wire [49:0] brick_collision, // 碰撞检测输入
    input wire [1:0]  game_state,  
    input wire        game_reset,  
    
    output reg [15:0] pix_data,
    output reg [9:0] ball_x, 
    output reg [9:0] ball_y,
    output reg [9:0] racket_x,
    output reg [9:0] racket_y,
    output reg        lose_sig      
);

    parameter H_VALID = 10'd640, V_VALID = 10'd480;
    parameter BLUE = 16'h001F, BLACK = 16'h0000, GREEN = 16'h07E0;
    parameter BALL_RADIUS = 5; 
    parameter RACKET_WIDTH = 80, RACKET_HEIGHT = 10;
    
    // ===================================
    // 定点数和速度参数
    // ===================================
    parameter FRAC_BITS = 7; 
    parameter RACKET_X_WIDTH = 10 + FRAC_BITS; 
    parameter BALL_POS_WIDTH = 10 + FRAC_BITS; 
    parameter FRAC_ONE = 1 << FRAC_BITS; 

    // 连续速度步长
    parameter BALL_SPEED_FP_STEP = 1; 
    
    // 球拍参数
    parameter RACKET_SPEED_FP_STEP = FRAC_ONE / 2; 
    parameter RACKET_MOVE_DIV = 3000; 
    
    // Y轴初始位置 (200)
    localparam BALL_INIT_Y_INT = 10'd200; 
    // X轴最大随机范围 (635 - 5 = 630)
    localparam RANDOM_RANGE = 10'd630;
    localparam MIN_X = 10'd5;
    
    // ===================================
    // 内部寄存器
    // ===================================
    reg ball_dx;  // 1: 左/上, 0: 右/下
    reg ball_dy;  
    reg left_pressed, right_pressed;
    reg hit_occurred;  // 碰撞标志
    reg clear_hit_sig; // 清除碰撞标志

    // 计数器
    reg [11:0] racket_move_cnt;
    
    // [速度调整] 小球减速计数器：位宽增加到 7 位
    reg [6:0] slow_move_cnt;
    // [速度调整] SLOW_DIV = 89 (90个周期更新一次)，速度约为原来的 2/3 
    localparam SLOW_DIV = 7'd89; 

    // [特殊砖块] 反弹冷却计数器：防止在特殊砖块内连续反弹
    reg [3:0] bounce_cooldown; 
    
    // [随机位置] 随机种子计数器
    reg [9:0] seed_cnt;
    // [随机位置] 随机化后的X坐标整数值
    wire [9:0] random_x_int; 
    
    // 位置定点数寄存器
    reg [BALL_POS_WIDTH-1:0] ball_x_fp, ball_y_fp;      
    reg [RACKET_X_WIDTH-1:0] racket_x_fp;

    // 临时变量
    reg [9:0] next_racket_x_int;    
    reg [RACKET_X_WIDTH-1:0] temp_racket_x_fp;
    reg [9:0] next_ball_x_int;      
    reg [9:0] next_ball_y_int;      
    reg [9:0] racket_x_int_temp;    
    reg [BALL_POS_WIDTH-1:0] next_ball_x_fp, next_ball_y_fp;
    reg next_ball_dx, next_ball_dy;

    // ===================================
    // 随机数生成和计数器更新
    // ===================================
    
    // 自由运行的计数器作为随机种子
    always @(posedge vga_clk) begin
        seed_cnt <= seed_cnt + 1;
    end

    // 随机X位置计算 (5 <= random_x_int <= 634)
    assign random_x_int = (seed_cnt % RANDOM_RANGE) + MIN_X;
    
    // ===================================
    // 初始值设置
    // ===================================
    initial begin
        // 使用随机X位置
        ball_x_fp = random_x_int << FRAC_BITS; 
        ball_y_fp = BALL_INIT_Y_INT << FRAC_BITS;
        racket_x_fp = 280 << FRAC_BITS; 
        ball_dx = 0; 
        ball_dy = 0; 
        hit_occurred = 0;
        clear_hit_sig = 0;
        racket_y = 10'd440; 
        ball_x = 10'd320; 
        ball_y = BALL_INIT_Y_INT; 
        racket_x = 10'd280;
        lose_sig = 0;
        slow_move_cnt = 0;
        bounce_cooldown = 0;
        seed_cnt = 0; // 初始化种子
    end
    
    // 整数位置输出
    always @(*) begin
        ball_x = ball_x_fp[BALL_POS_WIDTH-1 : FRAC_BITS]; 
        ball_y = ball_y_fp[BALL_POS_WIDTH-1 : FRAC_BITS]; 
        racket_x = racket_x_fp[RACKET_X_WIDTH-1 : FRAC_BITS];
    end

    // 按键处理 (保持不变)
    always @(posedge vga_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            left_pressed <= 0;
            right_pressed <= 0;
        end else begin
            left_pressed <= ~left; 
            right_pressed <= ~right;
        end
    end

    // 球拍移动逻辑 (保持不变)
    always @(posedge vga_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            racket_x_fp <= 280 << FRAC_BITS;
            racket_move_cnt <= 0;
        end else if (game_reset) begin
             racket_x_fp <= 280 << FRAC_BITS;
        end else if (game_state == 2'b01) begin
            racket_move_cnt <= racket_move_cnt + 1;
            
            if (racket_move_cnt >= RACKET_MOVE_DIV) begin
                racket_move_cnt <= 0;
                temp_racket_x_fp = racket_x_fp;
                
                if (left_pressed) begin 
                    temp_racket_x_fp = racket_x_fp - RACKET_SPEED_FP_STEP;
                end else if (right_pressed) begin
                    temp_racket_x_fp = racket_x_fp + RACKET_SPEED_FP_STEP;
                end
                
                next_racket_x_int = temp_racket_x_fp[RACKET_X_WIDTH-1 : FRAC_BITS];

                if (next_racket_x_int < RACKET_WIDTH/2) begin
                    racket_x_fp <= (RACKET_WIDTH/2) << FRAC_BITS;
                end else if (next_racket_x_int > H_VALID - RACKET_WIDTH/2) begin
                    racket_x_fp <= (H_VALID - RACKET_WIDTH/2) << FRAC_BITS;
                end else begin
                    racket_x_fp <= temp_racket_x_fp;
                end
            end
        end
    end

    // 砖块碰撞标志 (持久化) (保持不变)
    always @(posedge vga_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            hit_occurred <= 0;
        end else if (game_reset) begin
            hit_occurred <= 0;
        end else if (game_state == 2'b01) begin
            if (clear_hit_sig) begin
                hit_occurred <= 1'b0; // 物理逻辑已处理，清除标志
            end else if (brick_collision != 50'd0) begin
                hit_occurred <= 1'b1; // 检测到碰撞，置位标志
            end
        end else begin
            hit_occurred <= 0; 
        end
    end

    // ===================================
    // 小球物理移动 (慢速逻辑)
    // ===================================
    always @(posedge vga_clk or negedge sys_rst_n) begin
        
        // **注意：移除了 clear_hit_sig <= 1'b0;** // **现在 clear_hit_sig 的默认清零逻辑在下面的 if/else if/else 结构内部。**

        if (!sys_rst_n) begin
            // [随机位置]
            ball_x_fp <= random_x_int << FRAC_BITS; 
            ball_y_fp <= BALL_INIT_Y_INT << FRAC_BITS;
            ball_dx <= 0; 
            ball_dy <= 0; 
            lose_sig <= 0;
            slow_move_cnt <= 0;
            bounce_cooldown <= 0;
            clear_hit_sig <= 1'b0; // Hard reset clear
        end else if (game_reset) begin
            // [随机位置]
            ball_x_fp <= random_x_int << FRAC_BITS;
            ball_y_fp <= BALL_INIT_Y_INT << FRAC_BITS;
            ball_dx <= 0; 
            ball_dy <= 0; 
            lose_sig <= 0;
            slow_move_cnt <= 0;
            bounce_cooldown <= 0;
            clear_hit_sig <= 1'b0; // Game reset clear
        end else if (game_state == 2'b01) begin // PLAY STATE
            
            // 默认设置为清零，只有在满足碰撞处理条件时才会被设置为 1 (同步清零)
            clear_hit_sig <= 1'b0; 
            
            slow_move_cnt <= slow_move_cnt + 1; // 计数
            
            // 只有当计数器达到阈值，才进行物理状态更新
            if (slow_move_cnt == SLOW_DIV) begin 
                slow_move_cnt <= 0;

                // 冷却逻辑
                if (bounce_cooldown > 0) begin
                    bounce_cooldown <= bounce_cooldown - 1;
                end

                // 1. 预测下一位置 
                next_ball_x_fp = ball_x_fp + (ball_dx ? -BALL_SPEED_FP_STEP : BALL_SPEED_FP_STEP);
                next_ball_y_fp = ball_y_fp + (ball_dy ? -BALL_SPEED_FP_STEP : BALL_SPEED_FP_STEP);
                next_ball_dx = ball_dx;
                next_ball_dy = ball_dy;
                
                next_ball_x_int = next_ball_x_fp[BALL_POS_WIDTH-1 : FRAC_BITS];
                next_ball_y_int = next_ball_y_fp[BALL_POS_WIDTH-1 : FRAC_BITS];
                racket_x_int_temp = racket_x_fp[RACKET_X_WIDTH-1 : FRAC_BITS];

                // 2. 碰撞检测与响应 

                // 墙壁碰撞 
                if (next_ball_x_int <= BALL_RADIUS) next_ball_dx = 0; 
                else if (next_ball_x_int >= H_VALID - BALL_RADIUS) next_ball_dx = 1; 
                if (next_ball_y_int <= BALL_RADIUS) next_ball_dy = 0; 

                // 拍子碰撞 
                if (next_ball_y_int >= racket_y - BALL_RADIUS && 
                    next_ball_y_int <= racket_y + RACKET_HEIGHT &&
                    next_ball_x_int >= racket_x_int_temp - RACKET_WIDTH/2 && 
                    next_ball_x_int <= racket_x_int_temp + RACKET_WIDTH/2) begin
                    next_ball_dy = 1; // 拍子总是把球向上打 (dy=1)
                end

                // 砖块碰撞 (使用冷却机制解决特殊砖块卡顿)
                if (hit_occurred) begin
                    clear_hit_sig <= 1'b1;   // 设置为 1 覆盖了上面的默认清零
                    
                    if (bounce_cooldown == 0) begin
                        next_ball_dy = ~ball_dy; 
                        bounce_cooldown <= 10;   // 设置冷却时间
                    end
                end

                // 底部边界检测 -> 触发 LOSE
                if (next_ball_y_int >= V_VALID - BALL_RADIUS) begin
                    lose_sig <= 1;
                end else begin
                    // 3. 更新位置和方向 
                    ball_x_fp <= next_ball_x_fp;
                    ball_y_fp <= next_ball_y_fp;
                    ball_dx <= next_ball_dx;
                    ball_dy <= next_ball_dy;
                end
            end
        end else begin
            // 确保在非 PLAY 状态下 (START/WIN/END) clear_hit_sig 保持清零
            clear_hit_sig <= 1'b0;
        end
    end
    
    // 绘图输出逻辑 
    always @(*) begin
        // **修改 2：将 dist_sq 位宽增加到 [20:0]**
        reg [20:0] dist_sq;
        reg is_ball, is_racket;

        is_ball = 1'b0;
        is_racket = 1'b0;
        
        if (game_state == 2'b01) begin
            // 现在计算结果能完全适应 dist_sq 的位宽 (21位)
            dist_sq = (pix_x - ball_x) * (pix_x - ball_x) + (pix_y - ball_y) * (pix_y - ball_y);
            if (dist_sq <= (BALL_RADIUS * BALL_RADIUS)) is_ball = 1'b1;

            if (pix_x >= racket_x - RACKET_WIDTH/2 && pix_x <= racket_x + RACKET_WIDTH/2 &&
                pix_y >= racket_y && pix_y <= racket_y + RACKET_HEIGHT) begin
                is_racket = 1'b1;
            end

            if (is_ball) pix_data = BLUE; 
            else if (is_racket) pix_data = GREEN; 
            else pix_data = BLACK; 
        end else begin
            pix_data = BLACK;
        end
    end

endmodule