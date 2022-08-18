`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 23.07.2022 11:13:24
// Design Name: 
// Module Name: TestArbiter
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


module TestArbiter#(
 parameter NumOfRegInDesc = 5,
 parameter RegSpaceAddrWidth      = 10
);
     reg   [1                     : 0 ]    Valid           ;
     reg   [RegSpaceAddrWidth - 1 : 0 ]    DescAddrInProc  ;
     reg   [RegSpaceAddrWidth - 1 : 0 ]    DescAddrInSched ;
     wire  [1                     : 0 ]    Ready           ;
     wire  [RegSpaceAddrWidth - 1 : 0 ]    DescAddrOut     ;
     
    localparam period           = 20   ;   // duration for each bit = 20 * timescale = 20 * 1 ns  = 20ns  
    
    Arbiter     UUT (
      .  Valid            (  Valid            )
    , .  DescAddrInProc   (  DescAddrInProc   )
    , .  DescAddrInSched  (  DescAddrInSched  )
    , .  Ready            (  Ready            )
    , .  DescAddrOut      (  DescAddrOut      )
    );                

    
    initial 
         begin       
         Valid           = 'd3      ;
         DescAddrInProc  = 'd1      ;
         DescAddrInSched = 'd1111   ;
       
        #(period*2); // wait for period
         Valid            =  'd0                              ;
         DescAddrInProc   =  'd1                              ;
         DescAddrInSched  =  'd1111                           ;
       
        #(period*2); // wait for period
         Valid            = 'd1                              ;
         DescAddrInProc   = 'd1                              ;
         DescAddrInSched  = 'd1111                           ;
       
        #(period*2); // wait for period
         Valid            = 'd2                              ;
         DescAddrInProc   = 'd1                              ;
         DescAddrInSched  = 'd1111                           ;
       
        #(period*2); // wait for period
         Valid            = 'd3                              ;
         DescAddrInProc   = 'd1                              ;
         DescAddrInSched  = 'd1111                           ;
       
        #(period*2); // wait for period
        $stop;
        end
endmodule

