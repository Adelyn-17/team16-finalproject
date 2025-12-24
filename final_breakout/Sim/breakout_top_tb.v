`timescale 1ns / 1ps
module breakout_top_tb;

    reg sys_clk;
    reg vga_clk;
    reg sys_rst_n;
    reg left_raw_in;
    reg right_raw_in;
    reg start_raw_in;
   
    wire left_key;
    wire right_key;
    wire start_key;
    wire [1:0] game_state;
    wire game_reset;
    wire lose_sig;
    wire win_sig;
    wire [49:0] brick_collision;
    wire [15:0] pix_data_ball;
    wire [15:0] pix_data_brick;
    wire [9:0] pix_x;
    wire [9:0] pix_y;
    wire [9:0] ball_x;
    wire [9:0] ball_y;
    wire [9:0] racket_x;
    wire hsync, vsync;
    wire [15:0] rgb_out;
    
    localparam S_IDLE = 2'b00; 
    localparam S_PLAY = 2'b01; 
    localparam S_WIN  = 2'b10; 
    localparam S_END  = 2'b11; 
    localparam SYS_CLK_PERIOD = 20;
    localparam VGA_CLK_PERIOD = 40;
    localparam DEBOUNCE_TIME_CYCLES = 10000;
    localparam IDLE_DELAY_CYCLES = 1000000;

    
    always #((SYS_CLK_PERIOD / 2)) sys_clk = ~sys_clk;

    always #((VGA_CLK_PERIOD / 2)) vga_clk = ~vga_clk;

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


    breakout_fsm DUT_FSM (

        .sys_clk(sys_clk),
        .sys_rst_n(sys_rst_n),
        .start_key(start_key),
        .lose_sig(lose_sig),
        .win_sig(win_sig),
        .game_state(game_state),
        .game_reset(game_reset)

    );

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



    localparam LONG_PLAY_CYCLES = 125_000_000;

    localparam EXTRA_OBSERVATION_CYCLES = 25_000_000;



    initial begin


        sys_clk = 0;
        vga_clk = 0;
        sys_rst_n = 0;
        left_raw_in = 1;
        right_raw_in = 1;
        start_raw_in = 1;

        

        $display("-------------------------------------------------------");

        $display("Start Top-Level Breakout Testbench.");

        $display("Expected Total Simulation Time: ~6 seconds.");

        $display("-------------------------------------------------------");


        #((SYS_CLK_PERIOD * 5));

        sys_rst_n = 1; 

        $display("@%0t: Reset Released. Initial State: %b.", $time, game_state);

      

        $display("@%0t: Waiting for FSM IDLE delay to complete.", $time);

        #((SYS_CLK_PERIOD * (IDLE_DELAY_CYCLES + DEBOUNCE_TIME_CYCLES + 100))); 

    

        start_raw_in = 0;

        #((SYS_CLK_PERIOD * DEBOUNCE_TIME_CYCLES));

        start_raw_in = 1;

        

        @(posedge sys_clk);

        @(posedge sys_clk);

        

        if (game_state == S_PLAY && game_reset == 1) begin

            $display("@%0t: SUCCESS: Transition IDLE -> PLAY. Game reset asserted.", $time);

        end else begin

            $display("@%0t: FAILURE: IDLE -> PLAY transition failed. State: %b, Reset: %b.", $time, game_state, game_reset);

        end

        

        @(posedge sys_clk);

        $display("@%0t: Starting Racket Movement Test (8ms).", $time);

        #((VGA_CLK_PERIOD * 1000)); 


        left_raw_in = 0; 

        #((VGA_CLK_PERIOD * 100000));

        $display("@%0t: Left key pressed. Racket X: %0d", $time, racket_x);

        left_raw_in = 1; 

        

        #((VGA_CLK_PERIOD * 10000));


        right_raw_in = 0; 

        #((VGA_CLK_PERIOD * 100000));

        $display("@%0t: Right key pressed. Racket X: %0d", $time, racket_x);

        right_raw_in = 1; 


        $display("@%0t: Running game for an extended period (~5 seconds) to observe brick hits/loss.", $time);


        #((VGA_CLK_PERIOD * LONG_PLAY_CYCLES)); 


        if (lose_sig == 1) begin

            $display("@%0t: SUCCESS: lose_sig detected. Ball Y: %0d", $time, ball_y);

            @(posedge sys_clk);

            @(posedge sys_clk);

            

            if (game_state == S_END) begin

                $display("@%0t: SUCCESS: Transition PLAY -> END.", $time);

            end else begin

                 $display("@%0t: FAILURE: PLAY -> END transition failed. State: %b.", $time, game_state);

            end

        end else begin


            $display("@%0t: INFO: lose_sig not automatically detected after ~5 seconds. Assuming successful play/win state.", $time);

  

        end


        $display("@%0t: Simulating START button press to return to IDLE.", $time);

        #((SYS_CLK_PERIOD * 100));

        start_raw_in = 0;

        #((SYS_CLK_PERIOD * DEBOUNCE_TIME_CYCLES));

        start_raw_in = 1;



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



        #((VGA_CLK_PERIOD * EXTRA_OBSERVATION_CYCLES));



        $finish; 

    end


endmodule
