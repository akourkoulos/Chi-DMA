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
  parameter BRAM_NUM_COL      = 8                           ,
  parameter BRAM_COL_WIDTH    = 32                          ,
  parameter BRAM_ADDR_WIDTH   = 10                          ,
  parameter DATA_WIDTH        = BRAM_NUM_COL*BRAM_COL_WIDTH ,
  parameter CHI_Word_Width    = 64                          ,
  parameter Chunk             = 5                           ,
  parameter MEMAddrWidth      = 32                          
)(
    input                             Clk                  ,//--- proc inp ---
    input                             RST                  ,
    input                             enaA                 ,
    input  [BRAM_NUM_COL    - 1 : 0]  weA                  ,
    input  [BRAM_ADDR_WIDTH - 1 : 0]  addrA                ,
    input  Data_packet                dinA                 ,
    input                             ValidArbIn           , //----------------
    input                             InpReadyBRAM         , // From Arbiter BRAM
    input                             InpCmdFIFOFULL       , // From CHI-convert   
    output                            ReadyArbProc         , 
    output Data_packet                BRAMdoutA            ,                   
    output                            OutIssueValid        ,                   
    output CHI_Command                Command              ,
    output                            OutValidBRAM           
    );
    
    wire        [BRAM_NUM_COL    - 1 : 0] BRAMweB          ;
    wire        [BRAM_ADDR_WIDTH - 1 : 0] BRAMaddrB        ;
    Data_packet                           BRAMdinB         ;
    Data_packet                           BRAMdoutB        ;
    // FIFO_Arbiter signals
    wire                                  ValidArbSched    ;
    wire                                  ReadyArbSched    ;
    wire        [BRAM_ADDR_WIDTH - 1 : 0] WriteBackPointer ;
    wire        [BRAM_ADDR_WIDTH - 1 : 0] ArbPointer       ;
    // FIFO signa
    wire                                  FIFOEmpty        ;
    wire        [BRAM_ADDR_WIDTH - 1 : 0] PointerFIFO      ;
    wire                                  DequeueFIFO      ;
    
    //BRAM
    bytewrite_tdp_ram_rf#(
      BRAM_NUM_COL     ,  
      BRAM_COL_WIDTH   ,  
      BRAM_ADDR_WIDTH  , 
      DATA_WIDTH          
    )myBRAM(
      .clkA (Clk       ) ,
      .enaA (enaA      ) ,
      .weA  (weA       ) ,
      .addrA(addrA     ) ,
      .dinA (dinA      ) ,
      .clkB (Clk       ) ,
      .enaB (1         ) ,
      .weB  (BRAMweB   ) ,
      .addrB(BRAMaddrB ) ,
      .dinB (BRAMdinB  ) ,
      .doutA(BRAMdoutA ) ,
      .doutB(BRAMdoutB ) 
     );

    //Arbiter
    Arbiter#( 
       BRAM_ADDR_WIDTH  
    )ArbiterFIFO( 
      .Valid           ({ValidArbSched , ValidArbIn} ) ,
      .DescAddrInProc  (addrA                        ) ,
      .DescAddrInSched (WriteBackPointer             ) ,
      .Ready           ({ReadyArbSched,ReadyArbProc} ) ,
      .DescAddrOut     (ArbPointer                   ) 
    );
    
    //FIFO
    FIFO#(
      BRAM_ADDR_WIDTH   , //FIFO_WIDTH
      2**BRAM_ADDR_WIDTH  //FIFO_LENGTH
    )AddrPointerFIFO(
      .RST     (RST                                                          ) ,
      .Clk     (Clk                                                          ) ,
      .Inp     (ArbPointer                                                   ) ,
      .Enqueue (ValidArbSched & ReadyArbSched | (ValidArbIn & ReadyArbProc)  ) ,
      .Dequeue (DequeueFIFO                                                  ) ,
      .Outp    (PointerFIFO                                                  ) ,
      .FULL    (                                                             ) ,
      .Empty   (FIFOEmpty                                                    ) 
    );
    
    //Scheduler    
    Scheduler#(
      BRAM_ADDR_WIDTH ,
      BRAM_NUM_COL    ,
      BRAM_COL_WIDTH  ,
      CHI_Word_Width  ,
      Chunk           ,
      MEMAddrWidth    
    ) mySched (
       .RST               ( RST                  ) ,
       .Clk               ( Clk                  ) ,
       .DescDataIn        ( BRAMdoutB            ) ,
       .ReadyBRAM         ( InpReadyBRAM         ) ,
       .ReadyFIFO         ( ReadyArbSched        ) ,
       .FIFO_Addr         ( PointerFIFO          ) ,
       .Empty             ( FIFOEmpty            ) ,
       .CmdFIFOFULL       ( InpCmdFIFOFULL       ) ,
       .DescDataOut       ( BRAMdinB             ) ,
       .WE                ( BRAMweB              ) ,
       .BRAMAddrOut       ( BRAMaddrB            ) ,
       .ValidBRAM         ( OutValidBRAM         ) ,
       .Dequeue           ( DequeueFIFO          ) ,
       .ValidFIFO         ( ValidArbSched        ) ,
       .DescAddrPointer   ( WriteBackPointer     ) ,
       .IssueValid        ( OutIssueValid        ) ,
       .Command           ( Command              ) 
    );
endmodule

