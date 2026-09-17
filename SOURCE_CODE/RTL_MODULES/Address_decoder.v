//////////////////////////////////////////////////////////////////////////////////
// Module Name: Address_decoder
// Project Name: Cache_Controller
// Module Creation Date: 15.06.2026 
//////////////////////////////////////////////////////////////////////////////////

// 1 byte = 8 bit | 4 byte = 32 bit | 8 words = 32 byte cache line

module Address_decoder(output [19:0] tag,             //20 bit tag
                       output [6:0] index,            //7 bit cache line index
                       output reg [2:0] offset,           //3 bit word offset
                       input [31:0] CPU_addr);        //32 bit CPU address
   
   always @(*) begin
      case(CPU_addr[1:0])
         2'b00: offset = CPU_addr[4:2];
         2'b01: offset = CPU_addr[4:2];
         2'b10: offset = CPU_addr[4:2];
         2'b11: offset = CPU_addr[4:2];
      endcase
   end
   assign index = CPU_addr[11:5];
   assign tag = CPU_addr[31:12]; 
endmodule
