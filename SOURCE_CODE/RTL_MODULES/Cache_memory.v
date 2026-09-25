// Information:
// Cache data storage = 128 lines x 8 words x 32 bits = 32768 bits = 4 KB.
// Each SRAM macro = 256 words x 32 bits = 8192 bits = 1 KB.
// Four SRAM macros therefore implement the complete 4 KB cache data array.
//
// Cache line index = 7 bits.
// Word offset = 3 bits.
//
// The 10-bit SRAM address is formed as:
//   [9:8] = SRAM bank select
//   [7:0] = address inside the selected 256 x 32 SRAM.
//
// Therefore:
//   bank       = index[6:5]
//   macro_addr = {index[4:0], word_offset}
//
// Port 0 of every SRAM is used for cache writes.
// Port 1 of every SRAM is used for cache reads.
//
// The dout0 and dout1 ports of EVERY SRAM instance are explicitly connected.
// dout0 is not required by the cache datapath, but is captured on a wire so
// that the complete macro interface is physically represented in the netlist.
//
// The SRAM data array is not reset. Cache valid bits are reset to zero, so
// SRAM contents are irrelevant until a line has been filled.

module Cache_memory(output wire [31:0] read_data,         //data available at cache output
                    output wire [19:0] current_tag,       //tag of selected word-line
                    output wire current_valid,            //valid bit of selected word-line
                    output wire current_dirty,            //dirty bit of selected word-line
                    input [6:0] read_index,               //index of word-line to be read
                    input [2:0] read_offset,              //offset of word-line to be read
                    input write_en,                       //write enable signal, reading allowed when write_en = 0
                    input [6:0] write_index,              //index of word-line to be written
                    input [2:0] write_offset,             //offset of word-line to be written
                    input [31:0] write_data,              //data to be written in selected word-line
                    input metadata_write_en,              //write enable signal to modify tag
                    input [19:0] tag_in,                  //20 bit tag to be stored at selected index of tag_array
                    input valid_in,                       //'valid' bit to be set at the selected index of valid_bit_array
                    input dirty_in,                       //dirty bit to be set at selected index in dirty_bit_array
                    input clk,
                    input reset);

  reg [19:0]tag_array[127:0];                             //tag array, 128 lines, each line 20 bit wide
  reg valid_bit_array[127:0];                             //'valid' bit array, 128 lines, each line 1 bit wide
  reg dirty_bit_array[127:0];                             //dirty bit array, 128 lines, each line 1 bit wide

  wire [9:0] read_addr_full = {read_index, read_offset};  //10-bit logical address for the four-bank data array
  wire [9:0] write_addr_full = {write_index, write_offset};

  wire [1:0] read_bank_sel = read_addr_full[9:8];         //selects one of the four SRAM banks for reading
  wire [1:0] write_bank_sel = write_addr_full[9:8];      //selects one of the four SRAM banks for writing

  wire [7:0] read_macro_addr = read_addr_full[7:0];      //address inside selected SRAM bank
  wire [7:0] write_macro_addr = write_addr_full[7:0];

  wire bank0_write_select = write_en && (write_bank_sel == 2'd0);
  wire bank1_write_select = write_en && (write_bank_sel == 2'd1);
  wire bank2_write_select = write_en && (write_bank_sel == 2'd2);
  wire bank3_write_select = write_en && (write_bank_sel == 2'd3);

  wire bank0_read_select = (read_bank_sel == 2'd0);
  wire bank1_read_select = (read_bank_sel == 2'd1);
  wire bank2_read_select = (read_bank_sel == 2'd2);
  wire bank3_read_select = (read_bank_sel == 2'd3);

  wire [31:0] dout0_bank0;
  wire [31:0] dout0_bank1;
  wire [31:0] dout0_bank2;
  wire [31:0] dout0_bank3;

  wire [31:0] dout1_bank0;
  wire [31:0] dout1_bank1;
  wire [31:0] dout1_bank2;
  wire [31:0] dout1_bank3;

  reg [1:0] read_bank_sel_d;
  
  integer Index;
  
  freepdk45_sram_32x256_1rw1r SRAM_BANK_0 (.clk0(clk),
                                           .csb0(~bank0_write_select),
                                           .web0(~bank0_write_select),
                                           .addr0(write_macro_addr),
                                           .din0(write_data),
                                           .dout0(dout0_bank0),
                                           .clk1(clk),
                                           .csb1(~bank0_read_select),
                                           .addr1(read_macro_addr),
                                           .dout1(dout1_bank0));

  freepdk45_sram_32x256_1rw1r SRAM_BANK_1 (.clk0(clk),
                                           .csb0(~bank1_write_select),
                                           .web0(~bank1_write_select),
                                           .addr0(write_macro_addr),
                                           .din0(write_data),
                                           .dout0(dout0_bank1),
                                           .clk1(clk),
                                           .csb1(~bank1_read_select),
                                           .addr1(read_macro_addr),
                                           .dout1(dout1_bank1));

  freepdk45_sram_32x256_1rw1r SRAM_BANK_2 (.clk0(clk),
                                           .csb0(~bank2_write_select),
                                           .web0(~bank2_write_select),
                                           .addr0(write_macro_addr),
                                           .din0(write_data),
                                           .dout0(dout0_bank2),
                                           .clk1(clk),
                                           .csb1(~bank2_read_select),
                                           .addr1(read_macro_addr),
                                           .dout1(dout1_bank2));

  freepdk45_sram_32x256_1rw1r SRAM_BANK_3 (.clk0(clk),
                                           .csb0(~bank3_write_select),
                                           .web0(~bank3_write_select),
                                           .addr0(write_macro_addr),
                                           .din0(write_data),
                                           .dout0(dout0_bank3),
                                           .clk1(clk),
                                           .csb1(~bank3_read_select),
                                           .addr1(read_macro_addr),
                                           .dout1(dout1_bank3));

  assign read_data = (read_bank_sel_d == 2'd0) ? dout1_bank0 :
                     (read_bank_sel_d == 2'd1) ? dout1_bank1 :
                     (read_bank_sel_d == 2'd2) ? dout1_bank2 :
                                                  dout1_bank3;

  assign current_tag = tag_array[read_index];
  assign current_valid = valid_bit_array[read_index];
  assign current_dirty = dirty_bit_array[read_index];

  always @(posedge clk or negedge reset) begin
    if(reset == 1'b0) begin
      read_bank_sel_d <= 2'b00;
    end
    else begin
      read_bank_sel_d <= read_bank_sel;
    end
  end

  always @(posedge clk or negedge reset) begin
    if(reset == 1'b0) begin
        for(Index = 0; Index < 128; Index = Index + 1) begin
            tag_array[Index] <= 20'b0;
            valid_bit_array[Index] <= 1'b0;
            dirty_bit_array[Index] <= 1'b0;
        end
    end
    else begin
        if(metadata_write_en == 1'b1) begin
            tag_array[write_index] <= tag_in;
            valid_bit_array[write_index] <= valid_in;
            dirty_bit_array[write_index] <= dirty_in;
        end
    end
end

endmodule
