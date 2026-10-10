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
                winc <= 1'b0;    
                $display("[WRITE] Data = 0x%0h", in_data);
            end
            
            
        end
    endtask

    task read_byte();
        reg [DSIZE-1:0] sampled_data;
        begin
            @(negedge rclk);
            if(rempty)begin
                $display("[WARNING] FIFO is EMPTY! Cannot read data.");
            end
            else begin
            rinc <= 1'b1;   
            
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
            rinc <= 1'b0;    

            end

        end
    endtask


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

        
        // Scenario 1: Write 16 bytes to fill the FIFO and check FULL flag
        $display("\n--- Test 1: Writing 16 bytes to fill FIFO ---");
        for (i = 0; i < DEPTH; i = i + 1) begin
            write_byte(i + 8'hA0); 
        end

       repeat(2) @(posedge wclk);
       if (wfull !== 1'b1) begin
            $display("[ERROR] FIFO should be FULL after 16 writes!");
            err_count = err_count + 1;
        end else begin
            $display("[PASS] FIFO FULL flag asserted correctly.");
        end

        // Scenario 2: Verify write is blocked when FIFO is FULL
        $display("\n--- Test 2: Overflow check ---");

        @(negedge wclk);
        winc = 1'b1;
        wdata = 8'hFF;

        @(posedge wclk);
        #1;

        if (dut.inst_wptr_full.wbin !== DEPTH) begin
            $display("[ERROR] Write pointer changed while FULL!");
            err_count = err_count + 1;
        end else begin
            $display("[PASS] Overflow prevented.");
        end

        @(negedge wclk);
        winc = 1'b0;

        // Scenario 3: Read 16 bytes until FIFO is empty and check EMPTY flag
        $display("\n--- Test 3: Reading 16 bytes until empty ---");
        for (i = 0; i < DEPTH; i = i + 1) begin
            read_byte();
        end

        repeat(2) @(posedge rclk);

        if (rempty !== 1'b1) begin
            $display("[ERROR] FIFO should be EMPTY after 16 reads!");
            err_count = err_count + 1;
        end else begin
            $display("[PASS] FIFO EMPTY flag asserted correctly.");
        end

        // Scenario 4: Verify read is blocked when FIFO is EMPTY
        $display("\n--- Test 4: Underflow check ---");

        @(negedge rclk);
        rinc = 1'b1;

        @(posedge rclk);
        #1;

        if (dut.inst_rptr_empty.rbin !== DEPTH) begin
            $display("[ERROR] Read pointer changed while EMPTY!");
            err_count = err_count + 1;
        end else begin
            $display("[PASS] Underflow prevented.");
        end

        @(negedge rclk);
        rinc = 1'b0;

        #100;
        $display("--------------------------------------------------");
        if (err_count == 0)
            $display("[TEST PASSED] All directed FIFO tests passed!");
        else
            $display("[TEST FAILED] Total errors encountered: %0d", err_count);
        $display("--------------------------------------------------");
        $finish;
    end

endmodule




