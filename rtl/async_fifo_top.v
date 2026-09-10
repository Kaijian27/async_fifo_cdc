// ==============================================================================
// Module: async_fifo
// Description: Top-Level Asynchronous FIFO with CDC Synchronizers
// Author: Tan Kai Jian
// ==============================================================================

`timescale 1ns / 1ps

module async_fifo_top #(
    parameter DSIZE = 8, // Data bus width
    parameter ASIZE = 4  // Address pointer width (Depth = 2^ASIZE)
)(
    // --- Write Domain Signals ---
    input  wire             wclk,
    input  wire             wrst_n,
    input  wire             winc,
    input  wire [DSIZE-1:0] wdata,
    output wire             wfull,

    // --- Read Domain Signals ---
    input  wire             rclk,
    input  wire             rrst_n,
    input  wire             rinc,
    output wire [DSIZE-1:0] rdata,
    output wire             rempty
);

    // Internal interconnect wires
    wire [ASIZE-1:0] waddr, raddr;
    wire [ASIZE:0]   wptr, rptr;
    wire [ASIZE:0]   wq2_rptr, rq2_wptr;

    // ==========================================================================
    // TODO 1: Instantiate Dual-Port RAM (fifo_mem)
    // ==========================================================================
    fifo_mem #(
    .DATASIZE(DSIZE),
    .ADDRSIZE(ASIZE)
    )inst_fifo_mem(
        .wclk(wclk), .winc(winc), .wfull(wfull), .waddr(waddr), .wdata(wdata),
        .rclk(rclk), .rinc(rinc), .rempty(rempty), .raddr(raddr), .rdata(rdata)
    );


    // ==========================================================================
    // TODO 2: Instantiate Read Pointer to Write Domain Synchronizer (sync_2ff)
    // ==========================================================================
    sync_2ff #(.WIDTH(ASIZE + 1) 
    )inst_sync_r2w (
    .clk(wclk), .rst_n(wrst_n), .din(rptr), .dout(wq2_rptr)
    );

    // ==========================================================================
    // TODO 3: Instantiate Write Pointer to Read Domain Synchronizer (sync_2ff)
    // ==========================================================================
    sync_2ff #(.WIDTH(ASIZE + 1) 
    )inst_sync_w2r (
    .clk(rclk), .rst_n(rrst_n), .din(wptr), .dout(rq2_wptr)
    );

    // ==========================================================================
    // TODO 4: Instantiate Read Pointer & Empty Logic (rptr_empty)
    // - Connect rclk, rrst_n, rinc, rq2_wptr, rempty, raddr, rptr
    // ==========================================================================
    rptr_empty #(
    .ADDRSIZE(ASIZE)
    ) inst_rptr_empty(
    .rclk(rclk), .rrst_n(rrst_n),.rinc(rinc), .rq2_wptr(rq2_wptr), .rempty(rempty), .raddr(raddr), .rptr(rptr)
    );

    // ==========================================================================
    // TODO 5: Instantiate Write Pointer & Full Logic (wptr_full)
    // - Connect wclk, wrst_n, winc, wq2_rptr, wfull, waddr, wptr
    // ==========================================================================
    wptr_full #(
    .ADDRSIZE(ASIZE)
    )inst_wptr_full(
    .wclk(wclk), .wrst_n(wrst_n), .winc(winc), .wq2_rptr(wq2_rptr), .wfull(wfull), 
    .waddr(waddr), .wptr(wptr)
    );

endmodule