`timescale 1ns / 1ps
import CHIFlitsPkg ::*;
import CHIFIFOsPkg ::*;
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
`define RspErrWidth       2


module BarrelShifter#(
//--------------------------------------------------------------------------
  parameter CHI_DATA_WIDTH      = 64                    , // Bytes
  parameter ADDR_WIDTH_OF_DATA  = 6                     , // log2(CHI_DATA_WIDTH)  
  parameter SHIFT_WIDTH         = 9                     , // log2(CHI_DATA_WIDTH*8)
  parameter BRAM_COL_WIDTH      = 32                    ,
  parameter BRAM_ADDR_WIDTH     = 10                    ,
  parameter CMD_FIFO_LENGTH     = 32                    ,
  parameter DATA_FIFO_LENGTH    = 32                    ,
  parameter COUNTER_WIDTH       = 6                       // log2(FIFO_LENGTH) + 1
//--------------------------------------------------------------------------
) ( 
    input                                                        RST           ,
    input                                                        Clk           ,
    input                  CHI_Command                           CommandIn     , // CHI-Command (SrcAddr,DstAddr,Length,DescAddr,LastDescTrans)
    input                                                        EnqueueIn     ,
    input                                                        ValidDataBS   ,
    DatInbChannel.INBOUND                                        DatInbChan    , // Data inbound Chanel
    output                 reg        [CHI_DATA_WIDTH   - 1 : 0] BEOut         ,
    output                 reg        [CHI_DATA_WIDTH*8 - 1 : 0] DataOut       ,
    output                            [`RspErrWidth     - 1 : 0] DataError     ,
    output                            [BRAM_ADDR_WIDTH  - 1 : 0] DescAddr      ,
    output                                                       LastDescTrans ,
    output                 reg                                   ReadyDataBS   ,
    output                                                       FULLCmndBS
    );
    
    enum int unsigned { StartState         = 0 , 
                        MergeReadDataState = 1 , 
                        ExtraWriteState    = 2  } state , next_state ; 
                        
   
   // Transactions counters
   reg                   [BRAM_COL_WIDTH   - 1 : 0]  CountWriteBytes ;     
   reg                                               CntReadWE       ;  
   wire                  [BRAM_COL_WIDTH   - 1 : 0]  NextReadCnt     ;   
   reg                   [BRAM_COL_WIDTH   - 1 : 0]  CountReadBytes  ;    
   reg                                               CntWriteWE      ;  
   wire                  [BRAM_COL_WIDTH   - 1 : 0]  NextWriteCnt    ; 
   wire                  [BRAM_COL_WIDTH   - 1 : 0]  NextSrcAddr     ;  
   wire                  [BRAM_COL_WIDTH   - 1 : 0]  NextDstAddr     ; 
   // Crds register
   reg                   [`MaxCrds          - 1 : 0] DataCrdInbound  ; // Credits for inbound Data Chanel
   reg                   [COUNTER_WIDTH     - 1 : 0] GivenDataCrd    ; // counter used in order not to take more DataRsp than FIFO length
   // BS merge register and signals
   reg                   [CHI_DATA_WIDTH*8 - 1 : 0] PrevShiftedData  ; // Register that stores the shifted data that came to the previous DataRsp 
   reg                                              PrvShftdDataWE   ; // WE of register
   wire                  [CHI_DATA_WIDTH*8 - 1 : 0] ShiftedData      ; // Out of Barrel Shifted comb 
  //shift
   wire                  [SHIFT_WIDTH      - 1 : 0] shift            ; // shift amount of Barrel Shifter
  // signals of command FIFOs
   wire                                             EmptyCom         ; 
   reg                                              DeqFIFO          ;
   reg                                              DeqData          ;
   CHI_Command                                      Command          ;
  // signals of Data FIFO
   CHI_FIFO_Data_Packet                             DataFIFO         ;
   wire                                             DataEmpty        ;
   CHI_FIFO_Data_Packet                             DataFIFOIn       ;
   wire                                             EmptyFIFO        ; // Or of every FIFO Empty
           
    
   assign LastDescTrans = DeqFIFO & Command.LastDescTrans ;
   assign DescAddr      = Command.DescAddr                ;
   assign DataError     = DataFIFO.RespErr                ;
   
   assign DataFIFOIn    = '{default : 0 , Data : DatInbChan.RXDATFLIT.Data  , RespErr : DatInbChan.RXDATFLIT.RespErr};
   // Command FIFO(SrcAddr,DstAddr,BTS,SB,DescAddr,LastDescTrans)
   FIFO #(  
       .FIFO_WIDTH   (3*BRAM_COL_WIDTH + BRAM_ADDR_WIDTH + 1 )     ,  //FIFO_WIDTH       
       .FIFO_LENGTH  (CMD_FIFO_LENGTH                        )        //FIFO_LENGTH   
       )     
       FIFOCmnd    (     
       .RST        ( RST        ) ,      
       .Clk        ( Clk        ) ,      
       .Inp        ( CommandIn  ) , 
       .Enqueue    ( EnqueueIn  ) , 
       .Dequeue    ( DeqFIFO    ) , 
       .Outp       ( Command    ) , 
       .FULL       ( FULLCmndBS ) , 
       .Empty      ( EmptyCom   ) 
       );   
          
   // Data FIFO
   FIFO #(  
       .FIFO_WIDTH   (CHI_DATA_WIDTH*8 + `RspErrWidth) ,  //FIFO_WIDTH       
       .FIFO_LENGTH  (DATA_FIFO_LENGTH               )    //FIFO_LENGTH   
       )     
       FIFOData        (             
       .RST            ( RST                                         ),     
       .Clk            ( Clk                                         ),     
       .Inp            ( DataFIFOIn                                  ),
       .Enqueue        ( DatInbChan.RXDATFLITV & DataCrdInbound != 0 ),
       .Dequeue        ( DeqData                                     ),
       .Outp           ( DataFIFO                                    ),
       .FULL           (                                             ),
       .Empty          ( DataEmpty                                   )
       );                           
    
    //----------- Manage Read-Write Req Bytes counters -----------
    assign NextSrcAddr  = Command.SrcAddr + CountReadBytes  ;
    assign NextDstAddr  = Command.DstAddr + CountWriteBytes ;
    assign NextReadCnt  = (CountReadBytes  == 0) ? ((Command.Length < (CHI_DATA_WIDTH - Command.SrcAddr[ADDR_WIDTH_OF_DATA - 1 : 0])) ? (Command.Length) : (CHI_DATA_WIDTH - Command.SrcAddr[ADDR_WIDTH_OF_DATA - 1 : 0])) : ((CountReadBytes + CHI_DATA_WIDTH < Command.Length) ? (CountReadBytes + CHI_DATA_WIDTH) : (Command.Length)) ;
    //assign NextReadCnt  = (CHI_DATA_WIDTH - NextSrcAddr[ADDR_WIDTH_OF_DATA - 1 : 0] + CountReadBytes ) < Command.Length ? (CHI_DATA_WIDTH - NextSrcAddr[ADDR_WIDTH_OF_DATA - 1 : 0] + CountReadBytes ) : Command.Length ;
    assign NextWriteCnt = (CountWriteBytes == 0) ? ((Command.Length < (CHI_DATA_WIDTH - Command.DstAddr[ADDR_WIDTH_OF_DATA - 1 : 0])) ? (Command.Length) : (CHI_DATA_WIDTH - Command.DstAddr[ADDR_WIDTH_OF_DATA - 1 : 0])) : ((CountWriteBytes + CHI_DATA_WIDTH < Command.Length) ? (CountWriteBytes + CHI_DATA_WIDTH) : (Command.Length)) ;
    //assign NextWriteCnt = (CHI_DATA_WIDTH - NextDstAddr[ADDR_WIDTH_OF_DATA - 1 : 0] + CountWriteBytes) < Command.Length ? (CHI_DATA_WIDTH - NextDstAddr[ADDR_WIDTH_OF_DATA - 1 : 0] + CountWriteBytes) : Command.Length ;
    always_ff@(posedge Clk)begin
      if(RST)begin
        CountWriteBytes <= 0 ;
        CountReadBytes  <= 0 ;
      end
      else begin
        if(DeqFIFO == 1)begin
          CountReadBytes <= 0         ;
        end
        else if(CntReadWE == 1)begin
        CountReadBytes <= NextReadCnt ;
        end      
          
        if( DeqFIFO == 1)begin
          CountWriteBytes <= 0            ;
        end
        else if(CntWriteWE == 1)begin
          CountWriteBytes <= NextWriteCnt ;
        end
      end      
    end
    //------------------------------------------------------------------
    
    //////////////////////Enable the corect Bytes to be written////////////////////// 
    always_comb begin
      if(NextWriteCnt == Command.Length)begin // if last trans
        if((CHI_DATA_WIDTH - Command.DstAddr[ADDR_WIDTH_OF_DATA - 1 : 0] >= Command.Length))begin // if address range of Data that should be written is internal of CHI_DATA_WIDTH
          BEOut = ({CHI_DATA_WIDTH{1'b1}} << Command.DstAddr[ADDR_WIDTH_OF_DATA - 1 : 0]) & ~({CHI_DATA_WIDTH{1'b1}} << (Command.DstAddr[ADDR_WIDTH_OF_DATA - 1 : 0] + Command.Length)); 
        end
        else begin
          BEOut = ~({CHI_DATA_WIDTH{1'b1}} << Command.Length - CountWriteBytes) ;  // Enable the least significant bits 
        end
      end
      else begin
        if(CountWriteBytes == 0)
          BEOut = ({CHI_DATA_WIDTH{1'b1}} << Command.DstAddr[ADDR_WIDTH_OF_DATA - 1 : 0]) ; // enable the most significant or all bytes 
        else
          BEOut = {CHI_DATA_WIDTH{1'b1}} ;
      end
    end
    ////////////////////////////////////////////////////////////////////////////////////////
    
    // or of FIFOs' empty
    assign EmptyFIFO = EmptyCom | DataEmpty ;
    
    //>>>>>> Create Shift for BS comb <<<<<<<<<<
    assign shift          = (Command.SrcAddr[ADDR_WIDTH_OF_DATA - 1 : 0] - Command.DstAddr[ADDR_WIDTH_OF_DATA - 1 : 0]) << 3   ;//*8
    //>>>>>>>>>>>>>>>>>>><<<<<<<<<<<<<<<<<<<<<<<
    
    // ---------------------Barrel Shifter comb---------------------
    /*Barrel Shifter comb does a circular right shifts of its Data input by
     the amount of its shift input*/
    wire  [CHI_DATA_WIDTH*8 - 1 : 0] muxout [SHIFT_WIDTH - 3 - 1 : 0];  // muxes of Barrel Shifter
    assign muxout[0] = shift[3] ? ({DataFIFO.Data[7 : 0],DataFIFO.Data[CHI_DATA_WIDTH*8  - 1 :8]}): DataFIFO.Data ;
    genvar i ;
    generate 
    for(i = 1 ; i < SHIFT_WIDTH - 3 ; i++)
      assign muxout[i] = shift[i+3] ? ({muxout[i-1][2**(i + 3) - 1 : 0],muxout[i-1][CHI_DATA_WIDTH*8  - 1 : 2**(i + 3)]}): muxout[i-1] ;
    endgenerate
    assign ShiftedData = muxout[SHIFT_WIDTH - 3 - 1];
    // ---------------------end Barrel Shifter comb---------------------

    // Manage Register that stores the shifted data from BScomb
    always_ff@(posedge Clk) begin
      if(RST)
        PrevShiftedData <= 0 ;
      else
        if(PrvShftdDataWE)begin
          PrevShiftedData <= ShiftedData ;
        end
    end    
    
    //-------------------------------------Crds manager------------------------------------
     always_ff @ (posedge Clk) begin
     if(RST)begin
       DataCrdInbound <= 0 ;        // Reset FSM
       GivenDataCrd   <= 0 ;
     end        
     else begin
       // Inbound Data chanle Crd Counter
       if(DatInbChan.RXDATLCRDV & !(DataCrdInbound != 0 & DatInbChan.RXDATFLITV))
         DataCrdInbound <= DataCrdInbound + 1 ;
       else if(!DatInbChan.RXDATLCRDV & (DataCrdInbound != 0 & DatInbChan.RXDATFLITV))
         DataCrdInbound <= DataCrdInbound - 1 ;
       // Count the number of given Data Crds in order not to give more than DATA FIFO length
       if(DatInbChan.RXDATLCRDV & !DeqData)
         GivenDataCrd <= GivenDataCrd + 1 ;       
       else if(!DatInbChan.RXDATLCRDV & DeqData)
         GivenDataCrd <= GivenDataCrd - 1 ;
     end
   end
   // Give an extra Crd in outbound Data Chanel
   assign DatInbChan.RXDATLCRDV = !RST & (GivenDataCrd < CMD_FIFO_LENGTH & DataCrdInbound < `MaxCrds) ;
  //------------------------------------End Crds manager------------------------------------ 
  
  //################################ FSM  ################################
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
           if(!EmptyFIFO & (NextReadCnt < Command.Length) & ((Command.DstAddr[ADDR_WIDTH_OF_DATA - 1 : 0] < Command.SrcAddr[ADDR_WIDTH_OF_DATA - 1 : 0])))  // When Data should be shifted right and not last Chunk's Read then in the next state 2 Read Data should be merged to create the Write Data word (doesnt wait for CHI-COnv to dequeu BS)
             next_state = MergeReadDataState ;
           else if(!EmptyFIFO & (NextReadCnt < Command.Length) & ((NextWriteCnt < Command.Length & ValidDataBS & (Command.DstAddr[ADDR_WIDTH_OF_DATA - 1 : 0] > Command.SrcAddr[ADDR_WIDTH_OF_DATA - 1 : 0]))))  // When Data should be shifted left and not last Chunk's Read then in the next state 2 Read Data should be merged to create the Write Data word
             next_state = MergeReadDataState ;
           else if(!EmptyFIFO & (NextWriteCnt < Command.Length) & (NextReadCnt == Command.Length) & ValidDataBS)  // When it is the last Read Trans but not the last Write and Data must be shifted then should be an extra write  
             next_state = ExtraWriteState ;
           else                       // When Data needs no shift or it is the last Read/Write trans or CHI-Conv dont need the data yet(!ValidDataBS)
             next_state = StartState ; 
         end
       MergeReadDataState :
         begin
           if(NextReadCnt == Command.Length &  NextWriteCnt == Command.Length & !EmptyFIFO & ValidDataBS)        //  When last Read becomes the last Write return to StartState
             next_state = StartState ;
           else if (NextReadCnt == Command.Length &  NextWriteCnt < Command.Length & !EmptyFIFO & ValidDataBS)  //  When last Read completes a non-last Write then it should complete the last Write as well so an extra write should be done 
             next_state = ExtraWriteState ;
           else                                  // When next Write Trans needs alsa to merge data   
             next_state = MergeReadDataState ;            
         end
       ExtraWriteState : 
         if(!EmptyFIFO & ValidDataBS)  //  When last Read and last Write return to StartState and CHI-Conv needs the data (ValidDataBS)
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
           if(EmptyFIFO)begin     // if one of FIFOs is empty then BS is empty and do nothing
             ReadyDataBS    = 0 ;
             CntReadWE      = 0 ;
             CntWriteWE     = 0 ;
             DataOut        = 0 ;
             PrvShftdDataWE = 0 ;
             DeqFIFO        = 0 ;
             DeqData        = 0 ;
           end
           else begin
           // When Data must be shifted right and its not last Read then no enough data for a write  
             if((Command.DstAddr[ADDR_WIDTH_OF_DATA - 1 : 0] < Command.SrcAddr[ADDR_WIDTH_OF_DATA - 1 : 0]) & (NextReadCnt < Command.Length))begin  
               ReadyDataBS    = 0 ; // Barrel Shifter is empty because there are not enough data for a Write
               CntReadWE      = 1 ; // Update Read Counter
               CntWriteWE     = 0 ; // Dont update Write Counter because there are not enough data for a Write
               DataOut        = 0 ; // Output Data
               PrvShftdDataWE = 1 ; // Write shifted Data in register 
               DeqFIFO        = 0 ; // Dont Dequeue FIFOs (SrcAddr,DstAddr,Legnth)
               DeqData        = 1 ; // Dequeue Data FIFO because there are Data that have been read
             end
             // when not last Read and Write and no shift or left shift of data is needed then give shiftedData for Write
             else if(ValidDataBS & (((NextReadCnt < Command.Length)  & (NextWriteCnt < Command.Length)  & (Command.DstAddr[ADDR_WIDTH_OF_DATA - 1 : 0] >= Command.SrcAddr[ADDR_WIDTH_OF_DATA - 1 : 0]))))begin
               ReadyDataBS    = 1                                                                ;
               CntReadWE      = 1                                                                ;
               CntWriteWE     = 1                                                                ;
               DataOut        = ShiftedData                                                      ;
               PrvShftdDataWE = 1                                                                ;
               DeqFIFO        = 0                                                                ;
               DeqData        = 1                                                                ;  
             end
             // When last Read but not last Write so data must be shifted left then give first shifted data for write (read must become 2 writes) 
             else if(ValidDataBS & (NextReadCnt == Command.Length) & (NextWriteCnt < Command.Length))begin 
               ReadyDataBS    = 1           ;
               CntReadWE      = 0           ; // Dont Update Read Counter because it is the last Read but not last write
               CntWriteWE     = 1           ; // Update Write Counter
               DataOut        = ShiftedData ; 
               PrvShftdDataWE = 1           ; 
               DeqFIFO        = 0           ;
               DeqData        = 0           ;
             end
             // when last Read and Writethen give shifted Data for Write
             else if(ValidDataBS & (((NextReadCnt == Command.Length) & (NextWriteCnt == Command.Length))))begin
               ReadyDataBS    = 1                                                                ;
               CntReadWE      = 1                                                                ;
               CntWriteWE     = 1                                                                ;
               DataOut        = ShiftedData                                                      ;
               PrvShftdDataWE = 1                                                                ;
               DeqFIFO        = 1                                                                ;
               DeqData        = 1                                                                ;  
             end
             // if ValidDataBS == 0 and not shift right
             else begin  
               ReadyDataBS    = 0           ;
               CntReadWE      = 0           ;
               CntWriteWE     = 0           ;
               DataOut        = ShiftedData ;
               PrvShftdDataWE = 0           ;
               DeqFIFO        = 0           ;
               DeqData        = 0           ;
             end              
           end
         end
       MergeReadDataState : 
         begin        
           if(EmptyFIFO)begin     // if one of FIFOs is empty then BS is emptt and do nothing
             ReadyDataBS    = 0 ;
             CntReadWE      = 0 ;
             CntWriteWE     = 0 ;
             DataOut        = 0 ;
             PrvShftdDataWE = 0 ;
             DeqFIFO        = 0 ;
             DeqData        = 0 ;
           end
           else begin
           // If both of Read and Write are last trans then create the right DataOut and dequeue FIFO and go to Start State
             if(ValidDataBS & ((NextReadCnt == Command.Length & NextWriteCnt == Command.Length)))begin  
               ReadyDataBS    = 1                                                                                                                    ;
               CntReadWE      = 1                                                                                                                    ;
               CntWriteWE     = 1                                                                                                                    ;
               PrvShftdDataWE = 1                                                                                                                    ;
               DeqFIFO        = 1                                                                                                                    ;
               DeqData        = 1                                                                                                                    ;    
               DataOut        = (ShiftedData & (~({(CHI_DATA_WIDTH*8){1'b1}} >> shift))) | (PrevShiftedData & ({(CHI_DATA_WIDTH*8){1'b1}} >> shift)) ; // = {ShiftedData[CHI_DATA_WIDTH-1:CHI_DATA_WIDTH-shift],PrevShiftedData[CHI_DATA_WIDTH-shift-1:0]}
             end
             // If it is the last Read but not the last Write create the right DataOut and next cycle do an extra write
             else if(ValidDataBS & NextReadCnt == Command.Length & NextWriteCnt < Command.Length)begin  
               ReadyDataBS    = 1                                                                                                                    ;
               CntReadWE      = 0                                                                                                                    ;
               CntWriteWE     = 1                                                                                                                    ;
               PrvShftdDataWE = 1                                                                                                                    ;
               DeqFIFO        = 0                                                                                                                    ;
               DeqData        = 0                                                                                                                    ;  
               DataOut        = (ShiftedData &( ~({(CHI_DATA_WIDTH*8){1'b1}} >> shift))) | (PrevShiftedData & ({(CHI_DATA_WIDTH*8){1'b1}} >> shift)) ; // = {ShiftedData[CHI_DATA_WIDTH-1:CHI_DATA_WIDTH-shift],PrevShiftedData[CHI_DATA_WIDTH-shift-1:0]}
             end        
           // If both of Read and Write are not last trans then create the right DataOut and state to MergeReadDataState
             else if(ValidDataBS & ((NextReadCnt < Command.Length & NextWriteCnt < Command.Length)))begin  
               ReadyDataBS    = 1                                                                                                                    ;
               CntReadWE      = 1                                                                                                                    ;
               CntWriteWE     = 1                                                                                                                    ;
               PrvShftdDataWE = 1                                                                                                                    ;
               DeqFIFO        = 0                                                                                                                    ;
               DeqData        = 1                                                                                                                    ;    
               DataOut        = (ShiftedData & (~({(CHI_DATA_WIDTH*8){1'b1}} >> shift))) | (PrevShiftedData & ({(CHI_DATA_WIDTH*8){1'b1}} >> shift)) ; // = {ShiftedData[CHI_DATA_WIDTH-1:CHI_DATA_WIDTH-shift],PrevShiftedData[CHI_DATA_WIDTH-shift-1:0]}
             end 
             // if Dequeue BS == 0                                                                                                                                     
             else begin 
               ReadyDataBS    = 0                                                                                                                    ;
               CntReadWE      = 0                                                                                                                    ;
               CntWriteWE     = 0                                                                                                                    ;
               PrvShftdDataWE = 0                                                                                                                    ;
               DeqFIFO        = 0                                                                                                                    ;
               DeqData        = 0                                                                                                                    ;  
               DataOut        = (ShiftedData &( ~({(CHI_DATA_WIDTH*8){1'b1}} >> shift))) | (PrevShiftedData & ({(CHI_DATA_WIDTH*8){1'b1}} >> shift)) ; // = {ShiftedData[CHI_DATA_WIDTH-1:CHI_DATA_WIDTH-shift],PrevShiftedData[CHI_DATA_WIDTH-shift-1:0]}
             
             end
           end
         end
       ExtraWriteState : 
          if(EmptyFIFO)begin     // if one of FIFOs are empty then BS is empty and do nothing
             ReadyDataBS    = 0 ;
             CntReadWE      = 0 ;
             CntWriteWE     = 0 ;
             PrvShftdDataWE = 0 ;
             DeqFIFO        = 0 ;
             DeqData        = 0 ;  
             DataOut        = 0 ; 
           end
           else if(ValidDataBS) begin
             ReadyDataBS    = 1               ;
             CntReadWE      = 1               ;
             CntWriteWE     = 1               ;
             PrvShftdDataWE = 0               ;
             DeqFIFO        = 1               ;
             DeqData        = 1               ;
             DataOut        = PrevShiftedData ; 
           end
           else begin
             ReadyDataBS    = 0               ;
             CntReadWE      = 0               ;
             CntWriteWE     = 0               ;
             PrvShftdDataWE = 0               ;
             DeqFIFO        = 0               ;
             DeqData        = 0               ;
             DataOut        = PrevShiftedData ; 
           end
       default :
         begin                
           ReadyDataBS    = 0 ;
           CntReadWE      = 0 ;
           CntWriteWE     = 0 ;
           PrvShftdDataWE = 0 ;
           DeqFIFO        = 0 ;
           DeqData        = 0 ;  
           DataOut        = 0 ; 
         end                  
    endcase ;
  end
   //################################ END FSM  ################################
endmodule
