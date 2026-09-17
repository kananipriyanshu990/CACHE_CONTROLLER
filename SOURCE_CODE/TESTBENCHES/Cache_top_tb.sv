`timescale 1ns / 1ps                                            // Simulation time unit and precision

module Cache_top_tb;                                            // Testbench module (no ports)

  reg clk = 0;                                                  // Clock signal, initial 0
  reg reset = 0;                                                // Active-low reset, initial 0

  reg CPU_request;                                              // CPU request signal
  reg CPU_write;                                                // 1=write, 0=read
  reg [31:0]CPU_addr;                                           // CPU address
  reg [31:0]CPU_write_data;                                     // Data to write
  wire CPU_ready;                                               // CPU ready from cache
  wire [31:0]CPU_requested_data;                                // Data returned to CPU

  wire memory_read_request;                                     // Memory read request from cache
  wire memory_write_request;                                    // Memory write request from cache
  wire [31:0]memory_address;                                    // Address sent to memory
  wire [31:0]memory_write_data;                                 // Data to write to memory
  reg  [31:0]memory_read_data;                                  // Data read from memory (driven by testbench)
  reg memory_ready;                                             // Memory ready signal (driven by testbench)

  Cache_top CACHE_TOP (.clk(clk),                               // Instantiate DUT, connect all ports
                       .reset(reset),
                       .CPU_requested_data(CPU_requested_data),
                       .CPU_ready(CPU_ready),
                       .CPU_request(CPU_request),
                       .CPU_write(CPU_write),
                       .CPU_addr(CPU_addr),
                       .CPU_write_data(CPU_write_data),
                       .memory_read_request(memory_read_request),
                       .memory_write_request(memory_write_request),
                       .memory_address(memory_address),
                       .memory_write_data(memory_write_data),
                       .memory_read_data(memory_read_data),
                       .memory_ready(memory_ready));

 
  reg [31:0] main_mem [0:1023];                                  // Simple memory array of 1024 words
  reg mem_ready_reg;                                             // Internal register for memory ready pulse

   initial begin                                                  // Clock generation
     forever #5 clk = ~clk;                                      // Time period: 10ns
   end
     
  initial begin                                                  // Initialize memory with pattern
    for (int i=0; i<1024; i++) main_mem[i] = i;                  // Each word holds its own address value
  end

  // Memory response: generate one-cycle pulse for each request
  always @(posedge clk or negedge reset) begin                   // Memory controller behavior
    if (!reset) begin                                            // On reset, clear memory signals
      memory_ready   <= 1'b0;
      mem_ready_reg  <= 1'b0;
    end 
    else begin                                                   // Normal operation
      memory_ready <= 1'b0;                                      // Default: no memory ready
      if (memory_read_request && !mem_ready_reg) begin           // Read request not yet serviced
        memory_read_data <= main_mem[memory_address >> 2];       // Fetch data from memory (word address)
        memory_ready <= 1'b1;                                    // Assert ready
        mem_ready_reg <= 1'b1;                                   // Mark that request is being serviced
      end 
      else if (memory_write_request && !mem_ready_reg) begin     // Write request
        main_mem[memory_address >> 2] <= memory_write_data;      // Store data
        memory_ready <= 1'b1;                                    // Assert ready
        mem_ready_reg <= 1'b1;                                   // Mark serviced
      end 
      else if (mem_ready_reg) begin                              // If we just serviced, clear the flag
        mem_ready_reg <= 1'b0;
      end
    end
  end

  initial begin                                                  // Monitor CPU interface signals
    $monitor("CPU: time=%t, req=%b, wr=%b, addr=%h, data_in=%h, ready=%b, data_out=%h",
             $time, CPU_request, CPU_write, CPU_addr, CPU_write_data,
             CPU_ready, CPU_requested_data);
  end
      
  initial begin                                                  // Monitor memory interface signals
    $monitor("MEM: time=%t, rd_req=%b, wr_req=%b, addr=%h, wr_data=%h, rd_data=%h, ready=%b",
             $time, memory_read_request, memory_write_request,
             memory_address, memory_write_data, memory_read_data, memory_ready);
  end

  task cpu_read(input [31:0] addr);                              // Task to perform a CPU read
    begin
      @(posedge clk);                                            // Wait for clock edge
      CPU_request = 1'b1;                                        // Assert request
      CPU_write = 1'b0;                                          // Read operation
      CPU_addr = addr;                                           // Set address
      CPU_write_data = 32'h0;                                    // Don't care for read
      @(posedge clk);                                            // Wait one cycle
      wait(CPU_ready);                                           // Wait until cache signals ready
      @(posedge clk);                                            // Wait one more edge
      CPU_request = 1'b0;                                        // Deassert request
    end
  endtask

  task cpu_write(input [31:0] addr, input [31:0] data);          // Task to perform a CPU write
    begin
      @(posedge clk);                                            // Wait for clock edge
      CPU_request = 1'b1;                                        // Assert request
      CPU_write = 1'b1;                                          // Write operation
      CPU_addr = addr;                                           // Set address
      CPU_write_data = data;                                     // Set data
      @(posedge clk);                                            // Wait one cycle
      wait(CPU_ready);                                           // Wait until cache ready
      @(posedge clk);                                            // Wait one more edge
      CPU_request = 1'b0;                                        // Deassert request
    end
  endtask

  task apply_reset;                                              // Task to apply active-low reset
    begin
      reset = 1'b0;                                              // Assert reset
      CPU_request = 1'b0;                                        // Clear CPU request
      CPU_write = 1'b0;                                          // Clear write
      CPU_addr = 32'h0;                                          // Clear address
      CPU_write_data = 32'h0;                                    // Clear data
      memory_read_data = 32'h0;                                  // Clear memory read data
      memory_ready = 1'b0;                                       // Clear memory ready
      repeat (3) @(posedge clk);                                 // Hold reset for 3 cycles
      reset = 1'b1;                                              // Deassert reset
      repeat (2) @(posedge clk);                                 // Wait two more cycles for stable state
    end
  endtask

  
  initial begin                                                  // Main test sequence
    apply_reset;                                                 // Initialize system

    //Read miss (clean)
    cpu_read(32'h0000_0040);                                     // Execute read

    //Test 2: Read hit 
    cpu_read(32'h0000_0040);                                     // Execute read again

    //Test 3: Write hit 
    cpu_write(32'h0000_0040, 32'hD01AB5E7);                      // Write data

    //Read another address in same index but different tag (miss with dirty eviction)
    cpu_read(32'h1000_0040);                                     // Execute read, causing writeback

    //Read miss with clean eviction
    cpu_read(32'h2000_0040);                                     // Execute read, clean eviction

    //Write miss (clean) 
    cpu_write(32'h3000_0040, 32'h39557258);                      // Execute write miss

    #100 $finish;                                                // End simulation after delay
  end

endmodule