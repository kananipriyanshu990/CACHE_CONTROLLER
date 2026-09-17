module Cache_datapath(input [6:0]CPU_index,   //Address decoder ports
                      input [2:0]CPU_offset,
                      
                      //CPU ports
                      output [31:0]CPU_requested_data,
                      input [31:0]CPU_write_data,
                      
                      //Controller ports
                      input [19:0]saved_tag,
                      input [6:0]saved_index,
                      input [2:0]word_counter,
                      input cache_read_mode,
                      input memory_addr_mode,
                      input cache_write_source,
                      
                      //Cache memory ports
                      output reg [6:0]cache_read_index,
                      output reg [2:0]cache_read_offset,
                      output reg [31:0]cache_write_data,
                      input [31:0]cache_read_data,
                      input [19:0]cache_tag,
                      
                      //Memory ports
                      output reg [31:0]memory_address,
                      output [31:0]memory_write_data,
                      input [31:0]memory_read_data);
    
    always @(*)begin
        if(cache_read_mode == 1'b0)begin
            cache_read_index = CPU_index;
            cache_read_offset = CPU_offset;
        end
        else begin
            cache_read_index = saved_index;
            cache_read_offset = word_counter;
        end
    end
    
    assign memory_write_data = cache_read_data;
    
    assign CPU_requested_data = cache_read_data;
    
    always@(*)begin
        if(cache_write_source == 1'b1)begin
            cache_write_data = memory_read_data;
        end
        else begin
            cache_write_data = CPU_write_data;
        end
    end
    
    always @(*)begin
        if(memory_addr_mode == 1'b1)begin
            memory_address = {cache_tag, saved_index, word_counter, 2'b00};
        end
        else begin
            memory_address = {saved_tag, saved_index, word_counter, 2'b00}; 
        end
    end
    
    
endmodule
