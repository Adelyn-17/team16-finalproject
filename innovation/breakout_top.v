`timescale 1ns/1ps

module vga_colorbar(
    input  wire sys_clk,
    input  wire sys_rst_n,
    input  wire left,
    input  wire right,
    input  wire up,
    output wire hsync,
    output wire vsync,
    output wire [15:0] rgb
);

    wire vga_clk;
    wire [9:0] pix_x, pix_y;
    wire [15:0] ball_racket_data;
    wire [15:0] brick_data;
    wire [9:0] ball_x, ball_y;
    wire [9:0] racket_x, racket_y;
    wire [49:0] brick_collision;
    
    wire [1:0] game_state;
    wire win_sig;
    wire lose_sig;
    wire game_reset;
    wire [15:0] pix_data_mixed;
    
    wire left_db;
    wire right_db;
    wire up_db;

    
    pll pll_inst(
        .sys_clk    (sys_clk),
        .sys_rst_n  (sys_rst_n),
        .vga_clk    (vga_clk)
    );

    breakout_debounce #(.DEBOUNCE_TIME(10000)) db_inst (
        .clk        (sys_clk),
        .reset      (sys_rst_n), 
        .left_in    (left),
        .right_in   (right),
        .start_in   (up),
        .left_out   (left_db),
        .right_out  (right_db),
        .start_out  (up_db)
    );

    Game_Ctrl Game_Ctrl_inst(
        .sys_clk    (sys_clk),
        .sys_rst_n  (sys_rst_n),
        .start_key  (~up_db),
        .win_sig    (win_sig),
        .lose_sig   (lose_sig),
        .game_state (game_state),
        .game_reset (game_reset)
    );

    MoveBall MoveBall_inst(
        .vga_clk    (vga_clk),
        .sys_rst_n  (sys_rst_n),
        .pix_x      (pix_x),
        .pix_y      (pix_y),
        .left       (left_db),
        .right      (right_db),
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

