`timescale 1ns / 1ps
`include "RSParameters.vh"
import DataPkg::*; 
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 14.07.2022 18:55:18
// Design Name: 
// Module Name: TestScheduler
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

module TestScheduler#(
  RegSpaceAddrWidth = 32,
  NumOfRegInDesc    = 5 ,
  CHI_Word_Width    = 32,
  CounterWidth      = 32,
  Done_Status       = 1 ,
  Chunk             = 64
);
    reg                               RST              ;
    reg                               Clk              ;
    Data_packet                       DescDataIn       ;
    reg                               Ready            ;
    reg       [RegSpaceAddrWidth-1:0] FIFO_Addr        ;
    reg                               Empty            ;
    reg                               ReadyRead        ;
    reg                               DoneWrite        ;
    reg       [RegSpaceAddrWidth-1:0] DoneWriteAddr    ;
    Data_packet                       DescDataOut      ;
    wire      [NumOfRegInDesc   -1:0] WE               ;
    wire      [RegSpaceAddrWidth-1:0] DescAddrOut      ;
    wire                              Valid            ;
    wire      [RegSpaceAddrWidth-1:0] DescAddrPointer  ;
    wire                              Dequeue          ;
    Data_packet                       DataReadWrite    ;
    wire                              StartRead        ;
    wire      [RegSpaceAddrWidth-1:0] FinishedDescAddr ;
    wire                              FinishedDescValid;
    wire                              ReadyWrite       ;
    // duration for each bit = 20 * timescale = 20 * 1 ns  = 20ns
    localparam period = 20;  

    Scheduler UUT (
    .RST               (RST               ) ,
    .Clk               (Clk               ) ,
    .DescDataIn        (DescDataIn        ) ,
    .Ready             (Ready             ) ,
    .FIFO_Addr         (FIFO_Addr         ) ,
    .Empty             (Empty             ) ,
    .ReadyRead         (ReadyRead         ) ,
    .DoneWrite         (DoneWrite         ) ,
    .DoneWriteAddr     (DoneWriteAddr     ) ,
    .DescDataOut       (DescDataOut       ) , 
    .WE                (WE                ) ,
    .DescAddrOut       (DescAddrOut       ) ,
    .Valid             (Valid             ) ,
    .DescAddrPointer   (DescAddrPointer   ) ,
    .Dequeue           (Dequeue           ) ,
    .DataReadWrite     (DataReadWrite     ) ,
    .StartRead         (StartRead         ) , 
    .FinishedDescAddr  (FinishedDescAddr  ) ,    
    .FinishedDescValid (FinishedDescValid ) , 
    .ReadyWrite        (ReadyWrite        ) 
    );
    
    always 
    begin
        Clk = 1'b1; 
        #20; // high for 20 * timescale = 20 ns
    
        Clk = 1'b0;
        #20; // low for 20 * timescale = 20 ns
    end
    

    always @(posedge Clk)
        begin
    
        RST                    =  1             ;     
        DescDataIn             = {default : 0 } ;     
        DescDataIn.SrcAddr     = 'd10           ;
        DescDataIn.DstAddr     = 'd100          ;    
        DescDataIn.BytesToSend = 'd100          ;     
        DescDataIn.SentBytes   = 0              ;     
        Ready                  = 0              ;    
        FIFO_Addr              = 'd10           ;    
        Empty                  = 1              ;    
        ReadyRead              = 0              ;    
        DoneWrite              = 0              ;    
        DoneWriteAddr          = 'd0            ;    
        
        #(period*2); // wait for period begin
        #(period); // wait for period begin

        RST                    =  0             ;     
        DescDataIn             = {default : 0 } ;     
        DescDataIn.SrcAddr     = 'd10           ;
        DescDataIn.DstAddr     = 'd100          ;    
        DescDataIn.BytesToSend = 'd100          ;     
        DescDataIn.SentBytes   = 'd10           ;     
        Ready                  = 0              ;    
        FIFO_Addr              = 'd10           ;    
        Empty                  = 0              ;    
        ReadyRead              = 1              ;    
        DoneWrite              = 0              ;    
        DoneWriteAddr          = 'd0            ;
        
        #(period*2); // wait for period begin

        RST                    =  0             ;     
        DescDataIn             = {default : 0 } ;     
        DescDataIn.SrcAddr     = 'd10           ;
        DescDataIn.DstAddr     = 'd100          ;    
        DescDataIn.BytesToSend = 'd100          ;     
        DescDataIn.SentBytes   = 'd42           ;     
        Ready                  = 1              ;    
        FIFO_Addr              = 'd10           ;    
        Empty                  = 0              ;    
        ReadyRead              = 1              ;    
        DoneWrite              = 0              ;    
        DoneWriteAddr          = 'd0            ;
        
        #(period*2); // wait for period begin

        RST                    =  0             ;     
        DescDataIn             = {default : 0 } ;     
        DescDataIn.SrcAddr     = 'd10           ;
        DescDataIn.DstAddr     = 'd100          ;    
        DescDataIn.BytesToSend = 'd100          ;     
        DescDataIn.SentBytes   = 'd74           ;     
        Ready                  = 0              ;    
        FIFO_Addr              = 'd10           ;    
        Empty                  = 0              ;    
        ReadyRead              = 0              ;    
        DoneWrite              = 0              ;    
        DoneWriteAddr          = 'd0            ;
        
        #(period*2); // wait for period begin
        
        
        RST                    =  0             ;     
        DescDataIn             = {default : 0 } ;     
        DescDataIn.SrcAddr     = 'd10           ;
        DescDataIn.DstAddr     = 'd100          ;    
        DescDataIn.BytesToSend = 'd100          ;     
        DescDataIn.SentBytes   = 'd74           ;     
        Ready                  = 1              ;    
        FIFO_Addr              = 'd10           ;    
        Empty                  = 0              ;    
        ReadyRead              = 1              ;    
        DoneWrite              = 0              ;    
        DoneWriteAddr          = 'd0            ;
        
        #(period*2); // wait for period begin        
        
        RST                    =  0             ;     
        DescDataIn             = {default : 0 } ;     
        DescDataIn.SrcAddr     = 'd10           ;
        DescDataIn.DstAddr     = 'd100          ;    
        DescDataIn.BytesToSend = 'd100          ;     
        DescDataIn.SentBytes   = 'd74           ;     
        Ready                  = 0              ;    
        FIFO_Addr              = 'd10           ;    
        Empty                  = 1             ;    
        ReadyRead              = 0              ;    
        DoneWrite              = 0              ;    
        DoneWriteAddr          = 'd0            ;
        
        #(period*2); // wait for period begin
        $stop;
        end
    
  
  
endmodule

