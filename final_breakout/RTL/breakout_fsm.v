`timescale 1ns/1ps

module breakout_fsm(

    input wire sys_clk,
    input wire sys_rst_n,
    input wire start_key,
    input wire lose_sig,
    input wire win_sig,

    output reg [1:0]  game_state,
    output reg        game_reset
);
    

    localparam S_IDLE = 2'b00;
    localparam S_PLAY = 2'b01;
    localparam S_WIN  = 2'b10;
    localparam S_END  = 2'b11;

    reg [1:0] next_state;

    localparam IDLE_DELAY_MAX = 20'd1000000; 
    reg [19:0] idle_delay_counter;
    wire idle_delay_done = (idle_delay_counter == IDLE_DELAY_MAX);

    always @(posedge sys_clk or negedge sys_rst_n) begin
        if(!sys_rst_n) begin
            idle_delay_counter <= 20'h0;
        end else begin
            if (game_state == S_IDLE && !idle_delay_done) begin
                idle_delay_counter <= idle_delay_counter + 1'b1;
            end else if (game_state != S_IDLE) begin
                idle_delay_counter <= 20'h0;
            end
        end
    end

    always @(posedge sys_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            game_state <= S_IDLE;
        end else begin
            game_state <= next_state;
        end
    end

    always @(*) begin
        next_state = game_state;
        game_reset = 1'b0;

        case(game_state)
            S_IDLE: begin
                if (idle_delay_done && start_key) begin
                    next_state = S_PLAY;
                    game_reset = 1'b1;
                end
            end
            
            S_PLAY: begin
                if (lose_sig) begin
                    next_state = S_END;
                    game_reset = 1'b1;
                end else if (win_sig) begin
                    next_state = S_WIN;
                    game_reset = 1'b1;
                end
            end
            
            S_WIN: begin
                if (start_key) begin
                    next_state = S_IDLE;
                    game_reset = 1'b1;
                end
            end
            
            S_END: begin
                if (start_key) begin
                    next_state = S_IDLE;
                    game_reset = 1'b1;
                end
            end
            
            default: next_state = S_IDLE;
        endcase
    end
    

endmodule
