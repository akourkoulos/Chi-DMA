`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 22.07.2022 11:18:30
// Design Name: 
// Module Name: Arbiter
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


module Arbiter#( 
  parameter BRAM_ADDR_WIDTH  = 32
)(
    input logic        [1                       : 0 ] Valid           ,
    input logic        [BRAM_ADDR_WIDTH - 1     : 0 ] DescAddrInProc  ,
    input logic        [BRAM_ADDR_WIDTH - 1     : 0 ] DescAddrInSched ,
    output wire        [1                       : 0 ] Ready           ,
    output wire        [BRAM_ADDR_WIDTH - 1     : 0 ] DescAddrOut
    );
    
   
    assign Ready[0] =    Valid[0]                                                     ;
    assign Ready[1] =  (!Valid[0])& Valid[1]                                          ;
    assign DescAddrOut = Valid[0] ? DescAddrInProc :(Valid[1] ? DescAddrInSched : 'b0);
    
endmodule



