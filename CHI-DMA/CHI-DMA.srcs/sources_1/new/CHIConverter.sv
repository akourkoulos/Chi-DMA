`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 21.09.2022 00:23:26
// Design Name: 
// Module Name: CHIConverter
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module CHIConverter#(
  parameter BRAM_ADDR_WIDTH = 10 ,
  parameter MEM_ADDR_WIDTH  = 32 
  
)(
    input         Clk               ,
    input         RST               ,
    input  [MEM_ADDR_WIDTH - 1 : 0] SrcAddr           ,
    input  [MEM_ADDR_WIDTH - 1 : 0] DstAddr           ,
    input  [MEM_ADDR_WIDTH - 1 : 0] Length            ,
    input          Read              ,
    input  [BRAM_ADDR_WIDTH - 1 : 0] FinishedDescAddr  ,
    input          FinishedDescValid ,
    output [0 : 0] TXREQFLITPEND     ,  //Request inbound Chanel
    output         TXREQFLITV        ,
    output [0 : 0] TXREQFLIT         ,
    input          TXREQLCRDV        ,
    output [0 : 0] TXRSPFLITPEND     ,  //Response inbound Chanel
    output         TXRSPFLITV        ,
    output [0 : 0] TXRSPFLIT         ,
    input          TXRSPLCRDV        ,
    output [0 : 0] TXDATFLITPEND     ,  //Data inbound Chanel
    output         TXDATFLITV        ,
    output [0 : 0] TXDATFLIT         ,
    input          TXDATLCRDV        ,
    output [0 : 0] RXRSPFLITPEND     ,  //Response outbound Chanel
    output         RXRSPFLITV        ,
    output [0 : 0] RXRSPFLIT         ,
    input          RXRSPLCRDV        ,
    output [0 : 0] RXDATFLITPEND     ,  //Data outbound Chanel
    output         RXDATFLITV        ,
    output [0 : 0] RXDATFLIT         ,
    input          RXDATLCRDV        
    );                             
endmodule
