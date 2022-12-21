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
// Rsp opcode
`define DBIDResp          4'h3
`define CompDBIDResp      4'h5
//Data opcode
`define NonCopyBackWrData 4'h3
`define NCBWrDataCompAck  4'hc
`define CompData          4'h4

`define MaxCrds           15

`define StatusError       2

module TestCHIConverter#(
//--------------------------------------------------------------------------
  parameter BRAM_ADDR_WIDTH    = 10  ,
  parameter BRAM_NUM_COL       = 8   , // As the Data_packet fields
  parameter BRAM_COL_WIDTH     = 32  ,
  parameter MEM_ADDR_WIDTH     = 44  ,
  parameter CHI_DATA_WIDTH     = 64  , //Bytes
  parameter Chunk              = 5   ,
  parameter NUM_OF_REPETITIONS = 500 ,
  parameter FIFO_Length        = 128
//----------------------------------------------------------------------
);

reg                                      Clk               ;
reg                                      RST               ;
Data_packet                              DataBRAM          ; // From BRAM
reg                                      ReadyBRAM         ; // From Arbiter_BRAM
CHI_Command                              Command           ;
reg                                      IssueValid        ; 
ReqChannel                               ReqChan    ()     ; // Request ChannelS
RspOutbChannel                           RspOutbChan()     ; // Response outbound Chanel
DatOutbChannel                           DatOutbChan()     ; // Data outbound Chanel
RspInbChannel                            RspInbChan ()     ; // Response inbound Chanel
DatInbChannel                            DatInbChan ()     ; // Data inbound Chanel
reg                                      CmdFIFOFULL       ; // For Scheduler
reg                                      ValidBRAM         ; // For Arbiter_BRAM
reg            [BRAM_ADDR_WIDTH - 1 : 0] AddrBRAM          ; // For BRAM
Data_packet                              DescStatus        ;
reg            [BRAM_NUM_COL    - 1 : 0] WEBRAM            ;
  
    // duration for each bit = 20 * timescdoutBale = 20 * 1 ns  = 20ns
    localparam period = 20;  

    CHIConverter UUT    (
     .Clk               (Clk                   ) ,
     .RST               (RST                   ) ,
     .DataBRAM          (DataBRAM              ) ,
     .ReadyBRAM         (ReadyBRAM             ) ,
     .Command           (Command               ) ,
     .IssueValid        (IssueValid            ) ,
     .ReqChan           (ReqChan    .OUTBOUND  ) ,
     .RspOutbChan       (RspOutbChan.OUTBOUND  ) ,
     .DatOutbChan       (DatOutbChan.OUTBOUND  ) ,
     .RspInbChan        (RspInbChan .INBOUND   ) ,
     .DatInbChan        (DatInbChan .INBOUND   ) ,
     .CmdFIFOFULL       (CmdFIFOFULL           ) ,
     .ValidBRAM         (ValidBRAM             ) ,
     .AddrBRAM          (AddrBRAM              ) ,
     .DescStatus        (DescStatus            ) ,
     .WEBRAM            (WEBRAM                )    
    );
    
    //Crds signals
    int                               CountDataCrdsInb  = 0  ; 
    int                               CountRspCrdsInb   = 0  ;
    int                               CountReqCrdsOutb  = 0  ; 
    int                               CountDataCrdsOutb = 0  ;
    int                               CountRspCrdsOutb  = 0  ;
    reg     [31 : 0]                  GivenReqCrds           ;// use in order not to give more crds than fifo length
    //FIFO signals
    reg                               SigDeqReqR         ;
    reg                               SigReqEmptyR       ;
    reg                               SigDeqReqW         ;
    reg                               SigReqEmptyW       ;
    ReqFlit                           SigTXREQFLITR      ;
    ReqFlit                           SigTXREQFLITW      ;
    //Last Trans signals
    reg     [MEM_ADDR_WIDTH  - 1 : 0] SrcAddrReg         ;
    int                               DBID_Count    = 0  ; 
    
    // Read Req FIFO (keeps all the uncomplete read Requests)
   FIFO #(     
       .FIFO_WIDTH  ( REQ_FLIT_WIDTH ) ,       
       .FIFO_LENGTH ( FIFO_Length    )      
       )     
       myRFIFOReq  (     
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
       myWFIFOReq  (     
       .RST      ( RST                                                              ) ,      
       .Clk      ( Clk                                                              ) ,      
       .Inp      ( ReqChan.TXREQFLIT                                                ) , 
       .Enqueue  ( ReqChan.TXREQFLITV & ReqChan.TXREQFLIT.Opcode == `WriteUniquePtl ) , 
       .Dequeue  ( SigDeqReqW                                                       ) , 
       .Outp     ( SigTXREQFLITW                                                    ) , 
       .FULL     (                                                                  ) , 
       .Empty    ( SigReqEmptyW                                                     ) 
       );
       
    
    always
    begin
        Clk = 1'b0; 
        #20; // high for 20 * timescale = 20 ns
    
        Clk = 1'b1;
        #20; // low for 20 * timescale = 20 ns
    end
    
    //Signals for Completer
    always_comb begin
      if(ValidBRAM) begin
         ReadyBRAM                = 1                    ;
         DataBRAM.SrcAddr         = $urandom()           ;
         DataBRAM.DstAddr         = $urandom()           ;
         DataBRAM.BytesToSend     = $urandom()           ;
         DataBRAM.SentBytes       = DataBRAM.BytesToSend ;
         DataBRAM.Status          = 1                    ;
      end
      else begin
         ReadyBRAM                = 0 ;
         DataBRAM.SrcAddr         = 0 ;
         DataBRAM.DstAddr         = 0 ;
         DataBRAM.BytesToSend     = 0 ;
         DataBRAM.SentBytes       = 0 ;
         DataBRAM.Status          = 0 ;
      end
    end
    
    //Count inbound Crds
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
    
    // use in order not to give more crds than fifo length
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
    
    
    //give Outbound Crds
    always begin
      if(RST)begin
        ReqChan.TXREQLCRDV = 0;
        #period;
      end
      else begin
        ReqChan.TXREQLCRDV = 0;
        #(2*period*$urandom_range(2));
        if(GivenReqCrds < FIFO_Length & GivenReqCrds < `MaxCrds)
          ReqChan.TXREQLCRDV = 1;
        #(2*period);
      end
    end
    always begin
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
    always begin
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
    
    //Count Outbound Crds
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
    always begin     
      if(!SigReqEmptyR & SigTXREQFLITR.Opcode == `ReadOnce & CountDataCrdsInb != 0)begin
        //Response delay
        if(SrcAddrReg + 64 != SigTXREQFLITR.Addr)begin // 0 delay if addresses are continuous
          DatInbChan.RXDATFLITPEND     = 0      ;
          DatInbChan.RXDATFLITV        = 0      ;
          DatInbChan.RXDATFLIT         = 0      ;
          SigDeqReqR                   = 0      ;
          #(2*period*$urandom_range(40) + 4*period);  // random delay if addresses arent continuous
        end
          DatInbChan.RXDATFLITV = 1;
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
                                    BE         : {64{1'b1}}                                   ,
                                    Data       : 2**$urandom_range(0,512) - $urandom()        ,  //512 width of data
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
    always begin
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
    
    // Insert Command 
    initial
        begin
          // Reset;
         RST                       = 1      ;
         Command.SrcAddr           = 'd10   ;
         Command.DstAddr           = 'd1000 ;
         Command.Length            = 'd320  ;
         IssueValid                = 0      ;
         Command.DescAddr          = 'd1    ;
         Command.LastDescTrans     = 0      ;
         
         #(period*2); // wait for period   
         
         for(int i = 1 ; i < NUM_OF_REPETITIONS+1 ; i = i)begin
           RST                         = 0                                      ;
           Command.SrcAddr             = 'd64   * $urandom_range(10000)         ;
           Command.DstAddr             = 'd1000 * $urandom_range(10000)* 'd64   ;
           if(CmdFIFOFULL)begin        // Issue Command when CommandFIFO is not FULL                                 
             IssueValid                = 0                                      ;
           end                                                                  
           else begin                                                           
             IssueValid                = 1                                      ;
             i++                                                                ;
           end                                                                  
           Command.DescAddr            = i                                      ;
           if($urandom_range(0,5) == 1)begin //20% chance to be the last transaction of Desc
             Command.LastDescTrans = 1                                          ; // If last trans LastDescTrans=1 
             Command.Length            = $urandom_range(1,CHI_DATA_WIDTH*Chunk) ; // and length < CHI_CHI_DATA_WIDTH * Chunk
           end
           else begin
             Command.LastDescTrans = 0                                          ; 
             Command.Length            = CHI_DATA_WIDTH*Chunk                   ;
           end
          
           #(period*2); // wait for period  
           
           if(IssueValid == 1)begin
             RST                       = 0  ;                                   
             Command.SrcAddr           = 0  ;      
             Command.DstAddr           = 0  ;
             Command.Length            = 0  ;
             IssueValid                = 0  ;                                   
             Command.DescAddr          = 0  ;                                   
             Command.LastDescTrans     = 0  ;                                   
             
             #(period*2 + 2*period*$urandom_range(4));
           end
         end
         //stop
         RST                       = 0  ;                                   
         Command.SrcAddr           = 0  ;      
         Command.DstAddr           = 0  ;
         Command.Length            = 0  ;
         IssueValid                = 0  ;                                   
         Command.DescAddr          = 0  ;                                   
         Command.LastDescTrans     = 0  ;                                   
         
         while(1)
           #(period*2); // wait for period   
    end
    
    //@@@@@@@@@@@@@@@@@@@@@@@@@Check functionality@@@@@@@@@@@@@@@@@@@@@@@@@
      // Vector that keeps information for ckecking the operation of CHI-COnverter
      CHI_Command [NUM_OF_REPETITIONS       - 1 : 0]  TestVectorCommand     ; 
      ReqFlit     [NUM_OF_REPETITIONS*Chunk - 1 : 0]  TestVectorReadReq     ; 
      ReqFlit     [NUM_OF_REPETITIONS*Chunk - 1 : 0]  TestVectorWriteReq    ; 
      DataFlit    [NUM_OF_REPETITIONS*Chunk - 1 : 0]  TestVectorDataIn      ; 
      RspFlit     [NUM_OF_REPETITIONS*Chunk - 1 : 0]  TestVectorRspIn       ; 
      DataFlit    [NUM_OF_REPETITIONS*Chunk - 1 : 0]  TestVectorDataOut     ; 
      reg         [NUM_OF_REPETITIONS*Chunk - 1 : 0]  CommandPointer        ;
      reg         [NUM_OF_REPETITIONS*Chunk - 1 : 0]  ReadReqPointer        ;
      reg         [NUM_OF_REPETITIONS*Chunk - 1 : 0]  WriteReqPointer       ;
      reg         [NUM_OF_REPETITIONS*Chunk - 1 : 0]  DataInPointer         ;
      reg         [NUM_OF_REPETITIONS*Chunk - 1 : 0]  RspInPointer          ;
      reg         [NUM_OF_REPETITIONS*Chunk - 1 : 0]  DataOutPointer        ;
      int                                             CountFinishedCommands ;
      
      //Create TestVector
      always_ff@(posedge Clk) begin 
        if(RST) begin 
          TestVectorCommand     <= '{default : 0} ;
          TestVectorReadReq     <= '{default : 0} ;
          TestVectorWriteReq    <= '{default : 0} ;
          TestVectorDataIn      <= '{default : 0} ;
          TestVectorRspIn       <= '{default : 0} ;
          TestVectorDataOut     <= '{default : 0} ;
          ReadReqPointer        <= 0              ;
          WriteReqPointer       <= 0              ;
          DataInPointer         <= 0              ;
          RspInPointer          <= 0              ;
          DataOutPointer        <= 0              ;         
          CountFinishedCommands <= 0              ;  
          CommandPointer        <= 0              ;
        end
        else begin
          if(IssueValid & !CmdFIFOFULL)begin           // update a Command TestVector when insert a new command
            TestVectorCommand[CommandPointer] <= Command ;
            CommandPointer <= CommandPointer + 1 ;
          end
          if(ReqChan.TXREQFLITV & (ReqChan.TXREQFLIT.Opcode == `ReadOnce) & CountReqCrdsOutb != 0 )begin // update a Read TestVector when a new Read Req happens
            TestVectorReadReq[ReadReqPointer] <= ReqChan.TXREQFLIT ;
            ReadReqPointer <= ReadReqPointer + 1 ;
            uniqueReadTxnID(ReadReqPointer,ReqChan.TXREQFLIT);
          end
          if(ReqChan.TXREQFLITV & (ReqChan.TXREQFLIT.Opcode == `WriteUniquePtl) & CountReqCrdsOutb != 0 )begin // update a Write TestVector when a new Write Req happens
            TestVectorWriteReq[WriteReqPointer] <= ReqChan.TXREQFLIT ;
            WriteReqPointer <= WriteReqPointer + 1 ;
            uniqueWriteTxnID(WriteReqPointer,ReqChan.TXREQFLIT);
          end
          if(RspInbChan.RXRSPFLITV & CountRspCrdsInb != 0 )begin // update Rsp TestVector when a new Rsp comes 
            TestVectorRspIn[RspInPointer] <= RspInbChan.RXRSPFLIT ;
            RspInPointer <= RspInPointer + 1 ;
          end
          if(DatInbChan.RXDATFLITV & CountDataCrdsInb != 0 )begin    // update Data In TestVector when a new RspData comes 
            TestVectorDataIn[DataInPointer] <= DatInbChan.RXDATFLIT ;
            DataInPointer  <= DataInPointer + 1 ;
          end
          if(DatOutbChan.TXDATFLITV & CountDataCrdsOutb != 0 )begin // update Data Out TestVector when a new Data out Rsp Happens
            TestVectorDataOut[DataOutPointer] <= DatOutbChan.TXDATFLIT ;
            DataOutPointer <= DataOutPointer + 1 ;
          end
          if(UUT.SigDeqCommand)begin //Count finished Command Requests
            CountFinishedCommands <= CountFinishedCommands + 1;
          end
          if(CountFinishedCommands == NUM_OF_REPETITIONS & UUT.SigSizeEmpty)begin //When all commands are finished Check if every transaction happened ok
            CountFinishedCommands <= 0 ;
            printCheckList            ;
          end
        end
      end
        
      //task that checks if results are corect
      int j=0 ;
      task printCheckList ;
      begin
        #(period*2);
        for(int i = 0 ; i < NUM_OF_REPETITIONS ; i++)  begin // for every command in BS check
          automatic int lengthCount = 0 ;
          $display("%d :: SrcAddr : %d,DstAddr : %d,Length : %d,DescAddr : %d,LastDesc : %d", i+1,TestVectorCommand[i].SrcAddr,TestVectorCommand[i].DstAddr,TestVectorCommand[i].Length,TestVectorCommand[i].DescAddr,TestVectorCommand[i].LastDescTrans);
          //for every Transaction of a command
          while(lengthCount<TestVectorCommand[i].Length)begin
            //if a ReadOnce Read Req happens with corect Addr and a corect Data Rsp came with corect TxnID and Opcode then print corect
            if((TestVectorReadReq[j].Opcode == `ReadOnce & (TestVectorReadReq[j].Addr == (TestVectorCommand[i].SrcAddr + lengthCount)))
            &(TestVectorDataIn[j].Opcode == `CompData & (TestVectorDataIn[j].TxnID == (TestVectorReadReq[j].TxnID))))
              $write("%d : Correct Read Trans",lengthCount/64+1);
            // if Wrong Read Opcode print Error
            else if(TestVectorReadReq[j].Opcode != `ReadOnce)begin
              $display("\n--ERROR :: ReadReq Opcode is not ReadOnce , TxnID : %d",TestVectorReadReq[j].TxnID);
              $stop;
            end
            // if Wrong Read Addr print Error
            else if(TestVectorReadReq[j].Addr != (TestVectorCommand[i].SrcAddr + lengthCount))begin
              $display("\n--ERROR :: Requested ReadAddr is : %d , but it should be : %d , TxnID : %d",TestVectorReadReq[j].Addr ,TestVectorCommand[i].SrcAddr + lengthCount,TestVectorReadReq[j].TxnID);
              $stop;
            end
            // if Wrong Data Rsp Opcode print Error
            else if(TestVectorDataIn[j].Opcode != `CompData)begin
              $display("\n--ERROR :: DataRsp Opcode is not CompData , TxnID : %d",TestVectorReadReq[j].TxnID);
              $stop;
            end
            // if Wrong Data Rsp TxnID print Error
            else begin
              $display("\n--ERROR :: DataRsp TxnID :%d is not the same with ReadReq TxnID :%d",TestVectorDataIn[j].TxnID ,TestVectorReadReq[j].TxnID);
              $stop;
            end
            
            // if corect opcode and Addr of a Write Req and corect opcode TxnID of a DBID Rsp and corect Data Out Rsp opcode ,TxnID and BE then print corect
            if((TestVectorWriteReq[j].Opcode == `WriteUniquePtl & (TestVectorWriteReq[j].Addr == (TestVectorCommand[i].DstAddr + lengthCount)))
            &(((TestVectorRspIn[j].Opcode == `DBIDResp) | (TestVectorRspIn[j].Opcode == `CompDBIDResp)) & (TestVectorRspIn[j].TxnID == (TestVectorWriteReq[j].TxnID)))
            &((TestVectorDataOut[j].Opcode == `NonCopyBackWrData) & (TestVectorRspIn[j].DBID == TestVectorDataOut[j].TxnID)) )
              if(TestVectorDataOut[j].BE != ~({CHI_DATA_WIDTH{1'b1}} << (TestVectorCommand[i].Length - lengthCount)))begin
               // wrong Data Out BE
                $display("\n--Error :: BE is : %d and it should be :%d , TxnID : %d",TestVectorDataOut[j].BE ,~({CHI_DATA_WIDTH{1'b1}} << (TestVectorCommand[i].Length - lengthCount)),TestVectorDataOut[j].TxnID);
                $stop;
              end
              else 
                // Corect
                $display("%d Correct Write Trans",lengthCount/64+1);
            // Wrong Write Opcode
            else if(TestVectorReadReq[j].Opcode != `WriteUniquePtl)begin
              $display("\n--ERROR :: WriteReq Opcode is not WriteUniquePtl");
              $stop;
            end
            // Wrong Write Addr
            else if(TestVectorWriteReq[j].Addr != (TestVectorCommand[i].DstAddr + lengthCount))begin
              $display("\n--ERROR :: Requested WriteAddr is : %d , but it should be : %d",TestVectorWriteReq[j].Addr ,TestVectorCommand[i].DstAddr + lengthCount);
              $stop;
            end
            // Wrong DBID Rsp Opcode
            else if(TestVectorRspIn[j].Opcode != `DBIDResp & TestVectorRspIn[j].Opcode != `CompDBIDResp )begin
              $display("\n--ERROR :: DataRsp Opcode is not DBIDResp or CompDBIDResp");
              $stop;
            end
            // Wrong TxnID Rsp Opcode
            else if(TestVectorRspIn[j].TxnID != (TestVectorWriteReq[j].TxnID)) begin
              $display("\n--ERROR :: DBIDRsp TxnID :%d is not the same with WriteReq TxnID :%d",TestVectorRspIn[j].TxnID ,TestVectorWriteReq[j].TxnID);
              $stop;
            end
            // Wrong Data Out Opcode
            else if(TestVectorDataOut[j].Opcode != `NonCopyBackWrData) begin
              $display("\n--ERROR :: Data In Opcode is not NonCopyBackWrData");
              $stop;
            end
            // Wrong Data Out TxnID
            else begin
              $display("\n--ERROR :: DBIDRsp DBID :%d is not the same with Data Out DBID :%d",TestVectorRspIn[j].DBID , TestVectorDataOut[j].TxnID);
              $stop;
            end
            lengthCount=lengthCount+CHI_DATA_WIDTH;
            j++;
          end
        end
      end
      endtask ;
      
      // Function that checks if used Read TxnID is unique
       function void uniqueReadTxnID;
       input int j; 
       input ReqFlit TVReadReq;
        if(j!=0) begin // If more than one Req
          for( int k = 0 ; k < j ; k++)begin
            // if there is an earlier uncomplete Read or Write transaction with the same TxnID print error
            if((TVReadReq.TxnID == TestVectorReadReq[k].TxnID & TestVectorDataIn[k] == 0) | (TVReadReq.TxnID == TestVectorWriteReq[k].TxnID  & TestVectorRspIn[k] == 0 & TestVectorWriteReq[k]!=0))begin
              $display("\n--Error :: In ReadReq TxnID -> %d is already used",TVReadReq.TxnID);
              $stop;
              return;
            end
          end
        end
      endfunction
      
      // Function that checks if used Write TxnID is unique
      function void uniqueWriteTxnID(input int j , input ReqFlit TVWriteReq);
        if(j!=0)begin // If more than one Req
          for( int k = 0 ; k < j ; k++)begin
            // if there is an earlier uncomplete Read or Write transaction with the same TxnID print error
            if((TVWriteReq.TxnID == TestVectorWriteReq[k].TxnID & TestVectorRspIn[k] == 0) | (TVWriteReq.TxnID == TestVectorReadReq[k].TxnID & TestVectorDataIn[k] == 0 & TestVectorReadReq[k] != 0))begin
              $display("\n--Error :: In WriteReq TxnID -> %d is already used",TVWriteReq.TxnID );
              $stop;
              return;
            end
          end
        end
      endfunction
  
  
  
endmodule