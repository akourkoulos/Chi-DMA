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
  BRAM_ADDR_WIDTH   = 10 ,
  BRAM_NUM_COL      = 8  , // num of Reg in Descriptor
  BRAM_COL_WIDTH    = 32 , // width of a Reg in Descriptor 
  CHI_Word_Width    = 32 ,  
  Chunk             = 5  , // number of CHI-Words
  MEMAddrWidth      = 32 ,
  Done_Status       = 1  ,
  Idle_Status       = 0   
)(
    input  logic                              RST               ,
    input  logic                              Clk               ,
    input  Data_packet                        DescDataIn        , //sig from BRAM
    input  logic                              ReadyBRAM         , //sig from BRAM's Arbiter
    input  logic                              ReadyFIFO         , //sig from FIFO's Arbiter
    input  logic      [BRAM_ADDR_WIDTH  -1:0] FIFO_Addr         , //sig from FIFO
    input  logic                              Empty             , 
    input  logic                              CmdFIFOFULL       , //sig from chi-converter
    output Data_packet                        DescDataOut       , //sig for BRAM
    output wire       [BRAM_NUM_COL     -1:0] WE                , 
    output wire       [BRAM_ADDR_WIDTH  -1:0] BRAMAddrOut       , 
    output logic                              ValidBRAM         , //sig for BRAM's Arbiter
    output logic                              Dequeue           , //sig for FIFO
    output logic                              ValidFIFO         , //sig for FIFO 's Arbiter
    output wire       [BRAM_ADDR_WIDTH  -1:0] DescAddrPointer   , 
    output logic                              IssueValid        , //sig for chi-converter
    output wire       [MEMAddrWidth     -1:0] ReadAddr          ,
    output wire       [MEMAddrWidth     -1:0] ReadLength        ,
    output wire       [MEMAddrWidth     -1:0] WriteAddr         ,
    output wire       [MEMAddrWidth     -1:0] WriteLength       ,
    output wire       [BRAM_ADDR_WIDTH  -1:0] FinishedDescAddr  ,
    output wire                               FinishedDescValid 
    );
    
    enum int unsigned { IdleState      = 0 , 
                        IssueState     = 1 , 
                        WriteBackState = 2   } state , next_state ; 
                        
                        
    reg        [BRAM_ADDR_WIDTH   -1 : 0] AddrRegister      ;  // keeps the address pointer from FIFO
    
    wire       [BRAM_COL_WIDTH    -1 : 0] SigWordLength     ;
    reg        [1                    : 0] WEControl         ; // FSM Signals
    reg                                   RegWESig          ;
    
     
    assign SigWordLength = ((DescDataIn.BytesToSend - DescDataIn.SentBytes < CHI_Word_Width * Chunk) ? DescDataIn.BytesToSend - DescDataIn.SentBytes : CHI_Word_Width * Chunk);                                                                                  ;
    assign DescDataOut   = ('{default : 0 , SentBytes : (SigWordLength + DescDataIn.SentBytes)})                                                                              ;
        
    assign WE = WEControl ? ('b1 << `StatusRegIndx) : 0 ;
    
    assign BRAMAddrOut = Empty ? DescAddrPointer : FIFO_Addr ;
    
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
           if(!Empty & ReadyBRAM)  // FIFO is not empty so there is a Descripotr to serve and there is BRAM to read it
             next_state = IssueState ;
           else                        // There is not Descriptor to serve or BRAM Control
             next_state = IdleState ;
         end
       IssueState :
         begin
           if((DescDataIn.BytesToSend == DescDataOut.SentBytes & !CmdFIFOFULL) | !ReadyBRAM) // All Bytes of a Descriptor have been scheduled
             next_state = IdleState ;
           else if (!CmdFIFOFULL & ReadyBRAM)     // A chunk of one Descriptor have been served
             next_state = WriteBackState ;
           else
             next_state = IssueState ;            // Chunk is not over and there are more Bytes of the current Descriptor to be sent 
         end
       WriteBackState : 
         begin
           if(ReadyFIFO & ReadyBRAM)              // Descriptor Addr pointer wrote back to FIFO and there is Control of BRAM to read next Descriptor                                            
             next_state = IssueState ;
           else if (ReadyFIFO & !ReadyBRAM)       // Descriptor Addr pointer wrote back to FIFO and there is not Control of BRAM to read next Descriptor                                        
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
         begin                      // If not Empty request control of BRAM else do nothing
           WEControl     = 0                ;
           Dequeue       = 0                ;
           ValidFIFO     = 0                ;
           RegWESig      = 0                ;
           IssueValid    = 0                ;
           ValidBRAM     = (!Empty) ? 1 : 0 ;
         end
       IssueState : 
         begin         // Schedule a Read transaction when posible
           if(CmdFIFOFULL | !ReadyBRAM)begin  // If comand FIFO is FULL or there is not control of BRAM do nothing
             WEControl    = 0 ;
             Dequeue      = 0 ;
             ValidFIFO    = 0 ;
             RegWESig     = 1 ;
             IssueValid   = 0 ;
             ValidBRAM    = 1 ;
           end
           else begin
             if(DescDataIn.BytesToSend == DescDataOut.SentBytes)begin // If a Descriptor is finished schedule the last transaction and dequeue the pointer from FIFO
               WEControl    = 1 ;
               Dequeue      = 1 ;
               ValidFIFO    = 0 ;
               RegWESig     = 1 ;
               IssueValid   = 1 ;
               ValidBRAM    = 1 ;
             end
             else begin           //  schedul a new transaction
               WEControl    = 1 ;
               Dequeue      = 0 ;
               ValidFIFO    = 0 ;
               RegWESig     = 1 ;
               IssueValid   = 1 ;
               ValidBRAM    = 1 ;
             end
           end
         end
       WriteBackState : 
         begin                   // Request control of FIFO to re-write the dequeued address pointer back in the queue
           WEControl    = 0 ;
           Dequeue      = 0 ;
           ValidFIFO    = 1 ;
           RegWESig     = 0 ;
           IssueValid   = 0 ;
           ValidBRAM    = 1 ;
         end
       default :
         begin
           ValidBRAM     = 0 ;
           WEControl     = 0 ;
           Dequeue       = 0 ;
           ValidFIFO     = 0 ;
           RegWESig      = 0 ;
           IssueValid    = 0 ;
         end
    endcase ;
  end
    
    //update AddressRegister
    always_ff @ (posedge Clk) begin
      if(RST) begin
        AddrRegister <= 0 ;
      end
      else begin
        if(RegWESig)
          AddrRegister <= FIFO_Addr;          
      end
    end
endmodule
