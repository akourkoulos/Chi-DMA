`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08.09.2022 11:28:43
// Design Name: 
// Module Name: TestBarrelShifter
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


module TestBarrelShifter#(
  DataWidth  = 32 ,
  ShiftWidth = 5   //log base2 (DataWudth) 
);
     reg    [DataWidth  - 1 :0] inp   ;
     reg    [ShiftWidth - 1 :0] shift ;
     wire   [DataWidth  - 1 :0] outp  ;
     
    localparam period           = 20   ;   // duration for each bit = 20 * timescale = 20 * 1 ns  = 20ns  
    
    BarrelShifter     UUT (
      .  inp   (  inp    )
    , .  shift (  shift  )
    , .  outp  (  outp   )
    );                

    initial 
        begin       
        inp    = 'd3                                ;
        shift  = 'd0                                ;
       
        #(period*2); // wait for period
        inp     =  'd3                              ;
        shift   =  'd2                              ;
       
        #(period*2); // wait for period
         inp     = 'd3                              ;
         shift   = 'd3                              ;
       
        #(period*2); // wait for period
         inp     = 'd3                              ;
         shift   = 'd7                              ;
       
        #(period*2); // wait for period
        inp     = 'd3000000                          ;
        shift   = 'd20                              ;
       
        #(period*2); // wait for period
        $stop;
        end
endmodule
