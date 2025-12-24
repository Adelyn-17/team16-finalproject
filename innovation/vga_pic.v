`timescale 1ns/1ps
module vga_pic(
    input  wire        vga_clk,
    input  wire        sys_rst_n,
    input  wire [9:0]  pix_x,
    input  wire [9:0]  pix_y,
    input  wire [9:0]  ball_x,     
    input  wire [9:0]  ball_y,
    input  wire [1:0]  game_state, 
    input  wire        game_reset, 
    
    output reg  [15:0] brick_data,
    output reg  [49:0] brick_collision,
    output reg         win_sig     
);

    parameter BRICK_ROWS    = 5;
    parameter BRICK_COLS    = 10;
    parameter BRICK_WIDTH   = 60;
    parameter BRICK_HEIGHT  = 20;
    parameter BRICK_GAP     = 2;
    parameter BRICK_START_X = 10;
    parameter BRICK_START_Y = 30;
    parameter BG_COLOR      = 16'h0000;
    
    // 圆角半径
    parameter TEXT_RADIUS   = 3; 

    // 颜色定义
    wire [15:0] ROW_COLORS [0:4];
    assign ROW_COLORS[0] = 16'hF800; // 红
    assign ROW_COLORS[1] = 16'hFD20; // 橙
    assign ROW_COLORS[2] = 16'hFFE0; // 黄
    assign ROW_COLORS[3] = 16'h07E0; // 绿
    assign ROW_COLORS[4] = 16'h001F; // 蓝

    reg [49:0] brick_status; 
    
    // 特殊砖块变量
    reg [5:0] special_brick_id; 
    reg [5:0] lfsr_counter;     
    
    wire [9:0] brick_total_w = BRICK_WIDTH + BRICK_GAP;
    wire [9:0] brick_total_h = BRICK_HEIGHT + BRICK_GAP;

    // 砖块索引计算
    wire [9:0] col_idx = (pix_x - BRICK_START_X) / brick_total_w;
    wire [9:0] row_idx = (pix_y - BRICK_START_Y) / brick_total_h;
    
    wire valid_region = (pix_x >= BRICK_START_X) && (pix_x < BRICK_START_X + BRICK_COLS * brick_total_w) &&
                        (pix_y >= BRICK_START_Y) && (pix_y < BRICK_START_Y + BRICK_ROWS * brick_total_h);
                        
    wire on_brick_face = ((pix_x - BRICK_START_X) % brick_total_w < BRICK_WIDTH) &&
                         ((pix_y - BRICK_START_Y) % brick_total_h < BRICK_HEIGHT);
                         
    wire [5:0] current_brick_id = row_idx * BRICK_COLS + col_idx;
    
    wire is_brick_pixel = valid_region && on_brick_face && brick_status[current_brick_id];

    // 伪随机数生成器
    always @(posedge vga_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            lfsr_counter <= 0;
        end else begin
            if (lfsr_counter >= 49) 
                lfsr_counter <= 0;
            else 
                lfsr_counter <= lfsr_counter + 1;
        end
    end

    // 砖块逻辑控制
    integer i;
    always @(posedge vga_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            brick_status <= {50{1'b1}}; 
            win_sig <= 1'b0;
            special_brick_id <= 24; 
        end else if (game_reset) begin
            brick_status <= {50{1'b1}}; 
            win_sig <= 1'b0;
            special_brick_id <= lfsr_counter; 
        end else begin
            for (i = 0; i < 50; i = i + 1) begin
                if (brick_collision[i]) begin
                    if (i != special_brick_id) begin
                        brick_status[i] <= 1'b0;
                    end
                end
            end
            
            if (brick_status == (50'd1 << special_brick_id)) 
                win_sig <= 1'b1;
            else 
                win_sig <= 1'b0;
        end
    end

    // 碰撞检测逻辑
    integer r, c;
    always @(*) begin
        brick_collision = 50'b0; 
        if (game_state == 2'b01) begin
            for (r = 0; r < BRICK_ROWS; r = r + 1) begin
                for (c = 0; c < BRICK_COLS; c = c + 1) begin
                    if (brick_status[r * BRICK_COLS + c]) begin
                        if (ball_x + 8 >= BRICK_START_X + c * brick_total_w && 
                            ball_x - 8 <  BRICK_START_X + c * brick_total_w + BRICK_WIDTH && 
                            ball_y + 8 >= BRICK_START_Y + r * brick_total_h && 
                            ball_y - 8 <  BRICK_START_Y + r * brick_total_h + BRICK_HEIGHT) begin
                            brick_collision[r * BRICK_COLS + c] = 1'b1;
                        end
                    end
                end
            end
        end
    end

    // 圆角矩形绘制函数
    function automatic is_round_rect;
        input [9:0] x_in, y_in;
        input [9:0] x1, y1, x2, y2; 
        input [9:0] R;
        reg is_rect;
        begin
            is_rect = 1'b1;
            if (x_in < x1 || x_in >= x2 || y_in < y1 || y_in >= y2) begin
                is_rect = 1'b0;
            end else if (R > 0) begin
                if (x_in < x1 + R && y_in < y1 + R) is_rect = 1'b0;
                else if (x_in >= x2 - R && y_in < y1 + R) is_rect = 1'b0;
                else if (x_in < x1 + R && y_in >= y2 - R) is_rect = 1'b0;
                else if (x_in >= x2 - R && y_in >= y2 - R) is_rect = 1'b0;
            end
            is_round_rect = is_rect;
        end
    endfunction
    
    // 简易点阵字符显示逻辑
    reg is_text_pixel;
    wire [9:0] tx = pix_x; 
    wire [9:0] ty = pix_y;
    
    wire [11:0] diag_calc_lhs = (tx >= 320) ? ((tx - 320) * 3) : 12'd0; 
    wire [11:0] diag_calc_rhs = (ty >= 200) ? ((ty - 200) * 2) : 12'd0;
    wire [11:0] diag_calc_end_n_x = (tx >= 300) ? (tx - 300) : 12'd0;
    wire [11:0] diag_calc_end_n_y = (ty >= 200) ? (ty - 200) : 12'd0;
    wire [11:0] r_x_diff = (tx >= 340) ? (tx - 340) : 12'd0;
    wire [11:0] r_y_diff = (ty >= 235) ? (ty - 235) : 12'd0;
    wire [12:0] r_lhs = r_y_diff * 6;
    wire [12:0] r_rhs = r_x_diff * 5;

    // 文字绘制逻辑 (不变)
    always @(*) begin
        is_text_pixel = 0;
        if (game_state == 2'b00) begin // START
            // S
            if(is_round_rect(tx, ty, 180, 200, 220, 210, TEXT_RADIUS)) is_text_pixel = 1; 
            if(is_round_rect(tx, ty, 180, 225, 220, 235, TEXT_RADIUS)) is_text_pixel = 1; 
            if(is_round_rect(tx, ty, 180, 250, 220, 260, TEXT_RADIUS)) is_text_pixel = 1; 
            if(is_round_rect(tx, ty, 180, 200, 190, 235, TEXT_RADIUS)) is_text_pixel = 1; 
            if(is_round_rect(tx, ty, 210, 225, 220, 260, TEXT_RADIUS)) is_text_pixel = 1; 
            // T
            if(is_round_rect(tx, ty, 230, 200, 270, 210, TEXT_RADIUS)) is_text_pixel = 1; 
            if(is_round_rect(tx, ty, 245, 200, 255, 260, TEXT_RADIUS)) is_text_pixel = 1; 
            // A
            if(is_round_rect(tx, ty, 280, 200, 320, 210, TEXT_RADIUS)) is_text_pixel = 1; 
            if(is_round_rect(tx, ty, 280, 225, 320, 235, TEXT_RADIUS)) is_text_pixel = 1; 
            if(is_round_rect(tx, ty, 280, 200, 290, 260, TEXT_RADIUS)) is_text_pixel = 1; 
            if(is_round_rect(tx, ty, 310, 200, 320, 260, TEXT_RADIUS)) is_text_pixel = 1; 
            // R
            if(is_round_rect(tx, ty, 330, 200, 340, 260, TEXT_RADIUS)) is_text_pixel = 1; 
            if(is_round_rect(tx, ty, 340, 200, 370, 210, TEXT_RADIUS)) is_text_pixel = 1; 
            if(is_round_rect(tx, ty, 340, 225, 370, 235, TEXT_RADIUS)) is_text_pixel = 1; 
            if(is_round_rect(tx, ty, 360, 200, 370, 235, TEXT_RADIUS)) is_text_pixel = 1; 
            if(tx >= 340 && tx < 370 && ty >= 235 && ty < 260) begin
                if(r_lhs >= r_rhs - 30 && r_lhs <= r_rhs + 30) is_text_pixel = 1;
            end
            // T
            if(is_round_rect(tx, ty, 380, 200, 420, 210, TEXT_RADIUS)) is_text_pixel = 1; 
            if(is_round_rect(tx, ty, 395, 200, 405, 260, TEXT_RADIUS)) is_text_pixel = 1; 
        end
        else if (game_state == 2'b10) begin // WIN
            // W
            if(is_round_rect(tx, ty, 240, 200, 250, 260, TEXT_RADIUS)) is_text_pixel = 1; 
            if(is_round_rect(tx, ty, 270, 200, 280, 260, TEXT_RADIUS)) is_text_pixel = 1; 
            if(is_round_rect(tx, ty, 250, 250, 270, 260, TEXT_RADIUS)) is_text_pixel = 1; 
            if(is_round_rect(tx, ty, 255, 230, 265, 250, TEXT_RADIUS)) is_text_pixel = 1; 
            // I
            if(is_round_rect(tx, ty, 295, 200, 305, 260, TEXT_RADIUS)) is_text_pixel = 1; 
            // N
            if(is_round_rect(tx, ty, 320, 200, 330, 260, TEXT_RADIUS)) is_text_pixel = 1; 
            if(is_round_rect(tx, ty, 350, 200, 360, 260, TEXT_RADIUS)) is_text_pixel = 1; 
            if(tx >= 330 && tx < 350 && ty >= 200 && ty < 260) begin
                if(diag_calc_lhs >= diag_calc_rhs - 5 && diag_calc_lhs <= diag_calc_rhs + 5) is_text_pixel = 1;
            end
        end
        else if (game_state == 2'b11) begin // END
            // E
            if(is_round_rect(tx, ty, 240, 200, 250, 260, TEXT_RADIUS)) is_text_pixel = 1; 
            if(is_round_rect(tx, ty, 240, 200, 280, 210, TEXT_RADIUS)) is_text_pixel = 1; 
            if(is_round_rect(tx, ty, 240, 225, 270, 235, TEXT_RADIUS)) is_text_pixel = 1; 
            if(is_round_rect(tx, ty, 240, 250, 280, 260, TEXT_RADIUS)) is_text_pixel = 1; 
            // N
            if(is_round_rect(tx, ty, 290, 200, 300, 260, TEXT_RADIUS)) is_text_pixel = 1; 
            if(is_round_rect(tx, ty, 320, 200, 330, 260, TEXT_RADIUS)) is_text_pixel = 1; 
            if(tx >= 300 && tx < 320 && ty >= 200 && ty < 260) begin
                if( diag_calc_end_n_x * 3 >= diag_calc_end_n_y - 3 && diag_calc_end_n_x * 3 <= diag_calc_end_n_y + 3) is_text_pixel = 1; 
            end
            // D
            if(is_round_rect(tx, ty, 340, 200, 350, 260, TEXT_RADIUS)) is_text_pixel = 1; 
            if(is_round_rect(tx, ty, 340, 200, 380, 260, 7)) begin 
                if(tx >= 350 && tx < 370 && ty >= 210 && ty < 250) is_text_pixel = 0;
                else is_text_pixel = 1; 
            end
        end
    end

    // 最终颜色输出
    always @(posedge vga_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) brick_data <= BG_COLOR;
        else begin
            if (game_state == 2'b01) begin // PLAY: 显示砖块
                if (is_brick_pixel) begin
                    if (current_brick_id == special_brick_id)
                        brick_data <= 16'hFFFF; // 白颜色
                    else if(row_idx < 5) 
                        brick_data <= ROW_COLORS[row_idx];
                    else 
                        brick_data <= BG_COLOR;
                end else begin
                    brick_data <= BG_COLOR;
                end
            end
            else begin // START, WIN, END 状态
                case(game_state)
                    2'b00: brick_data <= is_text_pixel ? 16'h07E0 : BG_COLOR; // START (绿色)
                    2'b10: brick_data <= is_text_pixel ? 16'h001F : BG_COLOR; // WIN (蓝色)
                    2'b11: brick_data <= is_text_pixel ? 16'hF800 : BG_COLOR; // END (红色)
                    default: brick_data <= BG_COLOR;
                endcase
            end
        end
    end

endmodule