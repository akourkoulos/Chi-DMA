`timescale 1ns / 1ps
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
  parameter CHI_DATA_WIDTH   = 64                    , //Bytes
  parameter SHIFT_WIDTH      = 9                     , // log(CHI_DATA_WIDTH*8)
  parameter BRAM_COL_WIDTH   = 32                    ,
  parameter FIFO_LENGTH      = 32                    ,
  parameter COUNTER_WIDTH    = 6                       // log(FIFO_LENGTH) + 1
) ( 
    input                                        RST          ,
    input                                        Clk          ,
    input               [BRAM_COL_WIDTH  - 1 :0] SrcAddrIn    ,
    input               [BRAM_COL_WIDTH  - 1 :0] DstAddrIn    ,
    input                                        LastSrcTrans ,
    input                                        LastDstTrans ,
    input                                        EnqueueSrc   ,
    input                                        EnqueueDst   ,
    input                                        RXDATFLITV   ,
    input   DataFlit                             RXDATFLIT    ,
    output                                       RXDATLCRDV   ,
    input                                        DequeueBS    ,
    output  reg        [CHI_DATA_WIDTH*8 - 1 :0] DataOut      ,
    output  reg                                  EmptyBS      ,
    output                                       BSFULLSrc    ,
    output                                       BSFULLDst
    );
    
    enum int unsigned { StartState      = 0 , 
                        LeftShiftState  = 1 , 
                        RightShiftState = 2 ,
                        ExtraWriteState = 3  } state , next_state ; 
                        
                        

   reg [`MaxCrds          - 1 : 0] DataCrdInbound   ; // Credits for inbound Data Chanel
   reg [COUNTER_WIDTH     - 1 : 0] GivenDataCrd     ; // counter used in order not to take more DataRsp than FIFO length
  
   reg  [CHI_DATA_WIDTH*8 - 1 : 0]  PrevShiftedData ; // Register that stores the shifted data that came to the previous DataRsp 
   reg                              PrvShftdDataWE  ; // WE of register
   wire [CHI_DATA_WIDTH*8 - 1 : 0]  ShiftedData     ; // Out of Barrel Shifted comb 

   wire [BRAM_COL_WIDTH   - 1 : 0] AlignedSrcAddr   ;
   wire [BRAM_COL_WIDTH   - 1 : 0] AlignedDstAddr   ;
  
   wire [SHIFT_WIDTH      - 1 : 0] shift            ; // shift of Barrel Shifter
  
   wire                            SrcEmpty         ; // SrcAddr FIFO
   reg                             DeqSrcAddr       ;
   wire                            SrcAddrLast      ;
   wire [BRAM_COL_WIDTH   - 1 : 0] SrcAddr          ;
   reg                             DeqDstAddr       ; // DstAddr FIFO
   wire                            DstAddrLast      ;
   wire [BRAM_COL_WIDTH   - 1 : 0] DstAddr          ;
   wire                            DstEmpty         ; 
   wire [CHI_DATA_WIDTH*8 - 1 : 0] DataFIFO         ; // Data FIFO
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
       .Enqueue    ( EnqueueSrc ) , 
       .Dequeue    ( DeqSrcAddr ) , 
       .Outp       ( SrcAddr    ) , 
       .FULL       ( BSFULLSrc  ) , 
       .Empty      ( SrcEmpty   ) 
       );
       
           // LastSrcTrans FIFO
   FIFO #(  
       1              ,  //FIFO_WIDTH       
       FIFO_LENGTH       //FIFO_LENGTH  
       )     
       FIFOLastSrc  (              
       .RST         ( RST          ),     
       .Clk         ( Clk          ),     
       .Inp         ( LastSrcTrans ),
       .Enqueue     ( EnqueueSrc   ),
       .Dequeue     ( DeqSrcAddr   ),
       .Outp        ( SrcAddrLast  ),
       .FULL        ( BSFULLDst    ),
       .Empty       (              )
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
       .Enqueue     ( EnqueueDst  ), 
       .Dequeue     ( DeqDstAddr  ),
       .Outp        ( DstAddr     ),
       .FULL        (             ),
       .Empty       ( DstEmpty    )      
       );
           // LastDstTrans FIFO
   FIFO #(  
       1           ,  //FIFO_WIDTH       
       FIFO_LENGTH    //FIFO_LENGTH   
       )     
       FIFOLastDst     (             
       .RST            ( RST         ),     
       .Clk            ( Clk         ),     
       .Inp            ( LastDstTrans),
       .Enqueue        ( EnqueueDst  ),
       .Dequeue        ( DeqDstAddr  ),
       .Outp           ( DstAddrLast ),
       .FULL           (             ),
       .Empty          (             )
       );                           
          // Data FIFO
   FIFO #(  
       CHI_DATA_WIDTH*8 ,  //FIFO_WIDTH       
       FIFO_LENGTH         //FIFO_LENGTH   
       )     
       FIFOData        (             
       .RST            ( RST         ),     
       .Clk            ( Clk         ),     
       .Inp            ( RXFLITDAT   ),
       .Enqueue        ( RXFLITDATV  ),
       .Dequeue        ( DeqSrcAddr  ),
       .Outp           ( DataFIFO    ),
       .FULL           (             ),
       .Empty          ( DataEmpty   )
       );                           
    
    assign EmptyFIFO = SrcEmpty | DstEmpty | DataEmpty ;
    
    assign AlignedSrcAddr = {SrcAddr[BRAM_COL_WIDTH - 1 : SHIFT_WIDTH],{SHIFT_WIDTH{1'b0}}};
    assign AlignedDstAddr = {DstAddr[BRAM_COL_WIDTH - 1 : SHIFT_WIDTH],{SHIFT_WIDTH{1'b0}}};
    assign shift          = ((SrcAddr- AlignedSrcAddr) - (DstAddr - AlignedDstAddr))<<3    ;//*8
    
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
           if(!EmptyFIFO & !LastDstTrans & !LastSrcTrans & DequeueBS & (DstAddr - AlignedDstAddr) > (SrcAddr - AlignedSrcAddr))      // When DstAddr is bigger than SrcAddr compare to their aligned Addresses then Data must be shifted left  
             next_state = LeftShiftState ;
           else if(!EmptyFIFO & !LastSrcTrans & (DstAddr - AlignedDstAddr) < (SrcAddr - AlignedSrcAddr))                             // When DstAddr is smaller than SrcAddr compare to their aligned Addresses then Data must be shifted right  
             next_state = RightShiftState ;
           else if(!EmptyFIFO & !LastDstTrans & LastSrcTrans & DequeueBS & (DstAddr - AlignedDstAddr) > (SrcAddr - AlignedSrcAddr))  // When it is the last Read Trans but not the last Write then should be an extra write  
             next_state = ExtraWriteState ;
           else
             next_state = StartState ; 
         end
       LeftShiftState :
         begin
           if(LastSrcTrans & LastDstTrans & !EmptyFIFO & DequeueBS)         //  When last Read becomes the last Write return to StartState
             next_state = StartState ;
           else if (LastSrcTrans & !LastDstTrans & !EmptyFIFO & DequeueBS)  //  When last Read completes a non-last Write then it should complete the last Write as well so an extra write should be done 
             next_state = ExtraWriteState ;
           else
             next_state = LeftShiftState ;            
         end
       RightShiftState : 
         begin
           if(LastSrcTrans & LastDstTrans & !EmptyFIFO & DequeueBS)       //  When last Read becomes the last Write return to StartState                
             next_state = StartState ; 
           else if (LastSrcTrans & !LastDstTrans & !EmptyFIFO & DequeueBS) //  When last Read completes a non-last Write then it should complete the last Write as well so an extra write should be done                                        
             next_state = ExtraWriteState ;
           else
             next_state = RightShiftState ;                                                                                                                    
         end 
       ExtraWriteState : 
         if(LastSrcTrans & LastDstTrans & !EmptyFIFO & DequeueBS)  //  When last Read and last Write return to StartState
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
             DeqDstAddr     = 0 ;
             DeqSrcAddr     = 0 ;
             DataOut        = 0 ;
             PrvShftdDataWE = 0 ;
           end
           else begin
             if((DstAddr - AlignedDstAddr) < (SrcAddr - AlignedSrcAddr) & !LastSrcTrans)begin
               EmptyBS        = 1           ; // Barrel Shifter is empty because there are not enough data for a Write
               DeqDstAddr     = 0           ; // Dont Dequeue DstFIFO 
               DeqSrcAddr     = 1           ; // Dequeue SrcFIFO 
               PrvShftdDataWE = 1           ; // Write shifted Data in register
               DataOut        = 0           ; // Output Data 
             end
             else if(LastSrcTrans & !LastDstTrans & (DstAddr - AlignedDstAddr) > (SrcAddr - AlignedSrcAddr))begin
               EmptyBS        = 0           ;
               DeqDstAddr     = DequeueBS   ;
               DeqSrcAddr     = 0           ;
               PrvShftdDataWE = DequeueBS   ;
               DataOut        = ShiftedData ;
             end
             else if(!LastSrcTrans & !LastDstTrans & (DstAddr - AlignedDstAddr) > (SrcAddr - AlignedSrcAddr))begin
               EmptyBS        = 0           ;
               DeqDstAddr     = DequeueBS   ;
               DeqSrcAddr     = DequeueBS   ;
               PrvShftdDataWE = DequeueBS   ;
               DataOut        = ShiftedData ;
             end
             else if((LastSrcTrans & LastDstTrans) | (DstAddr - AlignedDstAddr) == (SrcAddr - AlignedSrcAddr))begin
               EmptyBS        = 0           ;
               DeqDstAddr     = DequeueBS   ;
               DeqSrcAddr     = DequeueBS   ;
               PrvShftdDataWE = 0           ;
               DataOut        = ShiftedData ;
             end
             else begin // it should never go to else 
               EmptyBS        = 1 ;
               DeqDstAddr     = 0 ;
               DeqSrcAddr     = 0 ;
               PrvShftdDataWE = 0 ;
               DataOut        = 0 ;
             end
           end
         end
       LeftShiftState : 
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
       RightShiftState : 
         begin                   // Request control of FIFO to re-write the dequeued address pointer back in the queue
           WEControl  = 0 ;
           Dequeue    = 0 ;
           ValidFIFO  = 1 ;
           RegWESig   = 0 ;
           IssueValid = 0 ;
           ValidBRAM  = 1 ;
         end
       ExtraWriteState : 
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
    
endmodule
