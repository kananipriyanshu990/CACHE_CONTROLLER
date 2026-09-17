`timescale 1ns / 1ps                                     

module Address_decoder_tb;                               // Testbench module (no ports)
   logic [31:0]CPU_addr;                                 // 32‑bit stimulus address
   logic [19:0]tag;                                      // 20‑bit tag output from DUT
   logic [6:0]index;                                     // 7‑bit index output
   logic [4:0]offset;                                    // 5‑bit offset output

   Address_decoder AD (.CPU_addr(CPU_addr),              // Instantiate DUT, connect inputs
                       .tag(tag),                        // and outputs by name
                       .index(index),
                       .offset(offset));

   initial begin                                         // Main stimulus process
      $monitor("t=%0t CPU_addr=%08h tag=%05h (%020b) index=%02h (%07b) offset=%02h (%05b)",
               $time, CPU_addr, tag, tag, index, index, offset, offset);
                                                         // Print time and all signals in hex/binary

      CPU_addr = 32'h0000_0000; #10;                     // All zeros
      CPU_addr = 32'hFFFF_FFFF; #10;                     // All ones
      CPU_addr = 32'hFFFFF000; #10;                      // High 20 bits set, low 12 bits zero
      CPU_addr = 32'h0000_0FE0; #10;                     // Index/offset near maximum (0xFE0 = 4064)
      CPU_addr = 32'h0000_001F; #10;                     // Offset all ones, index/tag zero
      CPU_addr = 32'hAAAA_AAAA; #10;                     // Alternating pattern (tag,index,offset)
      CPU_addr = 32'h5555_5555; #10;                     // Complementary alternating pattern
      CPU_addr = 32'h0000_1000; #10;                     // Page boundary (offset=0, index=0x20)
      CPU_addr = 32'h0000_20A3; #10;                     // Random address with non‑zero index/offset
      for (int i = 0; i < 32; i++) begin                 // Loop over all 32 bit positions
         CPU_addr = (32'h1 << i); #10;                   // Single‑bit stimulus (each bit set once)
      end
      #10;                                              
      $finish;                                          
   end
endmodule