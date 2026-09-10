// ==============================================================================
// Module: async_fifo_tb
// Description: Self-Checking Testbench for Asynchronous FIFO
// Author: Tan Kai Jian
// ==============================================================================

`timescale 1ns / 1ps

module async_fifo_tb;

    parameter DSIZE = 8;
    parameter ASIZE = 4; 
    localparam DEPTH = 1 << ASIZE; // 0_0001 -> 1_0000(16), (1 * 2^4 = 16) 

    // --- Write Domain Signals ---
    reg             wclk;
    reg             wrst_n;
    reg             winc;
    reg  [DSIZE-1:0] wdata;
    wire            wfull;

    // --- Read Domain Signals ---
    reg             rclk;
    reg             rrst_n;
    reg             rinc;
    wire [DSIZE-1:0] rdata;
    wire            rempty;

    // Golden model queue for self-checking
    reg [DSIZE-1:0] golden_queue [0:255];
    integer wr_idx = 0;
    integer rd_idx = 0;
    integer err_count = 0;

    async_fifo_top #(
        .DSIZE(DSIZE),
        .ASIZE(ASIZE)
    ) dut (
        .wclk   (wclk),
        .wrst_n (wrst_n),
        .winc   (winc),
        .wdata  (wdata),
        .wfull  (wfull),
        .rclk   (rclk),
        .rrst_n (rrst_n),
        .rinc   (rinc),
        .rdata  (rdata),
        .rempty (rempty)
    );

    // ==========================================================================
    // Clock Generation (Two Asynchronous Clocks)
    // - wclk: 100 MHz (Period = 10ns -> Toggle every 5ns)
    // - rclk: 40 MHz  (Period = 25ns -> Toggle every 12.5ns)
    // ==========================================================================
    initial wclk = 0;
    always #5 wclk = ~wclk;

    initial rclk = 0;
    always #12.5 rclk = ~rclk;

    // ==========================================================================
    // TODO 1: Implement write_byte Task
    //input: The direction of the variable entering the task
    //[DSIZE-1:0]: The bit-width (size) of that variable.
    // ==========================================================================
    task write_byte(input [DSIZE-1:0] in_data); 
        begin
            @(negedge wclk);
            if(wfull)begin
                $display("[WARNING] FIFO is FULL! Cannot write data: 0x%0h", in_data);
            end
            else begin
                winc <= 1'b1;
                wdata <= in_data;
                
                @(posedge wclk);

                golden_queue[wr_idx] = in_data;
                wr_idx = wr_idx + 1;

                @(negedge wclk);
                winc <= 1'b0;    // 拉低写使能，结束本次写入
                $display("[WRITE] Data = 0x%0h", in_data);
            end
            
            
        end
    endtask

    // ==========================================================================
    // TODO 2: Implement read_byte Task
    // ==========================================================================
    task read_byte();
        reg [DSIZE-1:0] sampled_data;
        begin
            @(negedge rclk);
            if(rempty)begin
                $display("[WARNING] FIFO is EMPTY! Cannot read data.");
            end
            else begin
            rinc <= 1'b1;   // 1. 拉高enable
            
            // 当前 raddr 指向的就是要消费的数据
            sampled_data = rdata;

            @(posedge rclk);
            #1;
            if (sampled_data !== golden_queue[rd_idx]) begin
                    $display("[ERROR] Data mismatch! Read: 0x%0h, Expected: 0x%0h", 
                    sampled_data, 
                    golden_queue[rd_idx]
                    );
                    err_count = err_count + 1;
                end else begin
                    $display("[PASS] Successfully read: 0x%0h", sampled_data);
            end
            rd_idx = rd_idx + 1;
            
            @(negedge rclk);
            rinc <= 1'b0;    // 拉低写使能，结束本次写入

            end

        end
    endtask


    // ==========================================================================
    /* TODO 3: Stimulus Sequence
    reset
    ↓
    write 16 data
    ↓
    check full
    ↓
    try overflow
    ↓
    read 16 data
    ↓
    compare every read
    ↓
    check empty
    ↓
    try underflow
    ↓
    PASS/FAIL
    */
    // ==========================================================================
    integer i;
    initial begin
        // Waveform dump for EDA Playground / GTKWave
        $dumpfile("async_fifo_tb.vcd");
        $dumpvars(0, async_fifo_tb);

        // Initialize control signals
        winc   = 0;
        wdata  = 0;
        rinc   = 0;
        wrst_n = 0;
        rrst_n = 0;

        // Reset sequence
        #40;
        wrst_n = 1;
        rrst_n = 1;
        #20;

        $display("--------------------------------------------------");
        $display("[TEST START] Starting Asynchronous FIFO Verification");
        $display("--------------------------------------------------");

        

        // Scenario 1: 连续写入 16 个数据，直到 FIFO 写满
        $display("\n--- Test 1: Writing 16 bytes to fill FIFO ---");
        for (i = 0; i < DEPTH; i = i + 1) begin
            write_byte(i + 8'hA0); // 写入 0xA0, 0xA1, 0xA2 ...
        end

        // 等两个写时钟周期观察 wfull 是否拉高
        repeat(2) @(posedge wclk);

        // Scenario 2: 满状态下尝试强行多写一次（验证保护机制）
        $display("\n--- Test 2: Writing to FULL FIFO (Overflow check) ---");
        write_byte(8'hFF);

        // Scenario 3: 连续读出所有 16 个数据，直到 FIFO 读空
        $display("\n--- Test 3: Reading 16 bytes until empty ---");
        for (i = 0; i < DEPTH; i = i + 1) begin
            read_byte();
        end

        // 等两个读时钟周期观察 rempty 是否拉高
        repeat(2) @(posedge rclk);

        // Scenario 4: 空状态下尝试强行多读一次（验证保护机制）
        $display("\n--- Test 4: Reading from EMPTY FIFO (Underflow check) ---");
        read_byte();

        #100;
        $display("--------------------------------------------------");
        if (err_count == 0)
            $display("[TEST PASSED] All data matched! No CDC data loss.");
        else
            $display("[TEST FAILED] Total errors encountered: %0d", err_count);
        $display("--------------------------------------------------");
        $finish;
    end

endmodule




