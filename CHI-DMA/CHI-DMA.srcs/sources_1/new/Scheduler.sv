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
  RegSpaceAddrWidth = 32 ,
  NumOfRegInDesc    = 5  ,
  CHI_Word_Width    = 32 ,
  CounterWidth      = 32 ,  
  Done_Status       = 1  ,
  Idle_Status       = 0  ,
  Chunk             = 64 ,
  MEMAddrWidth      = 32 ,
  RegWidth          = 32 , // width of a Reg in Descriptor 
  StateWidth        = 8 
)(
    input  logic                              RST               ,
    input  logic                              Clk               ,
    input  Data_packet                        DescDataIn        , //sig from RegSpace
    input  logic                              ReadyRegSpace     , //sig from RegSpace's Arbiter
    input  logic                              ReadyFIFO         , //sig from FIFO's Arbiter
    input  logic      [RegSpaceAddrWidth-1:0] FIFO_Addr         , //sig from FIFO
    input  logic                              Empty             , 
    input  logic                              CmdFIFOFULL       , //sig from chi-converter
    output Data_packet                        DescDataOut       , //sig for RegSpace
    output wire       [NumOfRegInDesc   -1:0] WE                , 
    output wire       [RegSpaceAddrWidth-1:0] RegSpaceAddrOut   , 
    output logic                              ValidRegSpace     , //sig for RegSpace's Arbiter
    output logic                              Dequeue           , //sig for FIFO
    output logic                              ValidFIFO         , //sig for FIFO 's Arbiter
    output wire       [RegSpaceAddrWidth-1:0] DescAddrPointer   , 
    output logic                              Read              , //sig for chi-converter
    output wire       [MEMAddrWidth     -1:0] ReadAddr          ,
    output wire       [MEMAddrWidth     -1:0] ReadLength        ,
    output wire       [MEMAddrWidth     -1:0] WriteAddr         ,
    output wire       [MEMAddrWidth     -1:0] WriteLength       ,
    output wire       [RegSpaceAddrWidth-1:0] FinishedDescAddr  ,
    output wire                               FinishedDescValid 
    );
    
    enum int unsigned { IdleState      = 0 , 
                        ReadState      = 1 , 
                        WriteBackState = 2   } state , next_state ; 
                        
                        
    reg        [RegSpaceAddrWidth -1 : 0] AddrRegister      ;  // keeps the address pointer from FIFO
    reg        [CounterWidth      -1 : 0] counter           ;  // count the bytes that have been sent to change chunk 
    
    wire       [CounterWidth      -1 : 0] NextCountIn       ;
    wire       [RegWidth          -1 : 0] SigWordLength     ;
    reg        [1                    : 0] WEControl         ; // FSM Signals
    reg                                   CountWESig        ;
    reg                                   RegWESig          ;
    
     
    assign SigWordLength = ((DescDataIn.BytesToSend - DescDataIn.SentBytes < CHI_Word_Width) ? DescDataIn.BytesToSend - DescDataIn.SentBytes : CHI_Word_Width);                                                                                  ;
    assign DescDataOut   = ('{default : 0 , SentBytes : (SigWordLength + DescDataIn.SentBytes)})                                                              ;
        
    assign WE = WEControl ? ('b1 << `StatusRegIndx) : 0 ;
    
    assign RegSpaceAddrOut = Empty ? DescAddrPointer : FIFO_Addr ;
    
    assign DescAddrPointer = AddrRegister ; 

    assign ReadAddr    = DescDataIn.SrcAddr + DescDataIn.SentBytes ;
    assign WriteAddr   = DescDataIn.DstAddr + DescDataIn.SentBytes ;
    assign ReadLength  = SigWordLength                             ;
    assign WriteLength = SigWordLength                             ;
    
    assign FinishedDescAddr = FIFO_Addr ;
    
    assign FinishedDescValid = DescDataIn.BytesToSend == DescDataOut.SentBytes ;
   
   //FSM's state
   always_ff @ (posedge Clk) begin
     if(RST)
       state <= IdleState ;         // Reset FSM
     else
       state <= next_state ;        // Change state
   end
   
   //FSM's next_state
   always_comb begin : next_state_logic
     case(state)
       IdleState :
         begin                           
           if(!Empty & ReadyRegSpace)  // FIFO is not empty so there is a Descripotr to serve and there is RegSpace to read it
             next_state = ReadState ;
           else                        // There is not Descriptor to serve or RegSpace Control
             next_state = IdleState ;
         end
       ReadState :
         begin
           if((DescDataIn.BytesToSend == DescDataOut.SentBytes & !CmdFIFOFULL) | !ReadyRegSpace) // Every Bytes of a Descriptor is sending
             next_state = IdleState ;
           else if (NextCountIn >= Chunk & !CmdFIFOFULL & ReadyRegSpace) // A chunk of one Descripotr have been served
             next_state = WriteBackState ;
           else
             next_state = ReadState ;            // Chunk is not over and there are more Bytes of the current Descriptor to be sent 
         end
       WriteBackState : 
         begin
           if(ReadyFIFO & ReadyRegSpace)         // Descriptor Addr pointer wrote back to FIFO and there is Control of RegSpace to read next Descriptor                                            
             next_state = ReadState ;
           else if (ReadyFIFO & !ReadyRegSpace)  // Descriptor Addr pointer wrote back to FIFO and there is not Control of RegSpace to read next Descriptor                                        
             next_state = IdleState ;
           else
             next_state = WriteBackState ;       // FIFO's control has not obtained yet                                                                                                            
         end 
       default : next_state = IdleState;
     endcase   
   end
   
   //FSM's signals
  always_comb begin
    case(state)
       IdleState :
         begin                      // If not Empty request control of RegSpace else do nothing
           WEControl     = 0                ;
           CountWESig    = 0                ;
           Dequeue       = 0                ;
           ValidFIFO     = 0                ;
           RegWESig      = 0                ;
           Read          = 0                ;
           ValidRegSpace = (!Empty) ? 1 : 0 ;
         end
       ReadState : 
         begin         // Schedule a Read transaction when posible
           if(CmdFIFOFULL | !ValidRegSpace)begin  // If comand FIFO is FULL or there is not control of RegSpace Wait
             WEControl    = 0 ;
             CountWESig   = 0 ;
             Dequeue      = 0 ;
             ValidFIFO    = 0 ;
             RegWESig     = 1 ;
             Read         = 0 ;
           end
           else begin
             if(DescDataIn.BytesToSend == DescDataOut.SentBytes | NextCountIn >= Chunk)begin // If a Descriptor or a Chunk is finished schedule the last transaction and dequeue the pointer from FIFO
               WEControl    = 1 ;
               CountWESig   = 1 ;
               Dequeue      = 1 ;
               ValidFIFO    = 0 ;
               RegWESig     = 1 ;
               Read         = 1 ;
             end
             else begin           // keep scheduling read transactions
               WEControl    = 1 ;
               CountWESig   = 1 ;
               Dequeue      = 0 ;
               ValidFIFO    = 0 ;
               RegWESig     = 1 ;
               Read         = 1 ;
             end
           end
         end
       WriteBackState : 
         begin                   // Request control of FIFO to re-write the dequeued address pointer back in the queue
           WEControl    = 0 ;
           CountWESig   = 0 ;
           Dequeue      = 0 ;
           ValidFIFO    = 1 ;
           RegWESig     = 0 ;
           Read         = 0 ;
         end
       default :
         begin
           ValidRegSpace = 0 ;
           WEControl     = 0 ;
           CountWESig    = 0 ;
           Dequeue       = 0 ;
           ValidFIFO     = 0 ;
           RegWESig      = 0 ;
           Read          = 0 ;
         end
    endcase ;
  end
  
   //update counter
    assign NextCountIn = counter + SigWordLength;
    always_ff @ (posedge Clk) begin 
      if(RST)begin 
        counter<=0;
      end
      else begin
        if(CountWESig) begin
          counter <= Dequeue ? 0 : NextCountIn  ;
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
