`timescale 1ns / 1ps

module fifo_mem #(
    parameter DATASIZE = 8, // Memory data word width
    parameter ADDRSIZE = 4  // Number of address bits (Depth = 2^ADDRSIZE)
)(
    input  wire                wclk,
    input  wire                winc,   // Write increment / enable
    input  wire                wfull,  // Write full flag from wptr_full
    input  wire [ADDRSIZE-1:0] waddr,  // Write address from wptr_full
    input  wire [DATASIZE-1:0] wdata,  // Write data

    input  wire                rclk,
    input  wire                rinc,   // Read increment / enable
    input  wire                rempty, // Read empty flag from rptr_empty
    input  wire [ADDRSIZE-1:0] raddr,  // Read address from rptr_empty
    output wire [DATASIZE-1:0] rdata   // Read data output
);

    localparam DEPTH = 1 << ADDRSIZE;

    // ==========================================================================
    // Declare the internal memory array
    // ==========================================================================
    reg [DATASIZE-1:0] mem [0:DEPTH-1];


    // ==========================================================================
    // Implement the synchronous write logic
    // - Sensitivity: posedge wclk
    // - Condition to write: write requested (winc) AND FIFO is not full (!wfull)
    // - Action: write wdata into mem[waddr]
    // ==========================================================================
    always @(posedge wclk) begin
        if(winc && !wfull)begin
            mem[waddr] <=wdata;
        end
    end


    // ==========================================================================
    // Implement read data assignment
    // ==========================================================================
    assign rdata = mem[raddr];

endmodule