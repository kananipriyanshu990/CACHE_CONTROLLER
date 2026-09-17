`timescale 1ns / 1ps                                    

module Cache_memory_tb;                                  // Testbench module (no ports)

   logic clk, reset;                                     // Clock and active‑low reset
   logic [6:0]read_index, write_index;                   // 7‑bit index for read/write
   logic [2:0]read_offset, write_offset;                 // 5‑bit offset within a cache line
   logic write_en, metadata_write_en;                    // Enable data write and metadata write
   logic [31:0]write_data;                               // Data word to write
   logic [19:0]tag_in;                                   // Tag to write (20 bits)
   logic valid_in, dirty_in;                             // Valid and dirty flags to write

   wire [31:0]read_data;                                 // Data word read out
   wire [19:0]current_tag; 
   wire current_valid, current_dirty;                    // Output metadata (tag, valid, dirty)

   Cache_memory CACHE_MEM (.clk(clk),                          // Instantiate DUT, connect all ports
                     .reset(reset),
                     .read_index(read_index),
                     .read_offset(read_offset),
                     .write_en(write_en),
                     .write_index(write_index),
                     .write_offset(write_offset),
                     .write_data(write_data),
                     .metadata_write_en(metadata_write_en),
                     .tag_in(tag_in),
                     .valid_in(valid_in),
                     .dirty_in(dirty_in),
                     .read_data(read_data),
                     .current_tag(current_tag),
                     .current_valid(current_valid),
                     .current_dirty(current_dirty));

   initial clk = 0;                                      // Initialize clock to 0
   always #5 clk = ~clk;                                 // Toggle every 5 ns -> 100 MHz clock

   initial begin                                         // Monitor all relevant signals
      $monitor("t=%0t | rst=%b | wr_en=%b meta_en=%b | wr_idx=%0d wr_off=%0d wr_data=0x%08H tag_in=0x%05H v=%b d=%b | rd_idx=%0d rd_off=%0d || read_data=0x%08H cur_tag=%b cur_v=%b cur_d=%b",
               $time,
               reset,
               write_en, metadata_write_en,
               write_index, write_offset, write_data, tag_in, valid_in, dirty_in,
               read_index, read_offset,
               read_data, current_tag, current_valid, current_dirty);
   end

   task do_reset;                                        // Task to assert reset synchronously
      reset = 1'b0;                                      // Deassert reset (active low)
      @(posedge clk); #1;                                // Wait one clock edge + small delta
      reset = 1'b1;                                      // Assert reset (active low)
   endtask

   task write_cache(input [6:0] index, input [2:0] offset, input [31:0] data);
                                                         // Write data word to cache
      write_en = 1'b1;  metadata_write_en = 1'b0;        // Enable data write, disable metadata write
      write_index = index;  write_offset = offset;  write_data = data;
      @(posedge clk); #1;                                // Drive during one clock cycle
      write_en = 1'b0;                                   // De‑assert after write
   endtask

   task write_metadata(input [6:0] index, input [19:0] tag, input valid, input dirt);
                                                         // Write tag/valid/dirty for a given index
      metadata_write_en = 1'b1;  write_en = 1'b0;        // Enable metadata write, disable data write
      write_index = index;  tag_in = tag;  valid_in = valid;  dirty_in = dirt;
      @(posedge clk); #1;                                // Drive for one clock cycle
      metadata_write_en = 1'b0;                          // De‑assert after write
   endtask

   task read_cache(input [6:0] index, input [2:0] offset);
                                                         // Read data and metadata from cache
      read_index = index;  read_offset = offset;         // Set read address; outputs update combinationaly
      #1;                                                // Small delay to let signals settle
   endtask

   initial begin                                         // Main stimulus sequence
      {write_en, metadata_write_en} = 2'b00;             // Initially disable both write enables
      {write_index, write_offset, write_data} = 0;       // Clear write address/data
      {tag_in, valid_in, dirty_in} = 0;                  // Clear metadata inputs
      {read_index, read_offset} = 0;                     // Clear read address
      reset = 1'b1;                                      // Start with reset asserted (active low)

      do_reset;                                          // Apply reset pulse

      read_cache(7'd0, 3'd0);                            // Read from index 0, offset 0 (should be zero after reset)
      #10;

      write_cache(7'd0, 3'd0, 32'hBE5D_0A2F);            // Write data to index0 offset0
      read_cache(7'd0, 3'd0);                            // Read back to verify
      #10;

      write_metadata(7'd0, 20'hA1C75, 1'b1, 1'b0);       // Write tag, valid=1, dirty=0 for index0
      read_cache(7'd0, 3'd0);                            // Read metadata (data unchanged)
      #10;

      write_cache(7'd5, 3'd3, 32'hCA0D_1731);            // Write data to another index/offset
      write_metadata(7'd5, 20'h12345, 1'b1, 1'b1);       // Set metadata for that index
      read_cache(7'd5, 3'd3);                            // Read back both data and metadata
      #10;

      write_cache(7'd127, 3'd7, 32'hF02A_BC5E);          // Write data to last index, offset 7
      write_metadata(7'd127, 20'hA0B14, 1'b1, 1'b1);     // Set metadata for same index
      read_cache(7'd127, 3'd7);                          // Read back
      #10;

      read_cache(7'd63, 3'd4);                           // Read an unwritten location (should be zero)
      #10;

      do_reset;                                          // Reset the cache
      read_cache(7'd0, 3'd0);                            // Verify data cleared
      #10;
      read_cache(7'd5, 'd3);                            // Verify metadata cleared as well
      #10;

      $finish;                                           // End simulation
   end

endmodule