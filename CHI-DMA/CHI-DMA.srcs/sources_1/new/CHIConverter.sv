`timescale 1ns / 1ps
import DataPkg     ::*; 
import CHIFlitsPkg ::*; 
import CHIFIFOsPkg ::*; 
import CompleterPkg::*; 
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
  parameter BRAM_ADDR_WIDTH     = 10                                     ,
  parameter BRAM_NUM_COL        = 8                                      , //As the Data_packet fields
  parameter BRAM_COL_WIDTH      = 32                                     ,
  parameter MEM_ADDR_WIDTH      = 44                                     , 
  parameter CMD_FIFO_LENGTH     = 32                                     ,
  parameter DATA_FIFO_LENGTH    = 32                                     ,
  parameter SIZE_WIDTH          = BRAM_ADDR_WIDTH + 7 + 1                , //DescAddr*BRAM_ADDR_WIDTH + Size*(log2(CHI_DATA_WIDTH) + 1) + LastDescTrans*1 
  parameter COUNTER_WIDTH       = 6                                      , //log2(DATA_FIFO_LENGTH) + 1
  parameter CHI_DATA_WIDTH      = 64                                     , //Bytes
  parameter ADDR_WIDTH_OF_DATA  = 6                                      , // log2(CHI_DATA_WIDTH)  
  parameter QoS                 = 8                                      , //??
  parameter TgtID               = 2                                      , //??
  parameter SrcID               = 1                                        //??
//--------------------------------------------------------------------------
)(
    input                                                           Clk               ,
    input                                                           RST               ,
    input          Data_packet                                      DataBRAM          , // From BRAM
    input                                                           IssueValid        ,
    input                                                           ReadyBRAM         , // From Arbiter_BRAM
    input          CHI_Command                                      Command           , // CHI-Command (SrcAddr,DstAddr,Length,DescAddr,LastDescTrans)
    input                                                           LastDescTrans     , // From BS
    input                               [BRAM_ADDR_WIDTH - 1 : 0]   DescAddr          ,
    input                               [CHI_DATA_WIDTH  - 1 : 0]   BE                , 
    input                               [CHI_DATA_WIDTH*8- 1 : 0]   ShiftedData       ,
    input                               [`RspErrWidth    - 1 : 0]   DataErr           ,
    input                                                           EmptyBS           ,
    input                                                           FULLBS            ,
    ReqChannel                                                      ReqChan           , // Request ChannelS
    RspOutbChannel                                                  RspOutbChan       , // Response outbound Chanel
    DatOutbChannel                                                  DatOutbChan       , // Data outbound Chanel
    RspInbChannel                                                   RspInbChan        , // Response inbound Chanel
    input          DataFlit                                         RXDATFLITV        , // Data inbound Chanel
    input                                                           RXDATFLIT         , 
    output                                                          CmdFIFOFULL       , // For Scheduler
    output                                                          ValidBRAM         , // For Arbiter_BRAM
    output                               [BRAM_ADDR_WIDTH - 1 : 0]  AddrBRAM          , // For BRAM
    output         Data_packet                                      DescStatus        ,
    output                               [BRAM_NUM_COL    - 1 : 0]  WEBRAM            ,
    output                                                          EnqueueBS         , // For BS
    output         CHI_Command                                      CommandBS         ,
    output                                                          DequeueBS
    );                         
    
   // Command FIFO signals
   wire                                             SigDeqCommand     ; // Dequeue
   CHI_Command                                      SigCommand        ; // DATA
   wire                                             SigCommandEmpty   ; // Empty
   //DBID FIFO signals
   CHI_FIFO_DBID_Packet                             SigDBIDFIFOIn     ; // DATA In
   CHI_FIFO_DBID_Packet                             SigDBIDPack       ; // DATA Out
   wire                                             SigEnqDBID        ;
   wire                                             SigDBIDEmpty      ; //Empty
   //TxnID registers
   reg                  [`TxnIDWidth           : 0] NextReadTxnID     ; // The next TxnID that can be used for a Read
   reg                  [`TxnIDWidth           : 0] FreeReadTxnID     ; // Number of available TxnID for Read    
   reg                  [`TxnIDWidth           : 0] NextWriteTxnID    ; // The next TxnID that can be used for a Write
   reg                  [`TxnIDWidth           : 0] FreeWriteTxnID    ; // Number of available TxnID for Write        
   //register for counting Requested Bytes
   reg                  [MEM_ADDR_WIDTH   - 1  : 0] ReadReqBytes      ; // Used to Count Bytes Requested from first element of FIFO
   reg                  [MEM_ADDR_WIDTH   - 1  : 0] WriteReqBytes     ; // Used to Count Bytes Requested from first element of FIFO
   //Credits 
   reg                  [`CrdRegWidth     - 1 : 0]  ReqCrd            ;
   reg                  [`CrdRegWidth     - 1 : 0]  RspCrdInbound     ;
   reg                  [`CrdRegWidth     - 1 : 0]  RspCrdOutbound    ;// CHI allows max 15 Crds per chanel
   reg                  [`CrdRegWidth     - 1 : 0]  DataCrdOutbound   ;
   reg                  [COUNTER_WIDTH    - 1 : 0]  GivenRspCrd       ; // Used in order not to give more Crds than  DATA_FIFO_LENGTH
   //Read Requester signals 
   reg                                              GaveBSCommand     ; // register indicates if a command has been given to BS
   wire                                             ReadReqArbValid   ; 
   wire                                             ReadReqArbReady   ;
   wire                                             ReadReqV          ;
   ReqFlit                                          ReadReqFlit       ;
   wire                                             SigDeqRead        ;
   wire                 [MEM_ADDR_WIDTH   - 1  : 0] SigReadAddr       ;
   wire                 [MEM_ADDR_WIDTH   - 1  : 0] NextSrcAddr       ;
   //Write Requester signals
   wire                                             WriteReqArbValid  ; 
   wire                                             WriteReqArbReady  ;
   wire                                             WriteReqV         ;
   ReqFlit                                          WriteReqFlit      ;
   wire                                             SigDeqWrite       ;
   wire                 [MEM_ADDR_WIDTH   - 1  : 0] SigWriteAddr      ;
   wire                 [MEM_ADDR_WIDTH   - 1  : 0] NextDstAddr       ;
   //Updater signal
   wire                                             FULLCmplter       ;
   //Arbiter signal
   reg                                              AccessReg         ; //register to for arbitrate the order of access
   
   //CommandFIFO FIFO (SrcAddr,DstAddr,BTS,SB,DescAddr,LastDescTrans)
   assign SigDeqCommand = SigDeqRead & SigDeqWrite ;
   FIFO #(     
       .FIFO_WIDTH  (3*BRAM_COL_WIDTH + BRAM_ADDR_WIDTH + 1 )  ,  //FIFO_WIDTH   
       .FIFO_LENGTH (CMD_FIFO_LENGTH                        )     //FIFO_LENGTH      
       )     
       CommandFIFO (     
       .RST        ( RST             ) ,      
       .Clk        ( Clk             ) ,      
       .Inp        ( Command         ) , 
       .Enqueue    ( IssueValid      ) , 
       .Dequeue    ( SigDeqCommand   ) , 
       .Outp       ( SigCommand      ) , 
       .FULL       ( CmdFIFOFULL     ) , 
       .Empty      ( SigCommandEmpty ) 
       );
       
   // DBID FIFO
   assign SigDBIDFIFOIn = '{default : 0                             ,
                            DBID    : RspInbChan.RXRSPFLIT.DBID     ,
                            RespErr : RspInbChan.RXRSPFLIT.RespErr   };
                            
   assign SigEnqDBID  = (RspInbChan.RXRSPFLITV == 1 & (RspInbChan.RXRSPFLIT.Opcode == `DBIDResp | RspInbChan.RXRSPFLIT.Opcode == `CompDBIDResp) & RspCrdInbound != 0 );
   FIFO #(     
       .FIFO_WIDTH  ( `DBIDRespWidth + `RspErrWidth ),  //FIFO_WIDTH       
       .FIFO_LENGTH ( DATA_FIFO_LENGTH              )   //FIFO_LENGTH      
       )     
       FIFODBID  (     
       .RST      ( RST            ) ,      
       .Clk      ( Clk            ) ,      
       .Inp      ( SigDBIDFIFOIn  ) , 
       .Enqueue  ( SigEnqDBID     ) , 
       .Dequeue  ( SigDeqDBID     ) , 
       .Outp     ( SigDBIDPack    ) , 
       .FULL     (                ) , 
       .Empty    ( SigDBIDEmpty   ) 
       );     
       
   // Completer (Status Updater)
   Completer_Packet CompDataPack ;
   assign CompDataPack = '{ default         : 0                   ,
                            LastDescTrans   : LastDescTrans       ,
                            DescAddr        : DescAddr            ,
                            DBIDRespErr     : SigDBIDPack.RespErr ,
                            DataRespErr     : DataErr               };
   Completer #(     
       .BRAM_ADDR_WIDTH ( BRAM_ADDR_WIDTH                      ) ,            
       .BRAM_NUM_COL    ( BRAM_NUM_COL                         ) ,        
       .FIFO_Length     ( DATA_FIFO_LENGTH                     ) , 
       .FIFO_WIDTH      ( BRAM_ADDR_WIDTH + `RspErrWidth*2 + 1 )   // FIFO_WIDTH is DescAdd + RespErrorWidth + LastDescTrans     
       )
       myCompleter   (     
       .RST          ( RST           ) ,      
       .Clk          ( Clk           ) ,      
       .CompDataPack ( CompDataPack  ) , 
       .ValidUpdate  ( SigDeqDBID    ) ,
       .DescData     ( DataBRAM      ) , 
       .ReadyBRAM    ( ReadyBRAM     ) ,
       .ValidBRAM    ( ValidBRAM     ) ,
       .AddrOut      ( AddrBRAM      ) ,
       .DataOut      ( DescStatus    ) ,
       .WE           ( WEBRAM        ) ,
       .FULL         ( FULLCmplter   )
       );
    
   // $$$$$$$$$$$$$$$$$$TxnID producer$$$$$$$$$$$$$$$$$$
    always_ff@(posedge Clk)begin
      if(RST) begin
        NextReadTxnID  <= 0     ;
        FreeReadTxnID  <= 'd128 ;
        NextWriteTxnID <= 'd128 ;
        FreeWriteTxnID <= 'd128 ;
      end
      else begin
        if(ReqChan.TXREQFLITV & ReqChan.TXREQFLIT.Opcode == `ReadOnce)begin // if a Read Request is happening
          if(!RXDATFLITV)
            FreeReadTxnID <= FreeReadTxnID - 1; // decrease number of available TxnID if there is not a DataRsp
          if(NextReadTxnID == 127) // update TxnID that will be used for the next Read
            NextReadTxnID <= 0 ;
          else 
            NextReadTxnID <= NextReadTxnID + 1 ;
        end
        else begin
          if(RXDATFLITV)  // if a Read Request is not happening increase number of available TxnID if there is a DataRsp
            FreeReadTxnID <= FreeReadTxnID + 1;
        end
        
        if(ReqChan.TXREQFLITV & ReqChan.TXREQFLIT.Opcode == `WriteUniquePtl)begin // if a Wriet Request is happening
          if(!(RspInbChan.RXRSPFLITV & (RspInbChan.RXRSPFLIT.Opcode == `DBIDResp | RspInbChan.RXRSPFLIT.Opcode == `CompDBIDResp))) // decrease number of available TxnID if there is not a DBIDRsp
            FreeWriteTxnID <= FreeWriteTxnID - 1;
          if(NextWriteTxnID == 255) // update TxnID that will be used for the next Write
            NextWriteTxnID <= 'd128 ;
          else 
            NextWriteTxnID <= NextWriteTxnID + 1 ;
        end
        else begin
          if(RspInbChan.RXRSPFLITV & (RspInbChan.RXRSPFLIT.Opcode == `DBIDResp | RspInbChan.RXRSPFLIT.Opcode == `CompDBIDResp)) // if a Write Request is not happening increase number of available TxnID if there is a DBIDRsp
            FreeWriteTxnID <= FreeWriteTxnID + 1;
        end
      end
    end   
   //$$$$$$$$$$$$$$$$$$End of TxnID producer$$$$$$$$$$$$$$$$$$
   
   // ################## Read Requester ##################
   
   // Request chanel from Arbiter
   assign ReadReqArbValid = (!SigCommandEmpty & ReqCrd != 0 & FreeReadTxnID != 0 & (SigCommand.Length != ReadReqBytes));
   // Enable valid for CHI-Request transaction 
   assign ReadReqV = (!SigCommandEmpty & ReqCrd != 0 & FreeReadTxnID != 0 & ReadReqArbReady & (SigCommand.Length != ReadReqBytes));
   // Dequeue Read command FIFO 
   assign SigDeqRead = !FULLBS & ((SigCommand.Length - ReadReqBytes <= CHI_DATA_WIDTH & ReadReqArbValid & ReadReqArbReady) | (SigCommand.Length == ReadReqBytes)) & !SigCommandEmpty ;
   // Create Addr field of Request Read flit 
   //----
   assign NextSrcAddr  = SigCommand.SrcAddr + ReadReqBytes ;
   // Next Read Addr is the aligned (SrcAddr + number of byets that have been sent) . To finde Aligned address just ignore the log2(CHI_DATA_WIDTH) least significant bits. The most significant bits are 0 because CHI_MEM_ADDR is larger than Requested SrcAddr Width
   assign SigReadAddr  = {{MEM_ADDR_WIDTH-BRAM_COL_WIDTH{1'b0}},{NextSrcAddr[BRAM_COL_WIDTH - 1 : ADDR_WIDTH_OF_DATA ],{ADDR_WIDTH_OF_DATA {1'b0}}}}; // Aligned Addrs
   //----
   // Create Addr field of Request Read flit 
   assign ReadReqFlit  = '{default       : 0             ,                       
                           QoS           : QoS           ,
                           TgtID         : TgtID         ,
                           SrcID         : SrcID         ,
                           TxnID         : NextReadTxnID ,
                           ReturnNID     : 0             ,
                           StashNIDValid : 0             ,
                           ReturnTxnID   : 0             ,
                           Opcode        : `ReadOnce     ,
                           Size          : 3'b110        , // 64 bytes
                           Addr          : SigReadAddr   ,
                           NS            : 0             , // Non-Secure bit disable
                           LikelyShared  : 0             ,
                           AllowRetry    : 0             ,
                           Order         : 0             ,
                           PCrdType      : 0             ,
                           MemAttr       : 4'b0101       , // EWA : 1 , Device : 0 , Cachable : 1 , Allocate : 0 
                           SnpAttr       : 1             ,
                           LPID          : 0             ,
                           Excl          : 0             ,
                           ExpCompAck    : 0             ,
                           TraceTag      : 0               } ;
   // Manage Registers 
   always_ff@(posedge Clk) begin 
     if(RST)begin
       ReadReqBytes  <= 0 ;
       GaveBSCommand <= 0 ;
     end
     else begin
       // Manage Reg that counts Bytes Requested from first element of FIFO
       if(SigDeqCommand) begin                          // When last Read and Write Req for this command reset value of reg
         ReadReqBytes  <= 0 ;
         GaveBSCommand <= 0 ;                           // A new command should be given to BS
       end
       else if(ReadReqArbValid & ReadReqArbReady)begin  // When new Read Req increase value of reg
         // if next Aligned read Addr - SrcAddr is smaller than Length then Requested Bytes are the difference else are Length  
         if({NextSrcAddr[BRAM_COL_WIDTH - 1 : ADDR_WIDTH_OF_DATA],{ADDR_WIDTH_OF_DATA {1'b0}}} + CHI_DATA_WIDTH - SigCommand.SrcAddr < SigCommand.Length)
           // ReadReqBytes = next read Aligned Addr - SrcAddr
           ReadReqBytes <= {NextSrcAddr[BRAM_COL_WIDTH - 1 : ADDR_WIDTH_OF_DATA],{ADDR_WIDTH_OF_DATA {1'b0}}} + CHI_DATA_WIDTH - SigCommand.SrcAddr ;
         else 
           // ReadReqBytes = Length
           ReadReqBytes <= SigCommand.Length ;
           
         if(EnqueueBS & !FULLBS)
           GaveBSCommand <= 1 ; // a command to BS have been given
       end
     end                   
   end 
   
   assign CommandBS = SigCommand ;
   assign EnqueueBS = ReadReqArbValid & ReadReqArbReady & ReadReqV & !GaveBSCommand ;
   // ################## End Read Requester ##################
   
   // ****************** Write Requester ******************
   // Request chanel from Arbiter
   assign WriteReqArbValid = (!SigCommandEmpty & ReqCrd != 0 & FreeWriteTxnID != 0 & (SigCommand.Length != WriteReqBytes));
   // Enable valid for CHI-Request transaction 
   assign WriteReqV = (!SigCommandEmpty & ReqCrd != 0 & FreeWriteTxnID != 0 & WriteReqArbReady & (SigCommand.Length != WriteReqBytes)) ;
   // Dequeue Write command FIFO 
   assign SigDeqWrite = !FULLBS & ((SigCommand.Length - WriteReqBytes <= CHI_DATA_WIDTH & WriteReqArbValid & WriteReqArbReady) | (SigCommand.Length == WriteReqBytes)) & !SigCommandEmpty ; ;
   // Create Addr field of Request Read flit 
   //----
   assign NextDstAddr  = SigCommand.DstAddr + WriteReqBytes ;
   // Next Write Addr is the aligned (DstAddr + number of byets that have been sent) . To finde Aligned address just ignore the log2(CHI_DATA_WIDTH) least significant bits. The most significant bits are 0 because CHI_MEM_ADDR is larger than Requested DstAddr Width
   assign SigWriteAddr  = {{MEM_ADDR_WIDTH - BRAM_COL_WIDTH{1'b0}},{NextDstAddr[BRAM_COL_WIDTH - 1 : ADDR_WIDTH_OF_DATA ],{ADDR_WIDTH_OF_DATA {1'b0}}}}; // Aligned Addrs
   // Create Addr field of Request Read flit 
   //----
   assign WriteReqFlit  = ( '{ default       : 0               ,                       
                               QoS           : QoS             ,
                               TgtID         : TgtID           ,
                               SrcID         : SrcID           ,
                               TxnID         : NextWriteTxnID  ,
                               ReturnNID     : 0               ,
                               StashNIDValid : 0               ,
                               ReturnTxnID   : 0               ,
                               Opcode        : `WriteUniquePtl ,
                               Size          : 3'b110          , // 64 bytes
                               Addr          : SigWriteAddr    ,
                               NS            : 0               , // Non-Secure bit disable
                               LikelyShared  : 0               ,
                               AllowRetry    : 0               ,
                               Order         : 0               ,
                               PCrdType      : 0               ,
                               MemAttr       : 4'b0101         , // EWA : 1 , Device : 0 , Cachable : 1 , Allocate : 0 
                               SnpAttr       : 1               ,
                               LPID          : 0               ,
                               Excl          : 0               ,
                               ExpCompAck    : 0               ,
                               TraceTag      : 0                }) ;
   
   // Manage Registers 
   always_ff@(posedge Clk) begin 
     if(RST)begin
       WriteReqBytes <= 0 ;
     end
     else begin
       // Manage Reg that counts Bytes Requested from first element of FIFO
       if(SigDeqCommand)        // When last Write Req reset value of reg
         WriteReqBytes <= 0 ;
       else if(WriteReqArbValid & WriteReqArbReady)begin    // When new non-last Write Req increase value of reg
         // if next Aligned write Addr - DstAddr is smaller than Length then Write Requested Bytes are the difference else are Length  
         if({NextSrcAddr[BRAM_COL_WIDTH - 1 : ADDR_WIDTH_OF_DATA],{ADDR_WIDTH_OF_DATA {1'b0}}} + CHI_DATA_WIDTH - SigCommand.SrcAddr < SigCommand.Length)
           // WriteReqBytes = next Aligned write Addr - DstAddr
           WriteReqBytes <= {NextDstAddr[BRAM_COL_WIDTH - 1 : ADDR_WIDTH_OF_DATA],{ADDR_WIDTH_OF_DATA {1'b0}}} + CHI_DATA_WIDTH - SigCommand.DstAddr ;
         else 
           // WriteReqBytes = Length
           WriteReqBytes <= SigCommand.Length ;       end
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
       else if(ReadReqArbValid & !WriteReqArbValid)
         AccessReg <= 1 ;
       else if(!ReadReqArbValid & WriteReqArbValid)
         AccessReg <= 0 ;
     end  
   end
   
   // Enable Ready signals by round robin if needed 
   assign  ReadReqArbReady  = (ReadReqArbValid & !WriteReqArbValid) ? 1 : ((ReadReqArbValid & WriteReqArbValid) ? !AccessReg : 0) ;
   assign  WriteReqArbReady = (!ReadReqArbValid & WriteReqArbValid) ? 1 : ((ReadReqArbValid & WriteReqArbValid) ?  AccessReg : 0) ;
   // Request chanel signals
   assign  ReqChan.TXREQFLIT    = WriteReqArbReady ? WriteReqFlit : (ReadReqArbReady ? ReadReqFlit : 0) ;
   assign  ReqChan.TXREQFLITV   = WriteReqArbReady ? WriteReqV    : (ReadReqArbReady ? ReadReqV    : 0) ;
   // ################## End Arbiter ##################      
       
      
     
   // Manage Credits
   always_ff@(posedge Clk) begin
     if(RST)begin
       ReqCrd          <= 0 ;
       RspCrdInbound   <= 0 ;
       RspCrdOutbound  <= 0 ;
       DataCrdOutbound <= 0 ;
       GivenRspCrd     <= 0 ;
     end
     else begin
       // Request chanel Crd Counter
       if(ReqChan.TXREQLCRDV & !(ReqCrd != 0 & ReqChan.TXREQFLITV) & ReqCrd < `MaxCrds)
         ReqCrd <= ReqCrd + 1 ;
       else if(!ReqChan.TXREQLCRDV & (ReqCrd != 0 & ReqChan.TXREQFLITV) & ReqCrd > 0)
         ReqCrd <= ReqCrd - 1 ;
       // Outbound Response chanle Crd Counter
       if(RspOutbChan.TXRSPLCRDV & !(RspCrdOutbound != 0 & RspOutbChan.TXRSPFLITV) & RspCrdOutbound < `MaxCrds)
         RspCrdOutbound <= RspCrdOutbound + 1 ;
       else if(!RspOutbChan.TXRSPLCRDV & (RspCrdOutbound != 0 & RspOutbChan.TXRSPFLITV) & RspCrdOutbound > 0)
         RspCrdOutbound <= RspCrdOutbound - 1 ;
       // Outbound Data chanle Crd Counter
       if(DatOutbChan.TXDATLCRDV & !(DataCrdOutbound != 0 & DatOutbChan.TXDATFLITV) & DataCrdOutbound <`MaxCrds)
         DataCrdOutbound <= DataCrdOutbound + 1 ;
       else if(!DatOutbChan.TXDATLCRDV & (DataCrdOutbound != 0 & DatOutbChan.TXDATFLITV) & DataCrdOutbound > 0 )
         DataCrdOutbound <= DataCrdOutbound - 1 ;
       // Inbound Response chanle Crd Counter
       if(RspInbChan.RXRSPLCRDV & !(RspCrdInbound != 0 & RspInbChan.RXRSPFLITV))
         RspCrdInbound <= RspCrdInbound + 1 ;
       else if(!RspInbChan.RXRSPLCRDV & (RspCrdInbound != 0 & RspInbChan.RXRSPFLITV))
         RspCrdInbound <= RspCrdInbound - 1 ;
       // Count the number of given Rsp Crds in order not to give more than DBID FIFO length
       if(RspInbChan.RXRSPLCRDV & !SigDeqDBID & (!RspInbChan.RXRSPFLITV | RspCrdInbound == 0 | RspInbChan.RXRSPFLIT.Opcode == `DBIDResp | RspInbChan.RXRSPFLIT.Opcode == `CompDBIDResp))
         GivenRspCrd <= GivenRspCrd + 1 ;
       else if(!RspInbChan.RXRSPLCRDV & SigDeqDBID & (!RspInbChan.RXRSPFLITV | RspCrdInbound == 0 | RspInbChan.RXRSPFLIT.Opcode == `DBIDResp | RspInbChan.RXRSPFLIT.Opcode == `CompDBIDResp))
         GivenRspCrd <= GivenRspCrd - 1 ;
       else if(!RspInbChan.RXRSPLCRDV & !SigDeqDBID & (RspInbChan.RXRSPFLITV & RspCrdInbound != 0 & RspInbChan.RXRSPFLIT.Opcode != `DBIDResp & RspInbChan.RXRSPFLIT.Opcode != `CompDBIDResp))
         GivenRspCrd <= GivenRspCrd - 1 ;
       else if(!RspInbChan.RXRSPLCRDV & SigDeqDBID & (RspInbChan.RXRSPFLITV & RspCrdInbound != 0 & RspInbChan.RXRSPFLIT.Opcode != `DBIDResp & RspInbChan.RXRSPFLIT.Opcode != `CompDBIDResp))
         GivenRspCrd <= GivenRspCrd - 2 ;
         else if(RspInbChan.RXRSPLCRDV & SigDeqDBID & (RspInbChan.RXRSPFLITV & RspCrdInbound != 0 & RspInbChan.RXRSPFLIT.Opcode != `DBIDResp & RspInbChan.RXRSPFLIT.Opcode != `CompDBIDResp))
         GivenRspCrd <= GivenRspCrd - 1 ;   
     end
   end
   ///////////////////
   //     |  No Rst //
   //     |  In comb//
   //     V         //
   ///////////////////
   // Give an extra Crd in outbound Rsp Chanel
   assign RspInbChan.RXRSPLCRDV = (!RST & ((GivenRspCrd  < DATA_FIFO_LENGTH) & (RspCrdInbound  < `MaxCrds))) ;
   
    // ****************** Data Sender ******************
   // Enable valid of CHI-DATA chanel 
   assign DatOutbChan.TXDATFLITV = (!EmptyBS & !SigDBIDEmpty & !FULLCmplter & DataCrdOutbound != 0) ? 1 : 0 ;
   // Dequeue FIFOs for DATA transfer 
   assign SigDeqDBID = DatOutbChan.TXDATFLITV ;
   // Dequeue BarrelShifter first sifted Data 
   assign DequeueBS  = SigDeqDBID ;
   // Create Request Write flit 
   assign DatOutbChan.TXDATFLIT    = '{default    : 0                               ,                       
                                       QoS        : QoS                             ,
                                       TgtID      : TgtID                           ,
                                       SrcID      : SrcID                           ,
                                       TxnID      : SigDBIDPack.DBID                ,
                                       HomeNID    : 0                               ,
                                       Opcode     : `NonCopyBackWrData              ,
                                       RespErr    : SigDBIDPack.RespErr | DataErr   ,
                                       Resp       : 0                               , // Resp should be 0 when NonCopyBackWrData Rsp
                                       DataSource : 0                               , 
                                       DBID       : 0                               ,
                                       CCID       : 0                               , 
                                       DataID     : 0                               ,
                                       TraceTag   : 0                               ,
                                       BE         : BE                              ,
                                       Data       : ShiftedData                     ,  
                                       DataCheck  : 0                               ,
                                       Poison     : 0                                 } ;
    // ****************** End Data Sender ******************
   assign RspOutbChan.TXRSPFLITV = 0 ; //usless
   assign RspOutbChan.TXRSPFLIT  = 0 ;
 endmodule
