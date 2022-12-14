`timescale 1ns / 1ps
import DataPkg    ::*;
import CHIFlitsPkg::*; 
import CHIFIFOsPkg::*;
//////////////////////////////////////////////////////////////////////////////////
// Company:         
// Engineer: 
// 
// Create Date: 19.11.2022 14:19:16
// Design Name: 
// Module Name: TestFULLSystem
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

`define MaxCrds           15
`define CrdRegWidth       4  // log2(MaxCrds)

// Req opcode
`define ReadOnce          6'h03 
`define WriteUniquePtl    6'h18
// Rsp opcode
`define DBIDResp          4'h3
`define CompDBIDResp      4'h5
//Data opcode
`define NonCopyBackWrData 4'h3
`define NCBWrDataCompAck  4'hc
`define CompData          4'h4

`define StatusError       2

module TestFULLSystem#(
//--------------------------------------------------------------------------
  parameter BRAM_NUM_COL        = 8    , // As the Data_packet fields
  parameter BRAM_COL_WIDTH      = 32   , // As the Data_packet field width
  parameter BRAM_ADDR_WIDTH     = 10   , // Addr Width in bits : 2 **BRAM_ADDR_WIDTH = RAM Depth
  parameter CHI_DATA_WIDTH      = 64   ,
  parameter ADDR_WIDTH_OF_DATA  = 6    , // log2(CHI_DATA_WIDTH)  
  parameter MAX_BytesToSend     = 5000 ,
  parameter P1_NUM_OF_TRANS     = 1    , // Number of inserted transfers for each phase
  parameter P2_NUM_OF_TRANS     = 1    ,  
  parameter P3_NUM_OF_TRANS     = 1    ,  
  parameter P4_NUM_OF_TRANS     = 1    ,  
  parameter P5_NUM_OF_TRANS     = 250  ,
  parameter P6_NUM_OF_TRANS     = 250  ,  
  parameter P7_NUM_OF_TRANS     = 15   ,  
  parameter P8_NUM_OF_TRANS     = 45   ,  
  parameter P9_NUM_OF_TRANS     = 450  ,   
  parameter LastPhase           = 9    ,// Number of Last Phase
  parameter PHASE_WIDTH         = 4    , // width of register that keeps the phase
  parameter Test_FIFO_Length    = 120 
//--------------------------------------------------------------------------
);

  reg  Clk  ;
  reg  RST  ;

  wire         [BRAM_NUM_COL    - 1 : 0]  weA            ;
  wire         [BRAM_ADDR_WIDTH - 1 : 0]  addrA          ;
  Data_packet                             dinA           ;
  Data_packet                             BRAMdoutA      ; 
  reg          [PHASE_WIDTH     - 1 : 0]  PhaseIn        ;
  reg                                     NewPhase       ;
  ReqChannel                              ReqChan    ()  ;
  RspOutbChannel                          RspOutbChan()  ;
  DatOutbChannel                          DatOutbChan()  ;
  RspInbChannel                           RspInbChan ()  ;
  DatInbChannel                           DatInbChan ()  ; 

 
  
   CHI_DMA DMA     (
     .Clk          (Clk          ) ,
     .RST          (RST          ) ,
     .weA          (weA          ) ,
     .addrA        (addrA        ) ,
     .dinA         (dinA         ) ,
     .BRAMdoutA    (BRAMdoutA    ) ,
     .ReqChan      (ReqChan      ) ,
     .RspOutbChan  (RspOutbChan  ) ,
     .DatOutbChan  (DatOutbChan  ) ,
     .RspInbChan   (RspInbChan   ) ,
     .DatInbChan   (DatInbChan   )   
    );
    
    
   PseudoCPU #(
   .P1_NUM_OF_TRANS    (P1_NUM_OF_TRANS ),
   .P2_NUM_OF_TRANS    (P2_NUM_OF_TRANS ),
   .P3_NUM_OF_TRANS    (P3_NUM_OF_TRANS ),
   .P4_NUM_OF_TRANS    (P4_NUM_OF_TRANS ),
   .P5_NUM_OF_TRANS    (P5_NUM_OF_TRANS ),
   .P6_NUM_OF_TRANS    (P6_NUM_OF_TRANS ),
   .P7_NUM_OF_TRANS    (P7_NUM_OF_TRANS ),
   .P8_NUM_OF_TRANS    (P8_NUM_OF_TRANS ),
   .P9_NUM_OF_TRANS    (P9_NUM_OF_TRANS ),
   .LastPhase          (LastPhase       ),
   .PHASE_WIDTH        (PHASE_WIDTH     ),
   .MAX_BytesToSend    (MAX_BytesToSend )
   )myCPU(
     .RST          (RST          ) ,
     .Clk          (Clk          ) ,
     .BRAMdoutA    (BRAMdoutA    ) ,
     .PhaseIn      (PhaseIn      ) ,
     .NewPhase     (NewPhase     ) ,
     .weA          (weA          ) ,
     .addrA        (addrA        ) ,
     .dinA         (dinA         ) 
    );
  
  // Simple CHI Responser
   Simple_CHI_Responser#(
     .FIFO_Length(Test_FIFO_Length)
   ) Simp_CHI_RSP         (
     .Clk                 (Clk                               ) ,
     .RST                 (RST                               ) ,
     .ReqChan             (ReqChan       .INBOUND            ) ,
     .RspOutbChan         (RspOutbChan   .INBOUND            ) ,
     .DatOutbChan         (DatOutbChan   .INBOUND            ) ,
     .RspInbChan          (RspInbChan    .OUTBOUND           ) ,
     .DatInbChan          (DatInbChan    .OUTBOUND           )  
    );  
   
   // Fully correctly transfered Descriptors
   reg [BRAM_ADDR_WIDTH - 1 : 0] CorrectTransfer  [P6_NUM_OF_TRANS - 1 : 0] ;
   int                           CTpointer        = 0                       ;

   // Fully correctly scheduled Descriptors
   reg [BRAM_ADDR_WIDTH - 1 : 0] CorrectSched    [P6_NUM_OF_TRANS - 1 : 0]  ;
   int                           CSpointer       = 0                        ;
   wire                          PhaseReqOver                               ;
   
   assign PhaseReqOver = ((PhaseIn  == 1 & CTpointer == P1_NUM_OF_TRANS) | (PhaseIn  == 2 & CTpointer == P2_NUM_OF_TRANS) | (PhaseIn  == 3 & CTpointer == P3_NUM_OF_TRANS) | (PhaseIn  == 4 & CTpointer == P4_NUM_OF_TRANS) |(PhaseIn  == 5 & CTpointer == P5_NUM_OF_TRANS) | (PhaseIn  == 6 & CTpointer == P6_NUM_OF_TRANS) | (PhaseIn  == 7 & CTpointer == P7_NUM_OF_TRANS) | (PhaseIn  == 8 & CTpointer == P8_NUM_OF_TRANS) | (PhaseIn  == 9 & CSpointer == P9_NUM_OF_TRANS));
   
   always
   begin
       Clk = 1'b1; 
       #20; // high for 20 * timescale = 20 ns
   
       Clk = 1'b0;
       #20; 
   end

   // duration for each bit = 20 * timescdoutBale = 20 * 1 ns  = 20ns
   localparam period = 20;  
   
   initial begin
     RST = 1 ;
     #(period*3);
     RST = 0 ;
   end
   
   always@(posedge Clk) begin
     if(RST)begin
       PhaseIn  = 0 ;
       NewPhase = 0 ;
       #period;
     end
     else begin
     // After Reset go to Phase 1 : 1 small(single CHI-transaction) Transfer
       if(PhaseIn  == 0)begin
         #period;
         PhaseIn  = 1 ;
         NewPhase = 1 ;   
         #(period*2)  ;   
         NewPhase = 0 ;   
         #(period)    ;    
       end
       // When Phase 1 is over(all of its transaction has finished and FIFOs of Converter and Completer are empty )  go to Phase 2 : one small missaligned transfers 2 Read - 1 Write
       else if((PhaseIn  == 1 & CTpointer == P1_NUM_OF_TRANS) & DMA.BS.EmptyCom & DMA.CHI_Conv.myCompleter.Empty)begin
         #period;
         PhaseIn  = 2 ;
         NewPhase = 1 ;     
         #(period*2)  ; 
         NewPhase = 0 ;   
         #(period)    ;    
       end
       // When Phase 2 is over go to Phase 3 : one small missaligned transfers 1 Read - 2 Write
       else if((PhaseIn  == 2 & CTpointer == P2_NUM_OF_TRANS) & DMA.BS.EmptyCom& DMA.CHI_Conv.myCompleter.Empty)begin
         #period;
         PhaseIn  = 3 ;
         NewPhase = 1 ;     
         #(period*2)  ;   
         NewPhase = 0 ;   
         #(period)    ;    
       end
       // When Phase 3 is over go to the Phase 4 : one big Transfer
       else if((PhaseIn  == 3 & CTpointer == P3_NUM_OF_TRANS) & DMA.BS.EmptyCom& DMA.CHI_Conv.myCompleter.Empty)begin
         #period;
         PhaseIn  = 4 ;
         NewPhase = 1 ;     
         #(period*2)  ;   
         NewPhase = 0 ;   
         #(period)    ;    
       end
       // When Phase 4 is over go to Phase 5 : many of small (single CHI-transaction) transfers
       else if((PhaseIn  == 4 & CTpointer == P4_NUM_OF_TRANS) & DMA.BS.EmptyCom& DMA.CHI_Conv.myCompleter.Empty)begin
         #period;
         PhaseIn  = 5 ;
         NewPhase = 1 ;     
         #(period*2)  ;   
         NewPhase = 0 ;   
         #(period)    ;    
       end
       // When Phase 5 is over go to Phase 6 : many of small (1 or 2 CHI-transaction) transfers
       else if((PhaseIn  == 5 & CTpointer == P5_NUM_OF_TRANS) & DMA.BS.EmptyCom & DMA.CHI_Conv.myCompleter.Empty)begin
         #period;
         PhaseIn  = 6 ;
         NewPhase = 1 ;    
         #(period*2)  ;   
         NewPhase = 0 ;   
         #(period)    ;    
       end
       // When Phase 6 is over go to Phase 7 : many of Large transfers
       else if((PhaseIn  == 6 & CTpointer == P6_NUM_OF_TRANS) & DMA.BS.EmptyCom & DMA.CHI_Conv.myCompleter.Empty)begin
         #period;
         PhaseIn  = 7 ;
         NewPhase = 1 ;    
         #(period*2)  ;   
         NewPhase = 0 ;   
         #(period)    ;    
       end
       // When Phase 7 is over go to Phase 8 : combination of large and small Transfers that they are comming with random delay
       else if((PhaseIn  == 7 & CTpointer == P7_NUM_OF_TRANS) & DMA.BS.EmptyCom & DMA.CHI_Conv.myCompleter.Empty)begin
         #period;
         PhaseIn  = 8 ;
         NewPhase = 1 ;   
         #(period*2)  ;   
         NewPhase = 0 ;   
         #(period)    ;    
       end
       // When Phase 7 is over go to Phase 8 (LastPhase) : a lot of Transfers with random size random Addresses (Descriptor and Memory) which are inserted in random time
       else if((PhaseIn  == 8 & CTpointer == P8_NUM_OF_TRANS) & DMA.BS.EmptyCom & DMA.CHI_Conv.myCompleter.Empty)begin
         #period;
         PhaseIn  = 9 ;
         NewPhase = 1 ;   
         #(period*2)  ;   
         NewPhase = 0 ;   
         #(period)    ;    
       end
       // All phases are finished
       else if((PhaseIn  == 9 & CTpointer == P9_NUM_OF_TRANS) & DMA.BS.EmptyCom & DMA.CHI_Conv.myCompleter.Empty)begin
         #period;
         PhaseIn  = 9 ;
         NewPhase = 0 ;   
         #(period*2)  ;  
         NewPhase = 0 ;   
         #(period)    ;    
       end
       else begin
         NewPhase = 0 ; 
         #(period)    ;    
       end
     end
   end  
  
   //@@@@@@@@@@@@@@@@@@@@@@@@@ Check of Scheduling  @@@@@@@@@@@@@@@@@@@@@@@@@
   // Vector that keeps information for ckecking the operation of module
   reg [BRAM_COL_WIDTH  - 1 : 0] TestVectorBRAM [5            - 1 : 0][2**BRAM_ADDR_WIDTH - 1 : 0] ; // first dimention 0 : SrcAddr , 1 : DstAddr, 2 : BTS, 3 : SB, 4 : LastDescValid

   //This block Stores in TestVector all Transfers tha have been inserted in DMA and 
   //checks if the scheduling of the tranfers is executed coreclty by comparing the 
   //addresses of the command with the correspondings of transfers. When the lastDescTrans
   //field of command is set then the Transfer is fully scheduled and the corresponding
   //DescAddr which is sheduled correctly is stored in CorrectSched Vector 
   always_ff@(posedge Clk) begin
     // Reset TestVector every time there is a phase change or a RST
     if(RST | (DMA.BS.EmptyCom & DMA.CHI_Conv.myCompleter.Empty & PhaseReqOver))begin
       TestVectorBRAM     <= '{default:0};
       CorrectSched       <= '{default:0};
       CSpointer          <= 0           ;
     end
     else begin
       if(weA != 0)begin  // when store someting in Descriptor update TestVector's SrcAddr ,DstAddr ,BTS fields
         for(int i = 0 ; i < 4 ; i++)begin
           if(weA[i])begin
             TestVectorBRAM[i][addrA] <= dinA[i*BRAM_COL_WIDTH +: BRAM_COL_WIDTH] ;
             end
         end
       end
       
       if(!DMA.mySched.CmdFIFOFULL & DMA.mySched.IssueValid) begin //When scheduler send command to the CHI-Converter Check correctness and update TestVector's SB and LastDescValid field 
         // if ReadAddr in command is SrcAddr+SB and WriteAddr = DstAddr + SB update TestVector's Sb and LastDescTrans fields
         if((TestVectorBRAM[0][DMA.mySched.Command.DescAddr] + TestVectorBRAM[3][DMA.mySched.Command.DescAddr] == DMA.mySched.Command.SrcAddr) & (TestVectorBRAM[1][DMA.mySched.Command.DescAddr] + TestVectorBRAM[3][DMA.mySched.Command.DescAddr] == DMA.mySched.Command.DstAddr))begin
           TestVectorBRAM[3][DMA.mySched.Command.DescAddr] <= TestVectorBRAM[3][DMA.mySched.Command.DescAddr] + DMA.mySched.Command.Length ;
           TestVectorBRAM[4][DMA.mySched.Command.DescAddr] <= DMA.mySched.Command.LastDescTrans ;
           // if LastDescTrans and SB == BTS display correct scheduling : Store Desc Addr in Array CorrectSched
           if(DMA.mySched.Command.LastDescTrans & (TestVectorBRAM[3][DMA.mySched.Command.DescAddr] + DMA.mySched.Command.Length == TestVectorBRAM[2][DMA.mySched.Command.DescAddr]))begin
             CorrectSched[CSpointer] = DMA.mySched.Command.DescAddr;
             CSpointer <= CSpointer + 1 ;
           end
           // if LastDescTrans and SB != BTS  or SB > BTS display Error 
           else if((DMA.mySched.Command.LastDescTrans & (TestVectorBRAM[3][DMA.mySched.Command.DescAddr] + DMA.mySched.Command.Length != TestVectorBRAM[2][DMA.mySched.Command.DescAddr]))| (TestVectorBRAM[3][DMA.mySched.Command.DescAddr] + DMA.mySched.Command.Length > TestVectorBRAM[2][DMA.mySched.Command.DescAddr]))begin
             $display("--Error :: Wrong Scheduling for Desc : %d (Not LastDescTrans or SB > BTS)",DMA.mySched.Command.DescAddr);
             $stop;
           end
         end
         else begin // if Expected ReadAddr is different from the real output ReadAddr display an Error
           $display("--ERROR :: Wrong ReadAddrOut or WriteAddrOut at Desc : %d, ExpReadAddr : %d , TrueReadAddr : %d" , DMA.mySched.Command.DescAddr,TestVectorBRAM[0][DMA.mySched.Command.DescAddr]+TestVectorBRAM[3][DMA.mySched.Command.DescAddr],DMA.mySched.Command.SrcAddr);
           $stop;
         end
       end
     end
   end
   //@@@@@@@@@@@@@@@@@@@@@@@@@ End of Scheduling Checking @@@@@@@@@@@@@@@@@@@@@@@@@
   
   
   //########################## Check CHI functionality ##########################
   //Sigs for Read Request FIFO
   wire     DequeueR        ;
   wire     ReqEmptyR       ;
   wire     ReqFULLR        ;
   ReqFlit  SigTXREQFLITR   ;
   //Sigs for Write Request FIFO
   wire     DequeueW        ;
   wire     ReqFULLW        ;
   wire     ReqEmptyW       ;
   ReqFlit  SigTXREQFLITW   ;
   //Sigs for Data Outbound FIFO                         
   wire     DataOutbFULL    ;
   wire     DataOutbEmpty   ;
   DataFlit SigTXDATFLIT    ;
   //Sigs for Data Inbound FIFO                         
   wire     DataInbFULL     ;
   wire     DataInbEmpty    ;
   DataFlit SigRXDATFLIT    ;
   //Sigs for Rsp Inbound FIFO                         
   wire     RspInbFULL      ;
   wire     RspInbEmpty     ;
   RspFlit  SigRXRSPFLIT    ;
   
   //---------------------Crd Manager--------------------------
   //Count the number of Credits on each channel and if a Transaction is 
   //attempted to happen without Credits
   
   //Credit Counters for each channel
    reg     [`CrdRegWidth      - 1 : 0] CountReqCrdsOutb  = 0  ; 
    reg     [`CrdRegWidth      - 1 : 0] CountDataCrdsOutb = 0  ;
    reg     [`CrdRegWidth      - 1 : 0] CountRspCrdsOutb  = 0  ;
    reg     [`CrdRegWidth      - 1 : 0] CountDataCrdsInb  = 0  ; 
    reg     [`CrdRegWidth      - 1 : 0] CountRspCrdsInb   = 0  ;
   //Count Converter's inbound Crds
    always_ff@(posedge Clk) begin
      if(RST)begin
        CountDataCrdsInb = 0 ;
        CountRspCrdsInb  = 0 ;
      end
      else begin
        if(DMA.DatInbChan.RXDATLCRDV & !DMA.DatInbChan.RXDATFLITV)
          CountDataCrdsInb <= CountDataCrdsInb + 1;
        else if(!DMA.DatInbChan.RXDATLCRDV & DMA.DatInbChan.RXDATFLITV)
          CountDataCrdsInb <= CountDataCrdsInb - 1;
        if(DMA.RspInbChan.RXRSPLCRDV & !DMA.RspInbChan.RXRSPFLITV) 
          CountRspCrdsInb <= CountRspCrdsInb + 1 ; 
        else if(!DMA.RspInbChan.RXRSPLCRDV & DMA.RspInbChan.RXRSPFLITV) 
          CountRspCrdsInb <= CountRspCrdsInb - 1; 
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
        if(DMA.DatOutbChan.TXDATLCRDV & !DMA.DatOutbChan.TXDATFLITV)
          CountDataCrdsOutb <= CountDataCrdsOutb + 1;
        else if(!DMA.DatOutbChan.TXDATLCRDV & DMA.DatOutbChan.TXDATFLITV)
          CountDataCrdsOutb <= CountDataCrdsOutb - 1;
        if(DMA.RspOutbChan.TXRSPLCRDV & !DMA.RspOutbChan.TXRSPFLITV) 
          CountRspCrdsOutb <= CountRspCrdsOutb + 1; 
        else if(!DMA.RspOutbChan.TXRSPLCRDV & DMA.RspOutbChan.TXRSPFLITV) 
          CountRspCrdsOutb <= CountRspCrdsOutb - 1; 
        if(DMA.ReqChan.TXREQLCRDV & !DMA.ReqChan.TXREQFLITV) 
          CountReqCrdsOutb <= CountReqCrdsOutb + 1; 
        else if(!DMA.ReqChan.TXREQLCRDV & DMA.ReqChan.TXREQFLITV) 
          CountReqCrdsOutb <= CountReqCrdsOutb - 1 ; 
      end
    end
    
    //Display Error when a Transaction is 
    //attempted to happen without Credits
    always_ff@(posedge Clk)begin
      if(DMA.ReqChan.TXREQFLITV & CountReqCrdsOutb == 0)begin
        $display("--Error :: There are no Crds to send a Request");
        $stop;
      end
      else if(DMA.DatOutbChan.TXDATFLITV & CountDataCrdsOutb == 0)begin
        $display("--Error :: There are no Crds to send Data");
        $stop;
      end
      else if(DMA.RspOutbChan.TXRSPFLITV & CountRspCrdsOutb == 0)begin
        $display("--Error :: There are no Crds to send a Rsp");
        $stop;
      end
      else if(DMA.DatInbChan.RXDATFLITV & CountDataCrdsInb == 0)begin
        $display("--Error :: There are no Crds to receive Data");
        $stop;
      end
      else if(DMA.RspInbChan.RXRSPFLITV & CountRspCrdsInb == 0)begin
        $display("--Error :: There are no Crds to receive Rsp");
        $stop;
      end
    end
    //---------------------END Crd Manager--------------------------
    
   //Test Cmnd FIFO Signals
   reg         DequeueCmnd   ;
   CHI_Command SigCommand    ;
   wire        SigCmndFULL   ;
   // Test Command FIFO : Each command that has been sheduled is enqueued in FIFO
   FIFO #(     
       .FIFO_WIDTH  ( COMMAND_WIDTH                                     ) ,       
       .FIFO_LENGTH ( 2*Test_FIFO_Length                                )     
   )TestCmndFIFO    (    
       .RST         ( RST                                               ) ,      
       .Clk         ( Clk                                               ) ,      
       .Inp         ( DMA.mySched.Command                               ) , 
       .Enqueue     ( DMA.mySched.IssueValid & !DMA.mySched.CmdFIFOFULL ) , 
       .Dequeue     ( DequeueCmnd                                       ) , 
       .Outp        ( SigCommand                                        ) , 
       .FULL        ( SigCmndFULL                                       ) , 
       .Empty       (                                                   ) 
       );
       
       
   // Read Req FIFO 
   ReqFlitFIFO #(     
       .FIFO_LENGTH ( 2*Test_FIFO_Length                                                                         )     
   )myRFIFOReq      (    
       .RST         ( RST                                                                                        ) ,      
       .Clk         ( Clk                                                                                        ) ,      
       .Inp         ( DMA.ReqChan.TXREQFLIT                                                                      ) , 
       .Enqueue     ( DMA.ReqChan.TXREQFLITV & DMA.ReqChan.TXREQFLIT.Opcode == `ReadOnce & CountReqCrdsOutb != 0 ) , 
       .Dequeue     ( DequeueR                                                                                   ) , 
       .Outp        ( SigTXREQFLITR                                                                              ) , 
       .FULL        ( ReqFULLR                                                                                   ) , 
       .Empty       ( ReqEmptyR                                                                                  ) 
       );
       
   // Write Req FIFO 
   ReqFlitFIFO #(     
       .FIFO_LENGTH ( 2*Test_FIFO_Length                                                                               )
   )myWFIFOReq      (     
       .RST         ( RST                                                                                              ) ,
       .Clk         ( Clk                                                                                              ) ,
       .Inp         ( DMA.ReqChan.TXREQFLIT                                                                            ) ,
       .Enqueue     ( DMA.ReqChan.TXREQFLITV & DMA.ReqChan.TXREQFLIT.Opcode == `WriteUniquePtl & CountReqCrdsOutb != 0 ) ,  
       .Dequeue     ( DequeueW                                                                                         ) ,
       .Outp        ( SigTXREQFLITW                                                                                    ) ,
       .FULL        ( ReqFULLW                                                                                         ) ,
       .Empty       ( ReqEmptyW                                                                                        ) 
       );
    
   // Outbound Data Rsp FIFO 
   FIFO #(                                                                                                                    
       .FIFO_WIDTH  ( DAT_FLIT_WIDTH                                                                                              ),
       .FIFO_LENGTH ( 2*Test_FIFO_Length                                                                                          )
   )myOutbDataFIFO  (                                                                                                             
       .RST         ( RST                                                                                                         ),
       .Clk         ( Clk                                                                                                         ),
       .Inp         ( DMA.DatOutbChan.TXDATFLIT                                                                                   ),
       .Enqueue     ( DMA.DatOutbChan.TXDATFLITV & DMA.DatOutbChan.TXDATFLIT.Opcode == `NonCopyBackWrData & CountDataCrdsOutb != 0),   
       .Dequeue     ( DequeueW                                                                                                    ),
       .Outp        ( SigTXDATFLIT                                                                                                ),
       .FULL        ( DataOutbFULL                                                                                                ),
       .Empty       ( DataOutbEmpty                                                                                               )
       );

   // Inbound Data Rsp FIFO 
   FIFO #(                                                                                                                    
       .FIFO_WIDTH  ( DAT_FLIT_WIDTH                                                                                   ),
       .FIFO_LENGTH ( 2*Test_FIFO_Length                                                                               )
   )myInbDataFIFO   (                                                                                                  
       .RST         ( RST                                                                                              ),
       .Clk         ( Clk                                                                                              ),
       .Inp         ( DMA.DatInbChan.RXDATFLIT                                                                         ),
       .Enqueue     ( DMA.DatInbChan.RXDATFLITV & DMA.DatInbChan.RXDATFLIT.Opcode == `CompData & CountDataCrdsInb != 0 ),   
       .Dequeue     ( DequeueR                                                                                         ),
       .Outp        ( SigRXDATFLIT                                                                                     ),
       .FULL        ( DataInbFULL                                                                                      ),
       .Empty       ( DataInbEmpty                                                                                     )
       );       
       
   // Inbound DBID Rsp FIFO 
   FIFO #(                                                                                                                    
       .FIFO_WIDTH  ( RSP_FLIT_WIDTH                                                                                                                                        ),
       .FIFO_LENGTH ( 2*Test_FIFO_Length                                                                                                                                    )
   )myInbDBIDFIFO   (                                                                                                                                                       
       .RST         ( RST                                                                                                                                                   ),
       .Clk         ( Clk                                                                                                                                                   ),
       .Inp         ( DMA.RspInbChan.RXRSPFLIT                                                                                                                              ),
       .Enqueue     ( DMA.RspInbChan.RXRSPFLITV & (DMA.RspInbChan.RXRSPFLIT.Opcode == `DBIDResp | DMA.RspInbChan.RXRSPFLIT.Opcode == `CompDBIDResp) & CountRspCrdsInb != 0  ),   
       .Dequeue     ( DequeueW                                                                                                                                              ),
       .Outp        ( SigRXRSPFLIT                                                                                                                                          ),
       .FULL        ( RspInbFULL                                                                                                                                            ),
       .Empty       ( RspInbEmpty                                                                                                                                           )
       );                                                                                                                                                                        
   
   
   // FIFOs should never be FULL because they are bigger than CHI_Responser 's FIFO and it wont give enough crds to make its FIFOs FULL    
   always_ff@(posedge Clk)begin
     if(SigCmndFULL | RspInbFULL | DataInbFULL | DataOutbFULL | ReqFULLW | ReqFULLR)begin
       $display("FIFIO FULL problem ...... " );
       $stop;
     end
   end
   
   //variable that counts the requested Bytes for each command
   int                              lengthCountR     = 0 ;
   int                              lengthCountW     = 0 ;
   wire [BRAM_COL_WIDTH - 1 : 0]    NextLengthCountR     ;
   wire [BRAM_COL_WIDTH - 1 : 0]    NextLengthCountW     ;
   
   assign NextLengthCountR = (lengthCountR == 0) ? ((SigCommand.Length <(CHI_DATA_WIDTH - SigCommand.SrcAddr[ADDR_WIDTH_OF_DATA - 1 : 0])) ? (SigCommand.Length) : (CHI_DATA_WIDTH - SigCommand.SrcAddr[ADDR_WIDTH_OF_DATA - 1 : 0])) : ((lengthCountR + CHI_DATA_WIDTH < SigCommand.Length) ? (lengthCountR + CHI_DATA_WIDTH) : (SigCommand.Length)) ;
   assign NextLengthCountW = (lengthCountW == 0) ? ((SigCommand.Length <(CHI_DATA_WIDTH - SigCommand.DstAddr[ADDR_WIDTH_OF_DATA - 1 : 0])) ? (SigCommand.Length) : (CHI_DATA_WIDTH - SigCommand.DstAddr[ADDR_WIDTH_OF_DATA - 1 : 0])) : ((lengthCountW + CHI_DATA_WIDTH < SigCommand.Length) ? (lengthCountW + CHI_DATA_WIDTH) : (SigCommand.Length)) ;
   //When Read Req and DataInb FIFOs are non-Empty the functionality of read transactions ha been checked so Dequeue these FIFOs
   assign DequeueR        = !DataInbEmpty & !ReqEmptyR & !RspInbEmpty & !DataOutbEmpty & !ReqEmptyW & ((NextLengthCountR == SigCommand.Length & NextLengthCountW == SigCommand.Length) | (NextLengthCountR != SigCommand.Length));
   //When Write Req , RspInb and DataOutb FIFOs are non-Empty the functionality of write transactions ha been checked so Dequeue these FIFOs
   assign DequeueW        = !RspInbEmpty & !DataOutbEmpty & !ReqEmptyW & !DataInbEmpty & !ReqEmptyR & ((NextLengthCountR == SigCommand.Length & NextLengthCountW == SigCommand.Length) | (NextLengthCountW != SigCommand.Length)) ;
   //When all of bytes of the command has been transfered and Dequeue Transaction-FIFOs then dequeue Command as well
   assign DequeueCmnd     = ((NextLengthCountR == SigCommand.Length & NextLengthCountW == SigCommand.Length) & DequeueR & DequeueW);
   
   // When all FIFOs are Non-Empty check if CHI-Transaction has been executed correctly 
   always_ff@(posedge Clk)begin
     // when a phase is over or Reset then reset vector that stores correct Transactions
     if(RST | (DMA.BS.EmptyCom & DMA.CHI_Conv.myCompleter.Empty & PhaseReqOver))begin
       CorrectTransfer <= '{default:0} ;
       CTpointer       <= 0            ;            
     end
     else begin
       if(DequeueR | DequeueW)begin
          //The Transactions are correct when Read is ReadOnce, the Read Address is the correct one , Response to Read is CompData ,
          //TxnID of response is the same with Request,Write transaction is WriteUniqueuePtl , it has the correct Address,
          //the Response for Write Request is DBIDResp or CompDBIDResp,TxnID of Write is tha same with Response,the outbound Data Rsp
          //is NonCopyBackWrData, its TxnID is the same with the DBID of the previous Response and BE is correct
          if((SigTXREQFLITR.Opcode == `ReadOnce & ((SigTXREQFLITR.Addr == (SigCommand.SrcAddr + lengthCountR) & lengthCountR!=0) | (SigTXREQFLITR.Addr == ({SigCommand.SrcAddr[BRAM_COL_WIDTH - 1 : ADDR_WIDTH_OF_DATA],{ADDR_WIDTH_OF_DATA{1'b0}}}) & lengthCountR == 0)))
          &(SigRXDATFLIT.Opcode == `CompData & (SigTXREQFLITR.TxnID == (SigRXDATFLIT.TxnID)))
          // if correct opcode and Addr of a Write Req and correct opcode ,TxnID of a DBID Rsp and correct Data Out Rsp opcode ,TxnID and BE then print correct
          &((SigTXREQFLITW.Opcode == `WriteUniquePtl & ((SigTXREQFLITW.Addr == (SigCommand.DstAddr + lengthCountW) & lengthCountW!=0) | (SigTXREQFLITW.Addr == ({SigCommand.DstAddr[BRAM_COL_WIDTH - 1 : ADDR_WIDTH_OF_DATA],{ADDR_WIDTH_OF_DATA{1'b0}}}) & lengthCountW == 0)))
          &(((SigRXRSPFLIT.Opcode == `DBIDResp) | (SigRXRSPFLIT.Opcode == `CompDBIDResp)) & (SigRXRSPFLIT.TxnID == (SigTXREQFLITW.TxnID)))
          &((SigTXDATFLIT.Opcode == `NonCopyBackWrData) & (SigRXRSPFLIT.DBID == SigTXDATFLIT.TxnID))))
            // correct BE
            if((NextLengthCountW == SigCommand.Length & (((SigCommand.Length < CHI_DATA_WIDTH) & (CHI_DATA_WIDTH - SigCommand.DstAddr[ADDR_WIDTH_OF_DATA - 1 : 0]) > SigCommand.Length) & (SigTXDATFLIT.BE == (({CHI_DATA_WIDTH{1'b1}}<<(SigCommand.DstAddr[ADDR_WIDTH_OF_DATA - 1 : 0])) & ~({CHI_DATA_WIDTH{1'b1}}<<(SigCommand.DstAddr[ADDR_WIDTH_OF_DATA - 1 : 0] + SigCommand.Length))))
            | SigTXDATFLIT.BE == ~({CHI_DATA_WIDTH{1'b1}}<<(NextLengthCountW - lengthCountW)))) 
            | SigTXDATFLIT.BE == ~({CHI_DATA_WIDTH{1'b1}}>>(NextLengthCountW - lengthCountW)))begin
             // Correct
             // if lastDescTrans update CorrectTransfer vector
              if(DequeueCmnd & SigCommand.LastDescTrans)begin
                CorrectTransfer[CTpointer] <= SigCommand.DescAddr;
                CTpointer                  <= CTpointer + 1      ;
              end
            end
            else begin
              // wrong Data Out BE
              $display("\n--Error :: BE is : %d , TxnID : %d",SigTXDATFLIT.BE ,SigTXDATFLIT.TxnID);
              $stop;              
            end
          // if Wrong Read Opcode print Error
          else if(SigTXREQFLITR.Opcode != `ReadOnce)begin
            $display("\n--ERROR :: ReadReq Opcode is not %d , TxnID : %d",SigTXREQFLITR.TxnID , `ReadOnce);
            $stop;
          end
          // if Wrong Read Addr print Error
          else if((SigTXREQFLITR.Addr != (SigCommand.SrcAddr + lengthCountR) | lengthCountR==0) & (SigTXREQFLITR.Addr != ({SigCommand.SrcAddr[BRAM_COL_WIDTH - 1 : ADDR_WIDTH_OF_DATA],{ADDR_WIDTH_OF_DATA{1'b0}}}) | lengthCountR != 0))begin
            $display("\n--ERROR :: Requested ReadAddr is : %d but it should be %d , TxnID : %d",SigTXREQFLITR.Addr ,(lengthCountR!=0 ) ? (SigCommand.SrcAddr + lengthCountR) : ({SigCommand.SrcAddr[BRAM_COL_WIDTH - 1 : ADDR_WIDTH_OF_DATA],{ADDR_WIDTH_OF_DATA{1'b0}}}) ,SigTXREQFLITR.TxnID);
            $stop;
          end
          // if Wrong Data Rsp Opcode print Error
          else if(SigRXDATFLIT.Opcode != `CompData)begin
            $display("\n--ERROR :: DataRsp Opcode is not CompData , TxnID : %d",SigRXDATFLIT.TxnID);
            $stop;
          end
          // if Wrong Data Rsp TxnID print Error
          else if(SigTXREQFLITR.TxnID != (SigRXDATFLIT.TxnID)) begin
            $display("\n--ERROR :: DataRsp TxnID :%d is not the same with ReadReq TxnID :%d",SigTXREQFLITR.TxnID ,SigRXDATFLIT.TxnID);
            $stop;
          end
          // Wrong Write Opcode
          else if(SigTXREQFLITW.Opcode != `WriteUniquePtl)begin
            $display("\n--ERROR :: WriteReq Opcode is not WriteUniquePtl");
            $stop;
          end
          // Wrong Write Addr
          else if((SigTXREQFLITW.Addr != (SigCommand.DstAddr + lengthCountW) | lengthCountW == 0) & (SigTXREQFLITW.Addr != ({SigCommand.DstAddr[BRAM_COL_WIDTH - 1 : ADDR_WIDTH_OF_DATA],{ADDR_WIDTH_OF_DATA{1'b0}}}) | lengthCountW != 0))begin
            $display("\n--ERROR :: Requested WriteAddr is : %d but it should be %d ,TxnID : %d",SigTXREQFLITW.Addr,(lengthCountW!=0 ) ? (SigCommand.DstAddr + lengthCountW) : ({SigCommand.DstAddr[BRAM_COL_WIDTH - 1 : ADDR_WIDTH_OF_DATA],{ADDR_WIDTH_OF_DATA{1'b0}}})  ,SigTXREQFLITW.TxnID);
            $stop;
          end
          // Wrong DBID Rsp Opcode
          else if(SigRXRSPFLIT.Opcode != `DBIDResp & SigRXRSPFLIT.Opcode != `CompDBIDResp )begin
            $display("\n--ERROR :: DataRsp Opcode is not DBIDResp or CompDBIDResp");
            $stop;
          end
          // Wrong TxnID Rsp Opcode
          else if(SigRXRSPFLIT.TxnID != (SigTXREQFLITW.TxnID)) begin
            $display("\n--ERROR :: DBIDRsp TxnID :%d is not the same with WriteReq TxnID :%d",SigRXRSPFLIT.TxnID ,SigTXREQFLITW.TxnID);
            $stop;
          end
          // Wrong Data Out Opcode
          else if(SigTXDATFLIT.Opcode != `NonCopyBackWrData) begin
            $display("\n--ERROR :: Data In Opcode is not NonCopyBackWrData");
            $stop;
          end
          // Wrong Data Out TxnID
          else begin
            $display("\n--ERROR :: DBIDRsp DBID :%d is not the same with Data Out DBID :%d",SigRXRSPFLIT.DBID , SigTXDATFLIT.TxnID);
            $stop;
          end
          
          // update command read Requested Bytes
          if(NextLengthCountR < SigCommand.Length)begin
            lengthCountR <= NextLengthCountR ;
          end
          else if((NextLengthCountR == SigCommand.Length) &(NextLengthCountW == SigCommand.Length)) begin
            lengthCountR <= 0 ;
          end
          // update command write Requested Bytes
          if(NextLengthCountW < SigCommand.Length)begin
            lengthCountW <= NextLengthCountW ;
          end
          else if((NextLengthCountR == SigCommand.Length) & (NextLengthCountW == SigCommand.Length)) begin
            lengthCountW <= 0 ;
          end
       end
     end
   end
   
   //Check for double used TxnID every time a new Request happens
   //When a Request happens check if there is the same TxnId inside Read or Write Req FIFO
   //and the corresponding response has not been arrived . If there is a double use TxnID
   //print an Error message
   always@(negedge Clk)begin
     #(period/2);
     if(myRFIFOReq.Enqueue | myWFIFOReq.Enqueue) begin
       for(int i = 0 ; i < 2*Test_FIFO_Length & (myRFIFOReq.MyQueue[i] != 0 | myWFIFOReq.MyQueue[i] != 0) ; i++ )begin
         // if there is a Request with the same TxnID in ReadReqFIFO and the corresponding DataRsp hasnt arrived the print error. (MyQueue[i][REQ_FLIT_WIDTH - 19 : REQ_FLIT_WIDTH - 19 - 7] is TxnID of i element )
         if(ReqChan.TXREQFLIT.TxnID == myRFIFOReq.MyQueue[i][REQ_FLIT_WIDTH - 19 : REQ_FLIT_WIDTH - 19 - 7] & myRFIFOReq.MyQueue[i] != 0 & myInbDataFIFO.MyQueue[i] == 0)begin
           $display("\n--ERROR :: TXNID : %d is already used for ReadReq : %p ", ReqChan.TXREQFLIT.TxnID,myRFIFOReq.MyQueue[i][REQ_FLIT_WIDTH - 19 : REQ_FLIT_WIDTH - 19 - 7]);
           $stop;
         end
         // if there is a Request with the same TxnID in WriteReqFIFO and the corresponding DBIDRsp hasnt arrived the print error. (MyQueue[i][REQ_FLIT_WIDTH - 19 : REQ_FLIT_WIDTH - 19 - 7] is TxnID of i element )
         else if(ReqChan.TXREQFLIT.TxnID == myWFIFOReq.MyQueue[i][REQ_FLIT_WIDTH - 19 : REQ_FLIT_WIDTH - 19 - 7] & myWFIFOReq.MyQueue[i] != 0 & myInbDBIDFIFO.MyQueue[i] == 0)begin
           $display("\n--ERROR :: TXNID : %d is already used for WriteReq : %p", ReqChan.TXREQFLIT.TxnID,myWFIFOReq.MyQueue[i]);
           $stop;
         end
       end
     end
   end
   
   //########################## End of CHI functionality Checking ##########################
   
   
   //********************************* DISPLAY THE CORRECT TRANS *********************************
   // When All Transactions has Finished Print the correct ones   
   int                           lastCheckPointer  = 0 ;
   int                           NZ                = 0 ; // used to count Non-Zero Finished Descriptors
   always_ff@(posedge Clk)begin 
     // if Empty AddrFIFO and Empty CommandFIFO and empty completer FIFO (All Desc have been scheduled)
     // check if every Desc is fully scheduled
     if(DMA.AddrPointerFIFO.Empty & DMA.CHI_Conv.SigCommandEmpty & DMA.CHI_Conv.myCompleter.Empty & CSpointer != lastCheckPointer)begin
       lastCheckPointer <= CSpointer ;
       for(int i = 0 ; i < 2**BRAM_ADDR_WIDTH ; i++)begin
        //if for some reason a Descriptor is written but BTS != SB or lastDescAddr == 0 (not Fully sheduled)
         if((TestVectorBRAM[3][i] != TestVectorBRAM[2][i] | TestVectorBRAM[4][i] == 0) & TestVectorBRAM[2][i] != 0 )begin
           $display("Desc : %d is not fully scheduled BTS : %d , SB : %D , LastDescTrans : %d", i,TestVectorBRAM[2][i],TestVectorBRAM[3][i],TestVectorBRAM[4][i]);
           $stop;
         end
       end
       if(((PhaseIn  == 1 & CSpointer == P1_NUM_OF_TRANS) | (PhaseIn  == 2 & CSpointer == P2_NUM_OF_TRANS) | (PhaseIn  == 3 & CSpointer == P3_NUM_OF_TRANS) | (PhaseIn  == 4 & CSpointer == P4_NUM_OF_TRANS) |(PhaseIn  == 5 & CSpointer == P5_NUM_OF_TRANS) | (PhaseIn  == 6 & CSpointer == P6_NUM_OF_TRANS) | (PhaseIn  == 7 & CSpointer == P7_NUM_OF_TRANS) | (PhaseIn  == 8 & CSpointer == P8_NUM_OF_TRANS) | (PhaseIn  == 9 & CSpointer == P9_NUM_OF_TRANS)))begin
         $display("All Descriptors are Fully scheduled ");
       end
     end
     
     // If All CHI_Transactions have been finished and all BRAM Status have been updated in each Phase
     if(PhaseReqOver & DMA.CHI_Conv.myCompleter.Empty & DMA.BS.EmptyCom)begin
       $display("------------------------PHASE : %d------------------------",PhaseIn);
       // -------Check if state of BRAM is correct-------
       for(int i = 0 ; i < 2**BRAM_ADDR_WIDTH ; i++)begin
         static bit errFlag = 0;
         // if BTS != SB or Status != Error or Idle problem... print error     
         if(DMA.myBRAM.ram_block[i][BRAM_COL_WIDTH*3 - 1 : BRAM_COL_WIDTH*2] != 0 &(DMA.myBRAM.ram_block[i][BRAM_COL_WIDTH*3 - 1 : BRAM_COL_WIDTH*2] != DMA.myBRAM.ram_block[i][BRAM_COL_WIDTH*4 - 1 : BRAM_COL_WIDTH*3] | (DMA.myBRAM.ram_block[i][BRAM_COL_WIDTH*5 - 1 : BRAM_COL_WIDTH*4] != `StatusIdle & DMA.myBRAM.ram_block[i][BRAM_COL_WIDTH*5 - 1 : BRAM_COL_WIDTH*4] != `StatusError)))begin
           $display("BRAM BTS :%d != SB : %d or Wrong Status : %d", DMA.myBRAM.ram_block[i][BRAM_COL_WIDTH*3 - 1 : BRAM_COL_WIDTH*2],DMA.myBRAM.ram_block[i][BRAM_COL_WIDTH*4 - 1 : BRAM_COL_WIDTH*3], DMA.myBRAM.ram_block[i][BRAM_COL_WIDTH*5 - 1 : BRAM_COL_WIDTH*4]);
           errFlag = 1 ;
           $stop;
         end 
         else if (i == 2**BRAM_ADDR_WIDTH - 1 & !errFlag)
           $display("Correct BRAM :: BTS=SB and correct Status");
       end
       // -------------------------------------------------
       CTpointer           <= 0 ;
       CorrectTransfer.sort   ();//sysVerilog methods for sorting
       CorrectSched   .sort   ();
       CorrectTransfer.reverse();
       CorrectSched   .reverse();
       NZ = 1 ;
       for(int i = 0 ; i < P6_NUM_OF_TRANS ; i++)begin
         if(CorrectSched[i] != 0)begin
           $write  ("%d Correct Sheduled Desc : %d",NZ , CorrectSched[i]);
           $display("!!Correct Transfer for Desc : %d",CorrectTransfer[i]);
           NZ = NZ + 1 ;
         end
       end
       $display("----------------------------------------------------------",);
     end
   end
//***********************************************************************************************
endmodule
