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
  parameter CHI_Word_Width    = 64                          ,
  parameter Chunk             = 5                           
//--------------------------------------------------------------------------
)(
    input                                                  Clk                  ,//--- proc inp ---
    input                                                  RST                  ,
    input                       [BRAM_NUM_COL    - 1 : 0]  weA                  ,
    input                       [BRAM_ADDR_WIDTH - 1 : 0]  addrA                ,
    input          Data_packet                             dinA                 , //----------------
    output         Data_packet                             BRAMdoutA            , // From BRAM to Proc  
    ReqChannel    .OUTBOUND                                ReqChan              , //-----CHI Channels----
    RspOutbChannel.OUTBOUND                                RspOutbChan          ,
    DatOutbChannel.OUTBOUND                                DatOutbChan          ,
    RspInbChannel .INBOUND                                 RspInbChan           , 
    DatInbChannel .INBOUND                                 DatInbChan             //---------------------
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
    CHI_Command                           Command           ;
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
    
    //BRAM
    bytewrite_tdp_ram_rf#(
      .BRAM_NUM_COL    (BRAM_NUM_COL    ),  
      .BRAM_COL_WIDTH  (BRAM_COL_WIDTH  ),  
      .BRAM_ADDR_WIDTH (BRAM_ADDR_WIDTH ), 
      .DATA_WIDTH      (DATA_WIDTH      )   
    )myBRAM(
      .clkA (Clk       ) ,
      .enaA (1'b1      ) ,
      .weA  (weA       ) ,
      .addrA(addrA     ) ,
      .dinA (dinA      ) ,
      .clkB (Clk       ) ,
      .enaB (1'b1      ) ,
      .weB  (BRAMweB   ) ,
      .addrB(BRAMaddrB ) ,
      .dinB (BRAMdinB  ) ,
      .doutA(BRAMdoutA ) ,
      .doutB(BRAMdoutB ) 
     );

    //Arbiter for FIFO
    Arbiter#( 
       .BRAM_ADDR_WIDTH (BRAM_ADDR_WIDTH )  
    )ArbiterFIFO( 
      .Valid           ({ValidArbFIFOSched , (weA != 0)} ) ,
      .DescAddrInProc  (addrA                            ) ,
      .DescAddrInSched (WriteBackPointer                 ) ,
      .Ready           ({ReadyArbFIFOSched,ReadyArbProc} ) ,
      .DescAddrOut     (ArbPointer                       ) 
    );
    
    //FIFO
    FIFO#(
      .FIFO_WIDTH  (BRAM_ADDR_WIDTH    ), //FIFO_WIDTH
      .FIFO_LENGTH (2**BRAM_ADDR_WIDTH )  //FIFO_LENGTH
    )AddrPointerFIFO(
      .RST     (RST                                                                  ) ,
      .Clk     (Clk                                                                  ) ,
      .Inp     (ArbPointer                                                           ) ,
      .Enqueue (ValidArbFIFOSched & ReadyArbFIFOSched | ((weA != 0) & ReadyArbProc)  ) ,
      .Dequeue (DequeueFIFO                                                          ) ,
      .Outp    (PointerFIFO                                                          ) ,
      .FULL    (                                                                     ) ,
      .Empty   (FIFOEmpty                                                            ) 
    );
    
    //Scheduler    
    Scheduler#(
      .BRAM_ADDR_WIDTH (BRAM_ADDR_WIDTH ) ,
      .BRAM_NUM_COL    (BRAM_NUM_COL    ) ,
      .BRAM_COL_WIDTH  (BRAM_COL_WIDTH  ) ,
      .CHI_Word_Width  (CHI_Word_Width  ) ,
      .Chunk           (Chunk           ) 
    ) mySched (
      .RST               ( RST                  ) ,
      .Clk               ( Clk                  ) ,
      .DescDataIn        ( BRAMdoutB            ) ,
      .ReadyBRAM         ( SchedReadyBRAM       ) ,
      .ReadyFIFO         ( ReadyArbFIFOSched    ) ,
      .FIFO_Addr         ( PointerFIFO          ) ,
      .Empty             ( FIFOEmpty            ) ,
      .CmdFIFOFULL       ( CmdFIFOFULL          ) ,
      .DescDataOut       ( BRAMdinSched         ) ,
      .WE                ( BRAMweSched          ) ,
      .BRAMAddrOut       ( BRAMaddrSched        ) ,
      .ValidBRAM         ( SchedValidBRAM       ) ,
      .Dequeue           ( DequeueFIFO          ) ,
      .ValidFIFO         ( ValidArbFIFOSched    ) ,
      .DescAddrPointer   ( WriteBackPointer     ) ,
      .IssueValid        ( IssueValid           ) ,
      .Command           ( Command              ) 
    );
    
    // Arbiter BRAM
    ArbiterBRAM#( 
      .BRAM_NUM_COL   ( BRAM_NUM_COL    ) ,
      .BRAM_ADDR_WIDTH( BRAM_ADDR_WIDTH ) 
    )ArbBRAM(
      .ValidA  ( CHIConValidBRAM ),
      .weA     ( BRAMweCHIC      ),
      .addrA   ( BRAMaddrCHIC    ),
      .dinA    ( BRAMdinCHIC     ),
      .ReadyA  ( ReadyCHIConv    ),
      .ValidB  ( SchedValidBRAM  ),
      .weB     ( BRAMweSched     ),
      .addrB   ( BRAMaddrSched   ),
      .dinB    ( BRAMdinSched    ),
      .ReadyB  ( SchedReadyBRAM  ),
      .weOut   ( BRAMweB         ),
      .addrOut ( BRAMaddrB       ),
      .dOut    ( BRAMdinB        )
    ); 
    
    //CHI-Converter
    CHIConverter CHI_Conv    (
     .Clk                    ( Clk                   ) ,
     .RST                    ( RST                   ) ,
     .DataBRAM               ( BRAMdoutB             ) ,
     .ReadyBRAM              ( ReadyCHIConv          ) ,
     .Command                ( Command               ) ,
     .IssueValid             ( IssueValid            ) ,
     .ReqChan                ( ReqChan               ) ,
     .RspOutbChan            ( RspOutbChan           ) ,
     .DatOutbChan            ( DatOutbChan           ) ,
     .RspInbChan             ( RspInbChan            ) ,
     .DatInbChan             ( DatInbChan            ) ,
     .CmdFIFOFULL            ( CmdFIFOFULL           ) ,
     .ValidBRAM              ( CHIConValidBRAM       ) ,
     .AddrBRAM               ( BRAMaddrCHIC          ) ,
     .DescStatus             ( BRAMdinCHIC           ) ,
     .WEBRAM                 ( BRAMweCHIC            )    
    );
    
endmodule

