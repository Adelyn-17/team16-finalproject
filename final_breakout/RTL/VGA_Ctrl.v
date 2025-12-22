`timescale 1ns/1ps

module VGA_Ctrl(
    input  wire        vga_clk,     
    input  wire        sys_rst_n,   
    input  wire [15:0] pix_data,    
    
    output wire [9:0]  pix_x,       
    output wire [9:0]  pix_y,       
    output wire        hsync,       
    output wire        vsync,       
    output wire [15:0] rgb          
);

// 时序参数定义 
// 水平时序（像素时钟周期）
localparam H_SYNC_PULSE  = 10'd96;   // 同步脉冲宽度
localparam H_BACK_PORCH  = 10'd40;   // 后沿消隐
localparam H_LEFT_BORDER = 10'd8;    // 左边框
localparam H_ACTIVE      = 10'd640;  // 有效显示区域
localparam H_RIGHT_BORDER= 10'd8;    // 右边框  
localparam H_FRONT_PORCH = 10'd8;    // 前沿消隐
localparam H_TOTAL_CYCLES= 10'd800;  // 总周期

// 垂直时序（行数）
localparam V_SYNC_PULSE  = 10'd2;    // 同步脉冲宽度
localparam V_BACK_PORCH  = 10'd25;   // 后沿消隐
localparam V_TOP_BORDER  = 10'd8;    // 上边框
localparam V_ACTIVE      = 10'd480;  // 有效显示区域
localparam V_BOTTOM_BORDER=10'd8;    // 下边框
localparam V_FRONT_PORCH = 10'd2;    // 前沿消隐
localparam V_TOTAL_LINES = 10'd525;  // 总行数

// 边界计算 
localparam H_SYNC_END   = H_SYNC_PULSE;
localparam H_BP_END     = H_SYNC_END + H_BACK_PORCH;
localparam H_BORDER_END = H_BP_END + H_LEFT_BORDER;
localparam H_ACTIVE_END = H_BORDER_END + H_ACTIVE;
localparam H_FP_START   = H_ACTIVE_END + H_RIGHT_BORDER;

localparam V_SYNC_END   = V_SYNC_PULSE;
localparam V_BP_END     = V_SYNC_END + V_BACK_PORCH;
localparam V_BORDER_END = V_BP_END + V_TOP_BORDER;
localparam V_ACTIVE_END = V_BORDER_END + V_ACTIVE;
localparam V_FP_START   = V_ACTIVE_END + V_BOTTOM_BORDER;

// 内部信号
reg [9:0] h_counter;    // 水平像素计数器 (0~799)
reg [9:0] v_counter;    // 垂直行计数器   (0~524)

wire in_h_active_region;  // 水平有效显示区域
wire in_v_active_region;  // 垂直有效显示区域
wire in_active_display;   // 有效显示区域
wire data_request_region; // 像素数据请求区域


always @(posedge vga_clk or negedge sys_rst_n) begin
    if (!sys_rst_n) begin
        h_counter <= 10'd0;
    end else begin
        if (h_counter == H_TOTAL_CYCLES - 1'd1) begin
            h_counter <= 10'd0;  
        end else begin
            h_counter <= h_counter + 1'd1;  
        end
    end
end


always @(posedge vga_clk or negedge sys_rst_n) begin
    if (!sys_rst_n) begin
        v_counter <= 10'd0;
    end else begin
        if (h_counter == H_TOTAL_CYCLES - 1'd1) begin
            if (v_counter == V_TOTAL_LINES - 1'd1) begin
                v_counter <= 10'd0;  
            end else begin
                v_counter <= v_counter + 1'd1;  
            end
        end
    end
end

 
// 水平同步：在同步脉冲期间为高电平
assign hsync = (h_counter < H_SYNC_PULSE) ? 1'b1 : 1'b0;

// 垂直同步：在同步脉冲期间为高电平  
assign vsync = (v_counter < V_SYNC_PULSE) ? 1'b1 : 1'b0;

// 区域判断
assign in_h_active_region = (h_counter >= H_BORDER_END) && 
                           (h_counter < H_ACTIVE_END);

// 垂直有效区域：同步+后沿+边框之后，有效显示区域之内
assign in_v_active_region = (v_counter >= V_BORDER_END) && 
                           (v_counter < V_ACTIVE_END);

// 完整有效显示区域
assign in_active_display = in_h_active_region && in_v_active_region;

// 数据请求区域：比显示区域提前一个时钟周期，用于流水线操作
assign data_request_region = ((h_counter >= H_BORDER_END - 1'd1) && 
                             (h_counter < H_ACTIVE_END - 1'd1)) &&
                             in_v_active_region;

// 坐标生成 
assign pix_x = data_request_region ? 
              (h_counter - (H_BORDER_END - 1'd1)) : 10'h3FF;
              
assign pix_y = data_request_region ? 
              (v_counter - V_BORDER_END) : 10'h3FF;

// RGB输出
// 在有效显示区域内输出像素数据，否则输出黑色
assign rgb = in_active_display ? pix_data : 16'h0000;

endmodule