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


module FIFO_Data(
    input logic RST,
    input logic [DataWidth-1:0] Inp,
    input logic Push,
    input logic Pop,
    output logic [DataWidth-1:0] Outp,
    output logic FULL,
    output logic Empty
    );
    
     reg [DataWidth-1:0]MyQueue[QueueSize-1:0];
     
     int state;
     
     always_comb begin
        if(RST)begin 
            state=0;
            Outp='d0;
            FULL=0;
            Empty=1;
            for (int i=0; i<QueueSize; i=i+1) MyQueue[i] = 'd0;
        end
            
        if(state==0)
            Empty=1;
        else
            Empty=0;
            
        if(state==QueueSize)
            FULL=1;
        else
            FULL=0;
            
        Outp=MyQueue[0];
     end
     
     always_ff@(posedge Push) begin
        if(state!=QueueSize)begin
            MyQueue[state]=Inp;
            state=state+1;
        end
     end
     
     always_ff@(posedge Pop) begin
        if(state!=0)begin
            for(int j=0;j<QueueSize-1;j=j+1) MyQueue[j]=MyQueue[j+1];
            MyQueue[QueueSize-1]=0;
            state=state-1;
        end
     end
endmodule
