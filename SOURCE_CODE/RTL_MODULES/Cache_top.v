//add ports for direct access to RAM in the end
module Cache_top(input clk,
                 input reset,
                 
                 //CPU interface
                 output [31:0]CPU_requested_data,
                 output CPU_ready,
                 input CPU_request,
                 input CPU_write,
                 input [31:0]CPU_addr,
                 input [31:0] CPU_write_data,
                 
                 //RAM Interface
                 output memory_read_request,
                 output memory_write_request,
                 output [31:0]memory_address,
                 output [31:0]memory_write_data,
                 input [31:0]memory_read_data,
                 input memory_ready);
    
    //Address decoder wires
    wire [19:0]tag;
    wire [6:0]index;
    wire [2:0]offset;
    
    //Cache wires
    wire [19:0]cache_tag;
    wire cache_valid;
    wire cache_dirty;
    wire [31:0]cache_read_data;
    
    //Controller to Cache wires
    wire cache_write_en;
    wire [6:0]write_index;
    wire [2:0]write_offset;
    wire metadata_write_en;
    wire [19:0]tag_data;
    wire valid_update;
    wire dirty_update;
    
    //Controller to Datapath wires
    wire [19:0]saved_tag;
    wire [6:0]saved_index;
    wire [2:0]word_counter;
    wire cache_read_mode;
    wire memory_addr_mode;
    wire cache_write_source;
    
    //Datapath to Cache wires
    wire [6:0]cache_read_index;
    wire [2:0]cache_read_offset;
    wire [31:0]cache_write_data;
    
    Address_decoder ADDR_DEC(.tag(tag),
                             .index(index),
                             .offset(offset),
                             .CPU_addr(CPU_addr));
    
    Cache_memory CACHE_MEM(.read_data(cache_read_data),
                           .current_tag(cache_tag),
                           .current_valid(cache_valid),
                           .current_dirty(cache_dirty),
                           .read_index(cache_read_index),
                           .read_offset(cache_read_offset),
                           .write_en(cache_write_en),
                           .write_index(write_index),
                           .write_offset(write_offset),
                           .write_data(cache_write_data),
                           .metadata_write_en(metadata_write_en),
                           .tag_in(tag_data),
                           .valid_in(valid_update),
                           .dirty_in(dirty_update),
                           .clk(clk),
                           .reset(reset));
    
    Cache_controller CACHE_CON (.CPU_ready(CPU_ready),
                                .CPU_request(CPU_request),
                                .CPU_write(CPU_write),
                                .request_tag(tag),
                                .request_index(index),
                                .request_offset(offset),
                                .metadata_write_en(metadata_write_en),
                                .tag_data(tag_data),
                                .valid_update(valid_update),
                                .dirty_update(dirty_update),
                                .cache_write_en(cache_write_en),
                                .write_index(write_index),
                                .write_offset(write_offset),
                                .word_counter(word_counter),
                                .cache_write_source(cache_write_source),
                                .saved_index(saved_index),
                                .saved_tag(saved_tag),
                                .cache_tag(cache_tag),
                                .cache_valid(cache_valid),
                                .cache_dirty(cache_dirty),
                                .cache_read_mode(cache_read_mode),
                                .memory_addr_mode(memory_addr_mode),
                                .memory_read_request(memory_read_request),
                                .memory_write_request(memory_write_request),
                                .memory_ready(memory_ready),
                                .clk(clk),
                                .reset(reset));
                     
    Cache_datapath CACHE_DAT(.CPU_index(index),
                             .CPU_offset(offset),
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
      
endmodule