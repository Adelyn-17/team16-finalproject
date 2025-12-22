`timescale 1ns/1ps

module breakout_fsm(
    // Input Ports
    input wire sys_clk,      // System Clock (50MHz)
    input wire sys_rst_n,    // System Reset (Active Low)
    input wire start_key,    // Debounced Start Button Input (Pulse or Level)
    input wire lose_sig,     // Signal that indicates the game is lost (Pulse)
    input wire win_sig,      // Signal that indicates the game is won (Pulse)
    
    // Output Ports
    output reg [1:0]  game_state,  // Current state of the game
    output reg        game_reset   // Reset pulse for game components
);
    
    // ===================================
    // 1. State Definitions
    // ===================================
    localparam S_IDLE = 2'b00; // Display START screen, wait for key press
    localparam S_PLAY = 2'b01; // Game is running
    localparam S_WIN  = 2'b10; // Display WIN screen
    localparam S_END  = 2'b11; // Display GAME OVER screen

    // ===================================
    // 2. Internal Registers and Wires
    // ===================================
    reg [1:0] next_state;
    
    // IDLE 延迟计数器
    localparam IDLE_DELAY_MAX = 20'd1000000; // 约 20ms @ 50MHz
    reg [19:0] idle_delay_counter;
    wire idle_delay_done = (idle_delay_counter == IDLE_DELAY_MAX);

    // ===================================
    // 3. IDLE 延迟计数器逻辑 (时序逻辑)
    // ===================================
    always @(posedge sys_clk or negedge sys_rst_n) begin
        if(!sys_rst_n) begin
            idle_delay_counter <= 20'h0;
        end else begin
            // 只有在 IDLE 状态下且未完成时才计数
            if (game_state == S_IDLE && !idle_delay_done) begin
                idle_delay_counter <= idle_delay_counter + 1'b1;
            end else if (game_state != S_IDLE) begin
                // 离开 IDLE 状态后重置计数器
                idle_delay_counter <= 20'h0;
            end
        end
    end
    
    // ===================================
    // 4. State Register Logic (时序逻辑)
    // ===================================
    always @(posedge sys_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            game_state <= S_IDLE; // 复位到 IDLE 状态
        end else begin
            game_state <= next_state;
        end
    end

    // ===================================
    // 5. Next State and Output Logic (组合逻辑)
    // ===================================
    always @(*) begin
        next_state = game_state;
        game_reset = 1'b0; // Default: no game component reset

        case(game_state)
            S_IDLE: begin
                // 必须满足两个条件：
                // 1. IDLE 延迟计数完成 (画面稳定)
                // 2. 检测到 start_key 信号 (无论是脉冲还是去抖后的电平)
                if (idle_delay_done && start_key) begin
                    next_state = S_PLAY;
                    game_reset = 1'b1; // 触发游戏组件复位
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
                // 重新开始
                if (start_key) begin
                    next_state = S_IDLE;
                    game_reset = 1'b1;
                end
            end
            
            S_END: begin
                // 重新开始
                if (start_key) begin
                    next_state = S_IDLE;
                    game_reset = 1'b1;
                end
            end
            
            default: next_state = S_IDLE;
        endcase
    end
    
endmodule