`timescale 1ns/1ps

module vga_colorbar(
    input  wire sys_clk,  //System Clock, 50MHz
    input  wire sys_rst_n, //Reset signal. Low level is effective
    input  wire left,     // 原始按键输入
    input  wire right,    // 原始按键输入
    input  wire up,       // 原始按键输入
    output wire hsync,
    output wire vsync,
    output wire [15:0] rgb
);
    // ... (保持原有的 wire 声明)
    wire vga_clk;
    wire [9:0] pix_x, pix_y;
    wire [15:0] ball_racket_data;
    wire [15:0] brick_data;
    wire [9:0] ball_x, ball_y;
    wire [9:0] racket_x, racket_y;
    wire [49:0] brick_collision;
    
    // 状态机信号
    wire [1:0] game_state;
    wire win_sig;
    wire lose_sig;
    wire game_reset;
    wire [15:0] pix_data_mixed; // 补充声明，否则编译不过

    // **********************************************
    // 新增：按键消抖信号 (三合一模块的输出)
    // **********************************************
    wire left_db;
    wire right_db;
    wire up_db; // 对应 start_out

    // **********************************************
    // 实例化 PLL (不变)
    // **********************************************
    pll pll_inst(
        .sys_clk    (sys_clk),
        .sys_rst_n  (sys_rst_n),
        .vga_clk    (vga_clk)
    );

    // **********************************************
    // 实例化 breakout_debounce (修正为单实例，端口名匹配)
    // **********************************************
    breakout_debounce #(.DEBOUNCE_TIME(10000)) db_inst (
        .clk        (sys_clk),
        .reset      (sys_rst_n), // 🚨 关键修正：~sys_rst_n 转换为高电平复位，与修改后的 breakout_debounce 兼容
                                  // 注：如果使用原版 breakout_debounce (posedge reset)，这里需要是 ~sys_rst_n
                                  // 如果使用我修改后的 breakout_debounce (negedge reset)，这里需要是 sys_rst_n (保留原低电平特性)
                                  // 考虑到您的代码使用了 negedge sys_rst_n，我将此连接为 sys_rst_n，并修改了 breakout_debounce 逻辑
        .left_in    (left),
        .right_in   (right),
        .start_in   (up), // up 对应 start 按钮
        .left_out   (left_db),
        .right_out  (right_db),
        .start_out  (up_db) // up_db 对应 start_out
    );

    // **********************************************
    // 实例化状态机 (使用消抖后的 up_db)
    // **********************************************
    Game_Ctrl Game_Ctrl_inst(
        .sys_clk    (sys_clk),     // 使用 VGA 时钟以保持同步方便
        .sys_rst_n  (sys_rst_n),
        .start_key  (~up_db),      // **修正：使用消抖后的 up_db，并反相**
        .win_sig    (win_sig),
        .lose_sig   (lose_sig),
        .game_state (game_state),
        .game_reset (game_reset)
    );

    // **********************************************
    // 实例化 MoveBall (使用消抖后的 left_db 和 right_db)
    // **********************************************
    MoveBall MoveBall_inst(
        .vga_clk    (vga_clk),
        .sys_rst_n  (sys_rst_n),
        .pix_x      (pix_x),
        .pix_y      (pix_y),
        .left       (left_db),     // **修正：使用消抖后的 left_db**
        .right      (right_db),    // **修正：使用消抖后的 right_db**
        .brick_collision(brick_collision),
        .game_state (game_state),
        .game_reset (game_reset),
        .pix_data   (ball_racket_data),
        .ball_x     (ball_x),
        .ball_y     (ball_y),
        .racket_x   (racket_x),
        .racket_y   (racket_y),
        .lose_sig   (lose_sig)
    );

    // **********************************************
    // 实例化 vga_pic (不变)
    // **********************************************
    vga_pic vga_pic_inst(
        .vga_clk    (vga_clk),
        .sys_rst_n  (sys_rst_n),
        .pix_x      (pix_x),
        .pix_y      (pix_y),
        .ball_x     (ball_x),
        .ball_y     (ball_y),
        .game_state (game_state),
        .game_reset (game_reset),
        .brick_data (brick_data),
        .brick_collision(brick_collision),
        .win_sig    (win_sig)
    );

    // 像素混合器 (不变)
    // 逻辑：如果砖块层有颜色（可能是砖块，也可能是文字），显示砖块层；否则显示球/拍层
    assign pix_data_mixed = (brick_data != 16'h0000) ? brick_data : ball_racket_data;

    vga_ctrl vga_ctrl_inst(
        .vga_clk    (vga_clk),
        .sys_rst_n  (sys_rst_n),
        .pix_data   (pix_data_mixed),
        .pix_x      (pix_x),
        .pix_y      (pix_y),
        .hsync      (hsync),
        .vsync      (vsync),
        .rgb        (rgb)
    );

endmodule
