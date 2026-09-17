//STATE encoding
`define IDLE 4'b0001                                           
`define LOOKUP 4'b0010                                         
`define HIT_READ 4'b0011                                       
`define HIT_WRITE 4'b0100                                      
`define MISS 4'b0101                                           
`define WRITEBACK 4'b0110                                    
`define REFILL 4'b0111                                       
`define UPDATE_METADATA 4'b1000                              
`define RESPOND 4'b1001                                      
`define WB_READ 4'b1010                                      // Present writeback word address to synchronous SRAM


module Cache_controller(//CPU to Controller ports
                        output reg CPU_ready,                                               // Indicates CPU can proceed
                        input CPU_request,                                                  // CPU wants to access cache
                        input CPU_write,                                                    // 1=write, 0=read
                        input [19:0]request_tag,                                            // Tag part of CPU address
                        input [6:0]request_index,                                           // Index part of CPU address
                        input [2:0]request_offset,                                          // Offset part of CPU address
                                                
                        //Cache to Controller ports
                        output reg metadata_write_en,                                       // Enable update of tag/valid/dirty
                        output reg [19:0]tag_data,                                          // Tag to write into metadata
                        output reg valid_update,                                            // New valid bit update
                        output reg dirty_update,                                            // New dirty bit update
                        output reg cache_write_en,                                          // Enable data array write
                        output reg [6:0]write_index,                                        // Index for data write
                        output reg [2:0]write_offset,                                       // Offset for data write
                        output reg [2:0]word_counter,                                       // Counter for sequential data transfer
                        output reg cache_write_source,                                      // Decides write data for cache between memory read (=1) and CPU write (=0)
                        output reg cache_read_mode,                                         //                                      
                        output reg memory_addr_mode,                                        // Chooses between writeback address(=1) and refill address(=0)
                        output reg [6:0]saved_index,                                        // Latched request_index
                        output reg [19:0]saved_tag,                                         // Latched request_tag
                        input [19:0]cache_tag,                                              // Tag read from cache metadata
                        input cache_valid,                                                  // Valid bit from cache
                        input cache_dirty,                                                  // Dirty bit from cache
                        
                        //Memory to Controller ports
                        output reg memory_read_request,                                     // Request memory read
                        output reg memory_write_request,                                    // Request memory write
                        input memory_ready,                                                 // Memory operation complete
                        
                        //Other inputs
                        input clk,                                                          // System clock
                        input reset );                                                      // Active-low reset
    
    reg [3:0] PRESENT_STATE;                                                                // Current FSM state
    reg [3:0] NEXT_STATE;                                                                   // Next FSM state (combinational)
    
    reg saved_write;                                                                        // Latched CPU_write from request
    reg [2:0]saved_offset;                                                                  // Latched request_offset
        
    wire lookup_hit;                                                                        // Hit indicator
    assign lookup_hit = cache_valid && (cache_tag == saved_tag);                            // Hit if valid and tag matches
    
   always @(posedge clk or negedge reset) begin                                             // Sequential logic: state and counters
        if (reset == 1'b0) begin                                                            // Active-low reset
            PRESENT_STATE <= `IDLE;                                                         // Start in IDLE
            word_counter <= 3'b000;                                                         // Clear word counter

            saved_write <= 1'b0;                                                            // Clear latched signals
            saved_index <= 7'b0000000;
            saved_offset <= 3'b000;
            saved_tag <= 20'h00000;
        end
        else begin                                                                          // Normal operation
            PRESENT_STATE <= NEXT_STATE;                                                    // Update state

            if (PRESENT_STATE == `IDLE && CPU_request == 1'b1) begin                        // On IDLE and request
                saved_write <= CPU_write;                                                   // Capture write/read
                saved_index <= request_index;                                               // Capture index
                saved_offset <= request_offset;                                             // Capture word offset
                saved_tag <= request_tag;                                                   // Capture tag
                word_counter <= 3'd0;                                                       // Reset word counter
            end

            if (PRESENT_STATE == `MISS && NEXT_STATE == `WB_READ) begin
                word_counter <= 3'b000;                                                         // Reset before first writeback read
            end
            else if (PRESENT_STATE == `MISS && NEXT_STATE == `REFILL) begin
                word_counter <= 3'b000;                                                         // Reset before refill
            end
            else if (PRESENT_STATE == `WRITEBACK && memory_ready == 1'b1) begin                     // During writeback, when memory ready
                if (word_counter == 3'd7)
                    word_counter <= 3'b000;
                else
                    word_counter <= word_counter + 3'd1;
            end
            else if (PRESENT_STATE == `REFILL && memory_ready == 1'b1) begin                         // During refill, when memory ready
                if (word_counter == 3'd7)                                                      // If last word done
                    word_counter <= 3'b000;                                                    // Reset (though transition to UPDATE)
                else
                    word_counter <= word_counter + 3'd1;                                         // Increment for next word
            end
        end
   end
   
   always @(*) begin                                                                        // Next state logic (combinational)
        NEXT_STATE = PRESENT_STATE;                                                          // Default: stay in current state
        case (PRESENT_STATE)
            `IDLE: begin
                if (CPU_request == 1'b1)                                                             // If CPU requests, go to LOOKUP
                    NEXT_STATE = `LOOKUP;
                else
                    NEXT_STATE = `IDLE;
            end

            `LOOKUP: begin
                if (lookup_hit == 1'b1) begin                                                        // If hit
                    if (saved_write == 1'b1)                                                 // Write hit -> HIT_WRITE
                        NEXT_STATE = `HIT_WRITE;
                    else                                                                     // Read hit -> HIT_READ
                        NEXT_STATE = `HIT_READ;
                end
                else begin                                                                   // Miss -> MISS
                    NEXT_STATE = `MISS;
                end
            end

            `HIT_READ: begin
                NEXT_STATE = `RESPOND;                                                       // After read, respond
            end

            `HIT_WRITE: begin
                NEXT_STATE = `RESPOND;                                                       // After write, respond
            end

            `MISS: begin
                if (cache_dirty == 1'b1)                                                     // If dirty, write back first
                    NEXT_STATE = `WB_READ;                                                   // Present first writeback word to SRAM
                else                                                                         // Else directly refill
                    NEXT_STATE = `REFILL;
            end

            `WB_READ: begin
                NEXT_STATE = `WRITEBACK;                                                     // SRAM data is valid in WRITEBACK
            end

            `WRITEBACK: begin
                if (memory_ready == 1'b1) begin
                    if (word_counter == 3'd7)
                        NEXT_STATE = `REFILL;                                                // All 8 words written
                    else
                        NEXT_STATE = `WB_READ;                                                // Read next word from SRAM
                end
                else
                    NEXT_STATE = `WRITEBACK;
            end

            `REFILL: begin
                if (memory_ready == 1'b1 && (word_counter == 3'd7))                            // After all 8 words read
                    NEXT_STATE = `UPDATE_METADATA;                                           // Update metadata
                else
                    NEXT_STATE = `REFILL;                                                    // Stay until done
            end

            `UPDATE_METADATA: begin
                NEXT_STATE = `RESPOND;                                                       // After updating metadata and an optional write-miss word, respond
            end

            `RESPOND: begin
                NEXT_STATE = `IDLE;                                                          // Back to idle after response
            end

            default: begin
                NEXT_STATE = `IDLE;                                                          // Safe default
            end
        endcase
    end
    
    always @(*) begin                                                                       // Output logic (combinational)
        CPU_ready = 1'b0;                                                                   // Default: not ready
        metadata_write_en = 1'b0;                                                           // Default: no metadata write
        tag_data = 20'h00000;                                                                // Default tag
        valid_update = 1'b0;                                                                // Default valid
        dirty_update = 1'b0;                                                                // Default dirty

        cache_write_en = 1'b0;                                                              // Default: no data write
        write_index = saved_index;                                                          // Use saved index
        write_offset = saved_offset;                                                        // Use saved offset
        
        cache_write_source = 1'b0;                                                          // Set default cache write source to CPU write data
        memory_addr_mode = 1'b0;
        cache_read_mode = 1'b0;                                                             //  

        memory_read_request = 1'b0;                                                         // Default: no memory request
        memory_write_request = 1'b0;
               
        case(PRESENT_STATE)
            `IDLE: begin
                    //no change                                  
                  end
            `LOOKUP: begin
                        cache_read_mode = 1'b1;                                      // Present saved request address to synchronous SRAM
                    end   
            `HIT_READ: begin
                         cache_read_mode = 1'b1;                                      // Hold requested SRAM read address
                      end  
            `HIT_WRITE: begin
                            cache_write_en = 1'b1;                                          // Write data to cache
                            write_index = saved_index;                                      // Use saved index
                            write_offset = saved_offset;                                    // Use saved offset
                            cache_write_source = 1'b0;                                      // Select data from CPU for writing into cache
                            
                            metadata_write_en = 1'b1;                                       // Update metadata
                            tag_data = cache_tag;                                           // Keep existing tag
                            valid_update = 1'b1;                                            // Keep valid=1
                            dirty_update = 1'b1;                                            // Set dirty=1 (write)
                       end  
            `MISS: begin
                    //no change                                 
                  end       
            `WB_READ: begin
                        cache_read_mode = 1'b1;                 // Present current writeback word to synchronous SRAM
                    end
            `WRITEBACK: begin 
                            memory_write_request = 1'b1;            // Request memory write
                            memory_addr_mode = 1'b1;
                            cache_read_mode = 1'b1;
                        end  
            `REFILL: begin
                        memory_read_request = 1'b1;                                         // Request memory read
                        cache_write_en = memory_ready;                                      // Write to cache when data valid
                        cache_write_source = 1'b1;                                          // Select data from memory for writing into cache
                        write_index = saved_index;                                          // Write to same index
                        write_offset = word_counter;                                          // Write to current word
                        memory_addr_mode = 1'b0;
                    end  
            `UPDATE_METADATA: begin
                                metadata_write_en = 1'b1;                                   // Update metadata for the refilled line
                                tag_data = saved_tag;                                       // Store the requested tag
                                valid_update = 1'b1;                                        // Mark the line valid
                                dirty_update = saved_write;                                 // Write miss becomes dirty after CPU write
                                if (saved_write == 1'b1) begin
                                    cache_write_en = 1'b1;                                  // Apply the original CPU write after refill
                                    write_index = saved_index;                              // Use the requested cache index
                                    write_offset = saved_offset;                            // Use the requested word offset
                                    cache_write_source = 1'b0;                              // Select CPU write data
                                end
                             end  
            `RESPOND: begin
                        CPU_ready = 1'b1;                                                   // Signal CPU ready
                        cache_write_source = 1'b0;
                     end           
            default: begin
                        //no change                             
                    end 
        endcase
    end   
endmodule