`timescale 1ns / 1ns
module breakout_debounce #(
    
    parameter DEBOUNCE_TIME = 10000
)(
    input wire clk,
    input wire reset,
    input wire left_in,
    input wire right_in,
    input wire start_in,
    output reg left_out,
    output reg right_out,
    output reg start_out
);


    reg [19:0] left_counter = 0;
    reg [19:0] right_counter = 0;
    reg [19:0] start_counter = 0;
    reg left_prev = 0;
    reg right_prev = 0;
    reg start_prev = 0;
    

    always @(posedge clk or negedge reset) begin
        if (!reset) begin 
            left_out <= 0;
            left_prev <= 0;
            left_counter <= 0;
        end else begin
            left_prev <= left_in;
            
            if (left_in != left_prev) begin

                left_counter <= 0;
            end else if (left_counter < DEBOUNCE_TIME) begin

                left_counter <= left_counter + 1;
            end else begin

                left_out <= left_in;
            end
        end
    end

    always @(posedge clk or negedge reset) begin
        if (!reset) begin 
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
    

    always @(posedge clk or negedge reset) begin
        if (!reset) begin 
            start_out <= 0;
            start_prev <= 0;
            start_counter <= 0;
        end else begin
            start_prev <= start_in;
            
            if (start_in != start_prev) begin
                start_counter <= 0;
            end else if (start_counter < DEBOUNCE_TIME) begin
                start_counter <= start_counter + 1;
            end else begin 
                start_out <= start_in;
            end
        end
    end
    

endmodule
