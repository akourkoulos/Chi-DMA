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
  parameter FIFO_LENGTH = 8   
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
    
     reg  [$clog2(FIFO_LENGTH)   - 1 : 0] wraddr                        ; // write pointer
     reg  [$clog2(FIFO_LENGTH)   - 1 : 0] rdaddr                        ; // read pointer
     
     reg  [$clog2(FIFO_LENGTH)       : 0] counter                       ;

     reg  [FIFO_WIDTH            - 1 : 0] MyQueue [FIFO_LENGTH - 1 : 0] ; // FIFO 
     
     // update Read pointer
     always_ff @(posedge Clk) begin
       if(RST)
         rdaddr <= 0;
       else begin
         if (Dequeue & !Empty & rdaddr != FIFO_LENGTH - 1)
          rdaddr <= rdaddr + 1 ; // increase read pointer when dequeue and not Empty and read pointer < Length of FIFO
         else if (Dequeue & !Empty & rdaddr == FIFO_LENGTH - 1)
          rdaddr <= 0          ; // increase read pointer when dequeue and not Empty and read pointer == Length of FIFO
       end
     end
     // update Write pointer
     always_ff@(posedge Clk)begin
       if(RST)
         wraddr <= 0;
       else begin
         if (Enqueue & !FULL & wraddr != FIFO_LENGTH - 1)
           wraddr <= wraddr + 1 ; // increase write pointer when enqueue , not FULL and write pointer < Length of FIFO
         else if(Enqueue & Dequeue & FULL & wraddr != FIFO_LENGTH - 1)
           wraddr <= wraddr + 1 ; // increase write pointer when enqueue , Dequeue and FULL and write pointer < Length of FIFO
         else if (Enqueue & !FULL & wraddr == FIFO_LENGTH - 1)
           wraddr <= 0          ; // increase write pointer when enqueue , not FULL and write pointer == Length of FIFO
         else if(Enqueue & Dequeue & FULL & wraddr == FIFO_LENGTH - 1)
           wraddr <= 0          ; // increase write pointer when enqueue , Dequeue and FULL and write pointer == Length of FIFO
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
     // count the number of elements in FIFO 
     always_ff@(posedge Clk)begin
       if(RST)
         counter <= 0 ;
       else begin
         if(Dequeue & !Enqueue & !Empty)
           counter <= counter - 1 ; 
         else if(!Dequeue & Enqueue & !FULL)
           counter <= counter + 1 ; 
         else if(Dequeue & Enqueue & Empty)
           counter <= counter + 1 ; 
       end
     end
     // FIFO FULL
     assign FULL = counter == FIFO_LENGTH;
     // FIFO EMpty
     assign Empty = counter == 0 ;
    
     endmodule
