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
  parameter BRAM_NUM_COL     = 8     , // As the Data_packet fields
  parameter BRAM_COL_WIDTH   = 32    , // As the Data_packet field width
  parameter BRAM_ADDR_WIDTH  = 10    , // Addr Width in bits : 2 **BRAM_ADDR_WIDTH = RAM Depth
  parameter CHI_DATA_WIDTH   = 64    ,
  parameter MAX_BytesToSend  = 5000  ,
  parameter P1_NUM_OF_TRANS   = 1    , // Number of inserted transfers for each phase
  parameter P2_NUM_OF_TRANS   = 1    ,  
  parameter P3_NUM_OF_TRANS   = 30   ,  
  parameter P4_NUM_OF_TRANS   = 5    ,  
  parameter P5_NUM_OF_TRANS   = 25   ,  
  parameter P6_NUM_OF_TRANS   = 150  ,                            
  parameter PHASE_WIDTH       = 3    , // width of register that keeps the phase
  parameter Test_FIFO_Length = 120 
//--------------------------------------------------------------------------
);

  reg  Clk  ;
  reg  RST  ;

  wire         [BRAM_NUM_COL    - 1 : 0]  weA            ;
  wire         [BRAM_ADDR_WIDTH - 1 : 0]  addrA          ;
  Data_packet                             dinA           ;
  Data_packet                             BRAMdoutA      ; 
  reg           [PHASE_WIDTH    - 1 : 0]  PhaseIn       ;
  reg                                     NewPhase      ;
  ReqChannel                              ReqChan     () ;
  RspOutbChannel                          RspOutbChan () ;
  DatOutbChannel                          DatOutbChan () ;
  RspInbChannel                           RspInbChan  () ;
  DatInbChannel                           DatInbChan  () ; 

 
  
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
   .P1_NUM_OF_TRANS    (P1_NUM_OF_TRANS  ),
   .P2_NUM_OF_TRANS    (P2_NUM_OF_TRANS  ),
   .P3_NUM_OF_TRANS    (P3_NUM_OF_TRANS  ),
   .P4_NUM_OF_TRANS    (P4_NUM_OF_TRANS  ),
   .P5_NUM_OF_TRANS    (P5_NUM_OF_TRANS  ),
   .P6_NUM_OF_TRANS    (P6_NUM_OF_TRANS  ),
   .MAX_BytesToSend    (MAX_BytesToSend  )
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
 
   Simple_CHI_Responser#(
     .FIFO_Length(Test_FIFO_Length)
   ) CHI_RSP  (
     .Clk                 (Clk                     ) ,
     .RST                 (RST                     ) ,
     .ReqChan             (ReqChan      .INBOUND   ) ,
     .RspOutbChan         (RspOutbChan  .INBOUND   ) ,
     .DatOutbChan         (DatOutbChan  .INBOUND   ) ,
     .RspInbChan          (RspInbChan   .OUTBOUND  ) ,
     .DatInbChan          (DatInbChan   .OUTBOUND  )  
    );
       
   // Fully correctly transfered Descriptors
   reg [BRAM_ADDR_WIDTH - 1 : 0] CorrectTransfer  [P6_NUM_OF_TRANS - 1 : 0] ;
   int                           CTpointer        = 0                       ;

   // Fully correctly scheduled Descriptors
   reg [BRAM_ADDR_WIDTH - 1 : 0] CorrectSched    [P6_NUM_OF_TRANS - 1 : 0]  ;
   int                           CSpointer       = 0                        ;
   wire                          PhaseReqOver                               ;
   
   assign PhaseReqOver = ((PhaseIn  == 1 & CTpointer == P1_NUM_OF_TRANS) | (PhaseIn  == 2 & CTpointer == P2_NUM_OF_TRANS) | (PhaseIn  == 3 & CTpointer == P3_NUM_OF_TRANS) | (PhaseIn  == 4 & CTpointer == P4_NUM_OF_TRANS) |(PhaseIn  == 5 & CTpointer == P5_NUM_OF_TRANS) | (PhaseIn  == 6 & CTpointer == P6_NUM_OF_TRANS));
   
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
       if(PhaseIn  == 0)begin
         PhaseIn  = 1 ;
         NewPhase = 1 ;   
         #(period*2)  ;   
         NewPhase = 0 ;   
         #(period)    ;    
       end
       else if((PhaseIn  == 1 & CTpointer == P1_NUM_OF_TRANS) & DMA.CHI_Conv.SigSizeEmpty & DMA.CHI_Conv.myCompleter.Empty)begin
         PhaseIn  = 2 ;
         NewPhase = 1 ;     
         #(period*2)  ; 
         NewPhase = 0 ;   
         #(period)    ;    
       end
       else if((PhaseIn  == 2 & CTpointer == P2_NUM_OF_TRANS) & DMA.CHI_Conv.SigSizeEmpty & DMA.CHI_Conv.myCompleter.Empty)begin
         PhaseIn  = 3 ;
         NewPhase = 1 ;     
         #(period*2)  ;   
         NewPhase = 0 ;   
         #(period)    ;    
       end
       else if((PhaseIn  == 3 & CTpointer == P3_NUM_OF_TRANS) & DMA.CHI_Conv.SigSizeEmpty & DMA.CHI_Conv.myCompleter.Empty)begin
         PhaseIn  = 4 ;
         NewPhase = 1 ;    
         #(period*2)  ;   
         NewPhase = 0 ;   
         #(period)    ;    
       end
       else if((PhaseIn  == 4 & CTpointer == P4_NUM_OF_TRANS) & DMA.CHI_Conv.SigSizeEmpty & DMA.CHI_Conv.myCompleter.Empty)begin
         PhaseIn  = 5 ;
         NewPhase = 1 ;   
         #(period*2)  ;   
         NewPhase = 0 ;   
         #(period)    ;    
       end
       else if((PhaseIn  == 5 & CTpointer == P5_NUM_OF_TRANS) & DMA.CHI_Conv.SigSizeEmpty & DMA.CHI_Conv.myCompleter.Empty)begin
         PhaseIn  = 6 ;
         NewPhase = 1 ;   
         #(period*2)  ;   
         NewPhase = 0 ;   
         #(period)    ;    
       end
       else if((PhaseIn  == 6 & CTpointer == P6_NUM_OF_TRANS) & DMA.CHI_Conv.SigSizeEmpty & DMA.CHI_Conv.myCompleter.Empty)begin
         PhaseIn  = 6 ;
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

   always_ff@(posedge Clk) begin
     if(RST | (DMA.CHI_Conv.SigSizeEmpty & DMA.CHI_Conv.myCompleter.Empty & PhaseReqOver))begin
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
         // if ReadAddr in command is SrcAddr+SB and WriteAddr = DstAddr + SB
         if((TestVectorBRAM[0][DMA.mySched.Command.DescAddr] + TestVectorBRAM[3][DMA.mySched.Command.DescAddr] == DMA.mySched.Command.SrcAddr) & (TestVectorBRAM[1][DMA.mySched.Command.DescAddr] + TestVectorBRAM[3][DMA.mySched.Command.DescAddr] == DMA.mySched.Command.DstAddr))begin
           TestVectorBRAM[3][DMA.mySched.Command.DescAddr] <= TestVectorBRAM[3][DMA.mySched.Command.DescAddr] + DMA.mySched.Command.Length ;
           TestVectorBRAM[4][DMA.mySched.Command.DescAddr] <= DMA.mySched.Command.LastDescTrans ;
           // if LastDescTrans and SB == BTS display correct scheduling
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
   wire                          Dequeue                                    ;
   wire                          ReqEmptyR                                  ;
   wire                          ReqFULLR                                   ;
   ReqFlit                       SigTXREQFLITR                              ;
                                                                            ;
   wire                          ReqFULLW                                   ;
   wire                          ReqEmptyW                                  ;
   ReqFlit                       SigTXREQFLITW                              ;
                                                                            ;
   wire                          DataOutbFULL                               ;
   wire                          DataOutbEmpty                              ;
   DataFlit                      SigTXDATFLIT                               ;
                                                                            ;
   wire                          DataInbFULL                                ;
   wire                          DataInbEmpty                               ;
   DataFlit                      SigRXDATFLIT                               ;
                                                                            ;
   wire                          RspInbFULL                                 ;
   wire                          RspInbEmpty                                ;
   RspFlit                       SigRXRSPFLIT                               ;
   
   //---------------------Crd Manager--------------------------
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
   // Test Command FIFO 
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
       .FULL        (                                                   ) , 
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
       .Dequeue     ( Dequeue                                                                                    ) , 
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
       .Dequeue     ( Dequeue                                                                                          ) ,
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
       .Dequeue     ( Dequeue                                                                                                     ),
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
       .Dequeue     ( Dequeue                                                                                          ),
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
       .Dequeue     ( Dequeue                                                                                                                                               ),
       .Outp        ( SigRXRSPFLIT                                                                                                                                          ),
       .FULL        ( RspInbFULL                                                                                                                                            ),
       .Empty       ( RspInbEmpty                                                                                                                                           )
       );                                                                                                                                                                        
   
   
   // FIFOs should never be FULL because they are bigger than CHI_Responser 's FIFO and it wont give enough crds to make its FIFOs FULL    
   always_ff@(posedge Clk)begin
     if(RspInbFULL | DataInbFULL | DataOutbFULL | ReqFULLW | ReqFULLR)begin
       $display("FIFIO FULL problem ...... " );
       $stop;
     end
   end
   
   int    lengthCount = 0;
   
   assign Dequeue     = !RspInbEmpty & !DataInbEmpty & !DataOutbEmpty & !ReqEmptyW & !ReqEmptyR ;
   assign DequeueCmnd = ((lengthCount + CHI_DATA_WIDTH >= SigCommand.Length) & Dequeue) ? 1 : 0 ;
   // When all FIFOs is Non-Empty check if CHI-Transaction has been executed correctly 
   always_ff@(posedge Clk)begin
     if(RST | (DMA.CHI_Conv.SigSizeEmpty & DMA.CHI_Conv.myCompleter.Empty & PhaseReqOver))begin
       CorrectTransfer <= '{default:0} ;
       CTpointer       <= 0            ;            
     end
     else begin
       if(Dequeue)begin
          if((SigTXREQFLITR.Opcode == `ReadOnce & (SigTXREQFLITR.Addr == (SigCommand.SrcAddr + lengthCount)))
          &(SigRXDATFLIT.Opcode == `CompData & (SigTXREQFLITR.TxnID == (SigRXDATFLIT.TxnID)))
          // if correct opcode and Addr of a Write Req and correct opcode TxnID of a DBID Rsp and correct Data Out Rsp opcode ,TxnID and BE then print correct
          &((SigTXREQFLITW.Opcode == `WriteUniquePtl & (SigTXREQFLITW.Addr == (SigCommand.DstAddr + lengthCount)))
          &(((SigRXRSPFLIT.Opcode == `DBIDResp) | (SigRXRSPFLIT.Opcode == `CompDBIDResp)) & (SigRXRSPFLIT.TxnID == (SigTXREQFLITW.TxnID)))
          &((SigTXDATFLIT.Opcode == `NonCopyBackWrData) & (SigRXRSPFLIT.DBID == SigTXDATFLIT.TxnID))))
            if(SigTXDATFLIT.BE != ~({CHI_DATA_WIDTH{1'b1}} << (SigCommand.Length - lengthCount)))begin
             // wrong Data Out BE
              $display("\n--Error :: BE is : %d and it should be :%d , TxnID : %d",SigTXDATFLIT.BE , ~({CHI_DATA_WIDTH{1'b1}} << (SigCommand.Length - lengthCount)),SigTXDATFLIT.TxnID);
              $stop;
            end
            else begin
              // Correct
              if(DequeueCmnd & SigCommand.LastDescTrans)begin
                CorrectTransfer[CTpointer] <= SigCommand.DescAddr;
                CTpointer                  <= CTpointer + 1      ;
              end
            end
          // if Wrong Read Opcode print Error
          else if(SigTXREQFLITR.Opcode != `ReadOnce)begin
            $display("\n--ERROR :: ReadReq Opcode is not %d , TxnID : %d",SigTXREQFLITR.TxnID , `ReadOnce);
            $stop;
          end
          // if Wrong Read Addr print Error
          else if(SigTXREQFLITR.Addr != (SigCommand.SrcAddr + lengthCount))begin
            $display("\n--ERROR :: Requested ReadAddr is : %d , but it should be : %d , TxnID : %d",SigTXREQFLITR.Addr ,(SigCommand.SrcAddr + lengthCount),SigTXREQFLITR.TxnID);
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
          else if(SigTXREQFLITW.Addr != (SigCommand.DstAddr + lengthCount))begin
            $display("\n--ERROR :: Requested WriteAddr is : %d , but it should be : %d",SigTXREQFLITW.Addr ,SigCommand.DstAddr + lengthCount);
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
          
          // update command Requested Bytes
          if(lengthCount + CHI_DATA_WIDTH < SigCommand.Length)begin
            lengthCount <= lengthCount + CHI_DATA_WIDTH ;
          end
          else begin
            lengthCount <= 0 ;
          end
       end
     end
   end
   //Check for double used TxnID every time a new Request happens 
   always_ff@(posedge Clk)begin
     if(myRFIFOReq.Enqueue | myWFIFOReq.Enqueue) begin
       automatic int i = 0 ;
       while(i < 2*Test_FIFO_Length & (myRFIFOReq.MyQueue[i] != 0 | myWFIFOReq.MyQueue[i] != 0))begin
         // if there is a Request with the same TxnID in ReadReqFIFO and the corresponding DataRsp hasnt arrived the print error
         if(CHI_RSP.ReqChan.TXREQFLIT.TxnID == myRFIFOReq.MyQueue[i].TxnID & myRFIFOReq.MyQueue[i] != 0 & myInbDataFIFO.MyQueue[i] == 0)begin
           $display("\n--ERROR :: TXNID : %d is already used for ReadReq ", CHI_RSP.ReqChan.TXREQFLIT.TxnID);
           $stop;
         end
         // if there is a Request with the same TxnID in WriteReqFIFO and the corresponding DBIDRsp hasnt arrived the print error
         else if(CHI_RSP.ReqChan.TXREQFLIT.TxnID == myWFIFOReq.MyQueue[i].TxnID & myWFIFOReq.MyQueue[i] != 0 & myInbDBIDFIFO.MyQueue[i] == 0)begin
           $display("\n--ERROR :: TXNID : %d is already used for WriteReq", CHI_RSP.ReqChan.TXREQFLIT.TxnID);
           $stop;
         end
         i++;
       end
     end
   end
   
   //########################## End of CHI functionality Checking ##########################
   
   
   //********************************* DISPLAY THE CORRECT TRANS *********************************
   // When All Transactions has Finished Print the correct ones   
   reg [BRAM_ADDR_WIDTH - 1 : 0] helpVect              ;
   int                           lastCheckPointer  = 0 ;
   int                           NZ                = 0 ; // used to count Non-Zero Finished Descriptors
   always_ff@(posedge Clk)begin 
     // if Empty AddrFIFO and Empty CommandFIFO(All Desc have been scheduled)
     // check if every Desc is fully scheduled
     if(DMA.AddrPointerFIFO.Empty & DMA.CHI_Conv.SigCommandEmpty & CSpointer != lastCheckPointer)begin
       lastCheckPointer <= CSpointer ;
       for(int i = 0 ; i < 2**BRAM_ADDR_WIDTH ; i++)begin
        //if for some reason a Descriptor is written but BTS != SB or lastDescAddr == 0 (not Fully sheduled)
         if((TestVectorBRAM[3][i] != TestVectorBRAM[2][i] | TestVectorBRAM[4][i] == 0) & TestVectorBRAM[2][i] != 0 )begin
           $display("Desc : %d is not fully scheduled", i);
           $stop;
         end
       end
       if(((PhaseIn  == 1 & CSpointer == P1_NUM_OF_TRANS) | (PhaseIn  == 2 & CSpointer == P2_NUM_OF_TRANS) | (PhaseIn  == 3 & CSpointer == P3_NUM_OF_TRANS) | (PhaseIn  == 4 & CSpointer == P4_NUM_OF_TRANS) |(PhaseIn  == 5 & CSpointer == P5_NUM_OF_TRANS) | (PhaseIn  == 6 & CSpointer == P6_NUM_OF_TRANS)))begin
         $display("All Descriptors are Fully scheduled ");
       end
     end
     
     // If All CHI_Transactions have been finished and all BRAM Status have been updated
     if(PhaseReqOver & DMA.CHI_Conv.myCompleter.Empty & DMA.CHI_Conv.SigSizeEmpty)begin
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
       $display("------------------------PHASE : %d------------------------",PhaseIn);
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
