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
  parameter BRAM_ADDR_WIDTH   = 10                                     ,
  parameter BRAM_NUM_COL      = 8                                      , //As the Data_packet fields
  parameter BRAM_COL_WIDTH    = 32                                     ,
  parameter MEM_ADDR_WIDTH    = 44                                     , 
  parameter CMD_FIFO_LENGTH   = 32                                     ,
  parameter DATA_FIFO_LENGTH  = 32                                     ,
  parameter SIZE_WIDTH        = BRAM_ADDR_WIDTH + 7 + 1                , //DescAddr*BRAM_ADDR_WIDTH + Size*(log2(CHI_DATA_WIDTH) + 1) + LastDescTrans*1 
  parameter COUNTER_WIDTH     = 6                                      , //log2(DATA_FIFO_LENGTH) + 1
  parameter CHI_DATA_WIDTH    = 64                                     , //Bytes
  parameter QoS               = 8                                      , //??
  parameter TgtID             = 2                                      , //??
  parameter SrcID             = 1                                        //??
//--------------------------------------------------------------------------
)(
    input                                        Clk               ,
    input                                        RST               ,
    input Data_packet                            DataBRAM          , // From BRAM
    input                                        IssueValid        ,
    input                                        ReadyBRAM         , // From Arbiter_BRAM
    input CHI_Command                            Command           , // CHI-Command (SrcAddr,DstAddr,Length,DescAddr,LastDescTrans)
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
    
   // Command FIFO signals
   wire                                             SigDeqCommand     ; // Dequeue
   CHI_Command                                      SigCommand        ; // DATA
   wire                                             SigCommandEmpty   ; // Empty
   //Size FIFO signals
   CHI_FIFO_Size_Packet                             SigSizeFIFOIn     ; // DATA In
   CHI_FIFO_Size_Packet                             SigSizePack       ; // DATA Out
   wire                                             SigSizeFULL       ;
   wire                                             SigSizeEmpty      ;
   //Data FIFO signals
   wire                                             SigDeqData        ; // Dequeue
   CHI_FIFO_Data_Packet                             SigDataFIFOIn     ; // DATA In
   CHI_FIFO_Data_Packet                             SigDataPack       ; // DATA Out
   wire                                             SigDataEmpty      ; // Empty
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
   reg                  [`CrdRegWidth      - 1 : 0] ReqCrd            ;
   reg                  [`CrdRegWidth      - 1 : 0] RspCrdInbound     ;
   reg                  [`CrdRegWidth      - 1 : 0] DataCrdInbound    ; // CHI allows max 15 Crds per chanel
   reg                  [`CrdRegWidth      - 1 : 0] RspCrdOutbound    ;
   reg                  [`CrdRegWidth      - 1 : 0] DataCrdOutbound   ;
   reg                  [COUNTER_WIDTH     - 1 : 0] GivenRspCrd       ; // Used in order not to give more Crds than  DATA_FIFO_LENGTH
   reg                  [COUNTER_WIDTH     - 1 : 0] GivenDataCrd      ; // Used in order not to give more Crds than  DATA_FIFO_LENGTH
   //Read Requester signals 
   wire                                             ReadReqArbValid   ; 
   wire                                             ReadReqArbReady   ;
   wire                                             ReadReqV          ;
   ReqFlit                                          ReadReqFlit       ;
   //Write Requester signals
   wire                                             WriteReqArbValid  ; 
   wire                                             WriteReqArbReady  ;
   wire                                             WriteReqV         ;
   ReqFlit                                          WriteReqFlit      ;
   //Updater signal
   wire                                             FULLUpdater       ;
   //Arbiter signal
   reg                                              AccessReg         ; //register to for arbitrate the order of access
   
   //CommandFIFO FIFO (SrcAddr,DstAddr,BTS,SB,DescAddr,LastDescTrans)
   assign SigDeqCommand = SigDeqRead & SigDeqWrite ;
   FIFO #(     
       3*BRAM_COL_WIDTH + BRAM_ADDR_WIDTH + 1  ,  //FIFO_WIDTH   
       CMD_FIFO_LENGTH                            //FIFO_LENGTH      
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
       
   // Size FIFO (Size(needed to calculate BE for DataFlit) , DescAddr , LastDescTrans(The last 2 fields are needed for Completer to update the right DescStatus in BRAM))
   assign SigSizeFIFOIn = '{default       : 0                                      ,
                            Size          : SigDataSize                            ,
                            DescAddr      : SigCommand.DescAddr                    ,
                            LastDescTrans : SigCommand.LastDescTrans & SigDeqWrite  };
   FIFO #(     
       SIZE_WIDTH        ,  //FIFO_WIDTH       
       DATA_FIFO_LENGTH     //FIFO_LENGTH      
       )     
       SizeFIFO (     
       .RST     ( RST                                               ) ,      
       .Clk     ( Clk                                               ) ,      
       .Inp     ( SigSizeFIFOIn                                     ) , 
       .Enqueue ( WriteReqArbValid & WriteReqArbReady & TXREQFLITV  ) , 
       .Dequeue ( SigDeqData                                        ) , 
       .Outp    ( SigSizePack                                       ) , 
       .FULL    ( SigSizeFULL                                       ) , 
       .Empty   ( SigSizeEmpty                                      ) 
       );
       
   // Read Data FIFO
   assign SigDataFIFOIn = '{default : 0                  ,
                            Data    : RXDATFLIT.Data     ,
                            RespErr  : RXDATFLIT.RespErr    };
   FIFO #(     
       CHI_DATA_WIDTH*8 + `RspErrWidth ,  //FIFO_WIDTH       
       DATA_FIFO_LENGTH                   //FIFO_LENGTH      
       )     
       FIFOData  (     
       .RST      ( RST                            ) ,      
       .Clk      ( Clk                            ) ,      
       .Inp      ( SigDataFIFOIn                  ) , 
       .Enqueue  ( RXDATFLITV & DataCrdInbound!=0 ) , 
       .Dequeue  ( SigDeqData                     ) , 
       .Outp     ( SigDataPack                    ) , 
       .FULL     (                                ) , 
       .Empty    ( SigDataEmpty                   ) 
       );
       
   // DBID FIFO
   assign SigDBIDFIFOIn = '{default : 0                  ,
                            DBID    : RXRSPFLIT.DBID     ,
                            RespErr  : RXRSPFLIT.RespErr   };
                            
   assign SigEnqDBID  = (RXRSPFLITV == 1 & (RXRSPFLIT.Opcode == `DBIDResp | RXRSPFLIT.Opcode == `CompDBIDResp) & RspCrdInbound != 0 );
   FIFO #(     
       `DBIDRespWidth + `RspErrWidth  ,  //FIFO_WIDTH       
       DATA_FIFO_LENGTH                  //FIFO_LENGTH      
       )     
       FIFODBID  (     
       .RST      ( RST            ) ,      
       .Clk      ( Clk            ) ,      
       .Inp      ( SigDBIDFIFOIn  ) , 
       .Enqueue  ( SigEnqDBID     ) , 
       .Dequeue  ( SigDeqData     ) , 
       .Outp     ( SigDBIDPack    ) , 
       .FULL     (                ) , 
       .Empty    ( SigDBIDEmpty   ) 
       );     
       
   // Completer (Status Updater)
   Completer_Packet CompDataPack ;
   assign CompDataPack = '{ default         : 0                         ,
                            LastDescTrans   : SigSizePack.LastDescTrans ,
                            DescAddr        : SigSizePack.DescAddr      ,
                            DBIDRespErr     : SigDBIDPack.RespErr       ,
                            DataRespErr     : SigDataPack.RespErr         };
   Completer #(     
       BRAM_ADDR_WIDTH                       ,            
       BRAM_NUM_COL                          ,        
       DATA_FIFO_LENGTH                      , 
       BRAM_ADDR_WIDTH + `RspErrWidth*2 + 1    // FIFO_WIDTH is DescAdd + RespErrorWidth + LastDescTrans     
       )
       myCompleter   (     
       .RST          ( RST           ) ,      
       .Clk          ( Clk           ) ,      
       .CompDataPack ( CompDataPack  ) , 
       .ValidUpdate  ( SigDeqData    ) ,
       .DescData     ( DataBRAM      ) , 
       .ReadyBRAM    ( ReadyBRAM     ) ,
       .ValidBRAM    ( ValidBRAM     ) ,
       .AddrOut      ( AddrBRAM      ) ,
       .DataOut      ( DescStatus    ) ,
       .WE           ( WEBRAM        ) ,
       .FULL         ( FULLUpdater   )
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
        if(TXREQFLITV & TXREQFLIT.Opcode == `ReadOnce)begin // if a Read Request is happening
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
        
        if(TXREQFLITV & TXREQFLIT.Opcode == `WriteUniquePtl)begin // if a Wriet Request is happening
          if(!(RXRSPFLITV & (RXRSPFLIT.Opcode == `DBIDResp | RXRSPFLIT.Opcode == `CompDBIDResp))) // decrease number of available TxnID if there is not a DBIDRsp
            FreeWriteTxnID <= FreeWriteTxnID - 1;
          if(NextReadTxnID == 255) // update TxnID that will be used for the next Write
            NextWriteTxnID <= NextWriteTxnID + 1 ;
          else 
            NextWriteTxnID <= NextWriteTxnID + 1 ;
        end
        else begin
          if(RXRSPFLITV & (RXRSPFLIT.Opcode == `DBIDResp | RXRSPFLIT.Opcode == `CompDBIDResp)) // if a Write Request is not happening increase number of available TxnID if there is a DBIDRsp
            FreeWriteTxnID <= FreeWriteTxnID + 1;
        end
      end
    end   
   //$$$$$$$$$$$$$$$$$$End of TxnID producer$$$$$$$$$$$$$$$$$$
   
   // ################## Read Requester ##################
   
   // Request chanel from Arbiter
   assign ReadReqArbValid = (!SigCommandEmpty & ReqCrd != 0 & FreeReadTxnID != 0 & (SigCommand.Length != ReadReqBytes)) ? 1 : 0 ;
   // Enable valid for CHI-Request transaction 
   assign ReadReqV = (!SigCommandEmpty & ReqCrd != 0 & FreeReadTxnID != 0 & ReadReqArbReady & (SigCommand.Length != ReadReqBytes)) ? 1 : 0 ;
   // Dequeue Read command FIFO 
   assign SigDeqRead = ((SigCommand.Length - ReadReqBytes <= CHI_DATA_WIDTH & ReadReqArbValid & ReadReqArbReady) | (SigCommand.Length == ReadReqBytes)) ? 1 : 0 ;
   // Create Request Read flit 
   assign ReadReqFlit  = '{default       : 0                                                                           ,                       
                           QoS           : QoS                                                                         ,
                           TgtID         : TgtID                                                                       ,
                           SrcID         : SrcID                                                                       ,
                           TxnID         : NextReadTxnID                                                               ,
                           ReturnNID     : 0                                                                           ,
                           StashNIDValid : 0                                                                           ,
                           ReturnTxnID   : 0                                                                           ,
                           Opcode        : `ReadOnce                                                                   ,
                           Size          : 3'b110                                                                      , // 64 bytes
                           Addr          : {{MEM_ADDR_WIDTH-BRAM_COL_WIDTH{1'b0}},(SigCommand.SrcAddr + ReadReqBytes)} ,
                           NS            : 0                                                                           , // Non-Secure bit disable
                           LikelyShared  : 0                                                                           ,
                           AllowRetry    : 0                                                                           ,
                           Order         : 0                                                                           ,
                           PCrdType      : 0                                                                           ,
                           MemAttr       : 4'b0101                                                                     , // EWA : 1 , Device : 0 , Cachable : 1 , Allocate : 0 
                           SnpAttr       : 1                                                                           ,
                           LPID          : 0                                                                           ,
                           Excl          : 0                                                                           ,
                           ExpCompAck    : 0                                                                           ,
                           TraceTag      : 0                                                                             } ;
   // Manage Registers 
   always_ff@(posedge Clk) begin 
     if(RST)begin
       ReadReqBytes <= 0 ;
     end
     else begin
       // Manage Reg that counts Bytes Requested from first element of FIFO
       if(SigDeqCommand)                             // When last Read and Write Req for this command reset value of reg
         ReadReqBytes <= 0 ;
       else if(ReadReqArbValid & ReadReqArbReady)    // When new Read Req increase value of reg
         ReadReqBytes <= ReadReqBytes + ((SigCommand.Length - ReadReqBytes <= CHI_DATA_WIDTH) ? (SigCommand.Length - ReadReqBytes) : CHI_DATA_WIDTH) ;
     end                   
   end 
   // ################## End Read Requester ##################
   
   // ****************** Write Requester ******************
   
   // Request chanel from Arbiter
   assign WriteReqArbValid = (!SigCommandEmpty & ReqCrd != 0 & FreeWriteTxnID != 0 & !SigSizeFULL & (SigCommand.Length != WriteReqBytes)) ? 1 : 0 ;
   // Enable valid for CHI-Request transaction 
   assign WriteReqV = (!SigCommandEmpty & ReqCrd != 0 & FreeWriteTxnID != 0 & !SigSizeFULL & WriteReqArbReady & (SigCommand.Length != WriteReqBytes)) ? 1 : 0 ;
   // Dequeue Write command FIFO 
   assign SigDeqWrite = ((SigCommand.Length - WriteReqBytes <= CHI_DATA_WIDTH & WriteReqArbValid & WriteReqArbReady) | (SigCommand.Length == WriteReqBytes)) ? 1 : 0 ;
   // Size of Data that will be sent
   assign SigDataSize = (SigCommand.Length - WriteReqBytes <= CHI_DATA_WIDTH ) ? (SigCommand.Length - WriteReqBytes) : CHI_DATA_WIDTH ;
   // Create Request Write flit 
   assign WriteReqFlit  = ( '{ default       : 0                                                                            ,                       
                               QoS           : QoS                                                                          ,
                               TgtID         : TgtID                                                                        ,
                               SrcID         : SrcID                                                                        ,
                               TxnID         : NextWriteTxnID                                                               ,
                               ReturnNID     : 0                                                                            ,
                               StashNIDValid : 0                                                                            ,
                               ReturnTxnID   : 0                                                                            ,
                               Opcode        : `WriteUniquePtl                                                              ,
                               Size          : 3'b110                                                                       , // 64 bytes
                               Addr          : {{MEM_ADDR_WIDTH-BRAM_COL_WIDTH{1'b0}},(SigCommand.DstAddr + WriteReqBytes)} ,
                               NS            : 0                                                                            , // Non-Secure bit disable
                               LikelyShared  : 0                                                                            ,
                               AllowRetry    : 0                                                                            ,
                               Order         : 0                                                                            ,
                               PCrdType      : 0                                                                            ,
                               MemAttr       : 4'b0101                                                                      , // EWA : 1 , Device : 0 , Cachable : 1 , Allocate : 0 
                               SnpAttr       : 1                                                                            ,
                               LPID          : 0                                                                            ,
                               Excl          : 0                                                                            ,
                               ExpCompAck    : 0                                                                            ,
                               TraceTag      : 0                                                                             }) ;
   
   // Manage Registers 
   always_ff@(posedge Clk) begin 
     if(RST)begin
       WriteReqBytes <= 0 ;
     end
     else begin
       // Manage Reg that counts Bytes Requested from first element of FIFO
       if(SigDeqCommand)        // When last Write Req reset value of reg
         WriteReqBytes <= 0 ;
       else if(WriteReqArbValid & WriteReqArbReady)    // When new non-last Write Req increase value of reg
         WriteReqBytes <= WriteReqBytes + ((SigCommand.Length - WriteReqBytes <= CHI_DATA_WIDTH) ? (SigCommand.Length - WriteReqBytes) : CHI_DATA_WIDTH);
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
   assign TXDATFLIT    = '{default    : 0                                             ,                       
                           QoS        : QoS                                           ,
                           TgtID      : TgtID                                         ,
                           SrcID      : SrcID                                         ,
                           TxnID      : SigDBIDPack.DBID                              ,
                           HomeNID    : 0                                             ,
                           Opcode     : `NonCopyBackWrData                            ,
                           RespErr    : SigDBIDPack.RespErr | SigDataPack.RespErr       ,
                           Resp       : 0                                             , // Resp should be 0 when NonCopyBackWrData Rsp
                           DataSource : 0                                             , 
                           DBID       : 0                                             ,
                           CCID       : 0                                             , 
                           DataID     : 0                                             ,
                           TraceTag   : 0                                             ,
                           BE         : ~({CHI_DATA_WIDTH{1'b1}} << SigSizePack.Size) ,
                           Data       : SigDataPack.Data                              ,  
                           DataCheck  : 0                                             ,
                           Poison     : 0                                               } ;
    // ****************** End Data Sender ******************
   assign TXRSPFLITV = 0 ; //usless
   assign TXRSPFLIT  = 0 ;
 endmodule
