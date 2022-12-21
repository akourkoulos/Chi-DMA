`timescale 1ns / 1ps

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


module FIFO#(
  parameter FIFO_WIDTH  = 32,
  parameter FIFO_LENGTH = 8   // must be a power of 2
)(
    input  wire                              RST     ,
    input  wire                              Clk     ,
    input  wire  [FIFO_WIDTH - 1 : 0]        Inp     ,
    input  wire                              Enqueue ,
    input  wire                              Dequeue ,
    output reg   [FIFO_WIDTH - 1 : 0]        Outp    ,
    output wire                              FULL    ,
    output wire                              Empty
    );
    
     reg  [$clog2(FIFO_LENGTH)       : 0] wraddr                        ; // write pointer
     reg  [$clog2(FIFO_LENGTH)       : 0] rdaddr                        ; // read pointer

     reg  [FIFO_WIDTH            - 1 : 0] MyQueue [FIFO_LENGTH - 1 : 0] ; // FIFO 
     
     // update Read pointer
     always_ff @(posedge Clk) begin
       if(RST)
         rdaddr <= 0;
       else begin
         if (Dequeue & !Empty)
          rdaddr <= rdaddr + 1 ; // increase read pointer when dequeue and not Empty
       end
     end
     // update Write pointer
     always_ff@(posedge Clk)begin
       if(RST)
         wraddr <= 0;
       else begin
         if (Enqueue & !FULL)
           wraddr <= wraddr + 1 ; // increase write pointer when enqueue and not FULL
         else if(Enqueue & Dequeue & FULL)
           wraddr <= wraddr + 1 ; // increase write pointer when enqueue and Dequeue and FULL
       end
     end
     // insert Data in FIFO when enqueue and not FULL
     always_ff@(posedge Clk)begin
       if(RST)
         MyQueue <= '{default : 0} ;
       else begin
         if ((Enqueue & !FULL) | (Enqueue & Dequeue & FULL))
          MyQueue[wraddr[$clog2(FIFO_LENGTH) - 1 : 0]] <=  Inp ;
       end
     end
     // Data out
     assign Outp = MyQueue[rdaddr[$clog2(FIFO_LENGTH) - 1 : 0]] ;
     // FIFO FULL
     assign FULL = (wraddr[$clog2(FIFO_LENGTH) - 1 : 0] == rdaddr[$clog2(FIFO_LENGTH) - 1 : 0]) & 
                        (wraddr[$clog2(FIFO_LENGTH)] != rdaddr[$clog2(FIFO_LENGTH)]);
     // FIFO EMpty
     assign Empty = (wraddr[$clog2(FIFO_LENGTH) - 1 : 0] == rdaddr[$clog2(FIFO_LENGTH) - 1 : 0]) & 
                         (wraddr[$clog2(FIFO_LENGTH)] == rdaddr[$clog2(FIFO_LENGTH)]);
    
     endmodule
