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


module BarrelShifter#(
  parameter CHI_DATA_WIDTH   = 64                    , //Bytes
  parameter BRAM_COL_WIDTH   = 32                    ,
  parameter FIFO_LENGTH      = 32                    
) ( 
    input                            RST          ,
    input                            Clk          ,
    input   [BRAM_COL_WIDTH  - 1 :0] SrcAddrIn    ,
    input   [BRAM_COL_WIDTH  - 1 :0] DstAddrIn    ,
    input                            LastSrcTrans ,
    input                            LastDstTrans ,
    input                            EnqueueBS    ,
    input                            RXDATFLITV   ,
    input   DataFlit                 RXDATFLIT    ,
    input                            RXDATLCRD    ,
    output [CHI_DATA_WIDTH*8 - 1 :0] DataOut      ,
    output                           ValidData
    );
    
    wire                          DeqSrcAddr  ;
    wire                          FIFOEmpty   ;
    wire                          FIFOFULL    ;
    wire                          SrcAddrLast ;
    wire [BRAM_COL_WIDTH  - 1 :0] SrcAddr     ;
    
            // SrcAddr FIFO
   FIFO #(  
       BRAM_COL_WIDTH      ,  //FIFO_WIDTH       
       FIFO_LENGTH            //FIFO_LENGTH   
       )     
       FIFOSrcAddr (     
       .RST        ( RST        ) ,      
       .Clk        ( Clk        ) ,      
       .Inp        ( SrcAddrIn  ) , 
       .Enqueue    ( EnqueueBS  ) , 
       .Dequeue    ( DeqSrcAddr ) , 
       .Outp       ( SrcAddr    ) , 
       .FULL       ( FIFOEmpty  ) , 
       .Empty      ( FIFOFULL   ) 
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
       .Enqueue     ( EnqueueBS    ),
       .Dequeue     ( DeqSrcAddr   ),
       .Outp        ( SrcAddrLast  ),
       .FULL        (              ),
       .Empty       (              )
       )
          // DstAddr FIFO
   FIFO #(  
      BRAM_COL_WIDTH  ,  //FIFO_WIDTH       
      FIFO_LENGTH        //FIFO_LENGTH   
       )     
       FIFODstAddr  (     
       .RST            ( RST                ,      
       .Clk            ( Clk                ,      
       .Inp            ( DstAddrIn ) ,
       .Enqueue        ( EnqueueBSID         , 
       .Dequeue        ( DeqDstAddr         , 
       .Outp           ( DstAddr  
       .FULL           (                    , 
       .Empty          (                    
       );
           // LastDstTrans FIFO
   FIFO #(  
      `RspErrWidth      ,  //FIFO_WIDTH       
       DATA_FIFO_LENGTH    //FIFO_LENGTH   
       )     
       FIFODBIDRspErr  (     
       .RST            ( RST                ) ,      
       .Clk            ( Clk                ) ,      
       .Inp            ( RXRSPFLIT.RespErr  ) , 
       .Enqueue        ( SigEnqDBID         ) , 
       .Dequeue        ( SigDeqData         ) , 
       .Outp           ( SigFIFODBIDRspErr  ) , 
       .FULL           (                    ) , 
       .Empty          (                    ) 
       );
       
    // ---------------------Barrel Shifter comb---------------------
    wire  [DataWidth - 1 : 0] muxout [ShiftWidth - 1 : 0]; 
    assign muxout[0] = shift[0] ? ({inp[0],inp[DataWidth  - 1 :1]}): inp ;
    genvar i ;
    generate 
    for(i = 1 ; i < ShiftWidth ; i++)
      assign muxout[i] = shift[i] ? ({muxout[i-1][2**i - 1 : 0],muxout[i-1][DataWidth  - 1 : 2**i]}): muxout[i-1] ;
    endgenerate
    // ---------------------end Barrel Shifter comb---------------------
    assign outp = muxout[ShiftWidth - 1];
    
endmodule
