`timescale 1ns / 1ps
import DataPkg::*;
import CHIFIFOsPkg ::*;
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 16.11.2022 18:49:09
// Design Name: 
// Module Name: CHI_DMA
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


module CHI_DMA#(
//--------------------------------------------------------------------------
  parameter BRAM_NUM_COL      = 8                           ,
  parameter BRAM_COL_WIDTH    = 32                          ,
  parameter BRAM_ADDR_WIDTH   = 10                          ,
  parameter DATA_WIDTH        = BRAM_NUM_COL*BRAM_COL_WIDTH ,
  parameter CHI_DATA_WIDTH    = 64                          ,
  parameter Chunk             = 5                           
//--------------------------------------------------------------------------
)(
    input                                                            Clk                  ,//--- proc inp ---
    input                                                            RST                  ,
    input                                 [BRAM_NUM_COL    - 1 : 0]  weA                  ,
    input                                 [BRAM_ADDR_WIDTH - 1 : 0]  addrA                ,
    input                    Data_packet                             dinA                 , //----------------
    output                   Data_packet                             BRAMdoutA            , // From BRAM to Proc  
    ReqChannel     .OUTBOUND                                         ReqChan              , //-----CHI Channels----
    RspOutbChannel .OUTBOUND                                         RspOutbChan          ,
    DatOutbChannel .OUTBOUND                                         DatOutbChan          ,
    RspInbChannel  .INBOUND                                          RspInbChan           , 
    DatInbChannel  .INBOUND                                          DatInbChan             //---------------------
    );
    
    //BRAM signals
    Data_packet                           BRAMdoutB         ;
    wire        [BRAM_NUM_COL    - 1 : 0] BRAMweB           ;
    wire        [BRAM_ADDR_WIDTH - 1 : 0] BRAMaddrB         ;
    Data_packet                           BRAMdinB          ;     
    // FIFO signa
    wire                                  FIFOEmpty         ;
    wire        [BRAM_ADDR_WIDTH - 1 : 0] PointerFIFO       ;
    wire                                  DequeueFIFO       ;
    wire        [BRAM_ADDR_WIDTH - 1 : 0] ArbPointer        ;
    //Scheduler signals
    CHI_Command                           CommandSched      ;
    wire                                  IssueValid        ;
    wire                                  SchedValidBRAM    ;
    wire                                  SchedReadyBRAM    ;
    wire        [BRAM_NUM_COL    - 1 : 0] BRAMweSched       ;
    wire        [BRAM_ADDR_WIDTH - 1 : 0] BRAMaddrSched     ;
    Data_packet                           BRAMdinSched      ;
    wire                                  ValidArbFIFOSched ;
    wire                                  ReadyArbFIFOSched ;
    wire        [BRAM_ADDR_WIDTH - 1 : 0] WriteBackPointer  ;
    // CHI_Conv signals
    wire                                  CmdFIFOFULL       ;
    wire                                  CHIConValidBRAM   ;
    wire                                  ReadyCHIConv      ;
    wire        [BRAM_NUM_COL    - 1 : 0] BRAMweCHIC        ;
    wire        [BRAM_ADDR_WIDTH - 1 : 0] BRAMaddrCHIC      ;
    Data_packet                           BRAMdinCHIC       ;
    // BS signals                                                                                                                                        
    CHI_Command                            CommandBS     ;
    wire                                   EnqueueIn     ;
    wire                                   DequeueBS     ;
    wire        [CHI_DATA_WIDTH   - 1 : 0] BEOut         ;
    wire        [CHI_DATA_WIDTH*8 - 1 : 0] DataOutBS     ;
    wire                                   EmptyBS       ;
    wire                                   FULLCmndBS    ;
    wire        [`RspErrWidth     - 1 : 0] DataError     ;
    wire                                   LastDescTrans ;
    wire        [BRAM_ADDR_WIDTH  - 1 : 0] DescAddrBS    ;
    
    //BRAM
    bytewrite_tdp_ram_rf#(
      .BRAM_NUM_COL    (BRAM_NUM_COL    ),  
      .BRAM_COL_WIDTH  (BRAM_COL_WIDTH  ),  
      .BRAM_ADDR_WIDTH (BRAM_ADDR_WIDTH ), 
      .DATA_WIDTH      (DATA_WIDTH      )   
    )myBRAM(
      .clkA (Clk       ) , // --- from cpu ---
      .enaA (1'b1      ) , 
      .weA  (weA       ) , 
      .addrA(addrA     ) ,
      .dinA (dinA      ) , // --- end cpu ---
      .clkB (Clk       ) , // --- from Arbiter BRAM ---
      .enaB (1'b1      ) ,
      .weB  (BRAMweB   ) ,
      .addrB(BRAMaddrB ) ,
      .dinB (BRAMdinB  ) , // --- end Arbiter BRAM ---
      .doutA(BRAMdoutA ) , // for cpu
      .doutB(BRAMdoutB )   // for scheduler and CHI-Converters
     );

    //Arbiter for FIFO
    Arbiter#( 
       .BRAM_ADDR_WIDTH (BRAM_ADDR_WIDTH )  
    )ArbiterFIFO( 
      .Valid           ({ValidArbFIFOSched , (weA != 0)} ) , // from scheduler and cpu   
      .DescAddrInProc  (addrA                            ) , // from cpu
      .DescAddrInSched (WriteBackPointer                 ) , // from scheduler
      .Ready           ({ReadyArbFIFOSched,ReadyArbProc} ) , // for scheduler
      .DescAddrOut     (ArbPointer                       )   // for FIFO
    );   
    
    //FIFO
    FIFO#(
      .FIFO_WIDTH  (BRAM_ADDR_WIDTH    ), //FIFO_WIDTH
      .FIFO_LENGTH (2**BRAM_ADDR_WIDTH )  //FIFO_LENGTH
    )AddrPointerFIFO(
      .RST     (RST                                                                 ) ,
      .Clk     (Clk                                                                 ) ,
      .Inp     (ArbPointer                                                          ) ,
      .Enqueue (ValidArbFIFOSched & ReadyArbFIFOSched | ((weA != 0) & ReadyArbProc) ) , // from Arbiter FIFO 
      .Dequeue (DequeueFIFO                                                         ) , // from scheduler
      .Outp    (PointerFIFO                                                         ) , // --- for scheduler ---
      .FULL    (                                                                    ) ,    
      .Empty   (FIFOEmpty                                                           )   // --- end scheduler ---
    );
    
    //Scheduler    
    Scheduler#(
      .BRAM_ADDR_WIDTH (BRAM_ADDR_WIDTH ) ,
      .BRAM_NUM_COL    (BRAM_NUM_COL    ) ,
      .BRAM_COL_WIDTH  (BRAM_COL_WIDTH  ) ,
      .CHI_DATA_WIDTH  (CHI_DATA_WIDTH  ) ,
      .Chunk           (Chunk           ) 
    ) mySched (
      .RST               ( RST                  ) ,
      .Clk               ( Clk                  ) ,
      .DescDataIn        ( BRAMdoutB            ) , // from BRAM 
      .ReadyBRAM         ( SchedReadyBRAM       ) , // from Arbiter BRAM
      .ReadyFIFO         ( ReadyArbFIFOSched    ) , // from Arbiter FIFO
      .FIFO_Addr         ( PointerFIFO          ) , // -- from FIFO --
      .Empty             ( FIFOEmpty            ) , // -- end FIFO -- 
      .CmdFIFOFULL       ( CmdFIFOFULL          ) , // from CHI-Conv
      .DescDataOut       ( BRAMdinSched         ) , // --- for Arbiter BRAM ---
      .WE                ( BRAMweSched          ) ,
      .BRAMAddrOut       ( BRAMaddrSched        ) ,
      .ValidBRAM         ( SchedValidBRAM       ) , // --- end Arbiter BRAM ---
      .Dequeue           ( DequeueFIFO          ) , // for FIFO
      .ValidFIFO         ( ValidArbFIFOSched    ) , // -- for Arbiter FIFO --
      .DescAddrPointer   ( WriteBackPointer     ) , // -- end Arbiter FIFO --
      .IssueValid        ( IssueValid           ) , // -- for CHI-Conv --
      .Command           ( CommandSched         )   // -- end CHI-Conv --
    );
    
    // Arbiter BRAM
    ArbiterBRAM#( 
      .BRAM_NUM_COL   ( BRAM_NUM_COL    ) ,
      .BRAM_ADDR_WIDTH( BRAM_ADDR_WIDTH ) 
    )ArbBRAM(
      .ValidA  ( CHIConValidBRAM ),// --- from CHI-COnv ---
      .weA     ( BRAMweCHIC      ),
      .addrA   ( BRAMaddrCHIC    ),
      .dinA    ( BRAMdinCHIC     ),// --- end CHI-Conv ---
      .ReadyA  ( ReadyCHIConv    ),// for CHI-Conv
      .ValidB  ( SchedValidBRAM  ),// --- from scheduler ---
      .weB     ( BRAMweSched     ),
      .addrB   ( BRAMaddrSched   ),
      .dinB    ( BRAMdinSched    ),// --- end scheduler ---
      .ReadyB  ( SchedReadyBRAM  ),// for scheduler
      .weOut   ( BRAMweB         ),// --- for BRAM ---
      .addrOut ( BRAMaddrB       ),
      .dOut    ( BRAMdinB        ) // --- end BRAM ---
    ); 
    
    //CHI-Converter
    CHIConverter CHI_Conv(
     .Clk                (Clk                         ) ,
     .RST                (RST                         ) ,
     .DataBRAM           (BRAMdoutB                   ) , // from BRAM
     .IssueValid         (IssueValid                  ) , //--- from scheduler---
     .Command            (CommandSched                ) , //--- end scheduler--- 
     .ReadyBRAM          (ReadyCHIConv                ) , // from Arbiter BRAM                                   
     .LastDescTrans      (LastDescTrans               ) , //--------from BS--------                                     
     .DescAddr           (DescAddrBS                  ) ,                                       
     .BE                 (BEOut                       ) ,                                       
     .ShiftedData        (DataOutBS                   ) ,                                       
     .DataErr            (DataError                   ) ,
     .EmptyBS            (EmptyBS                     ) ,
     .FULLCmndBS         (FULLCmndBS                  ) ,//--------from BS-------- 
     .ReqChan            (ReqChan                     ) ,//-----channels--------
     .RspOutbChan        (RspOutbChan                 ) ,
     .DatOutbChan        (DatOutbChan                 ) ,   
     .RspInbChan         (RspInbChan                  ) ,
     .RXDATFLITV         (DatInbChan      .RXDATFLITV ) ,//-----end channels--------
     .CmdFIFOFULL        (CmdFIFOFULL                 ) ,// for Scheduler
     .ValidBRAM          (CHIConValidBRAM             ) ,//---- for Arbiter BRAM----
     .AddrBRAM           (BRAMaddrCHIC                ) ,
     .DescStatus         (BRAMdinCHIC                 ) ,
     .WEBRAM             (BRAMweCHIC                  ) ,//----end Arbiter BRAM----
     .EnqueueBS          (EnqueueIn                   ) ,//-------for BS-------
     .CommandBS          (CommandBS                   ) ,
     .DequeueBS          (DequeueBS                   )  //-------end BS-------
    );
    // Barrel Shifter
    BarrelShifter BS     (
     .  RST              ( RST           ),
     .  Clk              ( Clk           ),
     .  CommandIn        ( CommandBS     ),//-- from CHI-Conv --
     .  EnqueueIn        ( EnqueueIn     ),
     .  DequeueBS        ( DequeueBS     ),//-------------------
     .  DatInbChan       ( DatInbChan    ), // Inb Data Chan
     .  BEOut            ( BEOut         ),//-- fror CHI-Conv --
     .  DataOut          ( DataOutBS     ),
     .  DataError        ( DataError     ),
     .  DescAddr         ( DescAddrBS    ),
     .  LastDescTrans    ( LastDescTrans ),
     .  EmptyBS          ( EmptyBS       ),
     .  FULLCmndBS       ( FULLCmndBS    ) //-------------------
    );      
endmodule

