`timescale 1ns / 1ps
import DataPkg::*;
import CHIFlitsPkg::*; 

//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07.10.2022 16:52:48
// Design Name: 
// Module Name: TestCHIConverter
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

// Req opcode
`define ReadOnce          6'h03 
`define WriteUniquePtl    6'h18
//Data opcoed
`define CompData          4'h4
//Rsp opcode
`define CompDBIDResp      4'h5

module TestCHIConverter#(
//--------------------------------------------------------------------------
  parameter BRAM_ADDR_WIDTH  = 10  ,
  parameter BRAM_NUM_COL     = 8   , // As the Data_packet fields
  parameter BRAM_COL_WIDTH   = 32  ,
  parameter MEM_ADDR_WIDTH   = 32  //<------ should be the same with BRAM_COL_WIDTH
//----------------------------------------------------------------------
);

reg                                   Clk               ;
reg                                   RST               ;
Data_packet                           DataBRAM          ; // From BRAM
reg                                   ReadyBRAM         ; // From Arbiter_BRAM
reg         [MEM_ADDR_WIDTH  - 1 : 0] SrcAddr           ;
reg         [MEM_ADDR_WIDTH  - 1 : 0] DstAddr           ;
reg         [MEM_ADDR_WIDTH  - 1 : 0] Length            ;
reg                                   IssueValid        ; 
reg         [BRAM_ADDR_WIDTH - 1 : 0] DescAddr          ; // Address of a finished Descriptor in BRAM
reg                                   FinishedDescValid ;
reg                                   TXREQFLITPEND     ; // Request outbound Chanel
reg                                   TXREQFLITV        ;
ReqFlit                               TXREQFLIT         ;
reg                                   TXREQLCRDV        ;
wire                                  TXRSPFLITPEND     ; // Response outbound Chanel
wire                                  TXRSPFLITV        ;
RspFlit                               TXRSPFLIT         ;
reg                                   TXRSPLCRDV        ;
wire                                  TXDATFLITPEND     ; // Data outbound Chanel
wire                                  TXDATFLITV        ;
DataFlit                              TXDATFLIT         ;
reg                                   TXDATLCRDV        ;
reg                                   RXRSPFLITPEND     ; // Response inbound Chanel
reg                                   RXRSPFLITV        ;
RspFlit                               RXRSPFLIT         ;
wire                                  RXRSPLCRDV        ;
reg                                   RXDATFLITPEND     ; // Data inbound Chanel
reg                                   RXDATFLITV        ;
DataFlit                              RXDATFLIT         ;
wire                                  RXDATLCRDV        ;
reg                                   CmdFIFOFULL       ; // For Scheduler
reg                                   ValidBRAM         ; // For Arbiter_BRAM
reg         [BRAM_ADDR_WIDTH - 1 : 0] AddrBRAM          ; // For BRAM
Data_packet                           DescStatus        ;
reg         [BRAM_NUM_COL    - 1 : 0] WEBRAM            ;
  
    // duration for each bit = 20 * timescdoutBale = 20 * 1 ns  = 20ns
    localparam period = 20;  

    CHIConverter UUT    (
     .Clk               (Clk               ) ,
     .RST               (RST               ) ,
     .DataBRAM          (DataBRAM          ) ,
     .ReadyBRAM         (ReadyBRAM         ) ,
     .SrcAddr           (SrcAddr           ) ,
     .DstAddr           (DstAddr           ) ,
     .Length            (Length            ) ,
     .IssueValid        (IssueValid        ) ,
     .DescAddr          (DescAddr          ) ,
     .FinishedDescValid (FinishedDescValid ) ,
     .TXREQFLITPEND     (TXREQFLITPEND     ) ,
     .TXREQFLITV        (TXREQFLITV        ) ,
     .TXREQFLIT         (TXREQFLIT         ) ,  
     .TXREQLCRDV        (TXREQLCRDV        ) ,
     .TXRSPFLITPEND     (TXRSPFLITPEND     ) ,
     .TXRSPFLITV        (TXRSPFLITV        ) ,
     .TXRSPFLIT         (TXRSPFLIT         ) ,
     .TXRSPLCRDV        (TXRSPLCRDV        ) ,
     .TXDATFLITPEND     (TXDATFLITPEND     ) ,
     .TXDATFLITV        (TXDATFLITV        ) ,
     .TXDATFLIT         (TXDATFLIT         ) ,
     .TXDATLCRDV        (TXDATLCRDV        ) ,
     .RXRSPFLITPEND     (RXRSPFLITPEND     ) ,
     .RXRSPFLITV        (RXRSPFLITV        ) ,
     .RXRSPFLIT         (RXRSPFLIT         ) ,
     .RXRSPLCRDV        (RXRSPLCRDV        ) ,
     .RXDATFLITPEND     (RXDATFLITPEND     ) ,
     .RXDATFLITV        (RXDATFLITV        ) ,
     .RXDATFLIT         (RXDATFLIT         ) ,
     .RXDATLCRDV        (RXDATLCRDV        ) ,
     .CmdFIFOFULL       (CmdFIFOFULL       ) ,
     .ValidBRAM         (ValidBRAM         ) ,
     .AddrBRAM          (AddrBRAM          ) ,
     .DescStatus        (DescStatus        ) ,
     .WEBRAM            (WEBRAM            )    
    );
    
    reg SigDeqReq;
    reg SigReqEmpty ;
    
     int i=0;
    ReqFlit SigTXREQFLIT  ;
    
    // Read Data FIFO
   FIFO #(     
       117 ,  //FIFO_WIDTH       
       117    //FIFO_LENGTH      
       )     
       myFIFOReq  (     
       .RST      ( RST             ) ,      
       .Clk      ( Clk             ) ,      
       .Inp      ( TXREQFLIT       ) , 
       .Enqueue  ( TXREQFLITV      ) , 
       .Dequeue  ( SigDeqReq       ) , 
       .Outp     ( SigTXREQFLIT    ) , 
       .FULL     (                 ) , 
       .Empty    ( SigReqEmpty     ) 
       );
       
    
    always
    begin
        Clk = 1'b1; 
        #20; // high for 20 * timescale = 20 ns
    
        Clk = 1'b0;
        #20; // low for 20 * timescale = 20 ns
    end
    
    always_comb begin
         ReadyBRAM  = ValidBRAM ;
    end
    
    always@(posedge Clk) begin     
      RXRSPFLITPEND     = 0      ;
      RXRSPFLITV        = 0      ;
      RXRSPFLIT         = 'd0    ;      
      RXDATFLITPEND     = 0      ;
      RXDATFLITV        = 0      ;
      RXDATFLIT         = 'd0    ;
      SigDeqReq         = 0      ;
      if(!SigReqEmpty & SigTXREQFLIT.Opcode == `ReadOnce )begin
       #(period*5)
        RXDATFLITV = 1;
        RXDATFLIT = '{default                : 0                                        ,                       
                                  QoS        : 0                                        ,
                                  TgtID      : 1                                        ,
                                  SrcID      : 2                                        ,
                                  TxnID      : SigTXREQFLIT.TxnID                       ,
                                  HomeNID    : 0                                        ,
                                  Opcode     : `CompData                                ,
                                  RespErr    : 0                                        ,
                                  Resp       : 0                                        , // Resp should be 0 when NonCopyBackWrData Rsp
                                  DataSource : 'b0                                      , 
                                  DBID       : 'b0                                      ,
                                  CCID       : 'b0                                      , 
                                  DataID     : 'b0                                      ,
                                  TraceTag   : 0                                        ,
                                  BE         : {64{1'b1}}                               ,
                                  Data       : 'd848392                                 , // EWA : 1 , Device : 0 , Cachable : 1 , Allocate : 0 
                                  DataCheck  : 64'b0                                    ,
                                  Poison     : 'b0                                        
                                  };     
        SigDeqReq = 1;
      end
      else if(!SigReqEmpty & SigTXREQFLIT.Opcode == `WriteUniquePtl  )begin
       #(period*5)
        RXRSPFLITV = 1;
        RXRSPFLIT = '{default              : 0                                        ,                       
                                  QoS      : 0                                        ,
                                  TgtID    : 1                                        ,
                                  SrcID    : 2                                        ,
                                  TxnID    : SigTXREQFLIT.TxnID                       ,
                                  Opcode   : `CompDBIDResp                            ,
                                  RespErr  : 0                                        ,
                                  Resp     : 0                                        ,
                                  FwdState : 0                                        , // Resp should be 0 when NonCopyBackWrData Rsp
                                  DBID     : i                                        , 
                                  PCrdType : 'b0                                      ,
                                  TraceTag : 'b0                                       
                                  };     
      i++;
      SigDeqReq = 1;
      end
      else begin
        RXDATFLITV = 0 ;
        RXDATFLIT  = 0 ;
        RXRSPFLITV = 0 ;
        RXRSPFLIT  = 0 ;
      end
     #(period*2) ;
    end

    
    always @(posedge Clk)
        begin
          // Reset;
         RST               = 1      ;
         DataBRAM          = 'd0    ;
         SrcAddr           = 'd10   ;
         DstAddr           = 'd1000 ;
         Length            = 'd320  ;
         IssueValid        = 1      ;
         DescAddr          = 'd1    ;
         FinishedDescValid = 0      ;
         TXREQLCRDV        = 1      ;
         TXRSPLCRDV        = 1      ;
         TXDATLCRDV        = 1      ;/*
         RXRSPFLITPEND     = 0      ;
         RXRSPFLITV        = 'd0    ;
         RXRSPFLIT         = 0      ;*//*
         RXDATFLITPEND     = 0      ;
         RXDATFLITV        = 0      ;
         RXDATFLIT         = 'd0    ;*/
         
         #(period); // signals change at the negedge of Clk  
         #(period*2); // wait for period   
          
          // Issue a transactiom . Take Crds
         RST               = 0      ;
         DataBRAM          = 'd0    ;
         SrcAddr           = 'd10   ;
         DstAddr           = 'd1000 ;
         Length            = 'd320  ;
         IssueValid        = 1      ;
         DescAddr          = 'd1    ;
         FinishedDescValid = 0      ;
         TXREQLCRDV        = 1      ;
         TXRSPLCRDV        = 1      ;
         TXDATLCRDV        = 1      ;
         #(period*2); // wait for period   
         // Issue one more transactiom .Take Crds
         RST               = 0      ;
         DataBRAM.Status   = 'd1    ;
         SrcAddr           = 'd20   ;
         DstAddr           = 'd2000 ;
         Length            = 'd100  ;
         IssueValid        = 1      ;
         DescAddr          = 'd2    ;
         FinishedDescValid = 1      ;
         TXREQLCRDV        = 1      ;
         TXRSPLCRDV        = 1      ;
         TXDATLCRDV        = 1      ;
         #(period*2); // wait for period   
         // Issue one more transactiom .Take Crds
         RST               = 0      ;
         DataBRAM.Status   = 'd1    ;
         SrcAddr           = 'd20   ;
         DstAddr           = 'd2000 ;
         Length            = 'd100  ;
         IssueValid        = 0      ;
         DescAddr          = 'd2    ;
         FinishedDescValid = 1      ;
         TXREQLCRDV        = 1      ;
         TXRSPLCRDV        = 1      ;
         TXDATLCRDV        = 1      ;
         #(period*60); // wait for period   
        $stop;
        end
endmodule