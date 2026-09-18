module Cache_memory(output wire [31:0] read_data,                 // Data available at cache output
                    output wire [19:0] current_tag,               // Tag of selected cache line
                    output wire current_valid,                    // Valid bit of selected cache line
                    output wire current_dirty,                    // Dirty bit of selected cache line
                    input [6:0] read_index,                       // Index of cache line to read
                    input [2:0] read_offset,                      // Word offset within cache line
                    input write_en,                               // Enables a cache data write
                    input [6:0] write_index,                      // Index of cache line to write
                    input [2:0] write_offset,                     // Word offset within cache line to write
                    input [31:0] write_data,                       // Data to write into cache
                    input metadata_write_en,                      // Enables metadata update
                    input [19:0] tag_in,                          // Tag to store at selected cache line
                    input valid_in,                               // Valid bit to store
                    input dirty_in,                               // Dirty bit to store
                    input clk,
                    input reset);                                 // Active-low reset

  integer Index = 0;                                               // Index for metadata reset

  reg [19:0] tag_array[127:0];                                    // 128 cache lines with 20-bit tags
  reg valid_bit_array[127:0];                                     // 128 valid bits
  reg dirty_bit_array[127:0];                                     // 128 dirty bits

  assign current_tag = tag_array[read_index];                     // Combinational metadata read
  assign current_valid = valid_bit_array[read_index];             // Combinational valid-bit read
  assign current_dirty = dirty_bit_array[read_index];             // Combinational dirty-bit read

  wire [9:0] read_addr_full = {read_index, read_offset};           // 10-bit address for the 1024 cache words
  wire [9:0] write_addr_full = {write_index, write_offset};        // 10-bit address for the 1024 cache words
  wire [1:0] read_bank_sel = read_addr_full[9:8];                  // Selects one of four 1-KB SRAM macros
  wire [1:0] write_bank_sel = write_addr_full[9:8];                // Selects the SRAM macro used for a write
  wire [7:0] read_macro_addr = read_addr_full[7:0];               // Address inside selected SRAM macro
  wire [7:0] write_macro_addr = write_addr_full[7:0];              // Write address inside selected SRAM macro

  wire [31:0] dout1_bank0;                                        // Read data from SRAM bank 0
  wire [31:0] dout1_bank1;                                        // Read data from SRAM bank 1
  wire [31:0] dout1_bank2;                                        // Read data from SRAM bank 2
  wire [31:0] dout1_bank3;                                        // Read data from SRAM bank 3

  wire bank0_write_select = write_en && (write_bank_sel == 2'd0); // Select bank 0 for a write
  wire bank1_write_select = write_en && (write_bank_sel == 2'd1); // Select bank 1 for a write
  wire bank2_write_select = write_en && (write_bank_sel == 2'd2); // Select bank 2 for a write
  wire bank3_write_select = write_en && (write_bank_sel == 2'd3); // Select bank 3 for a write

  wire bank0_read_select = (read_bank_sel == 2'd0);               // Select bank 0 for a read
  wire bank1_read_select = (read_bank_sel == 2'd1);               // Select bank 1 for a read
  wire bank2_read_select = (read_bank_sel == 2'd2);               // Select bank 2 for a read
  wire bank3_read_select = (read_bank_sel == 2'd3);               // Select bank 3 for a read

  freepdk45_sram_32x256_1rw1r SRAM_BANK_0 (.clk0(clk),
      .csb0(~bank0_write_select),
      .web0(~bank0_write_select),
      .addr0(write_macro_addr),
      .din0(write_data),
      .dout0(),
      .clk1(clk),
      .csb1(~bank0_read_select),
      .addr1(read_macro_addr),
      .dout1(dout1_bank0)
  );    // 1-KB OpenRAM bank 0

  freepdk45_sram_32x256_1rw1r SRAM_BANK_1 (                        // 1-KB OpenRAM bank 1
      .clk0(clk),
      .csb0(~bank1_write_select),
      .web0(~bank1_write_select),
      .addr0(write_macro_addr),
      .din0(write_data),
      .dout0(),
      .clk1(clk),
      .csb1(~bank1_read_select),
      .addr1(read_macro_addr),
      .dout1(dout1_bank1)
  );

  freepdk45_sram_32x256_1rw1r SRAM_BANK_2 (                        // 1-KB OpenRAM bank 2
      .clk0   (clk),
      .csb0   (~bank2_write_select),
      .web0   (~bank2_write_select),
      .addr0  (write_macro_addr),
      .din0   (write_data),
      .dout0  (),
      .clk1   (clk),
      .csb1   (~bank2_read_select),
      .addr1  (read_macro_addr),
      .dout1  (dout1_bank2)
  );

  freepdk45_sram_32x256_1rw1r SRAM_BANK_3 (                        // 1-KB OpenRAM bank 3
      .clk0   (clk),
      .csb0   (~bank3_write_select),
      .web0   (~bank3_write_select),
      .addr0  (write_macro_addr),
      .din0   (write_data),
      .dout0  (),
      .clk1   (clk),
      .csb1   (~bank3_read_select),
      .addr1  (read_macro_addr),
      .dout1  (dout1_bank3)
  );

  reg [1:0] read_bank_sel_d;                                      // Delayed bank select aligned with synchronous SRAM output

  always @(posedge clk or negedge reset) begin
    if (reset == 1'b0)
      read_bank_sel_d <= 2'b00;                                   // Reset read-bank selector
    else
      read_bank_sel_d <= read_bank_sel;                           // Delay bank selection by one SRAM read cycle
  end

  assign read_data = (read_bank_sel_d == 2'd0) ? dout1_bank0 :    // Select returned data from bank 0
                     (read_bank_sel_d == 2'd1) ? dout1_bank1 :    // Select returned data from bank 1
                     (read_bank_sel_d == 2'd2) ? dout1_bank2 :    // Select returned data from bank 2
                                                  dout1_bank3;    // Select returned data from bank 3

  always @(posedge clk or negedge reset) begin
    if (reset == 1'b0) begin
      for (Index = 0; Index < 128; Index = Index + 1) begin
        valid_bit_array[Index] <= 1'b0;                            // Invalidate every cache line after reset
        dirty_bit_array[Index] <= 1'b0;                            // Clear every dirty bit after reset
      end
    end
    else if (metadata_write_en == 1'b1) begin
      tag_array[write_index] <= tag_in;                            // Update tag
      valid_bit_array[write_index] <= valid_in;                    // Update valid bit
      dirty_bit_array[write_index] <= dirty_in;                    // Update dirty bit
    end
  end

endmodule
