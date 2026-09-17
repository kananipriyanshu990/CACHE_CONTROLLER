`timescale 1ns / 1ps                                     

module Cache_controller_tb;

      reg clk = 0;
      reg reset = 0;  
    
      reg CPU_request;
      reg CPU_write;
      reg [19:0]request_tag;
      reg [6:0]request_index;
      reg [4:0]request_offset;
      reg memory_ready;
    
      wire CPU_ready;
      wire metadata_write_en;
      wire [19:0]tag_data;
      wire valid_update;
      wire dirty_update;
      wire cache_write_en;
      wire [6:0]write_index;
      wire [4:0]write_offset;
      wire memory_read_request;
      wire memory_write_request;
      
         
      Cache_controller CACHE_CON (.CPU_ready(CPU_ready),
                                  .CPU_request(CPU_request),
                                  .CPU_write(CPU_write),
                                  .request_tag(request_tag),
                                  .request_index(request_index),
                                  .request_offset(request_offset),
                                  .metadata_write_en(metadata_write_en),
                                  .tag_data(tag_data),
                                  .valid_update(valid_update),
                                  .dirty_update(dirty_update),
                                  .cache_write_en(cache_write_en),
                                  .write_index(write_index),
                                  .write_offset(write_offset),
                                  .memory_read_request(memory_read_request),
                                  .memory_write_request(memory_write_request),
                                  .memory_ready(memory_ready),
                                  .clk(clk),
                                  .reset(reset));
    
      // Cache memory model
      reg [19:0]tag_mem[0:127];                            // 20 bit x 128 lines = 2560 bits/8 bits = 320 bytes 
      reg valid_mem[0:127];                                // 1 bit x 128 lines = 128 bits/8 bits = 16 bytes
      reg dirty_mem[0:127];                                // 1 bit x 128 lines = 128 bits/8 bits = 16 bytes
      reg [31:0]data_mem[0:127][0:7];                      // 32 bits x 8 words per line x 128 lines = 32768 bits/8 bits = 4096 bytes
    
      // Track last request index for metadata updates
      reg [6:0] last_index;
      reg [19:0] last_tag;
    
      always #5 clk = ~clk;
    
      always @(posedge clk) begin
        if (metadata_write_en) begin
          tag_mem[last_index]   <= tag_data;
          valid_mem[last_index] <= valid_update;
          dirty_mem[last_index] <= dirty_update;
        end
      end
    
      reg [31:0] main_mem [0:1023];                                          // 32 bits x 1024 words = 32768 bits/8 bits = 4096 byte RAM for testing
    
      always @(posedge clk) begin
        memory_ready <= 1'b0;
        if (memory_read_request) begin
          memory_ready <= 1'b1;
        end else if (memory_write_request) begin
          memory_ready <= 1'b1;
        end
      end
    
      // CPU read request task
      task cpu_read(input [19:0] tag, input [6:0] index, input [4:0] offset);
        begin
          @(posedge clk);
          CPU_request   = 1'b1;
          CPU_write     = 1'b0;
          request_tag   = tag;
          request_index = index;
          request_offset= offset;
          last_index    = index;
          last_tag      = tag;
          @(posedge clk);
          wait(CPU_ready);
          @(posedge clk);
          CPU_request = 1'b0;
        end
      endtask
    
      // CPU write request task
      task cpu_write(input [19:0] tag, input [6:0] index, input [4:0] offset, input [31:0] data);
        begin
          @(posedge clk);
          CPU_request    = 1'b1;
          CPU_write      = 1'b1;
          request_tag    = tag;
          request_index  = index;
          request_offset = offset;
          last_index     = index;
          last_tag       = tag;
          @(posedge clk);
          wait(CPU_ready);
          @(posedge clk);
          CPU_request = 1'b0;
        end
      endtask
    
      // Test input sequence
      initial begin
        for (int i=0; i<128; i++) begin                       
          tag_mem[i]   = 0;
          valid_mem[i] = 0;
          dirty_mem[i] = 0;
          for (int w=0; w<8; w++) data_mem[i][w] = 32'h0;
        end
        
        for (int i=0; i<1024; i++) main_mem[i] = i;           
    
        reset = 1'b0;                                         
        CPU_request = 1'b0;
        memory_ready = 1'b0;
        repeat (3) @(posedge clk);
        reset = 1'b1;
        repeat (2) @(posedge clk);
    
        $monitor("Time=%t, state=%b, CPU_ready=%b, valid_update=%b, dirty_update=%b, mem_rd=%b, mem_wr=%b",
                 $time, CACHE_CON.PRESENT_STATE, CPU_ready, valid_update, dirty_update,
                 memory_read_request, memory_write_request);
    
        //Read miss (clean line) 
        valid_mem[5] = 0;
        dirty_mem[5] = 0;
        cpu_read(20'h1, 7'd5, 5'd2);
    
        //Read hit 
        cpu_read(20'h1, 7'd5, 5'd3); 
    
        // Write hit (sets dirty line)
        cpu_write(20'h1, 7'd5, 5'd1, 32'hDE5AB0D7);   
    
        // Write miss with dirty eviction. Set index 6 as dirty and different tag to cause eviction
        tag_mem[6]   = 20'h2;
        valid_mem[6] = 1;
        dirty_mem[6] = 1;
        data_mem[6][0] = 32'h10AFB2D8;
        data_mem[6][1] = 32'h9AC5EB0;
        
        // deliberate miss, dirty writeback then refill
        cpu_write(20'h3, 7'd6, 5'd0, 32'h55555555);
    
        // Read miss with clean eviction 
        tag_mem[7]   = 20'h4;
        valid_mem[7] = 1;
        dirty_mem[7] = 0;
        cpu_read(20'h5, 7'd7, 5'd4);   
    
        #100 $finish;
      end
    
endmodule