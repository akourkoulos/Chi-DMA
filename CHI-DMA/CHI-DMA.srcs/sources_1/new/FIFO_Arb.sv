`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 22.07.2022 18:37:47
// Design Name: 
// Module Name: FIFO_Arb
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

//################################ FIFO MODULE ################################

module FIFO_Arb#(
  NumOfInp  = 2 ,
  FIFOWidth = 1
)(
    input wire                          Clk   ,
    input wire                          RST   ,
    input wire [FIFOWidth*NumOfInp-1:0] Inp   ,
    input wire                          Push  ,
    input wire                          Pop   ,
    output reg  [FIFOWidth-1        :0] Outp  ,
    output reg                          FULL  ,
    output reg                          Empty
    );
    
     reg [FIFOWidth-1:0]MyQueue[NumOfInp-1:0];
     wire [FIFOWidth-1:0]PushInMyQueue[NumOfInp-1:0];
     
     genvar i;
     generate
     for( i=0 ; i<NumOfInp ; i++)begin
       assign PushInMyQueue[i] = Inp[(i+1)*FIFOWidth-1:FIFOWidth*i] ;
     end 
     endgenerate
     
     assign Outp = MyQueue[0];
     
     int state;
     
     
     always_comb begin      
       if(state == 0)
           Empty = 1 ;
       else
           Empty = 0 ;
       if(state == NumOfInp)
           FULL  = 1 ;
       else
           FULL  = 0 ;
     end
     
     always_ff@(posedge Clk)begin      
      if(RST)begin 
        state = 0    ;
        for (int i=0; i<NumOfInp; i=i+1) MyQueue[i] = 'd0;
       end
       else begin
         if(Push == 1)begin                                         //push
           for(int i=0 ; i<NumOfInp ; i++)begin                                     
               MyQueue[i] <= PushInMyQueue[i] ;
               if(PushInMyQueue[i]!= 'b0 | i == 0)
                 state++ ;
           end
         end
         else if(Pop == 1 & Push == 0) begin                            //pop
           for(int i=0 ; i<NumOfInp-1 ; i++)begin 
             MyQueue[i         ] <= MyQueue[i+1]   ;
             MyQueue[NumOfInp-1] <= 0              ;
           end
           if(state != 0)
             state            <= state-1           ;
         end
       end
     end  
     

endmodule
