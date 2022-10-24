`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
/*Completer is the module that takes from CHI-Converter the Address pointer of
Descriptor and the errors of the transactions if there is any and updates the status
field of the Descriptor so the processor can understand that all transactions of 
the Descriptor is over and re-write it with new transaction. When the last transaction
of a Descriptor is finished then the MSB of DescAddr input is 1 and when CHI-Converter
enables the ValidUpdate signal then the address of Descripotr is enqueued in compliter's
FIFO. Then it requests from BRAM's Arbiter permission to access the BRAM and when it is 
obtained then the status of Descriptor is updated.*/
//////////////////////////////////////////////////////////////////////////////////
import DataPkg::*; 

// Indexes of Descriptor's fields
`define SRCRegIndx        0
`define DSTRegIndx        1
`define BTSRegIndx        2
`define SBRegIndx         3
`define StatusRegIndx     4
// Status state
`define StatusIdle        0
`define StatusError       2

`define RspErrWidth       2
`define NoError           0

module Completer#( 
  parameter BRAM_ADDR_WIDTH   = 10 ,
  parameter FIFO_Length       = 32 ,
  parameter BRAM_NUM_COL      = 8    // As the Data_packet fields
)(
    input                                         RST         ,
    input                                         Clk         ,
    input             [BRAM_ADDR_WIDTH       : 0] DescAddr    , //From CHI-Conv
    input             [`RspErrWidth      - 1 : 0] DBIDRespErr ,
    input             [`RspErrWidth      - 1 : 0] DataRespErr ,
    input                                         ValidUpdate ,
    input Data_packet                             DescData    , //From BRAM
    input                                         ReadyBRAM   , //From Arbiter_BRAM
    output                                        ValidBRAM   , //For Arbiter_BRAM
    output            [BRAM_ADDR_WIDTH   - 1 : 0] AddrOut     , //For BRAM
    output Data_packet                            DataOut     ,
    output reg        [BRAM_NUM_COL      - 1 : 0] WE          , 
    output                                        FULL          //For CHI-Conv
    ); 
    
     enum int unsigned { ReadState      = 0 , 
                         WriteState     = 1  } state , next_state ; 
                        
    wire                            Enqueue    ;
    reg                             Dequeue    ;
    wire                            Empty      ;
    
    wire [`RspErrWidth    - 1 : 0] SigDBIDErr ;
    wire [`RspErrWidth    - 1 : 0] SigDataErr ;
    
    assign Enqueue =  ValidUpdate & (DescAddr[BRAM_ADDR_WIDTH] | DBIDRespErr != `NoError |  DataRespErr != `NoError ) ;
    
    // Address FIFO 
       FIFO #(     
       BRAM_ADDR_WIDTH ,   //FIFO_WIDTH       
       FIFO_Length         //FIFO_LENGTH      
       )     
       FIFODescAddr (     
       .RST         ( RST                               ) ,      
       .Clk         ( Clk                               ) ,      
       .Inp         ( DescAddr[BRAM_ADDR_WIDTH - 1 : 0] ) , 
       .Enqueue     ( Enqueue                           ) , 
       .Dequeue     ( Dequeue                           ) , 
       .Outp        ( AddrOut                           ) , 
       .FULL        ( FULL                              ) , 
       .Empty       ( Empty                             ) 
       );
       
       // DBID Error FIFO 
       FIFO #(     
       `RspErrWidth      ,    //FIFO_WIDTH       
       FIFO_Length            //FIFO_LENGTH      
       )     
       FIFODBIDErr (     
       .RST        ( RST          ) ,      
       .Clk        ( Clk          ) ,      
       .Inp        ( DBIDRespErr  ) , 
       .Enqueue    ( Enqueue      ) , 
       .Dequeue    ( Dequeue      ) , 
       .Outp       ( SigDBIDErr   ) , 
       .FULL       (              ) , 
       .Empty      (              ) 
       );
       
       // Data Error FIFO 
       FIFO #(     
       `RspErrWidth     ,      //FIFO_WIDTH       
       FIFO_Length             //FIFO_LENGTH      
       )     
       FIFODataErr (     
       .RST        ( RST          ) ,      
       .Clk        ( Clk          ) ,      
       .Inp        ( DataRespErr  ) , 
       .Enqueue    ( Enqueue      ) , 
       .Dequeue    ( Dequeue      ) , 
       .Outp       ( SigDataErr   ) , 
       .FULL       (              ) , 
       .Empty      (              ) 
       );
       
   
   assign ValidBRAM = !Empty ;
    
   //FSM's state
   always_ff @ (posedge Clk) begin
     if(RST)
       state <= ReadState ;         // Reset FSM
     else
       state <= next_state ;        // Change state
   end
   //FSM's next_state
    always_comb begin : next_state_logic
     case(state)
       ReadState :
         begin                           
           if(ValidBRAM & ReadyBRAM & SigDBIDErr == `NoError & SigDataErr == `NoError)  
             next_state = WriteState ;  
           else
             next_state = ReadState ;
         end
       WriteState :
         begin
           next_state = ReadState ;
         end
       default : next_state = ReadState;
     endcase   
   end
    //FSM's signals
    always_comb begin 
     case(state)
       ReadState :
         begin            
         // if Error Update error Status               
           if(ValidBRAM & ReadyBRAM & (SigDBIDErr != `NoError | SigDataErr != `NoError))begin
             WE      = ('d1 << `StatusRegIndx)                  ;
             DataOut = '{ default : 0 , Status : `StatusError } ; 
             Dequeue = 1                                        ;
           end
           else begin
             WE      = 'b0 ;   
             DataOut = 'b0 ;
             Dequeue = 0   ;
           end
         end
       WriteState :
         begin
           if(ValidBRAM & ReadyBRAM & DescData.Status != `StatusError)begin
             WE      = ('d1 << `StatusRegIndx) ;
             DataOut = '{ default : 0 , Status : `StatusIdle } ;
             Dequeue = 1                                       ;
           end
           else begin
             WE      = 'b0 ;   
             DataOut = 'b0 ;
             Dequeue = 0   ;
           end
         end
       default begin
             WE      = 'b0 ;   
             DataOut = 'b0 ;
             Dequeue = 0   ;
           end
     endcase   
   end
endmodule
