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
  parameter MAX_BytesToSend   = 5000                        ,
  parameter DELAY_WIDTH       = 7                           , // width of counter used for delay
  parameter PHASE_WIDTH       = 3                           , // width of register that keeps the phase
  parameter LastPhase         = 6                           , // Number of Last Phase
  parameter NUM_OF_TRANS      = 50                            // Number of inserted transfers in last State
)(
    input                                                   RST                  ,
    input                                                   Clk                  ,    
    input                        [PHASE_WIDTH     - 1 : 0]  PhaseIn              ,
    input                                                   NewPhase             ,
    input           Data_packet                             BRAMdoutA            , // From BRAM to Proc  
    output reg                   [BRAM_NUM_COL    - 1 : 0]  weA                  , //------For BRAM------
    output reg                   [BRAM_ADDR_WIDTH - 1 : 0]  addrA                ,
    output          Data_packet                             dinA                  //--------------------
    );
    
    localparam period = 20;  
    
    //-----Signals for last phase------
    int                           numOfTrans           ; // number of transaction that should be inserted in DMA in last phase
    int                           numOfSchedTrans      ; // number of transactions that have been inserted in DMA in last phase
    reg                           NewTrans             ; // indicates that a there is a new transaction to be inserted in DMA in last phase
    reg [BRAM_ADDR_WIDTH - 1 : 0] RandBRAMpointer      ; // next Random Desc pointer in BRAM that will be read 
    reg [BRAM_ADDR_WIDTH - 1 : 0] NextRandBRAMpointer  ; 
    reg                           IncrRandBRAMpointer  ; // WE for increasing RandBRAMpointer
    // FMS states
    enum int unsigned { ReadState      = 0 , 
                        WriteState     = 1  } state , next_state ; 
    //-----End Signals for last phase------
    
    reg [PHASE_WIDTH     - 1 : 0] phase           ;
    int                           insertedTrans   ; // number of transaction that have been inserted in DMA 
    reg [BRAM_ADDR_WIDTH - 1 : 0] DescAddr        ; // Next Address of Descriptor to write
    reg                           IncrDescAddr    ; // WE for increasing DescAddr
    reg [DELAY_WIDTH     - 1 : 0] DelayCnt        ; // A simple counter that is used to add delay in phase 5
   
    // Manage Phase
    always_ff@(posedge Clk)begin
      if(RST)begin
          phase         <= 0 ;
          insertedTrans <= 0 ;
      end
      else begin
        if(NewPhase)begin
          phase         <= PhaseIn ;
          insertedTrans <= 0       ;
        end
      end
    end
    
    // Desc Address for Write Next Descriptor
    always_ff@(posedge Clk)begin
      if(RST)
        DescAddr <= 0 ;
      else
        if(IncrDescAddr)
          DescAddr <=  DescAddr + 1 ;
    end
    
    // Manage counter that is used for delay in phase 5
    always_ff@(posedge Clk)begin
      if(RST)
        DelayCnt <= 0 ;
      else begin
        if(phase == 5)
          DelayCnt <= DelayCnt + 1 ;
      end
    end
    
    always_comb begin
 //----------------------- 1st Phase ----------------------------
    // insert in DMA a small transaction
      if(phase == 1)begin
        IncrRandBRAMpointer  <= 1 ;
        if(insertedTrans < 1) begin
          weA              <= {BRAM_NUM_COL{1'b1}}    ;
          addrA            <= DescAddr                ;
          dinA.SrcAddr     <= CHI_DATA_WIDTH          ;
          dinA.DstAddr     <= CHI_DATA_WIDTH * 100000 ;
          dinA.BytesToSend <= CHI_DATA_WIDTH - 1      ;
          dinA.SentBytes   <= 0                       ;
          dinA.Status      <= `StatusActive           ;
          IncrDescAddr     <= 1                       ;
        end
        else begin 
          weA          <= 0 ;
          addrA        <= 0 ;
          dinA         <= 0 ;
          IncrDescAddr <= 0 ;
        end
      end
 //-----------------------END 1st Phase -------------------------
 //----------------------- 2nd Phase ----------------------------
      //insert in DMA a large transaction
      else if(phase == 2)begin
        IncrRandBRAMpointer  <= 1 ;
        if(insertedTrans < 1) begin
          weA              <= {BRAM_NUM_COL{1'b1}}    ;
          addrA            <= DescAddr                ;
          dinA.SrcAddr     <= CHI_DATA_WIDTH * 2      ;
          dinA.DstAddr     <= CHI_DATA_WIDTH * 200000 ;
          dinA.BytesToSend <= CHI_DATA_WIDTH * 50 + 2 ;
          dinA.SentBytes   <= 0                       ;
          dinA.Status      <= `StatusActive           ;
          IncrDescAddr     <= 1                       ;
        end
        else begin 
          weA          <= 0 ;
          addrA        <= 0 ;
          dinA         <= 0 ;
          IncrDescAddr <= 0 ;
        end
      end
 //-----------------------END 2nd Phase -------------------------
 //----------------------- 3rd Phase ----------------------------
      // insert in DMA many small transactions
      else if(phase == 3)begin
        IncrRandBRAMpointer  <= 1 ;
        if(insertedTrans < 10) begin
          weA              <= {BRAM_NUM_COL{1'b1}}                                  ;
          addrA            <= DescAddr                                              ;
          dinA.SrcAddr     <= CHI_DATA_WIDTH + CHI_DATA_WIDTH * 10 * insertedTrans  ;
          dinA.DstAddr     <= CHI_DATA_WIDTH * 100000 + 10 * insertedTrans          ;
          dinA.BytesToSend <= CHI_DATA_WIDTH - insertedTrans                        ;
          dinA.SentBytes   <= 0                                                     ;
          dinA.Status      <= `StatusActive                                         ;
          IncrDescAddr     <= 1                                                     ;
        end
        else begin 
          weA          <= 0 ;
          addrA        <= 0 ;
          dinA         <= 0 ;
          IncrDescAddr <= 0 ;
        end      
      end
 //-----------------------END 3rd Phase -------------------------
 //----------------------- 4th Phase ----------------------------
      // insert in DMA a few large transactions
      else if(phase == 4)begin
        IncrRandBRAMpointer  <= 1 ;
        if(insertedTrans < 5) begin
          weA              <= {BRAM_NUM_COL{1'b1}}                                    ;
          addrA            <= DescAddr                                                ;
          dinA.SrcAddr     <= CHI_DATA_WIDTH + CHI_DATA_WIDTH * 2000 * insertedTrans  ;
          dinA.DstAddr     <= CHI_DATA_WIDTH * 100000 + 20000 * insertedTrans         ;
          dinA.BytesToSend <= CHI_DATA_WIDTH * 25 + 2 * insertedTrans                 ;
          dinA.SentBytes   <= 0                                                       ;
          dinA.Status      <= `StatusActive                                           ;
          IncrDescAddr     <= 1                                                       ;
        end
        else begin 
          weA          <= 0 ;
          addrA        <= 0 ;
          dinA         <= 0 ;
          IncrDescAddr <= 0 ;
        end   
      end 
 //-----------------------END 4th Phase -------------------------
 //----------------------- 5th Phase ----------------------------
        // insert in DMA a both small and large transactions with delay
      else if(phase == 5)begin
        IncrRandBRAMpointer  <= 1 ;
        if(insertedTrans < 15) begin
          if(DelayCnt == 0 | DelayCnt == 7 | DelayCnt == 12)begin // insert large Trans
            weA              <= {BRAM_NUM_COL{1'b1}}                                    ;
            addrA            <= DescAddr                                                ;
            dinA.SrcAddr     <= CHI_DATA_WIDTH + CHI_DATA_WIDTH * 2000 * insertedTrans  ;
            dinA.DstAddr     <= CHI_DATA_WIDTH * 100000 + 20000 * insertedTrans         ;
            dinA.BytesToSend <= CHI_DATA_WIDTH * 25 + 2 * insertedTrans                 ;
            dinA.SentBytes   <= 0                                                       ;
            dinA.Status      <= `StatusActive                                           ;
            IncrDescAddr     <= 1                                                       ;
          end
          else if(DelayCnt % 3 == 0 )begin // insert small Trans
            weA              <= {BRAM_NUM_COL{1'b1}}                                  ;
            addrA            <= DescAddr                                              ;
            dinA.SrcAddr     <= CHI_DATA_WIDTH + CHI_DATA_WIDTH * 10 * insertedTrans  ;
            dinA.DstAddr     <= CHI_DATA_WIDTH * 100000 + 10 * insertedTrans          ;
            dinA.BytesToSend <= CHI_DATA_WIDTH - insertedTrans                        ;
            dinA.SentBytes   <= 0                                                     ;
            dinA.Status      <= `StatusActive                                         ;
            IncrDescAddr     <= 1                                                     ;
          end
        end
        else begin 
          weA          <= 0 ;
          addrA        <= 0 ;
          dinA         <= 0 ;
          IncrDescAddr <= 0 ;
        end     
      end
 //-----------------------END 5th Phase -------------------------
 //----------------------- Last Phase ----------------------------
      //6th Phase : insert NUM_OF_TRANS Random transaction in available Descriptor every random time
      else if(phase == LastPhase)begin
       IncrDescAddr <= 0 ;
       //FSM's signals
        case(state)
          ReadState :
            begin            
            // if should schedule a new transaction ReadBRAM else wait               
              if(numOfTrans != 0)begin
                weA                 <= 0               ;  
                addrA               <= RandBRAMpointer ;
                dinA                <= 0               ;
                IncrRandBRAMpointer <= 0               ;
              end
              else begin
                weA                 <= 0           ;  
                addrA               <= 0           ;
                dinA                <= 0           ;
                IncrRandBRAMpointer <= 0           ;
              end
            end
          WriteState :
            begin
            // if Ready FIFO Arbiter and there is an empty Descriptor schedule transaction
              if(BRAMdoutA.Status == `StatusIdle)begin 
                addrA                <= RandBRAMpointer                                                                      ;
                weA                  <= {BRAM_NUM_COL{1'b1}}                                                                 ;  
                dinA                 <= '{default : 0}                                                                       ;
                dinA.SrcAddr         <= $urandom_range(0,2**(BRAM_COL_WIDTH-6-1)) * CHI_DATA_WIDTH                           ; // 6 = log2(CHI_DATA_WIDTH)  so maxSrcAddr = 2^(BRAM_COL_WIDTH-1), SrcAddr is aligned
                dinA.DstAddr         <= $urandom_range(2**(BRAM_COL_WIDTH-6-1)+1,(2**(BRAM_COL_WIDTH-6))-1) * CHI_DATA_WIDTH ; // minDstAddr = 2^(BRAM_COL_WIDTH-1) + 1, maxDsyAddr = 2^(BRAM_COL_WIDTH) - 1,  DstAddr is aligned
                dinA.BytesToSend     <= $urandom_range(1,MAX_BytesToSend)                                                    ;
                dinA.SentBytes       <= 0                                                                                    ;
                dinA.Status          <= `StatusActive                                                                        ;
                IncrRandBRAMpointer  <= 1                                                                                    ;
                NextRandBRAMpointer  <= $urandom_range(0,2**BRAM_ADDR_WIDTH - 1)                                             ;
              end 
              // if this is no empty Descriptor Read the Next one
              else begin  
                weA                    <= 0                                                           ;  
                addrA                  <= RandBRAMpointer + $urandom_range(0,2**BRAM_ADDR_WIDTH - 1)  ;
                dinA                   <= '{default:0}                                                ;
                IncrRandBRAMpointer    <= 1                                                           ;
                NextRandBRAMpointer    <= addrA                                                       ;
              end
            end
          default begin
                weA                    <= 0              ;  
                addrA                  <= 0              ;
                dinA                   <= 0              ;
                IncrRandBRAMpointer    <= 0              ;
                NextRandBRAMpointer    <= 0              ;
          end
        endcase   
      end
 //-----------------------END Last Phase -------------------------
    end
    
    
 //********************** Last Phase's blocks **********************
    // There is a new transaction every random delays
    always@(negedge Clk) begin
      if(RST)begin
        NewTrans        = 0 ;
        numOfSchedTrans = 0 ;   
        #(period)           ; 
      end
      else begin
        if(numOfSchedTrans != NUM_OF_TRANS & phase == LastPhase )begin
          NewTrans        = 1                   ;
          numOfSchedTrans = numOfSchedTrans + 1 ;
          #(period*2)                           ; 
          NewTrans        = 0                   ;
          #(period * 2 * $urandom_range(10))    ; 
        end
      end     
    end
    
    //manage number of transaction that must be done 
    always_ff@(posedge Clk) begin
      if(RST)
        numOfTrans <= 0 ;
      else begin
        if(NewTrans & (weA == 0) & phase == LastPhase)begin
          numOfTrans <= numOfTrans + 1 ;        
        end
        else if(!NewTrans & (weA != 0) & phase == LastPhase)begin
          numOfTrans <= numOfTrans - 1 ;        
        end
      end
    end
    
    // BRAM pointer for Read Next Descriptor
    always_ff@(posedge Clk)begin
      if(RST)
        RandBRAMpointer <= $urandom_range(0,2**BRAM_ADDR_WIDTH - 1) ;
      else
        if(IncrRandBRAMpointer)
          RandBRAMpointer <=  NextRandBRAMpointer ;
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
            if(weA != 0)
               next_state = ReadState ;
            else
              next_state = WriteState ;
          end
        default : next_state = ReadState;
      endcase   
    end
endmodule
