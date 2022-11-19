`timescale 1ns / 1ps
import DataPkg::*;
////////////////////;//////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 18.11.2022 14:37:37
// Design Name: 
// Module Name: PseudoCPU
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

// Status state
`define StatusIdle        0
`define StatusActive      1
`define StatusError       2

module PseudoCPU#(
  parameter BRAM_NUM_COL      = 8                           ,
  parameter BRAM_COL_WIDTH    = 32                          ,
  parameter BRAM_ADDR_WIDTH   = 10                          ,
  parameter CHI_DATA_WIDTH    = 64                          ,
  parameter MAX_BytesToSend   = 5000
)(
    input  wire                                             RST                  ,
    input  wire                                             Clk                  ,   
    input  wire                                             ReadyArbProc         , // From Arb_FIFO to Proc
    input           Data_packet                             BRAMdoutA            , // From BRAM to Proc  
    output reg                   [BRAM_NUM_COL    - 1 : 0]  weA                  , //------For BRAM------
    output reg                   [BRAM_ADDR_WIDTH - 1 : 0]  addrA                ,
    output          Data_packet                             dinA                 ,//--------------------
    output reg                                              ValidArbIn            // For FIFO Arbiter    
    );
    
    localparam period = 20;  
    
    
    int numOfTrans; // number of transaction must be done 
    reg NewTrans  ;
    
    reg [BRAM_ADDR_WIDTH - 1 : 0] BRAMpointer      ; // next Desc pointer in BRAM that will be read
    reg                           IncrBRAMpointer  ; // WE for increasing BRAMpointer
    
    enum int unsigned { ReadState      = 0 , 
                        WriteState     = 1  } state , next_state ; 
    
    
    // There is a new transaction evry random delay
    always begin
      if(RST)
        NewTrans = 0 ;
      else begin
        NewTrans = 1 ;
        #(period * 2 ) ; 
        NewTrans = 0 ;
        #(period * 2 * $urandom_range(10)); 
      end     
    end
    
    //manage number of transaction that must be done 
    always_ff@(posedge Clk) begin
      if(RST)
        numOfTrans <= 0 ;
      else begin
        if(NewTrans & !(ValidArbIn & ReadyArbProc & weA != 0))begin
          numOfTrans <= numOfTrans + 1 ;        
        end
        else if(!NewTrans & (ValidArbIn & ReadyArbProc & weA != 0))begin
          numOfTrans <= numOfTrans - 1 ;        
        end
      end
    end
    
    // BRAM pointer for Read Next Descriptor
    always_ff@(posedge Clk)begin
      if(RST)
        BRAMpointer <= 0 ;
      else
        if(IncrBRAMpointer)
          BRAMpointer <= BRAMpointer + 1 ;
    end
      
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
            if(numOfTrans != 0)  
              next_state = WriteState ;  
            else
              next_state = ReadState ;
          end
        WriteState :
          begin
            if(ValidArbIn & ReadyArbProc & weA != 0)
               next_state = ReadState ;
            else
              next_state = WriteState ;
          end
        default : next_state = ReadState;
      endcase   
    end
     //FSM's signals
     always_comb begin 
      case(state)
        ReadState :
          begin            
          // if should schedule a new transaction ReadBRAM else wait               
            if(numOfTrans != 0)begin
              weA             <= 0           ;  
              addrA           <= BRAMpointer ;
              dinA            <= 0           ;
              ValidArbIn      <= 0           ;
              IncrBRAMpointer <= 0           ;
            end
            else begin
              weA             <= 0           ;  
              addrA           <= 0           ;
              dinA            <= 0           ;
              ValidArbIn      <= 0           ;
              IncrBRAMpointer <= 0           ;
            end
          end
        WriteState :
          begin
          // if Ready FIFO Arbiter and there is an empty Descriptor schedule transaction
            if(BRAMdoutA.Status == `StatusIdle)begin 
              ValidArbIn         <= 1                                                                                    ;
              addrA              <= BRAMpointer                                                                          ;
              if(ReadyArbProc)begin
                weA              <= {BRAM_NUM_COL{1'b1}}                                                                 ;  
                dinA             <= '{default : 0}                                                                       ;
                dinA.SrcAddr     <= $urandom_range(0,2**(BRAM_COL_WIDTH-6-1)) * CHI_DATA_WIDTH                           ; // 6 = log2(CHI_DATA_WIDTH)  so maxSrcAddr = 2^(BRAM_COL_WIDTH-1), SrcAddr is aligned
                dinA.DstAddr     <= $urandom_range(2**(BRAM_COL_WIDTH-6-1)+1,(2**(BRAM_COL_WIDTH-6))-1) * CHI_DATA_WIDTH ; // minDstAddr = 2^(BRAM_COL_WIDTH-1) + 1, maxDsyAddr = 2^(BRAM_COL_WIDTH) - 1,  DstAddr is aligned
                dinA.BytesToSend <= $urandom_range(1,MAX_BytesToSend)                                                    ;
                dinA.SentBytes   <= 0                                                                                    ;
                dinA.Status      <= `StatusActive                                                                        ;
                IncrBRAMpointer  <= 1                                                                                    ;
              end
              else begin
                weA              <= 0               ;  
                dinA             <= 0               ;
                IncrBRAMpointer  <= 0               ;
              end
            end 
            // if this is no empty Descriptor Read the Next one
            else begin  
              weA                <= 0               ;  
              addrA              <= BRAMpointer + 1 ;
              dinA               <= '{default:0}    ;
              ValidArbIn         <= 0               ;
              IncrBRAMpointer    <= 1               ;
            end
          end
        default begin
              weA                <= 0              ;  
              addrA              <= 0              ;
              dinA               <= 0              ;
              ValidArbIn         <= 0              ;
            end
      endcase   
    end
endmodule
