`timescale 1ns / 1ps
`include "RSParameters.vh"

//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 15.07.2022 15:50:05
// Design Name: 
// Module Name: FIFO_Addr
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


module FIFO_Addr#(
  RegSpaceAddrWidth = 32,
  NumOfDesc         = 8
)(
    input wire                              RST     ,
    input wire                              Clk     ,
    input wire  [RegSpaceAddrWidth - 1 : 0] Inp     ,
    input wire                              Enqueue ,
    input wire                              Dequeue ,
    output wire [RegSpaceAddrWidth - 1 : 0] Outp    ,
    output wire                             FULL    ,
    output wire                             Empty
    );
    
     reg [RegSpaceAddrWidth - 1 : 0] MyQueue [NumOfDesc : 0];
     
     int state;
     
     assign Empty = (state == 0            ) ? 1 : 0 ;
     assign FULL  = (state == NumOfDesc + 1) ? 1 : 0 ;
     
     assign Outp  =  MyQueue[0] ;
     
      always_ff @ (posedge Clk) begin
        if(RST)begin 
            state=0;
            for (int i=0; i<=NumOfDesc; i=i+1) MyQueue[i] = 'd0;
        end
        else begin  
          if(Enqueue == 1 & (Dequeue == 0 | Empty) & !FULL) begin
            MyQueue[state] = Inp       ;
            state          = state + 1 ;
          end
          else if(Enqueue == 0 & Dequeue == 1 & !Empty) begin
            for(int j=0 ; j < NumOfDesc ; j++) MyQueue[j] = MyQueue[j+1];
            MyQueue[NumOfDesc] = 0         ;
            state              = state - 1 ;
          end
          else if ( Enqueue == 1 & Dequeue == 1 & !Empty ) begin
            for(int j=0 ; j < NumOfDesc ; j++) MyQueue[j] = MyQueue[j+1];
            MyQueue[state - 1] = Inp;
          end            
        end
     end
endmodule
