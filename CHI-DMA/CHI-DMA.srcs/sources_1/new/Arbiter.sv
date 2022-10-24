`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
/*Arbiter of FIFO. Takes 2 request by the Valid signals and returns one Ready
Response that indicates that the module has the permission to access the FIFO*/
//////////////////////////////////////////////////////////////////////////////////



module Arbiter#( 
  parameter BRAM_ADDR_WIDTH  = 32
)(
    input logic        [1                       : 0 ] Valid           ,
    input logic        [BRAM_ADDR_WIDTH - 1     : 0 ] DescAddrInProc  , // Address pointer from proc
    input logic        [BRAM_ADDR_WIDTH - 1     : 0 ] DescAddrInSched , // Address pointer from sched
    output wire        [1                       : 0 ] Ready           ,
    output wire        [BRAM_ADDR_WIDTH - 1     : 0 ] DescAddrOut       // Address pointer for FIFO
    );
    
   
    assign Ready[0] =    Valid[0]                                                     ;
    assign Ready[1] =  (!Valid[0])& Valid[1]                                          ;
    assign DescAddrOut = Valid[0] ? DescAddrInProc :(Valid[1] ? DescAddrInSched : 'b0);
    
endmodule



