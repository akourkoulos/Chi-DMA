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
  parameter MEM_ADDR_WIDTH     = 44  ,//<------ should be the same with BRAM_COL_WIDTH
  parameter CHI_DATA_WIDTH     = 64  , //Bytes
  parameter Chunk              = 5   ,
  parameter NUM_OF_REPETITIONS = 50 ,
  parameter FIFO_Length        = 120
//----------------------------------------------------------------------
);

reg                                   Clk               ;
reg                                   RST               ;
Data_packet                           DataBRAM          ; // From BRAM
reg                                   ReadyBRAM         ; // From Arbiter_BRAM
CHI_Command                           Command           ;
reg                                   IssueValid        ; 
reg                                   TXREQFLITPEND     ; // Request outbound Channel
reg                                   TXREQFLITV        ;
ReqFlit                               TXREQFLIT         ;
reg                                   TXREQLCRDV        ;
wire                                  TXRSPFLITPEND     ; // Response outbound Channel
wire                                  TXRSPFLITV        ;
reg                                   TXRSPFLIT         ;
reg                                   TXRSPLCRDV        ;
wire                                  TXDATFLITPEND     ; // Data outbound Channel
wire                                  TXDATFLITV        ;
DataFlit                              TXDATFLIT         ;
reg                                   TXDATLCRDV        ;
reg                                   RXRSPFLITPEND     ; // Response inbound Channel
reg                                   RXRSPFLITV        ;
RspFlit                               RXRSPFLIT         ;
wire                                  RXRSPLCRDV        ;
reg                                   RXDATFLITPEND     ; // Data inbound Channel
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
     .Command           (Command           ) ,
     .IssueValid        (IssueValid        ) ,
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
    int                               CountDataCrdsInb  = 0  ; 
    int                               CountRspCrdsInb   = 0  ;
    int                               CountReqCrdsOutb  = 0  ; 
    int                               CountDataCrdsOutb = 0  ;
    int                               CountRspCrdsOutb  = 0  ;
    reg     [31 : 0]                  GivenReqCrds       ;// use in order not to give more crds than fifo length
    //FIFO signals
    reg                               SigDeqReqR         ;
    reg                               SigReqEmptyR       ;
    reg                               SigDeqReqW         ;
    reg                               SigReqEmptyW       ;
    ReqFlit                           SigTXREQFLITR      ;
    ReqFlit                           SigTXREQFLITW      ;
    //Last Trans signals
    reg     [MEM_ADDR_WIDTH  - 1 : 0] SrcAddrReg         ;
    reg                               SrcAddrRegWE       ;
    int                               DBID_Count    = 0  ; 
    
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
    
    //Manage Received Crds
    always_ff@(posedge Clk) begin
      if(RST)begin
        CountDataCrdsOutb = 0 ;
        CountRspCrdsOutb  = 0 ;
        CountReqCrdsOutb  = 0 ;
      end
      else begin
        if(TXDATLCRDV & !TXDATFLITV)
          CountDataCrdsOutb++;
        else if(!TXDATLCRDV & TXDATFLITV)
          CountDataCrdsOutb--;
        if(TXRSPLCRDV & !TXRSPFLITV) 
          CountRspCrdsOutb++; 
        else if(!TXRSPLCRDV & TXRSPFLITV) 
          CountRspCrdsOutb--; 
        if(TXREQLCRDV & !TXREQFLITV) 
          CountReqCrdsOutb++; 
        else if(!TXREQLCRDV & TXREQFLITV) 
          CountReqCrdsOutb--; 
      end
    end
    
    //Manage given Crds
    always_ff@(posedge Clk) begin
      if(RST)begin
        CountDataCrdsInb = 0 ;
        CountRspCrdsInb  = 0 ;
      end
      else begin
        if(RXDATLCRDV & !RXDATFLITV)
          CountDataCrdsInb++;
        else if(!RXDATLCRDV & RXDATFLITV)
          CountDataCrdsInb--;
        if(RXRSPLCRDV & !RXRSPFLITV) 
          CountRspCrdsInb++; 
        else if(!RXRSPLCRDV & RXRSPFLITV) 
          CountRspCrdsInb--; 
      end
    end
    
    // use in order not to give more crds than fifo length
    always_ff@(posedge Clk) begin
      if(RST)
        GivenReqCrds <= 0;
      else begin
        if(!TXREQLCRDV & TXREQFLITV & GivenReqCrds != 0)
          GivenReqCrds <= GivenReqCrds - 1 ;
        else if(TXREQLCRDV & (!TXREQFLITV | GivenReqCrds == 0))
          GivenReqCrds<= GivenReqCrds + 1 ;
      end
    end
    
    
    //give Crds
    always begin
      if(RST)begin
        TXREQLCRDV = 0;
        #period;
      end
      else begin
        TXREQLCRDV = 0;
        #(2*period*$urandom_range(2));
        if(GivenReqCrds < FIFO_Length & GivenReqCrds < `MaxCrds)
          TXREQLCRDV = 1;
        #(2*period);
      end
    end
    always begin
      if(RST) begin
        TXRSPLCRDV = 0;
        #period;
      end
      else begin
        TXRSPLCRDV = 0;
        #(2*period*$urandom_range(5));
        if(CountRspCrdsOutb < `MaxCrds)
          TXRSPLCRDV = 1;
        #(2*period);
      end
    end
    always begin
      if(RST) begin
        TXDATLCRDV = 0;
        #period;
      end
      else begin
        TXDATLCRDV = 0;
        #(2*period*$urandom_range(5));
        if(CountDataCrdsOutb < `MaxCrds)
          TXDATLCRDV = 1;
        #(2*period);
      end
    end
    
    
    // Data Response
    always begin     
      if(!SigReqEmptyR & SigTXREQFLITR.Opcode == `ReadOnce & CountDataCrdsInb != 0)begin
        //Response delay
        if(SrcAddrReg + 64 != SigTXREQFLITR.Addr)begin // 0 delay if addresses are continuous
          RXDATFLITPEND     = 0      ;
          RXDATFLITV        = 0      ;
          RXDATFLIT         = 0      ;
          SigDeqReqR        = 0      ;
          #(2*period*$urandom_range(40) + 4*period);  // random delay if addresses arent continuous
        end
          RXDATFLITV = 1;
          RXDATFLIT = '{default                : 0                                            ,                       
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
        RXDATFLITPEND     = 0      ;
        RXDATFLITV        = 0      ;
        RXDATFLIT         = 0      ;
        SigDeqReqR        = 0      ;
        if(RST)
          SrcAddrReg      = 0      ;    
        #(period*2) ;
      end
    end
    
    //DBID Respose 
    always begin
      if(!SigReqEmptyW & SigTXREQFLITW.Opcode == `WriteUniquePtl & CountRspCrdsInb != 0)begin
        RXRSPFLITPEND     = 0      ;
        RXRSPFLITV        = 0      ;
        RXRSPFLIT         = 0      ;
        SigDeqReqW        = 0      ;
        #(2*period*$urandom_range(10)) //response delay
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
                                  DBID     : DBID_Count                               , 
                                  PCrdType : 0                                        ,
                                  TraceTag : 0                                       
                                  };     
        DBID_Count++; //increase DBID pointer
        SigDeqReqW = 1;
        #(period*2);
      end
      else begin
        RXRSPFLITPEND     = 0      ;
        RXRSPFLITV        = 0      ;
        RXRSPFLIT         = 0      ;      
        SigDeqReqW        = 0      ;
        #(period*2) ;
      end
    end
    
    int temp = 0 ; //to insert probability
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
         
         for(int i = 1 ; i < NUM_OF_REPETITIONS ; i = i)begin
           RST                         = 0                                      ;
           Command.SrcAddr             = 'd10    * $urandom_range(10000)        ;
           Command.DstAddr             = 'd10000 * $urandom_range(10000)        ;
           if(CmdFIFOFULL)begin                                       
             IssueValid        = 0                                      ;
           end                                                          
           else begin                                                   
             IssueValid        = 1                                      ;
             i++                                                        ;
           end                                                          
           Command.DescAddr    = i                                      ;
           temp                = $urandom_range(0,5)                    ;
           if(temp[2] == 1)begin //20% chance to be the last transaction of Desc
             Command.LastDescTrans = 1                                          ; 
             Command.Length            = $urandom_range(1,CHI_DATA_WIDTH*Chunk) ;
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
         
         #(period*2500); // wait for period   
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
          if(IssueValid & !CmdFIFOFULL)begin
            TestVectorCommand[CommandPointer]= Command ;
            CommandPointer++ ;
          end
          if(TXREQFLITV & (TXREQFLIT.Opcode == `ReadOnce) & CountReqCrdsOutb != 0 )begin
            TestVectorReadReq[ReadReqPointer] <= TXREQFLIT ;
            ReadReqPointer++;
          end
          if(TXREQFLITV & (TXREQFLIT.Opcode == `WriteUniquePtl) & CountReqCrdsOutb != 0 )begin
            TestVectorWriteReq[WriteReqPointer] <= TXREQFLIT ;
            WriteReqPointer++;
          end
          if(RXRSPFLITV & CountRspCrdsInb != 0 )begin
            TestVectorRspIn[RspInPointer] <= RXRSPFLIT ;
            RspInPointer++;
          end
          if(RXDATFLITV & CountDataCrdsInb != 0 )begin
            TestVectorDataIn[DataInPointer] <= RXDATFLIT ;
            DataInPointer++;
          end
          if(TXDATFLITV & CountDataCrdsOutb != 0 )begin
            TestVectorDataOut[DataOutPointer] <= TXDATFLIT ;
            DataOutPointer++;
          end
          if(UUT.SigDeqCommand)
            CountFinishedCommands++;
          if(CountFinishedCommands == NUM_OF_REPETITIONS)begin
            CountFinishedCommands = 0 ;
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
          $display("SrcAddr : %d,DstAddr : %d,Length : %d,DescAddr : %d,LastDesc : %d", TestVectorCommand[i].SrcAddr,TestVectorCommand[i].DstAddr,TestVectorCommand[i].Length,TestVectorCommand[i].DescAddr,TestVectorCommand[i].LastDescTrans);
          while(lengthCount<TestVectorCommand[i].Length)begin
            automatic int unqRTxnID = uniqueReadTxnID(j);
            automatic int unqWTxnID = uniqueWriteTxnID(j);
            
            if((TestVectorReadReq[j].Opcode == `ReadOnce & (TestVectorReadReq[j].Addr == (TestVectorCommand[i].SrcAddr + lengthCount)) & unqRTxnID)
            &(TestVectorDataIn[j].Opcode == `CompData & (TestVectorDataIn[j].TxnID == (TestVectorReadReq[j].TxnID))))
              $display("Correct Read Trans");
            else if(TestVectorReadReq[j].Opcode != `ReadOnce)begin
              $display("--ERROR :: ReadReq Opcode is not ReadOnce");
              $stop;
            end
            else if(TestVectorReadReq[j].Addr != (TestVectorCommand[i].SrcAddr + lengthCount))begin
              $display("--ERROR :: Requested ReadAddr is : %d , but it should be : %d",TestVectorReadReq[j].Addr ,TestVectorCommand[i].SrcAddr + lengthCount);
              $stop;
            end
            else if(!unqRTxnID)begin
              $display("--ERROR :: TxnID : %d is reused",TestVectorReadReq[j].TxnID);
              $stop;
            end
            else if(TestVectorDataIn[j].Opcode != `CompData)begin
              $display("--ERROR :: DataRsp Opcode is not CompData");
              $stop;
            end
            else begin
              $display("--ERROR :: DataRsp TxnID :%d is not the same with ReadReq TxnID :%d",TestVectorDataIn[j].TxnID ,TestVectorReadReq[j].TxnID);
              $stop;
            end
            
            if((TestVectorWriteReq[j].Opcode == `WriteUniquePtl & (TestVectorWriteReq[j].Addr == (TestVectorCommand[i].DstAddr + lengthCount)) & unqWTxnID)
            &(((TestVectorRspIn[j].Opcode == `DBIDResp) | (TestVectorRspIn[j].Opcode == `CompDBIDResp)) & (TestVectorRspIn[j].TxnID == (TestVectorWriteReq[j].TxnID)))
            &((TestVectorDataOut[j].Opcode == `NonCopyBackWrData) & (TestVectorRspIn[j].DBID == TestVectorDataOut[j].TxnID)) )
              if((TestVectorCommand[i].Length<(lengthCount+CHI_DATA_WIDTH)) & (TestVectorDataOut[j].BE != ~({CHI_DATA_WIDTH{1'b1}} << (TestVectorCommand[i].Length - lengthCount))))begin
                $display("--Error :: BE is : %d and it should be :%d",TestVectorDataOut[j].BE ,~({CHI_DATA_WIDTH{1'b1}} << (TestVectorCommand[i].Length - lengthCount)));
                $stop;
              end
              else 
                $display("Correct Write Trans");
            else if(TestVectorReadReq[j].Opcode != `WriteUniquePtl)begin
              $display("--ERROR :: WriteReq Opcode is not WriteUniquePtl");
              $stop;
            end
            else if(TestVectorWriteReq[j].Addr != (TestVectorCommand[i].DstAddr + lengthCount))begin
              $display("--ERROR :: Requested WriteAddr is : %d , but it should be : %d",TestVectorWriteReq[j].Addr ,TestVectorCommand[i].DstAddr + lengthCount);
              $stop;
            end
            else if(!unqWTxnID)begin
              $display("--ERROR :: TxnID : %d is reused",TestVectorWriteReq[j].TxnID);
              $stop;
            end
            else if(TestVectorRspIn[j].Opcode != `DBIDResp & TestVectorRspIn[j].Opcode != `CompDBIDResp )begin
              $display("--ERROR :: DataRsp Opcode is not DBIDResp or CompDBIDResp");
              $stop;
            end
            else if(TestVectorRspIn[j].TxnID != (TestVectorWriteReq[j].TxnID)) begin
              $display("--ERROR :: DBIDRsp TxnID :%d is not the same with WriteReq TxnID :%d",TestVectorRspIn[j].TxnID ,TestVectorWriteReq[j].TxnID);
              $stop;
            end
            else if(TestVectorDataOut[j].Opcode != `NonCopyBackWrData) begin
              $display("--ERROR :: Data In Opcode is not NonCopyBackWrData");
              $stop;
            end
            else begin
              $display("--ERROR :: DBIDRsp DBID :%d is not the same with Data Out DBID :%d",TestVectorRspIn[j].DBID , TestVectorDataOut[j].TxnID);
              $stop;
            end
            lengthCount=lengthCount+CHI_DATA_WIDTH;
            j++;
          end
        end
      end
      endtask ;
      
      
      function int uniqueReadTxnID(input int j);
        automatic int  k = j ;
        while(TestVectorDataIn[k].TxnID!= TestVectorReadReq[j].TxnID) begin
          if(TestVectorReadReq[j].TxnID == TestVectorReadReq[k].TxnID | TestVectorReadReq[j].TxnID == TestVectorWriteReq[k].TxnID)begin
            $display("--Error :: In ReadReq TxnID -> %d is already used",TestVectorReadReq[j].TxnID );
            return 0;
          end
          k++;
        end
        return 1 ;
  endfunction
  
  function int uniqueWriteTxnID(input int j);
        automatic int  k = j ;
        while(TestVectorRspIn[k].TxnID!= TestVectorWriteReq[j].TxnID) begin
          if(TestVectorWriteReq[j].TxnID == TestVectorWriteReq[k].TxnID | TestVectorWriteReq[j].TxnID == TestVectorReadReq[k].TxnID)begin
            $display("--Error :: In ReadReq TxnID -> %d is already used",TestVectorReadReq[j].TxnID );
            return 0;
          end
          k++;
        end
        return 1 ;
  endfunction
  
endmodule