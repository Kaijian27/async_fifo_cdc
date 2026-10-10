`timescale 1ns / 1ps

module wptr_full #(
    parameter ADDRSIZE = 4
)(
    input  wire                wclk,
    input  wire                wrst_n,     // Active-low write domain reset
    input  wire                winc,       // Write enable
    input  wire [ADDRSIZE:0]   wq2_rptr,   // Synchronized read pointer from rclk domain (Gray code)
    output reg                 wfull,      // Full status flag
    output wire [ADDRSIZE-1:0] waddr,      // Memory write address
    output reg  [ADDRSIZE:0]   wptr        // Write pointer to rclk domain (Gray code)
);

    reg  [ADDRSIZE:0] wbin;
    wire [ADDRSIZE:0] wbinnext;
    wire [ADDRSIZE:0] wgraynext;
    wire              wfull_val;

    // ==========================================================================
    // Memory Write Address Assignment
    // Extract lower ADDRSIZE bits of wbin for waddr
    // ==========================================================================
    assign waddr = wbin[ADDRSIZE-1:0];


    // ==========================================================================
    // Binary Pointer Next-Value Logic
    // ==========================================================================
    assign wbinnext = wbin + (winc & !wfull);


    // ==========================================================================
    // Binary to Gray Code Conversion
    // ==========================================================================
    assign wgraynext = (wbinnext >>1) ^ wbinnext;


    // ==========================================================================
    //  Full Flag Evaluation (The Classic Cummings Full Logic)
    // ==========================================================================
    assign wfull_val =(wgraynext == {~wq2_rptr[ADDRSIZE:ADDRSIZE-1], wq2_rptr[ADDRSIZE-2:0]});

    // ==========================================================================
    // Sequential Updates
    // ==========================================================================
    always @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n) begin
            // TODO: Reset states (wbin, wptr, wfull)
            wbin <= 0;
            wptr <= 0;
            wfull <= 1'b0;
        end else begin
            wbin <= wbinnext;
            wptr <= wgraynext;
            wfull <= wfull_val;
        end
    end

endmodule