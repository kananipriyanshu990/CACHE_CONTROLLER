`timescale 1ns / 1ps                                     

module Cache_datapath_tb;

  reg [6:0]CPU_index;
  reg [2:0]CPU_offset;
  reg [31:0]CPU_write_data;
  reg [19:0]saved_tag;
  reg [6:0]saved_index;
  reg [2:0]word_counter;
  reg cache_read_mode;
  reg memory_addr_mode;
  reg cache_write_source;
  reg [31:0]cache_read_data;
  reg [19:0]cache_tag;
  reg [31:0]memory_read_data;

  wire [31:0]CPU_requested_data;
  wire [6:0]cache_read_index;
  wire [2:0]cache_read_offset;
  wire [31:0]cache_write_data;
  wire [31:0]memory_address;
  wire [31:0]memory_write_data;

  Cache_datapath dut (.CPU_index(CPU_index),
                      .CPU_offset(CPU_offset),
                      .CPU_requested_data(CPU_requested_data),
                      .CPU_write_data(CPU_write_data),
                      .saved_tag(saved_tag),
                      .saved_index(saved_index),
                      .word_counter(word_counter),
                      .cache_read_mode(cache_read_mode),
                      .memory_addr_mode(memory_addr_mode),
                      .cache_write_source(cache_write_source),
                      .cache_read_index(cache_read_index),
                      .cache_read_offset(cache_read_offset),
                      .cache_write_data(cache_write_data),
                      .cache_read_data(cache_read_data),
                      .cache_tag(cache_tag),
                      .memory_address(memory_address),
                      .memory_write_data(memory_write_data),
                      .memory_read_data(memory_read_data));


  initial begin
    $monitor("Time=%t | CPU_req_data=%h, cache_rd_idx=%d, cache_rd_off=%d, cache_wr_data=%h, mem_addr=%h, mem_wr_data=%h",
             $time, CPU_requested_data, cache_read_index, cache_read_offset, cache_write_data, memory_address, memory_write_data);
  end

  initial begin
    CPU_index = 7'd0;
      CPU_offset = 3'd0;
      CPU_write_data = 32'h0;
      saved_tag = 20'h0;
      saved_index = 7'd0;
      word_counter = 3'd0;
      cache_read_mode = 1'b0;
      memory_addr_mode = 1'b0;
      cache_write_source = 1'b0;
      cache_read_data = 32'h0;
      cache_tag = 20'h0;
      memory_read_data = 32'h0;
      
      #10;
   
      cache_read_mode = 1'b0;
      CPU_index = 7'd10;
      CPU_offset = 3'd5;
      saved_index = 7'd99;  
      word_counter = 3'd7;  
      cache_read_data = 32'h5217_0486; 
      #10;
      
      cache_read_mode = 1'b1;
      
      #20;

      memory_addr_mode = 1'b0;
      saved_tag = 20'hAB0E5;
      saved_index = 7'd42;
      word_counter = 3'd3;
      cache_tag = 20'h10207; // not used
      #10;

      memory_addr_mode = 1'b1;
      cache_tag = 20'hFEDCB;
      
      #20;

      cache_write_source = 1'b0;
      CPU_write_data = 32'hA5BC2DF7;
      memory_read_data = 32'h52FCA719; // not used
      #10;
      // cache_write_source = 1 => use memory_read_data
      cache_write_source = 1'b1;
      memory_read_data = 32'hD01AD258;
      
      #20;
    $finish;
  end

endmodule