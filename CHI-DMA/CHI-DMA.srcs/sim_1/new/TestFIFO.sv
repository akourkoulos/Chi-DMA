`timescale 1ns / 1ps
`include "RSParameters.vh"

//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 15.07.2022 16:12:56
// Design Name: 
// Module Name: TestFIFO
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


module TestFIFO#(
  RegSpaceAddrWidth = 32,
  NumOfDesc         = 8
);
    reg                               RST     ;
    reg                               Clk     ;
    reg   [RegSpaceAddrWidth - 1 : 0] Inp     ;
    reg                               Enqueue ;
    reg                               Dequeue ;
    wire [RegSpaceAddrWidth - 1 : 0]  Outp    ;
    wire                              FULL    ;
    wire                              Empty   ;
    // duration for each bit = 20 * timescale = 20 * 1 ns  = 20ns
    localparam period = 20;  

    FIFO_Addr UUT (
    .RST     ( RST     ) , 
    .Clk     ( Clk     ) , 
    .Inp     ( Inp     ) , 
    .Enqueue ( Enqueue ) , 
    .Dequeue ( Dequeue ) , 
    .Outp    ( Outp    ) , 
    .FULL    ( FULL    ) , 
    .Empty   ( Empty   ) 
    );
    
     always 
     begin
         Clk = 1'b1; 
         #20; // high for 20 * timescale = 20 ns
     
         Clk = 1'b0;
         #20; // low for 20 * timescale = 20 ns
     end
    
     initial  
        begin
        RST      = 1  ;
        Inp      = 0  ;
        Enqueue  = 1  ;
        Dequeue  = 1  ;
        
        #(period*2); // wait for period  
        RST      = 0  ;
        Inp      = 0  ;
        Enqueue  = 1  ;
        Dequeue  = 0  ;
        
        #(period*2); // wait for period  
        RST      = 0  ;
        Inp      = 1  ;
        Enqueue  = 1  ;
        Dequeue  = 0  ;
        
        #(period*2); // wait for period        
        RST      = 0   ;
        Inp      = 'd2 ;
        Enqueue  = 1   ;
        Dequeue  = 0   ;
 
         #(period*2); // wait for period  
        RST      = 0  ;
        Inp      = 0  ;
        Enqueue  = 1  ;
        Dequeue  = 0  ;
        
        #(period*2); // wait for period  
        RST      = 0  ;
        Inp      = 1  ;
        Enqueue  = 1  ;
        Dequeue  = 0  ;
        
        #(period*2); // wait for period        
        RST      = 0   ;
        Inp      = 'd2 ;
        Enqueue  = 1   ;
        Dequeue  = 0   ;
         #(period*2); // wait for period  
        RST      = 0  ;
        Inp      = 0  ;
        Enqueue  = 1  ;
        Dequeue  = 0  ;
        
        #(period*2); // wait for period  
        RST      = 0  ;
        Inp      = 1  ;
        Enqueue  = 1  ;
        Dequeue  = 0  ;
        
        #(period*2); // wait for period        
        RST      = 0   ;
        Inp      = 'd2 ;
        Enqueue  = 1   ;
        Dequeue  = 0   ;
       
       #(period*2); // wait for period        
        RST      = 0   ;
        Inp      = 'd6 ;
        Enqueue  = 1   ;
        Dequeue  = 1   ;
        
        end 
endmodule

