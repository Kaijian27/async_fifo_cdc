`timescale 1ns / 1ps

module sync_2ff #(
 parameter WIDTH = 4
)(
input wire clk,// Destination clock (接收端时钟)
input wire  rst_n, // Active-low reset (低电平有效复位)
input wire [WIDTH-1:0] din, // Asynchronous data input (跨域来的输入)
output reg[WIDTH-1:0] dout // Synchronized data output (同步后的输出)
);

// Intermediate register between stage 1 and stage 2
reg [WIDTH-1:0] q1;

 // - On active-low reset (!rst_n): reset both q1 and dout to 0
 // - On clock edge:
 //  Stage 1 (q1) samples din
 //  Stage 2 (dout) samples q1
always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
   q1 <= 0;
   dout <= 0 ;
  end else begin
   q1 <= din;
   dout <= q1;
  end
 end

endmodule