`timescale 1ns / 1ps
import DataPkg    ::*; 
import CHIFlitsPkg::*; 
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 21.09.2022 00:23:26
// Design Name: 
// Module Name: CHIConverter
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
//`define WriteUniqueFull 0x19
// Rsp opcode
`define DBIDResp          4'h3
`define CompDBIDResp      4'h5
//Data opcode
`define NonCopyBackWrData 4'h3
`define NCBWrDataCompAck  4'hc
`define CompData          4'h4

`define DBIDRespWidth     8
`define TxnIDWidth        8
`define RspErrWidth       2

`define MaxCrds           15
`define CrdRegWidth       4  // log2(MaxCrds)

module CHIConverter#(    
//--------------------------------------------------------------------------
  parameter BRAM_ADDR_WIDTH  = 10                    ,
  parameter BRAM_NUM_COL     = 8                     , // As the Data_packet fields
  parameter BRAM_COL_WIDTH   = 32                    ,
  parameter MEM_ADDR_WIDTH   = 44                    ,//<------ should be the same with BRAM_COL_WIDTH
  parameter CMD_FIFO_LENGTH  = 32                    ,
  parameter DATA_FIFO_LENGTH = 32                    ,
  parameter TXID_FIFO_LENGTH = 2**(`TxnIDWidth - 1)  , 
  parameter SIZE_FIFO_WIDTH  = 7                     , //log2(CHI_DATA_WIDTH) + 1 
  parameter COUNTER_WIDTH    = 6                     , //log2(DATA_FIFO_LENGTH) + 1
  parameter CHI_DATA_WIDTH   = 64                    , //Bytes
  parameter QoS              = 8                     , //??
  parameter TgtID            = 2                     , //??
  parameter SrcID            = 1                       //??
//--------------------------------------------------------------------------
)(
    input                                        Clk               ,
    input                                        RST               ,
    input Data_packet                            DataBRAM          , // From BRAM
    input                                        ReadyBRAM         , // From Arbiter_BRAM
    input              [MEM_ADDR_WIDTH  - 1 : 0] SrcAddr           ,
    input              [MEM_ADDR_WIDTH  - 1 : 0] DstAddr           ,
    input              [MEM_ADDR_WIDTH  - 1 : 0] Length            ,
    input                                        IssueValid        , 
    input              [BRAM_ADDR_WIDTH - 1 : 0] DescAddr          , // Address of a finished Descriptor in BRAM
    input                                        FinishedDescValid ,
    output                                       TXREQFLITPEND     , // Request outbound Chanel
    output                                       TXREQFLITV        ,
    output ReqFlit                               TXREQFLIT         ,
    input                                        TXREQLCRDV        ,
    output                                       TXRSPFLITPEND     , // Response outbound Chanel
    output                                       TXRSPFLITV        ,
    output RspFlit                               TXRSPFLIT         ,
    input                                        TXRSPLCRDV        ,
    output                                       TXDATFLITPEND     , // Data outbound Chanel
    output                                       TXDATFLITV        ,
    output DataFlit                              TXDATFLIT         ,
    input                                        TXDATLCRDV        ,
    input                                        RXRSPFLITPEND     , // Response inbound Chanel
    input                                        RXRSPFLITV        ,
    input  RspFlit                               RXRSPFLIT         ,
    output reg                                   RXRSPLCRDV        ,
    input                                        RXDATFLITPEND     , // Data inbound Chanel
    input                                        RXDATFLITV        ,
    input  DataFlit                              RXDATFLIT         ,
    output reg                                   RXDATLCRDV        ,
    output                                       CmdFIFOFULL       , // For Scheduler
    output                                       ValidBRAM         , // For Arbiter_BRAM
    output             [BRAM_ADDR_WIDTH - 1 : 0] AddrBRAM          , // For BRAM
    output Data_packet                           DescStatus        ,
    output             [BRAM_NUM_COL    - 1 : 0] WEBRAM        
    );                         
    
   //Read command FIFO signals
   wire                            SigDeqRead        ; // Dequeue
   wire [BRAM_COL_WIDTH   - 1 : 0] SigSrcAddr        ; // DATA
   wire                            SigSrcAddrFULL    ; // FULL
   wire                            SigSrcAddrEmpty   ; // Empty
   wire [BRAM_COL_WIDTH   - 1 : 0] SigRLength        ; // Length DATA
   //Write command FIFO signals
   wire                            SigDeqWrite       ; // Dequeue    
   wire [BRAM_COL_WIDTH   - 1 : 0] SigDstAddr        ; // DATA       
   wire                            SigDstAddrFULL    ; // FULL       
   wire                            SigDstAddrEmpty   ; // Empty      
   wire [BRAM_COL_WIDTH   - 1 : 0] SigWLength        ; // Length DATA
   //Desc Addr FIFO signals
   wire [BRAM_ADDR_WIDTH      : 0] SigDescAddr       ; // DATA
   wire                            SigDescAddrFULL   ; // FULL
   wire                            SigDescAddrEmpty  ; // Empty
   //Desc Addr for each write transaction FIFO signals
   wire [BRAM_ADDR_WIDTH      : 0] SigWrtTxnDescAddr ;
   //Data FIFO signals
   wire                            SigDeqData        ; // Dequeue
   wire [CHI_DATA_WIDTH*8 - 1 : 0] SigFIFOData       ; // DATA
   wire                            SigDataEmpty      ; //Empty
   //Data RspErr FIFO signals
   wire [`RspErrWidth     - 1 : 0] SigFIFODataRspErr ;
   //DBID FIFO signals
   wire [`DBIDRespWidth   - 1 : 0] SigFIFODBID       ; // DATA
   wire                            SigEnqDBID        ; // Enqueue
   wire                            SigDBIDEmpty      ; //Empty
    //DBID RspErr FIFO signals
   wire [`RspErrWidth     - 1 : 0] SigFIFODBIDRspErr ;
   //Size FIFO signals
   wire [SIZE_FIFO_WIDTH  - 1 : 0] SigFIFOSize       ; // DATA IN
   wire [SIZE_FIFO_WIDTH  - 1 : 0] SigDataSize       ; // DATA OUT
   wire                            SigSizeFULL       ;
   //TxnID FIFO signal
   wire [`TxnIDWidth      - 1 : 0] SigFinishedTxnIDR ; // DATA IN
   wire                            SigEnqTxnIDR      ; // Enqueue       
   wire [`TxnIDWidth      - 1 : 0] SigNextTxnIDR     ; // DATA OUT
   wire                            SigTxnIDEmptyR    ; // Empty
   
   wire [`TxnIDWidth      - 1 : 0] SigFinishedTxnIDW ; // DATA IN
   wire                            SigEnqTxnIDW      ; // Enqueue       
   wire [`TxnIDWidth      - 1 : 0] SigNextTxnIDW     ; // DATA OUT
   wire                            SigTxnIDEmptyW    ; // Empty
   //register
   reg  [MEM_ADDR_WIDTH   - 1 : 0] ReadReqBytes      ; // Used to Count Bytes Requested from first element of FIFO
   reg  [MEM_ADDR_WIDTH   - 1 : 0] WriteReqBytes     ; // Used to Count Bytes Requested from first element of FIFO
   //Credits 
   reg  [`CrdRegWidth      - 1 : 0] ReqCrd           ;
   reg  [`CrdRegWidth      - 1 : 0] RspCrdInbound    ;
   reg  [`CrdRegWidth      - 1 : 0] DataCrdInbound   ; // CHI allows max 15 Crds per chanel
   reg  [`CrdRegWidth      - 1 : 0] RspCrdOutbound   ;
   reg  [`CrdRegWidth      - 1 : 0] DataCrdOutbound  ;
   reg  [COUNTER_WIDTH     - 1 : 0] GivenRspCrd      ; // Used in order not to give more Crds than  DATA_FIFO_LENGTH
   reg  [COUNTER_WIDTH     - 1 : 0] GivenDataCrd     ; // Used in order not to give more Crds than  DATA_FIFO_LENGTH
   //Read Requester signals 
   wire                            ReadReqArbValid   ; 
   wire                            ReadReqArbReady   ;
   wire                            ReadReqV          ;
   ReqFlit                         ReadReqFlit       ;
   //Write Requester signals 
   wire                            WriteReqArbValid  ; 
   wire                            WriteReqArbReady  ;
   wire                            WriteReqV         ;
   ReqFlit                         WriteReqFlit      ;
   //Updater signals
   wire                            FULLUpdater       ;
   //Arbiter signals
   reg                             AccessReg         ;
   
   //SrcAddr Read command FIFO
   FIFO #(     
       BRAM_COL_WIDTH ,   //FIFO_WIDTH       
       CMD_FIFO_LENGTH    //FIFO_LENGTH      
       )     
       FIFOSrcAddr (     
       .RST        ( RST             ) ,      
       .Clk        ( Clk             ) ,      
       .Inp        ( SrcAddr         ) , 
       .Enqueue    ( IssueValid      ) , 
       .Dequeue    ( SigDeqRead      ) , 
       .Outp       ( SigSrcAddr      ) , 
       .FULL       ( SigSrcAddrFULL  ) , 
       .Empty      ( SigSrcAddrEmpty ) 
       );

   // Length Read command FIFO
   FIFO #(     
       BRAM_COL_WIDTH ,   //FIFO_WIDTH       
       CMD_FIFO_LENGTH    //FIFO_LENGTH      
       )     
       FIFORLengh  (     
       .RST        ( RST             ) ,      
       .Clk        ( Clk             ) ,      
       .Inp        ( Length          ) , 
       .Enqueue    ( IssueValid      ) , 
       .Dequeue    ( SigDeqRead      ) , 
       .Outp       ( SigRLength      ) , 
       .FULL       (                 ) , 
       .Empty      (                 ) 
       );
       
   //DstAddr Write command FIFO
   FIFO #(     
       BRAM_COL_WIDTH ,   //FIFO_WIDTH       
       CMD_FIFO_LENGTH    //FIFO_LENGTH      
       )     
       FIFODstAddr (     
       .RST        ( RST             ) ,      
       .Clk        ( Clk             ) ,      
       .Inp        ( DstAddr         ) , 
       .Enqueue    ( IssueValid      ) , 
       .Dequeue    ( SigDeqWrite     ) , 
       .Outp       ( SigDstAddr      ) , 
       .FULL       ( SigDstAddrFULL  ) , 
       .Empty      ( SigDstAddrEmpty ) 
       );

   // Length Write command FIFO
   FIFO #(     
       BRAM_COL_WIDTH ,   //FIFO_WIDTH       
       CMD_FIFO_LENGTH    //FIFO_LENGTH      
       )     
       FIFOWLengh  (     
       .RST        ( RST             ) ,      
       .Clk        ( Clk             ) ,      
       .Inp        ( Length          ) , 
       .Enqueue    ( IssueValid      ) , 
       .Dequeue    ( SigDeqWrite     ) , 
       .Outp       ( SigWLength      ) , 
       .FULL       (                 ) , 
       .Empty      (                 ) 
       );
       
   // Descriptors Addr FIFO
   FIFO #(     
       BRAM_ADDR_WIDTH + 1 ,  //FIFO_WIDTH       
       CMD_FIFO_LENGTH        //FIFO_LENGTH      
       )     
       FIFODescAddr     (     
       .RST             ( RST                                  ) ,      
       .Clk             ( Clk                                  ) ,      
       .Inp             ( {FinishedDescValid,DescAddr}         ) , 
       .Enqueue         ( IssueValid                           ) , 
       .Dequeue         ( SigDeqWrite                          ) , 
       .Outp            ( SigDescAddr                          ) , 
       .FULL            ( SigDescAddrFULL                      ) , 
       .Empty           ( SigDescAddrEmpty                     ) 
       );
       
   // Descriptors Addr for each write transaction FIFO
   FIFO #(     
       BRAM_ADDR_WIDTH + 1 ,  //FIFO_WIDTH       
       DATA_FIFO_LENGTH       //FIFO_LENGTH      
       )     
       FIFOWrtTxnDescAddr (     
       .RST               ( RST                                                                               ) ,      
       .Clk               ( Clk                                                                               ) ,      
       .Inp               ( {SigDescAddr[BRAM_ADDR_WIDTH] & SigDeqWrite,SigDescAddr[BRAM_ADDR_WIDTH - 1 : 0]} ) , 
       .Enqueue           ( WriteReqArbValid & WriteReqArbReady                                               ) , 
       .Dequeue           ( SigDeqData                                                                        ) , 
       .Outp              ( SigWrtTxnDescAddr                                                                 ) , 
       .FULL              (                                                                                   ) , 
       .Empty             (                                                                                   ) 
       );
       
   // Read Data FIFO
   FIFO #(     
       CHI_DATA_WIDTH*8 ,  //FIFO_WIDTH       
       DATA_FIFO_LENGTH    //FIFO_LENGTH      
       )     
       FIFOData  (     
       .RST      ( RST                            ) ,      
       .Clk      ( Clk                            ) ,      
       .Inp      ( RXDATFLIT.Data                 ) , 
       .Enqueue  ( RXDATFLITV & DataCrdInbound!=0 ) , 
       .Dequeue  ( SigDeqData                     ) , 
       .Outp     ( SigFIFOData                    ) , 
       .FULL     (                                ) , 
       .Empty    ( SigDataEmpty                   ) 
       );
   
   // Read Data RspErr FIFO
   FIFO #(     
       `RspErrWidth      ,  //FIFO_WIDTH       
        DATA_FIFO_LENGTH    //FIFO_LENGTH      
       )     
       FIFODataRspErr  (     
       .RST            ( RST                            ) ,      
       .Clk            ( Clk                            ) ,      
       .Inp            ( RXDATFLIT.RespErr              ) , 
       .Enqueue        ( RXDATFLITV & DataCrdInbound!=0 ) , 
       .Dequeue        ( SigDeqData                     ) , 
       .Outp           ( SigFIFODataRspErr              ) , 
       .FULL           (                                ) , 
       .Empty          (                                ) 
       );
       
   // DBID FIFO
   FIFO #(     
       8                ,  //FIFO_WIDTH       
       DATA_FIFO_LENGTH    //FIFO_LENGTH      
       )     
       FIFODBID  (     
       .RST      ( RST            ) ,      
       .Clk      ( Clk            ) ,      
       .Inp      ( RXRSPFLIT.DBID ) , 
       .Enqueue  ( SigEnqDBID     ) , 
       .Dequeue  ( SigDeqData     ) , 
       .Outp     ( SigFIFODBID    ) , 
       .FULL     (                ) , 
       .Empty    ( SigDBIDEmpty   ) 
       );
       
        // Read DBID RspErr FIFO
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
       
   // Size FIFO
   FIFO #(     
       SIZE_FIFO_WIDTH  ,  //FIFO_WIDTH (log2(CHI_DATA_WIDTH) + 1)  
       DATA_FIFO_LENGTH     //FIFO_LENGTH 
       )     
       FIFOSize  (     
       .RST      ( RST            ) ,      
       .Clk      ( Clk            ) ,      
       .Inp      ( SigDataSize    ) , 
       .Enqueue  ( WriteReqV      ) , 
       .Dequeue  ( SigDeqData     ) , 
       .Outp     ( SigFIFOSize    ) , 
       .FULL     ( SigSizeFULL    ) , 
       .Empty    (                ) 
       );
       
   // Read TXNID FIFO
   FIFOInit #(     
       8                ,  //FIFO_WIDTH       
       TXID_FIFO_LENGTH ,  //FIFO_LENGTH
       0                   //FIRST_INIT_VALUE      
       )     
       FIFOTXNIDR (     
       .RST       ( RST                                                      ) ,
       .Clk       ( Clk                                                      ) ,
       .Inp       ( SigFinishedTxnIDR                                        ) ,
       .Enqueue   ( SigEnqTxnIDR                                             ) ,
       .Dequeue   ( TXREQFLITV & TXREQFLIT.Opcode == `ReadOnce & ReqCrd != 0 ) , 
       .Outp      ( SigNextTxnIDR                                            ) ,
       .FULL      (                                                          ) ,
       .Empty     ( SigTxnIDEmptyR                                           )
       );                                                                    
       
   // Write TXNID FIFO
   FIFOInit #(     
       8                ,  //FIFO_WIDTH       
       TXID_FIFO_LENGTH ,  //FIFO_LENGTH
       TXID_FIFO_LENGTH    //FIRST_INIT_VALUE      
       )     
       FIFOTXNIDW (     
       .RST       ( RST                                                            ) ,      
       .Clk       ( Clk                                                            ) ,      
       .Inp       ( SigFinishedTxnIDW                                              ) , 
       .Enqueue   ( SigEnqTxnIDW                                                   ) , 
       .Dequeue   ( TXREQFLITV & TXREQFLIT.Opcode == `WriteUniquePtl & ReqCrd != 0 ) , 
       .Outp      ( SigNextTxnIDW                                                  ) , 
       .FULL      (                                                                ) , 
       .Empty     ( SigTxnIDEmptyW                                                 ) 
       );
       
   // Status Updater
   Completer #(     
       BRAM_ADDR_WIDTH  ,         
       DATA_FIFO_LENGTH ,            
       BRAM_NUM_COL   
       )myCompleter (     
       .RST         ( RST               ) ,      
       .Clk         ( Clk               ) ,      
       .DescAddr    ( SigWrtTxnDescAddr ) , 
       .DBIDRespErr ( SigFIFODBIDRspErr ) , 
       .DataRespErr ( SigFIFODataRspErr ) , 
       .ValidUpdate ( SigDeqData        ) , 
       .DescData    ( DataBRAM          ) , 
       .ReadyBRAM   ( ReadyBRAM         ) ,
       .ValidBRAM   ( ValidBRAM         ) ,
       .AddrOut     ( AddrBRAM          ) ,
       .DataOut     ( DescStatus        ) ,
       .WE          ( WEBRAM            ) ,
       .FULL        ( FULLUpdater       )
       );
   
   assign CmdFIFOFULL = SigSrcAddrFULL | SigDstAddrFULL ;
        
   // ################## Read Requester ##################
   
   // Request chanel from Arbiter
   assign ReadReqArbValid = (!SigSrcAddrEmpty & ReqCrd != 0 & !SigTxnIDEmptyR) ? 1 : 0 ;
   // Enable valid for CHI-Request transaction 
   assign ReadReqV = (!SigSrcAddrEmpty & ReqCrd != 0 & !SigTxnIDEmptyR & ReadReqArbReady) ? 1 : 0 ;
   // Dequeue Read command FIFO 
   assign SigDeqRead = (SigRLength - ReadReqBytes <= CHI_DATA_WIDTH & ReadReqArbValid & ReadReqArbReady) ? 1 : 0 ;
   // Create Request Read flit 
   assign ReadReqFlit  = '{default       : 0                         ,                       
                           QoS           : QoS                       ,
                           TgtID         : TgtID                     ,
                           SrcID         : SrcID                     ,
                           TxnID         : SigNextTxnIDR             ,
                           ReturnNID     : 0                         ,
                           StashNIDValid : 0                         ,
                           ReturnTxnID   : 0                         ,
                           Opcode        : `ReadOnce                 ,
                           Size          : 3'b110                    , // 64 bytes
                           Addr          : SigSrcAddr + ReadReqBytes ,
                           NS            : 0                         , // Non-Secure bit disable
                           LikelyShared  : 0                         ,
                           AllowRetry    : 0                         ,
                           Order         : 0                         ,
                           PCrdType      : 0                         ,
                           MemAttr       : 4'b0101                   , // EWA : 1 , Device : 0 , Cachable : 1 , Allocate : 0 
                           SnpAttr       : 1                         ,
                           LPID          : 0                         ,
                           Excl          : 0                         ,
                           ExpCompAck    : 0                         ,
                           TraceTag      : 0                           } ;
   // Manage Registers 
   always_ff@(posedge Clk) begin 
     if(RST)begin
       ReadReqBytes <= 0 ;
     end
     else begin
       // Manage Reg that counts Bytes Requested from first element of FIFO
       if(SigDeqRead)                                // When last Read Req reset value of reg
         ReadReqBytes <= 0 ;
       else if(ReadReqArbValid & ReadReqArbReady)    // When new non-last Read Req increase value of reg
         ReadReqBytes <= ReadReqBytes + CHI_DATA_WIDTH ;
     end                   
   end 
   // ################## End Read Requester ##################
   
   // ****************** Write Requester ******************
   
   // Request chanel from Arbiter
   assign WriteReqArbValid = (!SigDstAddrEmpty & ReqCrd != 0 & !SigTxnIDEmptyW & !SigSizeFULL) ? 1 : 0 ;
   // Enable valid for CHI-Request transaction 
   assign WriteReqV = (!SigDstAddrEmpty & ReqCrd != 0 & !SigTxnIDEmptyW & !SigSizeFULL & WriteReqArbReady) ? 1 : 0 ;
   // Dequeue Write command FIFO 
   assign SigDeqWrite = (SigWLength - WriteReqBytes <= CHI_DATA_WIDTH & WriteReqArbValid & WriteReqArbReady) ? 1 : 0 ;
   // Size of Data that will be sent
   assign SigDataSize = (SigWLength - WriteReqBytes <= CHI_DATA_WIDTH ) ? (SigWLength - WriteReqBytes) : CHI_DATA_WIDTH ;
   // Create Request Write flit 
   assign WriteReqFlit  = ( '{ default       : 0                          ,                       
                               QoS           : QoS                        ,
                               TgtID         : TgtID                      ,
                               SrcID         : SrcID                      ,
                               TxnID         : SigNextTxnIDW              ,
                               ReturnNID     : 0                          ,
                               StashNIDValid : 0                          ,
                               ReturnTxnID   : 0                          ,
                               Opcode        : `WriteUniquePtl            ,
                               Size          : 3'b110                     , // 64 bytes
                               Addr          : SigDstAddr + WriteReqBytes ,
                               NS            : 0                          , // Non-Secure bit disable
                               LikelyShared  : 0                          ,
                               AllowRetry    : 0                          ,
                               Order         : 0                          ,
                               PCrdType      : 0                          ,
                               MemAttr       : 4'b0101                    , // EWA : 1 , Device : 0 , Cachable : 1 , Allocate : 0 
                               SnpAttr       : 1                          ,
                               LPID          : 0                          ,
                               Excl          : 0                          ,
                               ExpCompAck    : 0                          ,
                               TraceTag      : 0                           }) ;
   
   // Manage Registers 
   always_ff@(posedge Clk) begin 
     if(RST)begin
       WriteReqBytes <= 0 ;
     end
     else begin
       // Manage Reg that counts Bytes Requested from first element of FIFO
       if(SigDeqWrite)        // When last Write Req reset value of reg
         WriteReqBytes <= 0 ;
       else if(WriteReqArbValid & WriteReqArbReady)    // When new non-last Write Req increase value of reg
         WriteReqBytes <= WriteReqBytes + CHI_DATA_WIDTH  ;
     end                   
   end                                            
   // ****************** End Write Requester ******************

   // ################## Arbiter ##################
   // Reg for round robin
   always_ff@(posedge Clk) begin
     if(RST)
       AccessReg <= 0 ;
     else begin
       if(ReadReqArbValid & WriteReqArbValid)
         AccessReg <= !AccessReg ;
     end  
   end
   
   // Enable Ready signals by round robin if needed 
   assign  ReadReqArbReady  = (ReadReqArbValid & !WriteReqArbValid) ? 1 : ((ReadReqArbValid & WriteReqArbValid) ? !AccessReg : 0) ;
   assign  WriteReqArbReady = (!ReadReqArbValid & WriteReqArbValid) ? 1 : ((ReadReqArbValid & WriteReqArbValid) ?  AccessReg : 0) ;
   // Request chanel signals
   assign  TXREQFLIT    = WriteReqArbReady ? WriteReqFlit : (ReadReqArbReady ? ReadReqFlit : 0) ;
   assign  TXREQFLITV   = WriteReqArbReady ? WriteReqV    : (ReadReqArbReady ? ReadReqV    : 0) ;
   // ################## End Arbiter ##################      
       
      
     
   // Manage Credits
   always_ff@(posedge Clk) begin
     if(RST)begin
       ReqCrd          <= 0 ;
       RspCrdInbound   <= 0 ;
       DataCrdInbound  <= 0 ;
       RspCrdOutbound  <= 0 ;
       DataCrdOutbound <= 0 ;
       GivenRspCrd     <= 0 ;
       GivenDataCrd    <= 0 ;
     end
     else begin
       // Request chanel Crd Counter
       if(TXREQLCRDV & !(ReqCrd != 0 & TXREQFLITV) & ReqCrd < `MaxCrds)
         ReqCrd <= ReqCrd + 1 ;
       else if(!TXREQLCRDV & (ReqCrd != 0 & TXREQFLITV) & ReqCrd > 0)
         ReqCrd <= ReqCrd - 1 ;
       // Outbound Response chanle Crd Counter
       if(TXRSPLCRDV & !(RspCrdOutbound != 0 & TXRSPFLITV) & RspCrdOutbound < `MaxCrds)
         RspCrdOutbound <= RspCrdOutbound + 1 ;
       else if(!TXRSPLCRDV & (RspCrdOutbound != 0 & TXRSPFLITV) & RspCrdOutbound > 0)
         RspCrdOutbound <= RspCrdOutbound - 1 ;
       // Outbound Data chanle Crd Counter
       if(TXDATLCRDV & !(DataCrdOutbound != 0 & TXDATFLITV) & DataCrdOutbound <`MaxCrds)
         DataCrdOutbound <= DataCrdOutbound + 1 ;
       else if(!TXDATLCRDV & (DataCrdOutbound != 0 & TXDATFLITV) & DataCrdOutbound > 0 )
         DataCrdOutbound <= DataCrdOutbound - 1 ;
       // Inbound Response chanle Crd Counter
       if(RXRSPLCRDV & !(RspCrdInbound != 0 & RXRSPFLITV))
         RspCrdInbound <= RspCrdInbound + 1 ;
       else if(!RXRSPLCRDV & (RspCrdInbound != 0 & RXRSPFLITV))
         RspCrdInbound <= RspCrdInbound - 1 ;
       // Count the number of given Rsp Crds in order not to give more than DBID FIFO length
       if(RXRSPLCRDV & !SigDeqData & (!RXRSPFLITV | RspCrdInbound == 0 | RXRSPFLIT.Opcode == `DBIDResp | RXRSPFLIT.Opcode == `CompDBIDResp))
         GivenRspCrd <= GivenRspCrd + 1 ;
       else if(!RXRSPLCRDV & SigDeqData & (!RXRSPFLITV | RspCrdInbound == 0 | RXRSPFLIT.Opcode == `DBIDResp | RXRSPFLIT.Opcode == `CompDBIDResp))
         GivenRspCrd <= GivenRspCrd - 1 ;
       else if(!RXRSPLCRDV & !SigDeqData & (RXRSPFLITV & RspCrdInbound != 0 & RXRSPFLIT.Opcode != `DBIDResp & RXRSPFLIT.Opcode != `CompDBIDResp))
         GivenRspCrd <= GivenRspCrd - 1 ;
       else if(!RXRSPLCRDV & SigDeqData & (RXRSPFLITV & RspCrdInbound != 0 & RXRSPFLIT.Opcode != `DBIDResp & RXRSPFLIT.Opcode != `CompDBIDResp))
         GivenRspCrd <= GivenRspCrd - 2 ;
         else if(RXRSPLCRDV & SigDeqData & (RXRSPFLITV & RspCrdInbound != 0 & RXRSPFLIT.Opcode != `DBIDResp & RXRSPFLIT.Opcode != `CompDBIDResp))
         GivenRspCrd <= GivenRspCrd - 1 ;
       // Inbound Data chanle Crd Counter
       if(RXDATLCRDV & !(DataCrdInbound != 0 & RXDATFLITV))
         DataCrdInbound <= DataCrdInbound + 1 ;
       else if(!RXDATLCRDV & (DataCrdInbound != 0 & RXDATFLITV))
         DataCrdInbound <= DataCrdInbound - 1 ;
       // Count the number of given Data Crds in order not to give more than DATA FIFO length
       if(RXDATLCRDV & !SigDeqData)
         GivenDataCrd <= GivenDataCrd + 1 ;       
       else if(!RXDATLCRDV & SigDeqData)
         GivenDataCrd <= GivenDataCrd - 1 ;      
         
     end
   end
   ///////////////////
   //     |  No Rst //
   //     |  In comb//
   //     V         //
   ///////////////////
   // Give an extra Crd in outbound Rsp Chanel
   assign RXRSPLCRDV = (!RST & ((GivenRspCrd  < DATA_FIFO_LENGTH) & (RspCrdInbound  < `MaxCrds))) ;
   // Give an extra Crd in outbound Data Chanel
   assign RXDATLCRDV = (!RST & ((GivenDataCrd < DATA_FIFO_LENGTH) & (DataCrdInbound < `MaxCrds))) ;
   
   
    // ****************** Data Sender ******************
   // Enable valid of CHI-DATA chanel 
   assign TXDATFLITV = (!SigDataEmpty & !SigDBIDEmpty & !FULLUpdater & DataCrdOutbound != 0) ? 1 : 0 ;
   // Dequeue FIFOs for DATA transfer 
   assign SigDeqData = TXDATFLITV ;
   // Create Request Write flit 
   assign TXDATFLIT    = '{default    : 0                                        ,                       
                           QoS        : QoS                                      ,
                           TgtID      : TgtID                                    ,
                           SrcID      : SrcID                                    ,
                           TxnID      : SigFIFODBID                              ,
                           HomeNID    : 0                                        ,
                           Opcode     : `NonCopyBackWrData                       ,
                           RespErr    : SigFIFODBIDRspErr | SigFIFODataRspErr    ,
                           Resp       : 0                                        , // Resp should be 0 when NonCopyBackWrData Rsp
                           DataSource : 0                                        , 
                           DBID       : 0                                        ,
                           CCID       : 0                                        , 
                           DataID     : 0                                        ,
                           TraceTag   : 0                                        ,
                           BE         : ~({CHI_DATA_WIDTH{1'b1}} << SigFIFOSize) ,
                           Data       : SigFIFOData                              ,  
                           DataCheck  : 0                                        ,
                           Poison     : 0                                          } ;
    // ****************** End Data Sender ******************
    
    // ****************** RSP Handler  ******************
    // Re-enqueue TxnID of finished transaction
    assign SigFinishedTxnIDR = (SigEnqTxnIDR) ? (RXDATFLIT.TxnID) : 0     ;
    assign SigFinishedTxnIDW = (SigEnqTxnIDW) ? (RXRSPFLIT.TxnID) : 0     ;
    assign SigEnqTxnIDR      = (RXDATFLITV == 1 & DataCrdInbound != 0)    ;
    assign SigEnqTxnIDW      = (RXRSPFLITV == 1 & RspCrdInbound  != 0)    ;
    // Enqueue DBID
    assign SigEnqDBID  = (RXRSPFLITV == 1 & (RXRSPFLIT.Opcode == `DBIDResp | RXRSPFLIT.Opcode == `CompDBIDResp) & RspCrdInbound != 0 );
    // ****************** End of RSP Handler ******************
    
   assign TXRSPFLITV = 0 ; //usless
 endmodule
