`timescale 1ns / 1ps
`define SRCRegIndx    0
`define DSTRegIndx    1
`define BTSRegIndx    2
`define SBRegIndx     3
`define StatusRegIndx 4

import DataPkg::*; 

//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12.07.2022 12:41:34
// Design Name: 
// Module Name: Scheduler
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
 

module Scheduler#(
  RegSpaceAddrWidth = 32,
  NumOfRegInDesc    = 5 ,
  CHI_Word_Width    = 32,
  CounterWidth      = 32,  
  Done_Status       = 1 ,
  Idle_Status       = 0 ,
  Chunk             = 64,
  MEMAddrWidth      = 32,
  StateWidth        = 8 
)(
    input  logic                              RST               ,
    input  logic                              Clk               ,
    input  Data_packet                        DescDataIn        ,//sig from RegSpace
    input  logic                              Ready             ,//sig from Arbiter
    input  logic      [RegSpaceAddrWidth-1:0] FIFO_Addr         ,//sig from FIFO
    input  logic                              Empty             ,
    input  logic                              ReadyRead         ,//sig from chi-converter
    input  logic                              DoneWrite         ,
    input  logic      [RegSpaceAddrWidth-1:0] DoneWriteAddr     ,
    output Data_packet                        DescDataOut       ,//sig for Descriptor
    output wire       [NumOfRegInDesc   -1:0] WE                ,
    output wire       [RegSpaceAddrWidth-1:0] DescAddrOut       ,
    output wire                               Valid             ,//sig for arbiter
    output wire       [RegSpaceAddrWidth-1:0] DescAddrPointer   ,
    output wire                               Dequeue           ,//sig for fifo
    output wire       [MEMAddrWidth     -1:0] ReadAddr          ,//sig for chi-converter
    output wire       [MEMAddrWidth     -1:0] ReadLength        ,
    output wire       [MEMAddrWidth     -1:0] WriteAddr         ,
    output wire       [MEMAddrWidth     -1:0] WriteLength       ,
    output wire                               StartRead         ,
    output wire       [RegSpaceAddrWidth-1:0] FinishedDescAddr  ,
    output wire                               FinishedDescValid ,
    output wire                               ReadyWrite
    );
    
    reg        [RegSpaceAddrWidth -1 : 0] AddrRegister      ;  // keeps the address pointer from FIFO
    reg        [CounterWidth      -1 : 0] counter           ;  // count the bytes that have been sent to change chunk 
    reg        [StateWidth-1         : 0] state             ;
    
    wire       [CounterWidth      -1 : 0] NextCountIn       ;
    wire       [CHI_Word_Width    -1 : 0] SentBytesSignal   ;
    wire       [CHI_Word_Width    -1 : 0] SignalChunkToSend ;

    wire       [1                    : 0] WEControl         ; //FSM Signals
    wire                                  DataControl       ;
    wire       [1                    : 0] AddrControl       ;
    wire                                  CountWESig        ;
    wire                                  RegWESig          ;
    
    Data_packet                           SigDescDataOut    ;
    Data_packet                           SigDoneStatus     ;
     
    assign SignalChunkToSend = ((DescDataIn.BytesToSend - DescDataIn.SentBytes < CHI_Word_Width) ? DescDataIn.BytesToSend - DescDataIn.SentBytes : CHI_Word_Width);
    assign SentBytesSignal   = SignalChunkToSend + DescDataIn.SentBytes                                                                                           ;
    assign SigDescDataOut    = ('{default : 0 , SentBytes : SentBytesSignal})                                                                                     ;
    assign SigDoneStatus     = ('{default : 0 , Status : Done_Status})                                                                                            ;
    
    assign DescDataOut = DataControl  ? SigDoneStatus  : SigDescDataOut ;
    
    assign WE = WEControl ? ('b1 << `StatusRegIndx) : ((Empty | (!ReadyRead | !StartRead)) ? 'b0 : ('b1 << `SBRegIndx)) ;
    
    assign DescAddrOut = (AddrControl == 00) ? FIFO_Addr :((AddrControl == 01) ? DoneWriteAddr : AddrRegister );
    
    assign DescAddrPointer = AddrRegister ; 

    assign ReadAddr    = DescDataIn.SrcAddr + DescDataIn.SentBytes ;
    assign WriteAddr   = DescDataIn.DstAddr + DescDataIn.SentBytes ;
    assign ReadLength  = SignalChunkToSend                         ;
    assign WriteLength = SignalChunkToSend                         ;
    
    
    assign FinishedDescAddr = FIFO_Addr ;
    
    assign FinishedDescValid = DescDataIn.BytesToSend == SigDescDataOut.SentBytes;
   
    //assign Valid = (((StartRead & ReadyRead) & NextCountIn >= Chunk) | counter >= Chunk ) & ((SigDescDataOut.SentBytes != DescDataIn.BytesToSend) | ((SigDescDataOut.SentBytes == DescDataIn.BytesToSend) & !(StartRead & ReadyRead))) ;
   //assign StartRead = (DescDataIn.BytesToSend != DescDataIn.SentBytes) & (!Empty & !DoneWrite) & DescDataIn.Status==Idle_Status ;
    //assign ReadyWrite = DoneWrite; 
   // assign Dequeue = (((SigDescDataOut.SentBytes == DescDataIn.BytesToSend) & StartRead & ReadyRead) | (Ready & Valid) | (DescDataIn.SentBytes == DescDataIn.BytesToSend) | DescDataIn.Status != Idle_Status) & !Empty ;
   
   //FSM's state
   always_ff @ (posedge Clk) begin
     if(RST) begin
       state <= 0 ;
     end
     else begin
       case(state)
         'd0 : begin                           
                 if(!Empty & !DoneWrite)                                            //fifo is not empty so there is a descripotr to serve
                   state <= 'd1 ;
                 else if (DoneWrite)                                                // all transaction of a Descriptor have been finished
                   state <= 'd2 ;
               end
         'd1 : begin
                 if(DescDataIn.BytesToSend == SigDescDataOut.SentBytes & ReadyRead) //every Bytes of a Descriptor is sending
                   state <= 'd0 ;
                 else if (NextCountIn >= Chunk & ReadyRead)                         //A chunk of one Descripotr have been served
                   state <= 'd3 ;
               end
         'd2 : state <= 'd0 ;
         'd3 : begin                                                                     
                 if(Ready & !DoneWrite)                                             //pointer of non finished Descripotr wrote back to fifo
                   state <= 'd1 ;
                 else if (Ready & DoneWrite)                                        //All transactions of a Desc have been finished and pointer Wrote to FIFO
                   state <= 'd2 ;
                 else if (!Ready & DoneWrite)                                       //Cant Write to FIFO yet and all transaction of a Desc finished
                   state <= 'd4 ;
               end
         'd4 : begin
                 if(Ready)                                                          //pointer Wrote in fifo
                   state <= 'd0 ;
                 else if (!Ready)                                                   //cant Write to fifo yet
                   state <= 'd3 ;  
               end    
       endcase        
     end
   end
   
   //FSM's signals
  always_comb begin
  end
  
   //update counter
    assign NextCountIn = counter + SignalChunkToSend;
    always_ff @ (posedge Clk) begin 
      if(RST)begin 
        counter<=0;
      end
      else begin
        if(CountWESig) begin
          counter <= Dequeue ? 0 : NextCountIn ;
        end
      end
    end
    
    //update AddressRegister
    always_ff @ (posedge Clk) begin
      if(RST) begin
        AddrRegister = 0 ;
      end
      else begin
        if(RegWESig)
          AddrRegister = FIFO_Addr;          
      end
      
    end
endmodule
