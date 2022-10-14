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
  parameter MEM_ADDR_WIDTH   = 44  ,//<------ should be the same with BRAM_COL_WIDTH
  parameter CHI_DATA_WIDTH   = 64  , //Bytes
  parameter Chunk            = 5   ,
  parameter FIFO_Length      = 120
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
    
    //Crds signals
    int                           CountDataCrds = 0 ; 
    int                           CountRspCrds  = 0 ;
    reg [31 : 0]                  GivenReqCrds      ;// use in order not to give more crds than fifo length
    //FIFO signals
    reg                           SigDeqReqR         ;
    reg                           SigReqEmptyR       ;
    reg                           SigDeqReqW         ;
    reg                           SigReqEmptyW       ;
    ReqFlit                       SigTXREQFLITR  ;
    ReqFlit                       SigTXREQFLITW  ;
    int                           i=0;
    //Last Trans signals
    reg [MEM_ADDR_WIDTH  - 1 : 0] SrcAddrReg  ;
    reg                           SrcAddrRegWE;

    // Read Req FIFO
   FIFO #(     
       117         ,  //FIFO_WIDTH       
       FIFO_Length    //FIFO_LENGTH      
       )     
       myRFIFOReq  (     
       .RST      ( RST                                          ) ,      
       .Clk      ( Clk                                          ) ,      
       .Inp      ( TXREQFLIT                                    ) , 
       .Enqueue  ( TXREQFLITV & TXREQFLIT.Opcode == `ReadOnce   ) , 
       .Dequeue  ( SigDeqReqR                                   ) , 
       .Outp     ( SigTXREQFLITR                                ) , 
       .FULL     (                                              ) , 
       .Empty    ( SigReqEmptyR                                 ) 
       );
       
    // Write Req FIFO
   FIFO #(     
       117         ,  //FIFO_WIDTH       
       FIFO_Length    //FIFO_LENGTH      
       )     
       myWFIFOReq  (     
       .RST      ( RST                                              ) ,      
       .Clk      ( Clk                                              ) ,      
       .Inp      ( TXREQFLIT                                        ) , 
       .Enqueue  ( TXREQFLITV & TXREQFLIT.Opcode == `WriteUniquePtl ) , 
       .Dequeue  ( SigDeqReqW                                       ) , 
       .Outp     ( SigTXREQFLITW                                    ) , 
       .FULL     (                                                  ) , 
       .Empty    ( SigReqEmptyW                                     ) 
       );
       
    
    always
    begin
        Clk = 1'b1; 
        #20; // high for 20 * timescale = 20 ns
    
        Clk = 1'b0;
        #20; // low for 20 * timescale = 20 ns
    end
    
    //Signals for Completer
    always_comb begin
      if(ValidBRAM) begin
         ReadyBRAM = 1         ;
         DataBRAM  = $urandom();
      end
      else begin
        ReadyBRAM = 0 ;
        DataBRAM  = 0 ;
      end
    end
    
    //Manage given Crds
    always_ff@(posedge Clk) begin
      if(RXDATLCRDV & !RXDATFLITV)
        CountDataCrds++;
      else if(!RXDATLCRDV & RXDATFLITV)
        CountDataCrds--;
      if(RXRSPLCRDV & !RXRSPFLITV) 
        CountRspCrds++; 
      else if(!RXRSPLCRDV & RXRSPFLITV) 
        CountRspCrds--; 
    end
    
    // use in order not to give more crds than fifo length
    always_ff@(posedge Clk) begin
      if(RST)
        GivenReqCrds <= 0;
      else begin
        if(!TXREQLCRDV & TXREQFLITV & CountDataCrds != 0)
          GivenReqCrds-- ;
        else if(TXREQLCRDV & !(TXREQFLITV & CountDataCrds != 0))
          GivenReqCrds++ ;
      end
    end
    
    //give Crds
    always begin
      TXREQLCRDV = 0;
      #(2*period*$urandom_range(5) + period);
      if(GivenReqCrds < FIFO_Length)
        TXREQLCRDV = 1;
      #(2*period) ;
      TXREQLCRDV = 0;
      #period ;
    end
    always begin
      TXRSPLCRDV = 0;
      #(2*period*$urandom_range(5) + period);
      TXRSPLCRDV = 1;
      #(2*period) ;
      TXRSPLCRDV = 0;
      #period ;
    end
    always begin
      TXDATLCRDV = 0;
      #(2*period*$urandom_range(5) + period);
      TXDATLCRDV = 1;
      #(2*period) ;
      TXDATLCRDV = 0;
      #period ;
    end
    
    
    // Data Response
    always begin     
      if(!SigReqEmptyR & SigTXREQFLITR.Opcode == `ReadOnce & CountDataCrds != 0 )begin
        //response delay
        if(SrcAddrReg + 64 != SigTXREQFLITR.Addr)begin // 0 delay if addresses are continuous
          #(2*period*$urandom_range(7) + 3*period);  // random delay if addresses arent continuous
        end
        RXDATFLITV = 1;
        RXDATFLIT = '{default                : 0                                        ,                       
                                  QoS        : 0                                        ,
                                  TgtID      : 1                                        ,
                                  SrcID      : 2                                        ,
                                  TxnID      : SigTXREQFLITR.TxnID                      ,
                                  HomeNID    : 0                                        ,
                                  Opcode     : `CompData                                ,
                                  RespErr    : 0                                        ,
                                  Resp       : 0                                        , // Resp should be 0 when NonCopyBackWrData Rsp
                                  DataSource : 0                                        , 
                                  DBID       : 0                                        ,
                                  CCID       : 0                                        , 
                                  DataID     : 0                                        ,
                                  TraceTag   : 0                                        ,
                                  BE         : {64{1'b1}}                               ,
                                  Data       : 2**$urandom_range(0,512) - $urandom()    ,  //512 width of data
                                  DataCheck  : 0                                        ,
                                  Poison     : 0                                        
                                  }; 
        SrcAddrRegWE = 1;    
        SigDeqReqR = 1;
        #(period*2);
        RXDATFLITPEND     = 0      ;
        RXDATFLITV        = 0      ;
        RXDATFLIT         = 0      ;
        SigDeqReqR        = 0      ;
        SrcAddrRegWE      = 0      ; 
        if(SrcAddrReg +64 != SigTXREQFLITR.Addr)
          #period;
      end
      else begin
        RXDATFLITPEND     = 0      ;
        RXDATFLITV        = 0      ;
        RXDATFLIT         = 'd0    ;
        SigDeqReqR        = 0      ;
        SrcAddrRegWE      = 0      ; 
        #(period*2) ;
      end
    end
    
    always_ff@(posedge Clk)begin
      if(RST)
        SrcAddrReg <= 0 ;
      else
        if(SrcAddrRegWE)
          SrcAddrReg <= SigTXREQFLITR.Addr ;
    end

    //DBID Respose 
    always begin
      if(!SigReqEmptyW & SigTXREQFLITW.Opcode == `WriteUniquePtl & CountRspCrds != 0)begin
        #(2*period*$urandom_range(10) + 3*period) //response delay//response delay
        RXRSPFLITV = 1;
        RXRSPFLIT = '{default              : 0                                        ,                       
                                  QoS      : 0                                        ,
                                  TgtID    : 1                                        ,
                                  SrcID    : 2                                        ,
                                  TxnID    : SigTXREQFLITW.TxnID                      ,
                                  Opcode   : `CompDBIDResp                            ,
                                  RespErr  : 0                                        ,
                                  Resp     : 0                                        ,
                                  FwdState : 0                                        , // Resp should be 0 when NonCopyBackWrData Rsp
                                  DBID     : i                                        , 
                                  PCrdType : 0                                        ,
                                  TraceTag : 0                                       
                                  };     
        i++; //increase DBID pointer
        SigDeqReqW = 1;
        #(period*2);
        RXRSPFLITPEND     = 0      ;
        RXRSPFLITV        = 0      ;
        RXRSPFLIT         = 'd0    ;
        SigDeqReqW        = 0      ;
        #period;
      end
      else begin
        RXRSPFLITPEND     = 0      ;
        RXRSPFLITV        = 0      ;
        RXRSPFLIT         = 'd0    ;      
        SigDeqReqW        = 0      ;
        #(period*2) ;
      end
    end
    
    int temp =0;
    always @(posedge Clk)
        begin
          // Reset;
         RST               = 1      ;
         SrcAddr           = 'd10   ;
         DstAddr           = 'd1000 ;
         Length            = 'd320  ;
         IssueValid        = 1      ;
         DescAddr          = 'd1    ;
         FinishedDescValid = 0      ;
         
         #(period); // signals change at the negedge of Clk  
         #(period*2); // wait for period   
         
         for(int i = 1 ; i<20 ; i++)begin
           RST               = 0                                      ;
           SrcAddr           = 'd10    * $urandom_range(10000)        ;
           DstAddr           = 'd10000 * $urandom_range(10000)        ;
           Length            = $urandom_range(3,CHI_DATA_WIDTH*Chunk) ;
           if(CmdFIFOFULL)
             IssueValid      = 0                                      ;
           else
             IssueValid      = 1                                      ;
           DescAddr          = i                                      ;
           temp              = $urandom(5)                            ;
           FinishedDescValid = temp[2]                                ; //20% chance to be the last transaction of Desc
           #(period*2); // wait for period  
         end
         //stop
         RST               = 0  ;                                   
         SrcAddr           = 0  ;      
         DstAddr           = 0  ;
         Length            = 0  ;
         IssueValid        = 0  ;                                   
         DescAddr          = 1  ;                                   
         FinishedDescValid = 0  ;                                   
         
         #(period*1500); // wait for period   
        $stop;
        end
endmodule