// ==============================================================================
// Module: rptr_empty
// Description: Read pointer generation and empty flag logic for Async FIFO
// Author: Tan Kai Jian
// ==============================================================================

`timescale 1ns / 1ps

module rptr_empty #(
    parameter ADDRSIZE = 4
)(
    input  wire                rclk,
    input  wire                rrst_n,     // Active-low read domain reset
    input  wire                rinc,       // Read enable
    input  wire [ADDRSIZE:0]   rq2_wptr,   // Synchronized write pointer from wclk domain (Gray code)
    output reg                 rempty,     // Empty status flag
    output wire [ADDRSIZE-1:0] raddr,      // Memory read address
    output reg  [ADDRSIZE:0]   rptr        // Read pointer to wclk domain (Gray code)
);

    reg  [ADDRSIZE:0] rbin;
    wire [ADDRSIZE:0] rbinnext;
    wire [ADDRSIZE:0] rgraynext;
    wire              rempty_val;

    // ==========================================================================
    // TODO 1: Memory Address Assignment
    // ==========================================================================
    assign raddr = rbin[ADDRSIZE-1:0]; // raddr 给 RAM 当读地址，只拿低位


    // ==========================================================================
    // TODO 2: Binary Pointer Next-Value Logic
    // ==========================================================================
    assign rbinnext = rbin + (rinc & !rempty); //rbin(next-value), will put back rbin


    // ==========================================================================
    // TODO 3: Binary to Gray Code Conversion
    // ==========================================================================
     assign rgraynext = (rbinnext >>1) ^ rbinnext; // graycode used for sending 


    // ==========================================================================
    // TODO 4: Empty Flag Evaluation
    // Compare next Gray pointer (rgraynext) with synchronized write pointer (rq2_wptr)
    // ==========================================================================
    assign rempty_val = (rgraynext == rq2_wptr); // 提前对比


    // ==========================================================================
    // TODO 5: Sequential Updates
    // ==========================================================================
    always @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) begin
            rbin   <= 0;
            rptr   <= 0;
            rempty <= 1'b1;// 复位时 FIFO 本身就是空的
        end else begin
            rbin   <= rbinnext; //next cycle
            rptr   <= rgraynext; //next cycle
            rempty <= rempty_val;
        end
    end

endmodule