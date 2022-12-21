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

module CHI_Responser#(
//--------------------------------------------------------------------------
  parameter FIFO_Length         = 120                      ,
  parameter BRAM_COL_WIDTH      = 32                       , 
  parameter MEM_ADDR_WIDTH      = 44                       , 
  parameter CHI_DATA_WIDTH      = 64                       ,
  parameter ADDR_WIDTH_OF_DATA  = $clog2(CHI_DATA_WIDTH)     // log2(CHI_DATA_WIDTH)  
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
    
    reg     [2**MEM_ADDR_WIDTH  + 2 : 0] myDDR                  ;
    reg     [2**MEM_ADDR_WIDTH  + 2 : 0] ShiftedDDR             ;
    //Crds signals
    reg     [`CrdRegWidth       - 1 : 0] CountDataCrdsInb  = 0  ; 
    reg     [`CrdRegWidth       - 1 : 0] CountRspCrdsInb   = 0  ;
    reg     [`CrdRegWidth       - 1 : 0] CountReqCrdsOutb  = 0  ; 
    reg     [`CrdRegWidth       - 1 : 0] CountDataCrdsOutb = 0  ;
    reg     [`CrdRegWidth       - 1 : 0] CountRspCrdsOutb  = 0  ;
    int                                  GivenReqCrds           ;// use in order not to give more crds than fifo length
    //FIFO signals
    reg                                  SigDeqReqR             ;
    reg                                  SigReqEmptyR           ;
    reg                                  SigDeqReqW             ;
    reg                                  SigReqEmptyW           ;
    ReqFlit                              SigTXREQFLITR          ;
    ReqFlit                              SigTXREQFLITW          ;
    reg     [MEM_ADDR_WIDTH     - 1 : 0] SigAddr                ; 
    
    reg     [BRAM_COL_WIDTH     - 1 : 0] SrcAddrReg             ; // reg to see if NextReadReqAddr is contiouse with the last transaction(so DataRsp must come faster)
    reg     [`DBIDRespWidth     - 1 : 0] DBID_Count    = 0      ; // NextDBID field for DBID RSP
    
   // Read Req FIFO (keeps all the uncomplete read Requests)
   FIFO #(     
       .FIFO_WIDTH  ( REQ_FLIT_WIDTH ) ,       
       .FIFO_LENGTH ( FIFO_Length    )     
       )     
       myRFIFOReq(     
       .RST      ( RST                                                        ) ,      
       .Clk      ( Clk                                                        ) ,      
       .Inp      ( ReqChan.TXREQFLIT                                          ) , 
       .Enqueue  ( ReqChan.TXREQFLITV & ReqChan.TXREQFLIT.Opcode == `ReadOnce ) , 
       .Dequeue  ( SigDeqReqR                                                 ) , 
       .Outp     ( SigTXREQFLITR                                              ) , 
       .FULL     (                                                            ) , 
       .Empty    ( SigReqEmptyR                                               ) 
       );
       
    // Write Req FIFO (keeps all the uncomplete read Writeuests)
   FIFO #(     
       .FIFO_WIDTH  ( REQ_FLIT_WIDTH ) ,       
       .FIFO_LENGTH ( FIFO_Length    )         
       )     
       myWFIFOReq(     
       .RST      ( RST                                                              ) ,      
       .Clk      ( Clk                                                              ) ,      
       .Inp      ( ReqChan.TXREQFLIT                                                ) , 
       .Enqueue  ( ReqChan.TXREQFLITV & ReqChan.TXREQFLIT.Opcode == `WriteUniquePtl ) , 
       .Dequeue  ( SigDeqReqW                                                       ) , 
       .Outp     ( SigTXREQFLITW                                                    ) , 
       .FULL     (                                                                  ) , 
       .Empty    ( SigReqEmptyW                                                     ) 
       );
       
    //initialize DDR
    genvar i ;
    generate 
    for(i = 0 ; i < 2**(MEM_ADDR_WIDTH) ; i++)
      always_ff@(posedge Clk)  
        if(RST)
          begin
            myDDR[(i+1)*8 - 1:i*8] <= $urandom();
      end 
    endgenerate;
       
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
    
    // use in order not to give more crds on Converter's ReqChanel than fifo length
    always_ff@(posedge Clk) begin
      if(RST)
        GivenReqCrds <= 0;
      else begin
        if(!ReqChan.TXREQLCRDV & ReqChan.TXREQFLITV & GivenReqCrds != 0)
          GivenReqCrds <= GivenReqCrds - 1 ;
        else if(ReqChan.TXREQLCRDV & (!ReqChan.TXREQFLITV | GivenReqCrds == 0))
          GivenReqCrds<= GivenReqCrds + 1 ;
      end
    end
    
    //give Converter's Outbound Crds
    always@(negedge Clk) begin
      if(RST)begin
        ReqChan.TXREQLCRDV = 0;
        #period;
      end
      else begin
        ReqChan.TXREQLCRDV = 0;
        #(2*period*$urandom_range(2));
        if(GivenReqCrds < FIFO_Length & CountReqCrdsOutb < `MaxCrds)
          ReqChan.TXREQLCRDV = 1;
        #(2*period);
      end
    end
     always@(negedge Clk) begin
      if(RST) begin
        RspOutbChan.TXRSPLCRDV = 0;
        #period;
      end
      else begin
        RspOutbChan.TXRSPLCRDV = 0;
        #(2*period*$urandom_range(5));
        if(CountRspCrdsOutb < `MaxCrds)
          RspOutbChan.TXRSPLCRDV = 1;
        #(2*period);
      end
    end
    always@(negedge Clk) begin
      if(RST) begin
        DatOutbChan.TXDATLCRDV = 0;
        #period;
      end
      else begin
        DatOutbChan.TXDATLCRDV = 0;
        #(2*period*$urandom_range(5));
        if(CountDataCrdsOutb < `MaxCrds)
          DatOutbChan.TXDATLCRDV = 1;
        #(2*period);
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
    
    // Data Response
    always@(negedge Clk) begin     
      if(!SigReqEmptyR & SigTXREQFLITR.Opcode == `ReadOnce & CountDataCrdsInb != 0)begin
        //Response delay
        if(SrcAddrReg + CHI_DATA_WIDTH != SigTXREQFLITR.Addr)begin // 0 delay if addresses are continuous
          DatInbChan.RXDATFLITPEND     = 0      ;
          DatInbChan.RXDATFLITV        = 0      ;
          DatInbChan.RXDATFLIT         = 0      ;
          SigDeqReqR                   = 0      ;
          #(2*period*$urandom_range(40) + 4*period);  // random delay if addresses arent continuous
        end
          DatInbChan.RXDATFLITV = 1;
          // used to take hte correct bytes from DDR for read Rsponse
          assign ShiftedDDR = myDDR >> ({SigTXREQFLITR.Addr[MEM_ADDR_WIDTH - 1 : ADDR_WIDTH_OF_DATA],{ADDR_WIDTH_OF_DATA{1'b0}}} * 8);
          // Data FLIT
          DatInbChan.RXDATFLIT = '{default     : 0                                            ,                       
                                    QoS        : 0                                            ,
                                    TgtID      : 1                                            ,
                                    SrcID      : 2                                            ,
                                    TxnID      : SigTXREQFLITR.TxnID                          ,
                                    HomeNID    : 0                                            ,
                                    Opcode     : `CompData                                    ,
                                    RespErr    : `StatusError*(($urandom_range(0,100)) == 1)  , // samll probability to be an error
                                    Resp       : 0                                            , // Resp should be 0 when NonCopyBackWrData Rsp
                                    DataSource : 0                                            , 
                                    DBID       : 0                                            ,
                                    CCID       : 0                                            , 
                                    DataID     : 0                                            ,
                                    TraceTag   : 0                                            ,
                                    BE         : {CHI_DATA_WIDTH{1'b1}}                       ,
                                    Data       : ShiftedDDR[CHI_DATA_WIDTH * 8 : 0]           , //512 width of data
                                    DataCheck  : 0                                            ,
                                    Poison     : 0                                        
                                    }; 
          SrcAddrReg   = SigTXREQFLITR.Addr ;    
          SigDeqReqR   = 1;
          #(period*2);
      end
      else begin
        DatInbChan.RXDATFLITPEND     = 0      ;
        DatInbChan.RXDATFLITV        = 0      ;
        DatInbChan.RXDATFLIT         = 0      ;
        SigDeqReqR        = 0      ;
        if(RST)
          SrcAddrReg      = 0      ;    
        #(period*2) ;
      end
    end
    
    //DBID Respose 
    always@(negedge Clk) begin
      if(!SigReqEmptyW & SigTXREQFLITW.Opcode == `WriteUniquePtl & CountRspCrdsInb != 0)begin
        RspInbChan.RXRSPFLITPEND     = 0      ;
        RspInbChan.RXRSPFLITV        = 0      ;
        RspInbChan.RXRSPFLIT         = 0      ;
        SigDeqReqW                   = 0      ;
        #(2*period*$urandom_range(10)) //response delay
        RspInbChan.RXRSPFLITV = 1; 
        RspInbChan.RXRSPFLIT = '{default   : 0                                        ,                       
                                  QoS      : 0                                        ,
                                  TgtID    : 1                                        ,
                                  SrcID    : 2                                        ,
                                  TxnID    : SigTXREQFLITW.TxnID                      ,
                                  Opcode   : `CompDBIDResp                            ,
                                  RespErr  : 0                                        ,
                                  Resp     : 0                                        ,
                                  FwdState : 0                                        , // Resp should be 0 when NonCopyBackWrData Rsp
                                  DBID     : DBID_Count                               , // new DBID for every Rsp
                                  PCrdType : 0                                        ,
                                  TraceTag : 0                                       
                                  };     
        DBID_Count <= DBID_Count + 1; //increase DBID pointer
        SigDeqReqW = 1;
        #(period*2);
      end
      else begin
        RspInbChan.RXRSPFLITPEND     = 0      ;
        RspInbChan.RXRSPFLITV        = 0      ;
        RspInbChan.RXRSPFLIT         = 0      ;      
        SigDeqReqW                   = 0      ;
        #(period*2) ;
      end
    end
endmodule
