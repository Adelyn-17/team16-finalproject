`timescale 1ns / 1ns
module breakout_debounce #(
    // DEBOUNCE_TIME 由实例化时传入的值或默认值确定
    parameter DEBOUNCE_TIME = 10000 // 50MHz 时钟下约 200 us
)(
    input wire clk,             // 50MHz时钟
    input wire reset,           // 假设这里连接的是低电平有效的 sys_rst_n
    input wire left_in,         // 原始左按钮输入
    input wire right_in,        // 原始右按钮输入
    input wire start_in,        // 原始开始按钮输入
    output reg left_out,        // 去抖后左按钮输出
    output reg right_out,       // 去抖后右按钮输出
    output reg start_out        // 去抖后开始按钮输出
);

    // ===============================
    // 内部寄存器
    // ===============================
    reg [19:0] left_counter = 0;
    reg [19:0] right_counter = 0;
    reg [19:0] start_counter = 0;
    reg left_prev = 0;
    reg right_prev = 0;
    reg start_prev = 0;
    
    // ===============================
    // 左按钮去抖
    // 采用 低电平有效复位 (!reset)
    // ===============================
    always @(posedge clk or negedge reset) begin
        if (!reset) begin // 低电平有效复位
            left_out <= 0;
            left_prev <= 0;
            left_counter <= 0;
        end else begin
            left_prev <= left_in;
            
            if (left_in != left_prev) begin
                // 按钮状态变化，重置计数器
                left_counter <= 0;
            end else if (left_counter < DEBOUNCE_TIME) begin
                // 计数中，保持输出不变
                left_counter <= left_counter + 1;
            end else begin
                // 稳定后更新输出
                left_out <= left_in;
            end
        end
    end
    
    // ===============================
    // 右按钮去抖
    // ===============================
    always @(posedge clk or negedge reset) begin
        if (!reset) begin // 低电平有效复位
            right_out <= 0;
            right_prev <= 0;
            right_counter <= 0;
        end else begin
            right_prev <= right_in;
            
            if (right_in != right_prev) begin
                right_counter <= 0;
            end else if (right_counter < DEBOUNCE_TIME) begin
                right_counter <= right_counter + 1;
            end else begin
                right_out <= right_in;
            end
        end
    end
    
    // ===============================
    // 开始按钮去抖
    // ===============================
    always @(posedge clk or negedge reset) begin
        if (!reset) begin // 低电平有效复位
            start_out <= 0;
            start_prev <= 0;
            start_counter <= 0;
        end else begin
            start_prev <= start_in;
            
            if (start_in != start_prev) begin
                start_counter <= 0;
            end else if (start_counter < DEBOUNCE_TIME) begin // ⬅️ 已修正: } -> end, { -> begin
                start_counter <= start_counter + 1;
            end else begin // ⬅️ 已修正: } -> end, { -> begin
                start_out <= start_in;
            end
        end
    end
    
endmodule