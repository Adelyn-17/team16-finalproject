`timescale 1ns/1ps
module MoveBall_logic (
    input wire vga_clk,
    input wire sys_rst_n,
    input wire [9:0] pix_x,
    input wire [9:0] pix_y,
    input wire left,
    input wire right,
    input wire [49:0] brick_collision,
    input wire [1:0]  game_state, 
    input wire        game_reset, 
    
    output reg [15:0] pix_data,
    output reg [9:0] ball_x, 
    output reg [9:0] ball_y,
    output reg [9:0] racket_x,
    output reg [9:0] racket_y,
    output reg       lose_sig 
);

    parameter H_VALID = 10'd640, V_VALID = 10'd480;
    parameter BLUE = 16'h001F, BLACK = 16'h0000, GREEN = 16'h07E0;
    parameter BALL_RADIUS = 5; 
    parameter RACKET_WIDTH = 80, RACKET_HEIGHT = 10;
    
    parameter FRAC_BITS = 7; 
    parameter RACKET_X_WIDTH = 10 + FRAC_BITS; 
    parameter BALL_POS_WIDTH = 10 + FRAC_BITS; 
    parameter FRAC_ONE = 1 << FRAC_BITS; 

    parameter BALL_SPEED_FP_STEP = FRAC_ONE / 4; 
    parameter RACKET_SPEED_FP_STEP = FRAC_ONE / 2; 
    
    parameter RACKET_MOVE_DIV = 3000; 
    parameter BALL_MOVE_DIV   = 5000; 
    parameter DRAW_MOVE_DIV = 4; 
    parameter DRAW_FP_STEP = 1; 

    reg ball_dx; 
    reg ball_dy; 
    reg left_pressed, right_pressed;

    reg [11:0] racket_move_cnt;
    reg [14:0] ball_move_cnt;  
    reg [1:0] draw_move_cnt; 

    reg [BALL_POS_WIDTH-1:0] ball_x_fp, ball_y_fp;      
    reg [BALL_POS_WIDTH-1:0] ball_x_draw_fp, ball_y_draw_fp; 
    reg [RACKET_X_WIDTH-1:0] racket_x_fp;

    reg hit_occurred; 
    
    reg [9:0] next_racket_x_int;    
    reg [RACKET_X_WIDTH-1:0] temp_racket_x_fp;
    reg [9:0] next_ball_x_int;      
    reg [9:0] next_ball_y_int;      
    reg [9:0] racket_x_int_temp;    
    reg [BALL_POS_WIDTH-1:0] next_ball_x_fp, next_ball_y_fp;
    reg next_ball_dx, next_ball_dy;

	 reg [19:0] dist_sq;
    reg is_ball, is_racket;
	 
    initial begin
        ball_x_fp = 320 << FRAC_BITS; 
        ball_y_fp = 240 << FRAC_BITS;
        ball_x_draw_fp = 320 << FRAC_BITS; 
        ball_y_draw_fp = 240 << FRAC_BITS;
        racket_x_fp = 280 << FRAC_BITS; 
        ball_dx = 0; ball_dy = 0;
        hit_occurred = 0;
        racket_y = 10'd440; 
        ball_x = 10'd320; ball_y = 10'd240; racket_x = 10'd280;
        lose_sig = 0;
    end
    
    always @(*) begin
        ball_x = ball_x_draw_fp[BALL_POS_WIDTH-1 : FRAC_BITS]; 
        ball_y = ball_y_draw_fp[BALL_POS_WIDTH-1 : FRAC_BITS]; 
        racket_x = racket_x_fp[RACKET_X_WIDTH-1 : FRAC_BITS];
    end

    /
    always @(posedge vga_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            left_pressed <= 0;
            right_pressed <= 0;
        end else begin
            left_pressed <= ~left; 
            right_pressed <= ~right;
        end
    end


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

    always @(posedge vga_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            hit_occurred <= 0;
        end else begin
            if (brick_collision != 50'd0) begin
                hit_occurred <= 1'b1; 
            end else if (ball_move_cnt == 0) begin
                hit_occurred <= 1'b0; 
            end
        end
    end

    always @(posedge vga_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            ball_x_fp <= 320 << FRAC_BITS;
            ball_y_fp <= 240 << FRAC_BITS;
            ball_x_draw_fp <= 320 << FRAC_BITS; 
            ball_y_draw_fp <= 240 << FRAC_BITS; 
            ball_dx <= 0; ball_dy <= 0;
            ball_move_cnt <= 0;
            draw_move_cnt <= 0; 
            lose_sig <= 0;
        end else if (game_reset) begin

            ball_x_fp <= 320 << FRAC_BITS;
            ball_y_fp <= 240 << FRAC_BITS;
            ball_x_draw_fp <= 320 << FRAC_BITS; 
            ball_y_draw_fp <= 240 << FRAC_BITS; 
            ball_dx <= 0; ball_dy <= 0; 
            lose_sig <= 0;
        end else if (game_state == 2'b01) begin 
            
            ball_move_cnt <= ball_move_cnt + 1;

            if (ball_move_cnt >= BALL_MOVE_DIV - 1) begin 
                ball_move_cnt <= 0;

                next_ball_x_fp = ball_x_fp + (ball_dx ? -BALL_SPEED_FP_STEP : BALL_SPEED_FP_STEP);
                next_ball_y_fp = ball_y_fp + (ball_dy ? -BALL_SPEED_FP_STEP : BALL_SPEED_FP_STEP);
                next_ball_dx = ball_dx;
                next_ball_dy = ball_dy;
                
                next_ball_x_int = next_ball_x_fp[BALL_POS_WIDTH-1 : FRAC_BITS];
                next_ball_y_int = next_ball_y_fp[BALL_POS_WIDTH-1 : FRAC_BITS];
                racket_x_int_temp = racket_x_fp[RACKET_X_WIDTH-1 : FRAC_BITS];

                if (next_ball_x_int <= BALL_RADIUS) next_ball_dx = 0; 
                else if (next_ball_x_int >= H_VALID - BALL_RADIUS) next_ball_dx = 1; 

                if (next_ball_y_int <= BALL_RADIUS) next_ball_dy = 0; 

                
                if (next_ball_y_int >= racket_y - BALL_RADIUS && 
                    next_ball_y_int <= racket_y + RACKET_HEIGHT &&
                    next_ball_x_int >= racket_x_int_temp - RACKET_WIDTH/2 && 
                    next_ball_x_int <= racket_x_int_temp + RACKET_WIDTH/2) begin
                    next_ball_dy = 1; 
                end

                if (hit_occurred) begin
                    next_ball_dy = ~ball_dy; 
                end

                if (next_ball_y_int >= V_VALID - BALL_RADIUS) begin
                    lose_sig <= 1; 
                end else begin
                    ball_x_fp <= next_ball_x_fp;
                    ball_y_fp <= next_ball_y_fp;
                    ball_dx <= next_ball_dx;
                    ball_dy <= next_ball_dy;
                end
            end
        
            draw_move_cnt <= draw_move_cnt + 1;
            if (draw_move_cnt >= DRAW_MOVE_DIV - 1) begin
                draw_move_cnt <= 0;
                if (ball_x_draw_fp != ball_x_fp) begin
                    if (ball_x_fp > ball_x_draw_fp) ball_x_draw_fp <= ball_x_draw_fp + DRAW_FP_STEP;
                    else ball_x_draw_fp <= ball_x_draw_fp - DRAW_FP_STEP;
                end
                if (ball_y_draw_fp != ball_y_fp) begin
                    if (ball_y_fp > ball_y_draw_fp) ball_y_draw_fp <= ball_y_draw_fp + DRAW_FP_STEP;
                    else ball_y_draw_fp <= ball_y_draw_fp - DRAW_FP_STEP;
                end
            end
            
        end
    end
    
    always @(*) begin
        is_ball = 1'b0;
        is_racket = 1'b0;
        
        if (game_state == 2'b01) begin 
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
