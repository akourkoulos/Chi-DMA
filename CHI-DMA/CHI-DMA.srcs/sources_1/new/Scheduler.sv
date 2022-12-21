`timescale 1ns / 1ps
import CHIFIFOsPkg ::*; 
//////////////////////////////////////////////////////////////////////////////////
/*Scheduler is the module which determines the way that the transactions is going to
be executed. Firstly Scheduler takes the address pointer from FIFO that has been 
written by processor when it first wrote BRAM and reads the corresponding of the
address pointer Descriptor of BRAM if there is permission from BRAM's Arbiter. 
Then if there is still permission from BRAM's Arbiter and CHI-Converter(which is 
the module that will execute the transaction)is not FULL then Scheduler passes the
command of Chunk CHI-transactions to the CHI-Converter and update the SentBytes 
field of Descriptor by the amount of bytes of scheduled transaction. If there are 
not Chunk CHI-transactions in Descriptor then Scheduler schedules all the remaining
bytes. At the same time the address pointer that was read from FIFO is being written 
inside a register and the signal dequeues the first element from FIFO is enabled. 
Subsequently Scheduler writes the address pointer that is written inside the 
register back in FIFO if there are more non-scheduled transactions in Descriptor
and reads the next one. This operation repeats until all transactions of Descriptors 
have been scheduled and the FIFO is empty. Scheduler accomplishes the above 
procedure by implementing an FSM a few registers and some combinational logic.*/
//////////////////////////////////////////////////////////////////////////////////

// Indexes of Descriptor's fields
`define SRCRegIndx    0
`define DSTRegIndx    1
`define BTSRegIndx    2
`define SBRegIndx     3
`define StatusRegIndx 4
// Status state
`define StatusIdle    0
`define StatusError   2

import DataPkg::*; 


module Scheduler#(
  parameter BRAM_ADDR_WIDTH   = 10 , 
  parameter BRAM_NUM_COL      = 8  , // num of Reg in Descriptor
  parameter BRAM_COL_WIDTH    = 32 , // width of a Reg in Descriptor 
  parameter CHI_DATA_WIDTH    = 64 , // CHI bus width
  parameter Chunk             = 5   // number of CHI-Words 
)(
    input                                     RST               ,
    input                                     Clk               ,
    input  Data_packet                        DescDataIn        , //sig from BRAM
    input                                     ReadyBRAM         , //sig from BRAM's Arbiter
    input                                     ReadyFIFO         , //sig from FIFO's Arbiter
    input             [BRAM_ADDR_WIDTH  -1:0] FIFO_Addr         , //sig from FIFO
    input                                     Empty             , 
    input                                     CmdFIFOFULL       , //sig from chi-converter
    output Data_packet                        DescDataOut       , //sig for BRAM
    output wire       [BRAM_NUM_COL     -1:0] WE                , 
    output wire       [BRAM_ADDR_WIDTH  -1:0] BRAMAddrOut       , 
    output reg                                ValidBRAM         , //sig for BRAM's Arbiter
    output reg                                Dequeue           , //sig for FIFO
    output reg                                ValidFIFO         , //sig for FIFO 's Arbiter
    output wire       [BRAM_ADDR_WIDTH  -1:0] DescAddrPointer   , 
    output reg                                IssueValid        , //sig for chi-converter
    output CHI_Command                        Command          
    );
    
    //FMS states : Idle       -> Read BRAM when not empty, 
    //             Issue      -> pass a comand to CHI-Converter,
    //             WriteBakck -> re-enqueue the address pointer back to FIFO
    
    enum int unsigned { IdleState      = 0 , 
                        IssueState     = 1 , 
                        WriteBackState = 2   } state , next_state ; 
                        
                        
    reg        [BRAM_ADDR_WIDTH   -1 : 0] AddrRegister      ;  // keeps the address pointer from FIFO
    reg                                   RegWESig          ;
    
    wire       [BRAM_COL_WIDTH    -1 : 0] SigWordLength     ; // Signal to update SentBytes field of Descriptor
    reg                                   WEControl         ; // Signal that FSM provides and controls WE of BRAM 
    
    // Data output for Descriptor : updated SentBytes field (or Status field if Descriptor has no transactions)
    assign SigWordLength = ((DescDataIn.BytesToSend - DescDataIn.SentBytes < CHI_DATA_WIDTH * Chunk) ? DescDataIn.BytesToSend - DescDataIn.SentBytes : CHI_DATA_WIDTH * Chunk);                                                                                  ;
    assign DescDataOut   = ('{default : 0 , SentBytes : (SigWordLength + DescDataIn.SentBytes) , Status : `StatusIdle})                                                       ;
    // if FSM enables WEControl then WE for SentBytes field enables(or Status field if Descriptor has no transactions) els 0 ;  
    assign WE = WEControl ? ((SigWordLength == 0) ? ('b1 << `StatusRegIndx) : ('b1 << `SBRegIndx) ): 0 ;
    // if FIFO empty then Address for BRAM is the address of register in order not to lose 1 cycle if there is only one address pointer in fifo
    assign BRAMAddrOut = Empty ? DescAddrPointer : FIFO_Addr ;
    // Write back to FIFO the pointer of register
    assign DescAddrPointer = AddrRegister ; 
    // command for CHI-converter(transaction's information)
    assign Command.SrcAddr       = DescDataIn.SrcAddr + DescDataIn.SentBytes       ;
    assign Command.DstAddr       = DescDataIn.DstAddr + DescDataIn.SentBytes       ;
    assign Command.Length        = SigWordLength                                   ;
    assign Command.DescAddr      = FIFO_Addr                                       ;
    assign Command.LastDescTrans = DescDataIn.BytesToSend == DescDataOut.SentBytes ;
   
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
             next_state = WriteBackState ;        // FIFO's control has not obtained yet                                                                                                            
         end 
       default : next_state = IdleState;          // Default state
     endcase   
   end
   
   //FSM's signals
  always_comb begin
    case(state)
       IdleState :
         begin                      // If not Empty request control of BRAM else do nothing
           WEControl  = 0                ; // Controls the WE output for BRAM
           Dequeue    = 0                ; // Dequeue signal for FIFO
           ValidFIFO  = 0                ; // Request permission from FIFO's Arbiter
           RegWESig   = 0                ; // WE for register that stores the address pointer from FIFO
           IssueValid = 0                ; // Indicates that the command for CHI-Converter is Valid
           ValidBRAM  = (!Empty) ? 1 : 0 ; // Request permission from BRAM's Arbiter
         end
       IssueState : 
         begin         // Schedule a new transaction when posible
           if(CmdFIFOFULL | !ReadyBRAM)begin  // If comand FIFO is FULL or there is not control of BRAM do nothing (Dont schedule)
             WEControl  = 0 ;
             Dequeue    = 0 ;
             ValidFIFO  = 0 ;
             RegWESig   = 1 ;
             IssueValid = 0 ;
             ValidBRAM  = 1 ;
           end
           else begin                         // Schedule a new transaction 
             WEControl  = 1                      ;
             Dequeue    = 1                      ;
             ValidFIFO  = 0                      ;
             RegWESig   = 1                      ;
             IssueValid = 1 & SigWordLength != 0 ;
             ValidBRAM  = 1                      ;
           end
         end
       WriteBackState : 
         begin                   // Request control of FIFO to re-write the dequeued address pointer back in the queue
           WEControl  = 0 ;
           Dequeue    = 0 ;
           ValidFIFO  = 1 ;
           RegWESig   = 0 ;
           IssueValid = 0 ;
           ValidBRAM  = 1 ;
         end
       default :
         begin
           ValidBRAM  = 0 ;
           WEControl  = 0 ;
           Dequeue    = 0 ;
           ValidFIFO  = 0 ;
           RegWESig   = 0 ;
           IssueValid = 0 ;
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
