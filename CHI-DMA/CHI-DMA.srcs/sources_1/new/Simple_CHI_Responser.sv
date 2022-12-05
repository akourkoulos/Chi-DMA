`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 19.11.2022 13:06:59
// Design Name: 
// Module Name: CHI_Responser
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
`define DBIDRespWidth     8

`define MaxCrds           15
`define CrdRegWidth       4  // log2(MaxCrds)


// Req opcode
`define ReadOnce          6'h03 
`define WriteUniquePtl    6'h18
//Data opcoed
`define CompData          4'h4
// Rsp opcode
`define DBIDResp          4'h3
`define CompDBIDResp      4'h5
//Data opcode
`define NonCopyBackWrData 4'h3
`define NCBWrDataCompAck  4'hc
`define CompData          4'h4

`define StatusError       2

module Simple_CHI_Responser#(
//-------------------------------------------------------------------------- 
  parameter TIME_DELAY         = 11             ,
  parameter TIME_DELAY_WIDTH   = 4              ,  
  parameter FIFO_Length        = TIME_DELAY + 2 ,
  parameter BRAM_COL_WIDTH     = 32             ,        
  parameter CHI_DATA_WIDTH     = 64                        
//--------------------------------------------------------------------------
)(
    input            Clk               ,
    input            RST               ,
    ReqChannel       ReqChan           , // Request ChannelS
    RspOutbChannel   RspOutbChan       , // Response outbound Chanel
    DatOutbChannel   DatOutbChan       , // Data outbound Chanel
    RspInbChannel    RspInbChan        , // Response inbound Chanel
    DatInbChannel    DatInbChan          // Data inbound Chanel
    );
    
    localparam period = 20;
    
    //Crds signals
    reg     [`CrdRegWidth      - 1 : 0] CountDataCrdsInb  = 0  ; 
    reg     [`CrdRegWidth      - 1 : 0] CountRspCrdsInb   = 0  ;
    reg     [`CrdRegWidth      - 1 : 0] CountReqCrdsOutb  = 0  ; 
    reg     [`CrdRegWidth      - 1 : 0] CountDataCrdsOutb = 0  ;
    reg     [`CrdRegWidth      - 1 : 0] CountRspCrdsOutb  = 0  ;
    //FIFO signals
    reg                                 SigDeqReq              ;
    reg                                 SigReqEmpty            ;
    ReqFlit                             SigTXREQFLIT           ;
    
    reg     [`DBIDRespWidth    - 1 : 0] DBID_Count             ; // NextDBID field for DBID RSP
    
    reg     [TIME_DELAY        - 1 : 0] Delayer                ; // delay Req for TIME_DEALY
    reg     [TIME_DELAY_WIDTH  - 1 : 0] SigResp                ;
    
   // Req FIFO (keeps all the uncomplete Requests)
   FIFO #(     
       .FIFO_WIDTH  ( REQ_FLIT_WIDTH ) ,       
       .FIFO_LENGTH ( FIFO_Length    )     
       )     
       myFIFOReq (     
       .RST      ( RST                ) ,      
       .Clk      ( Clk                ) ,      
       .Inp      ( ReqChan.TXREQFLIT  ) , 
       .Enqueue  ( ReqChan.TXREQFLITV ) , 
       .Dequeue  ( SigDeqReq          ) , 
       .Outp     ( SigTXREQFLIT       ) , 
       .FULL     (                    ) , 
       .Empty    ( SigReqEmpty        ) 
       );
       
   always_ff@(posedge Clk)begin
     if(RST)
       Delayer <= 0 ;
     else
     begin
       if(!(SigResp & (CountDataCrdsInb == 0 | CountRspCrdsInb == 0)))begin
         for(int i = 0 ; i < TIME_DELAY - 1 ; i++) begin
           Delayer[i] <= Delayer[i+1];
         end
         Delayer[TIME_DELAY - 1] <= ReqChan.TXREQFLITV & CountReqCrdsOutb != 0 ;
       end
     end
   end
   
   assign SigResp = Delayer[0];
 
   //Count Converter's inbound Crds
    always_ff@(posedge Clk) begin
      if(RST)begin
        CountDataCrdsInb = 0 ;
        CountRspCrdsInb  = 0 ;
      end
      else begin
        if(DatInbChan.RXDATLCRDV & !DatInbChan.RXDATFLITV)
          CountDataCrdsInb <= CountDataCrdsInb + 1;
        else if(!DatInbChan.RXDATLCRDV & DatInbChan.RXDATFLITV)
          CountDataCrdsInb <= CountDataCrdsInb - 1;
        if(RspInbChan.RXRSPLCRDV & !RspInbChan.RXRSPFLITV) 
          CountRspCrdsInb <= CountRspCrdsInb + 1 ; 
        else if(!RspInbChan.RXRSPLCRDV & RspInbChan.RXRSPFLITV) 
          CountRspCrdsInb <= CountRspCrdsInb - 1; 
      end
    end
    
    
    //give Converter's Outbound Crds
    always_comb begin
      if(RST)begin
        ReqChan.TXREQLCRDV = 0 ;
      end
      else begin
        if(CountReqCrdsOutb < `MaxCrds)
          ReqChan.TXREQLCRDV = 1 ;
        else
          ReqChan.TXREQLCRDV = 0 ;
      end
    end
    always_comb begin
      if(RST) begin
        RspOutbChan.TXRSPLCRDV = 0 ;
      end
      else begin
        if(CountRspCrdsOutb < `MaxCrds)
          RspOutbChan.TXRSPLCRDV = 1 ;
        else 
          RspOutbChan.TXRSPLCRDV = 0 ;
      end
    end
    always_comb begin
      if(RST) begin
        DatOutbChan.TXDATLCRDV = 0;
      end
      else begin
        if(CountDataCrdsOutb < `MaxCrds)
          DatOutbChan.TXDATLCRDV = 1 ;
        else
          DatOutbChan.TXDATLCRDV = 0 ;
      end
    end
    
    //Count Converter's Outbound Crds
    always_ff@(posedge Clk) begin
      if(RST)begin
        CountDataCrdsOutb = 0 ;
        CountRspCrdsOutb  = 0 ;
        CountReqCrdsOutb  = 0 ;
      end
      else begin
        if(DatOutbChan.TXDATLCRDV & !DatOutbChan.TXDATFLITV)
          CountDataCrdsOutb <= CountDataCrdsOutb + 1;
        else if(!DatOutbChan.TXDATLCRDV & DatOutbChan.TXDATFLITV)
          CountDataCrdsOutb <= CountDataCrdsOutb - 1;
        if(RspOutbChan.TXRSPLCRDV & !RspOutbChan.TXRSPFLITV) 
          CountRspCrdsOutb <= CountRspCrdsOutb + 1; 
        else if(!RspOutbChan.TXRSPLCRDV & RspOutbChan.TXRSPFLITV) 
          CountRspCrdsOutb <= CountRspCrdsOutb - 1; 
        if(ReqChan.TXREQLCRDV & !ReqChan.TXREQFLITV) 
          CountReqCrdsOutb <= CountReqCrdsOutb + 1; 
        else if(!ReqChan.TXREQLCRDV & ReqChan.TXREQFLITV) 
          CountReqCrdsOutb <= CountReqCrdsOutb - 1 ; 
      end
    end
    
    
    always_comb begin     
      if(!SigReqEmpty & SigTXREQFLIT.Opcode == `ReadOnce & CountDataCrdsInb != 0 & SigResp)begin
        // Data Response
        DatInbChan.RXDATFLITV = 1;
        DatInbChan.RXDATFLIT = '{default     : 0                                            ,                       
                                  QoS        : 0                                            ,
                                  TgtID      : 1                                            ,
                                  SrcID      : 2                                            ,
                                  TxnID      : SigTXREQFLIT.TxnID                           ,
                                  HomeNID    : 0                                            ,
                                  Opcode     : `CompData                                    ,
                                  RespErr    : `StatusError*(($urandom_range(0,100)) == 1)  , // samll probability to be an error
                                  Resp       : 0                                            , // Resp should be 0 when NonCopyBackWrData Rsp
                                  DataSource : 0                                            , 
                                  DBID       : 0                                            ,
                                  CCID       : 0                                            , 
                                  DataID     : 0                                            ,
                                  TraceTag   : 0                                            ,
                                  BE         : {64{1'b1}}                                   ,
                                  Data       : 2**$urandom_range(0,512) - $urandom()        ,  //512 width of data
                                  DataCheck  : 0                                            ,
                                  Poison     : 0                                        
                                  }; 
        SigDeqReq    = 1 ;
      end
      else begin
        DatInbChan.RXDATFLITPEND     = 0      ;
        DatInbChan.RXDATFLITV        = 0      ;
        DatInbChan.RXDATFLIT         = 0      ;
        SigDeqReq                    = 0      ;
      end

      //DBID Respose    
      if(!SigReqEmpty & SigTXREQFLIT.Opcode == `WriteUniquePtl & CountRspCrdsInb != 0 & SigResp)begin
        RspInbChan.RXRSPFLITV = 1; 
        RspInbChan.RXRSPFLIT = '{default   : 0                                        ,                       
                                  QoS      : 0                                        ,
                                  TgtID    : 1                                        ,
                                  SrcID    : 2                                        ,
                                  TxnID    : SigTXREQFLIT.TxnID                       ,
                                  Opcode   : `CompDBIDResp                            ,
                                  RespErr  : 0                                        ,
                                  Resp     : 0                                        ,
                                  FwdState : 0                                        , // Resp should be 0 when NonCopyBackWrData Rsp
                                  DBID     : DBID_Count                               , // new DBID for every Rsp
                                  PCrdType : 0                                        ,
                                  TraceTag : 0                                       
                                  };     
      end
      else begin
        RspInbChan.RXRSPFLITPEND     = 0      ;
        RspInbChan.RXRSPFLITV        = 0      ;
        RspInbChan.RXRSPFLIT         = 0      ;      
      end
      
      //sig to dequeue FIFO
      if((!SigReqEmpty & SigTXREQFLIT.Opcode == `ReadOnce & CountDataCrdsInb != 0 & SigResp)|(!SigReqEmpty & SigTXREQFLIT.Opcode == `WriteUniquePtl & CountRspCrdsInb != 0 & SigResp))
        SigDeqReq = 1 ;
      else
        SigDeqReq = 0 ;    
    end
    
    // Create new DBID
    always_ff@(posedge Clk)begin
      if(RST)
        DBID_Count <= 0 ;
      else 
        if(RspInbChan.RXRSPFLITV & SigTXREQFLIT.Opcode == `WriteUniquePtl & CountRspCrdsInb != 0)
          DBID_Count <= DBID_Count + 1 ; //increase DBID pointer
    end
endmodule
