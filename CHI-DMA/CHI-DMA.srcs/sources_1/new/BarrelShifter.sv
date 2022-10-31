`timescale 1ns / 1ps
import CHIFlitsPkg::*;
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07.09.2022 19:50:51
// Design Name: 
// Module Name: BarrelShifter
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
`define MaxCrds           15
`define CrdRegWidth       4  // log2(MaxCrds)


module BarrelShifter#(
//--------------------------------------------------------------------------
  parameter CHI_DATA_WIDTH   = 64                    , // Bytes
  parameter SIZE_FIFO_WIDTH  = 7                     , // log2(CHI_DATA_WIDTH) + 1 
  parameter SHIFT_WIDTH      = 9                     , // log2(CHI_DATA_WIDTH*8)
  parameter BRAM_COL_WIDTH   = 32                    ,
  parameter FIFO_LENGTH      = 32                    ,
  parameter COUNTER_WIDTH    = 6                       // log2(FIFO_LENGTH) + 1
//--------------------------------------------------------------------------
) ( 
    input                                         RST          ,
    input                                         Clk          ,
    input               [BRAM_COL_WIDTH   - 1 :0] SrcAddrIn    ,
    input               [BRAM_COL_WIDTH   - 1 :0] DstAddrIn    ,
    input               [BRAM_COL_WIDTH   - 1 :0] LengthIn     ,
    input                                         EnqueueIn    ,
    input                                         DequeueBS    ,
    input                                         RXDATFLITV   ,
    input   DataFlit                              RXDATFLIT    ,
    output                                        RXDATLCRDV   ,
    output  reg        [CHI_DATA_WIDTH   - 1 : 0] BEOut        ,
    output  reg        [CHI_DATA_WIDTH*8 - 1 : 0] DataOut      ,
    output  reg                                   EmptyBS      ,
    output                                        BSFULL
    );
    
    enum int unsigned { StartState         = 0 , 
                        MergeReadDataState = 1 , 
                        ExtraWriteState    = 2  } state , next_state ; 
                        
   
   // Transactions counters
   reg  [BRAM_COL_WIDTH   - 1 : 0]  CountWriteBytes ;     
   reg                              CntReadWE       ;  
   wire [BRAM_COL_WIDTH   - 1 : 0]  NextReadCnt     ;  
   wire [BRAM_COL_WIDTH   - 1 : 0]  NextSrcAddr     ;
   reg  [BRAM_COL_WIDTH   - 1 : 0]  CountReadBytes  ;    
   reg                              CntWriteWE      ;  
   wire [BRAM_COL_WIDTH   - 1 : 0]  NextWriteCnt    ; 
   wire [BRAM_COL_WIDTH   - 1 : 0]  NextDstAddr     ; 
   // Crds register
   reg  [`MaxCrds          - 1 : 0] DataCrdInbound  ; // Credits for inbound Data Chanel
   reg  [COUNTER_WIDTH     - 1 : 0] GivenDataCrd    ; // counter used in order not to take more DataRsp than FIFO length
   // BS merge register and signals
   reg  [CHI_DATA_WIDTH*8 - 1 : 0] PrevShiftedData  ; // Register that stores the shifted data that came to the previous DataRsp 
   reg                             PrvShftdDataWE   ; // WE of register
   wire [CHI_DATA_WIDTH*8 - 1 : 0] ShiftedData      ; // Out of Barrel Shifted comb 
   // Aligned Addresses
   wire [BRAM_COL_WIDTH   - 1 : 0] AlignedSrcAddr   ;
   wire [BRAM_COL_WIDTH   - 1 : 0] AlignedDstAddr   ;
  //shift
   wire [SHIFT_WIDTH      - 1 : 0] shift            ; // shift amount of Barrel Shifter
  // signals of Src,Dst,Length FIFOs
   wire                            EmptySrc         ; 
   reg                             DeqFIFO          ;
   reg                             DeqData          ;
   wire [BRAM_COL_WIDTH   - 1 : 0] SrcAddr          ;
   wire [BRAM_COL_WIDTH   - 1 : 0] DstAddr          ;
   wire [BRAM_COL_WIDTH   - 1 : 0] Length           ;
  // signals of Data FIFO
   wire [CHI_DATA_WIDTH*8 - 1 : 0] DataFIFO         ;
   wire                            DataEmpty        ;
   
   wire                            EmptyFIFO        ; // Or of every FIFO Empty
    
    

            // SrcAddr FIFO
   FIFO #(  
       BRAM_COL_WIDTH      ,  //FIFO_WIDTH       
       FIFO_LENGTH            //FIFO_LENGTH   
       )     
       FIFOSrcAddr (     
       .RST        ( RST        ) ,      
       .Clk        ( Clk        ) ,      
       .Inp        ( SrcAddrIn  ) , 
       .Enqueue    ( EnqueueIn  ) , 
       .Dequeue    ( DeqFIFO    ) , 
       .Outp       ( SrcAddr    ) , 
       .FULL       ( BSFULL     ) , 
       .Empty      ( EmptySrc   ) 
       );
            // DstAddr FIFO
   FIFO #(  
      BRAM_COL_WIDTH  ,  //FIFO_WIDTH       
      FIFO_LENGTH        //FIFO_LENGTH   
      )     
       FIFODstAddr  (     
       .RST         ( RST         ),     
       .Clk         ( Clk         ),     
       .Inp         ( DstAddrIn   ),
       .Enqueue     ( EnqueueIn   ), 
       .Dequeue     ( DeqFIFO     ),
       .Outp        ( DstAddr     ),
       .FULL        (             ),
       .Empty       (             )      
       );          
            // Length FIFO
   FIFO #(  
      BRAM_COL_WIDTH  ,  //FIFO_WIDTH       
      FIFO_LENGTH        //FIFO_LENGTH   
      )     
       FIFOLength   (     
       .RST         ( RST         ),     
       .Clk         ( Clk         ),     
       .Inp         ( LengthIn    ),
       .Enqueue     ( EnqueueIn   ), 
       .Dequeue     ( DeqFIFO     ),
       .Outp        ( Length      ),
       .FULL        (             ),
       .Empty       (             )      
       );                 
          // Data FIFO
   FIFO #(  
       CHI_DATA_WIDTH*8 ,  //FIFO_WIDTH       
       FIFO_LENGTH         //FIFO_LENGTH   
       )     
       FIFOData        (             
       .RST            ( RST                              ),     
       .Clk            ( Clk                              ),     
       .Inp            ( RXDATFLIT.Data                   ),
       .Enqueue        ( RXDATFLITV & DataCrdInbound != 0 ),
       .Dequeue        ( DeqData                          ),
       .Outp           ( DataFIFO                         ),
       .FULL           (                                  ),
       .Empty          ( DataEmpty                        )
       );                           
    
    // Manage counters 
    assign NextSrcAddr  = (CountReadBytes  + SrcAddr);
    assign NextReadCnt  = (CHI_DATA_WIDTH + {NextSrcAddr[BRAM_COL_WIDTH - 1 : SIZE_FIFO_WIDTH - 1],{SIZE_FIFO_WIDTH - 1{1'b0}}} - SrcAddr) < Length ? (CHI_DATA_WIDTH + {NextSrcAddr[BRAM_COL_WIDTH - 1 : SIZE_FIFO_WIDTH - 1],{SIZE_FIFO_WIDTH - 1{1'b0}}} - SrcAddr) : Length ;
    assign NextDstAddr  = (CountWriteBytes + DstAddr);
    assign NextWriteCnt = (CHI_DATA_WIDTH + {NextDstAddr[BRAM_COL_WIDTH - 1 : SIZE_FIFO_WIDTH - 1],{SIZE_FIFO_WIDTH - 1{1'b0}}} - DstAddr) < Length ? (CHI_DATA_WIDTH + {NextDstAddr[BRAM_COL_WIDTH - 1 : SIZE_FIFO_WIDTH - 1],{SIZE_FIFO_WIDTH - 1{1'b0}}} - DstAddr) : Length ;
    always_ff@(posedge Clk)begin
      if(RST)begin
        CountWriteBytes <= 0 ;
        CountReadBytes  <= 0 ;
      end
      else begin
        if(CntReadWE == 1 | DeqFIFO == 1)begin
          CountReadBytes = (DeqFIFO) ? 0 : NextReadCnt ;
        end
        if(CntWriteWE == 1 | DeqFIFO == 1)begin
          CountWriteBytes = (DeqFIFO) ? 0 : NextWriteCnt ;
        end
      end      
    end
    
    // Enable the corect Bytes to be written 
    always_comb begin
      if(NextWriteCnt == Length)begin // if last trans
        if(Length < CHI_DATA_WIDTH &  AlignedDstAddr + CHI_DATA_WIDTH - DstAddr > Length)begin // if address range of Data that should be written is internal of CHI_DATA_WIDTH
          BEOut = ({CHI_DATA_WIDTH{1'b1}}<<(DstAddr - AlignedDstAddr)) & ~({CHI_DATA_WIDTH{1'b1}}<<(DstAddr - AlignedDstAddr + Length)); 
        end
        else begin
          BEOut = ~({CHI_DATA_WIDTH{1'b1}}<<(NextWriteCnt - CountWriteBytes)) ;  // Enable the least significant bits 
        end
      end
      else begin
         BEOut = ~({CHI_DATA_WIDTH{1'b1}}>>(NextWriteCnt - CountWriteBytes)) ; // enable the most significant or all bytes 
      end
    end
    
    // or of FIFO's empty
    assign EmptyFIFO = EmptySrc | DataEmpty ;
    
    assign AlignedSrcAddr = {SrcAddr[BRAM_COL_WIDTH - 1 : SIZE_FIFO_WIDTH - 1],{SIZE_FIFO_WIDTH - 1{1'b0}}};
    assign AlignedDstAddr = {DstAddr[BRAM_COL_WIDTH - 1 : SIZE_FIFO_WIDTH - 1],{SIZE_FIFO_WIDTH - 1{1'b0}}};
    assign shift          = ((SrcAddr - AlignedSrcAddr) - (DstAddr - AlignedDstAddr))<<3   ;//*8
    
    // ---------------------Barrel Shifter comb---------------------
    /*Barrel Shifter comb does a circular right shifts of its Data input by
     the amount of its shift input*/
    wire  [CHI_DATA_WIDTH*8 - 1 : 0] muxout [CHI_DATA_WIDTH*8 - 1 : 0];  // muxes of Barrel Shifter
    assign muxout[0] = shift[0] ? ({DataFIFO[0],DataFIFO[CHI_DATA_WIDTH*8  - 1 :1]}): DataFIFO ;
    genvar i ;
    generate 
    for(i = 1 ; i < SHIFT_WIDTH ; i++)
      assign muxout[i] = shift[i] ? ({muxout[i-1][2**i - 1 : 0],muxout[i-1][CHI_DATA_WIDTH*8  - 1 : 2**i]}): muxout[i-1] ;
    endgenerate
    assign ShiftedData = muxout[SHIFT_WIDTH - 1];
    // ---------------------end Barrel Shifter comb---------------------

    // Manage Register that stores the shifted data from BScomb
    always_ff@(posedge Clk) begin
      if(RST)
        PrevShiftedData = 0 ;
      else
        if(PrvShftdDataWE)begin
          PrevShiftedData = ShiftedData ;
        end
    end    
    
    // manage Crds
     always_ff @ (posedge Clk) begin
     if(RST)begin
       DataCrdInbound <= 0 ;        // Reset FSM
       GivenDataCrd   <= 0 ;
     end        
     else begin
       // Inbound Data chanle Crd Counter
       if(RXDATLCRDV & !(DataCrdInbound != 0 & RXDATFLITV))
         DataCrdInbound <= DataCrdInbound + 1 ;
       else if(!RXDATLCRDV & (DataCrdInbound != 0 & RXDATFLITV))
         DataCrdInbound <= DataCrdInbound - 1 ;
       // Count the number of given Data Crds in order not to give more than DATA FIFO length
       if(RXDATLCRDV & !DequeueBS)
         GivenDataCrd <= GivenDataCrd + 1 ;       
       else if(!RXDATLCRDV & DequeueBS)
         GivenDataCrd <= GivenDataCrd - 1 ;
     end
   end
   // Give an extra Crd in outbound Data Chanel
   assign RXDATLCRDV = !RST & (GivenDataCrd < FIFO_LENGTH & DataCrdInbound < `MaxCrds) ;
    
     //FSM's state
   always_ff @ (posedge Clk) begin
     if(RST)
       state <= StartState ;        // Reset FSM
     else
       state <= next_state ;        // Change state
   end
         
   //FSM's next_state
   always_comb begin : next_state_logic
     case(state)
       StartState :
         begin                           
           if(!EmptyFIFO & NextReadCnt < Length & ((NextWriteCnt < Length & DequeueBS & (DstAddr - AlignedDstAddr) > (SrcAddr - AlignedSrcAddr)) | ((DstAddr - AlignedDstAddr) < (SrcAddr - AlignedSrcAddr))))  // When Data should be shifted left or right and not last Chunk's Read and Write then in the next state 2 Read Data shoudld be merged to create the Write Data word
             next_state = MergeReadDataState ;
           else if(!EmptyFIFO & NextWriteCnt < Length & NextReadCnt == Length & DequeueBS & (DstAddr - AlignedDstAddr) > (SrcAddr - AlignedSrcAddr))  // When it is the last Read Trans but not the last Write and Data must be shifted then should be an extra write  
             next_state = ExtraWriteState ;
           else                       // When Data needs no shift or it is the last Read/Write trans or CHI-Conv dont need the data yet(!DequeueBS)
             next_state = StartState ; 
         end
       MergeReadDataState :
         begin
           if( NextReadCnt == Length &  NextWriteCnt == Length & !EmptyFIFO & DequeueBS)         //  When last Read becomes the last Write return to StartState
             next_state = StartState ;
           else if ( NextReadCnt == Length &  NextWriteCnt < Length & !EmptyFIFO & DequeueBS)  //  When last Read completes a non-last Write then it should complete the last Write as well so an extra write should be done 
             next_state = ExtraWriteState ;
           else                                  // When next Write Trans needs alsa to merge data   
             next_state = MergeReadDataState ;            
         end
       ExtraWriteState : 
         if(NextReadCnt == Length &  NextWriteCnt == Length & !EmptyFIFO & DequeueBS)  //  When last Read and last Write return to StartState and CHI-Conv needs the data (DequeueBS)
           next_state = StartState ;
         else
           next_state = ExtraWriteState ;
       default : next_state = StartState ;          // Default state
     endcase   
   end
   
   //FSM's signals
  always_comb begin
    case(state)
       StartState :
         begin                      
           if(EmptyFIFO)begin     // if one of FIFOs is empty then BS is emptt and do nothing
             EmptyBS        = 1 ;
             CntReadWE      = 0 ;
             CntWriteWE     = 0 ;
             DataOut        = 0 ;
             PrvShftdDataWE = 0 ;
             DeqFIFO        = 0 ;
             DeqData        = 0 ;
           end
           else begin
             if((DstAddr - AlignedDstAddr) < (SrcAddr - AlignedSrcAddr) & NextReadCnt < Length)begin  // When Data must be shifted right and its not last Read then no enough data for a write  
               EmptyBS        = 1 ; // Barrel Shifter is empty because there are not enough data for a Write
               CntReadWE      = 1 ; // Update Read Counter
               CntWriteWE     = 0 ; // Dont update Write Counter because there are not enough data for a Write
               DataOut        = 0 ; // Output Data
               PrvShftdDataWE = 1 ; // Write shifted Data in register 
               DeqFIFO        = 0 ; // Dont Dequeue FIFOs (SrcAddr,DstAddr,Legnth)
               DeqData        = 1 ; // Dequeue Data FIFO because there are Data that have been read
             end
             else if(NextReadCnt == Length & NextWriteCnt < Length & (DstAddr - AlignedDstAddr) > (SrcAddr - AlignedSrcAddr))begin // When last Read but not last write and data must be shifted left then give first data for write (read must become 2 writes) 
               EmptyBS        = 0           ;
               CntReadWE      = 0           ; // Dont Update Read Counter because it is the last Read but not last write
               CntWriteWE     = DequeueBS   ; // Update Write Counter
               DataOut        = ShiftedData ; 
               PrvShftdDataWE = DequeueBS   ; 
               DeqFIFO        = 0           ;
               DeqData        = 0           ;
             end
             else if((NextReadCnt == Length & NextWriteCnt == Length ) | (NextReadCnt < Length  & NextWriteCnt < Length  & (DstAddr - AlignedDstAddr) >= (SrcAddr - AlignedSrcAddr)))begin // when last Read-Write or no shift or left shift of data needed then give Data for Write
               EmptyBS        = 0                                                             ;
               CntReadWE      = DequeueBS                                                     ;
               CntWriteWE     = DequeueBS                                                     ;
               DataOut        = ShiftedData                                                   ;
               PrvShftdDataWE = DequeueBS                                                     ;
               DeqFIFO        = (DequeueBS & NextReadCnt == Length & NextWriteCnt == Length ) ;
               DeqData        = DequeueBS                                                     ;             
             end
             else begin // it should never go to else 
               EmptyBS        = 1 ;
               CntReadWE      = 0 ;
               CntWriteWE     = 0 ;
               DataOut        = 0 ;
               PrvShftdDataWE = 0 ;
               DeqFIFO        = 0 ;
               DeqData        = 0 ;
             end              
           end
         end
       MergeReadDataState : 
         begin        
           if(EmptyFIFO)begin     // if one of FIFOs is empty then BS is emptt and do nothing
             EmptyBS        = 1 ;
             CntReadWE      = 0 ;
             CntWriteWE     = 0 ;
             DataOut        = 0 ;
             PrvShftdDataWE = 0 ;
             DeqFIFO        = 0 ;
             DeqData        = 0 ;
           end
           else begin
             if((NextReadCnt == Length & NextWriteCnt == Length ) | (NextReadCnt < Length & NextWriteCnt < Length ))begin  // If both of Read and Write are last trans then create the right DataOut and dequeue FIFO else just create the right DataOut
               EmptyBS        = 0                                                                                                                    ;
               CntReadWE      = DequeueBS                                                                                                            ;
               CntWriteWE     = DequeueBS                                                                                                            ;
               PrvShftdDataWE = DequeueBS                                                                                                            ;
               DeqFIFO        = (DequeueBS & NextReadCnt == Length & NextWriteCnt == Length )                                                        ;
               DeqData        = DequeueBS                                                                                                            ;    
               DataOut        = (ShiftedData & (~({(CHI_DATA_WIDTH*8){1'b1}} >> shift))) | (PrevShiftedData & ({(CHI_DATA_WIDTH*8){1'b1}} >> shift)) ; // = {ShiftedData[CHI_DATA_WIDTH-1:CHI_DATA_WIDTH-shift],PrevShiftedData[CHI_DATA_WIDTH-shift-1:0]}
             end
             else if(NextReadCnt == Length & NextWriteCnt < Length)begin  // If it is the last Read and but not the last Write create the right DataOut and next cycle do an extra write
               EmptyBS        = 0                                                                                                                    ;
               CntReadWE      = 0                                                                                                                    ;
               CntWriteWE     = DequeueBS                                                                                                            ;
               PrvShftdDataWE = DequeueBS                                                                                                            ;
               DeqFIFO        = 0                                                                                                                    ;
               DeqData        = 0                                                                                                                    ;  
               DataOut        = (ShiftedData &( ~({(CHI_DATA_WIDTH*8){1'b1}} >> shift))) | (PrevShiftedData & ({(CHI_DATA_WIDTH*8){1'b1}} >> shift)) ; // = {ShiftedData[CHI_DATA_WIDTH-1:CHI_DATA_WIDTH-shift],PrevShiftedData[CHI_DATA_WIDTH-shift-1:0]}
             end                                                                                                                                             
             else begin // it should never go to else
               EmptyBS        = 0 ;
               CntReadWE      = 0 ;
               CntWriteWE     = 0 ;
               PrvShftdDataWE = 0 ;
               DeqFIFO        = 0 ;
               DeqData        = 0 ;  
               DataOut        = 0 ; 
             
             end
           end
         end
       ExtraWriteState : 
          if(EmptyFIFO)begin     // if one of FIFOs is empty then BS is emptt and do nothing
             EmptyBS        = 1 ;
             CntReadWE      = 0 ;
             CntWriteWE     = 0 ;
             PrvShftdDataWE = 0 ;
             DeqFIFO        = 0 ;
             DeqData        = 0 ;  
             DataOut        = 0 ; 
           end
           else begin
             EmptyBS        = 0               ;
             CntReadWE      = 1               ;
             CntWriteWE     = 1               ;
             PrvShftdDataWE = 0               ;
             DeqFIFO        = 1               ;
             DeqData        = 1               ;
             DataOut        = PrevShiftedData ; 
           end
       default :
         begin                
           EmptyBS        = 1 ;
           CntReadWE      = 0 ;
           CntWriteWE     = 0 ;
           PrvShftdDataWE = 0 ;
           DeqFIFO        = 0 ;
           DeqData        = 0 ;  
           DataOut        = 0 ; 
         end                  
    endcase ;
  end
    
endmodule
