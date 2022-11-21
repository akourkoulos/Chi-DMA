`timescale 1ns / 1ps
import DataPkg    ::*;
import CHIFlitsPkg::*; 
import CHIFIFOsPkg::*;
////////////////////import DataPkg::*;//////////////////////////////////////////////////////////////
// Company:         import CHIFlitsPkg::*; 
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

`define MaxCrds           15

`define StatusError       2

module TestFULLSystem#(
//--------------------------------------------------------------------------
  parameter BRAM_NUM_COL     = 8     , // As the Data_packet fields
  parameter BRAM_COL_WIDTH   = 32    , // As the Data_packet field width
  parameter BRAM_ADDR_WIDTH  = 10    , // Addr Width in bits : 2 **BRAM_ADDR_WIDTH = RAM Depth
  parameter CHI_DATA_WIDTH   = 64    ,
  parameter MAX_BytesToSend  = 5000  ,
  parameter NUM_OF_TRANS     = 250   ,
  parameter Test_FIFO_Length = 120 
//--------------------------------------------------------------------------
);

  reg  Clk  ;
  reg  RST  ;

  wire         [BRAM_NUM_COL    - 1 : 0]  weA            ;
  wire         [BRAM_ADDR_WIDTH - 1 : 0]  addrA          ;
  Data_packet                             dinA           ;
  wire                                    ValidArbIn     ;
  wire                                    ReadyArbProc   ;
  Data_packet                             BRAMdoutA      ;
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
     .ValidArbIn   (ValidArbIn   ) ,
     .ReadyArbProc (ReadyArbProc ) ,
     .BRAMdoutA    (BRAMdoutA    ) ,
     .ReqChan      (ReqChan      ) ,
     .RspOutbChan  (RspOutbChan  ) ,
     .DatOutbChan  (DatOutbChan  ) ,
     .RspInbChan   (RspInbChan   ) ,
     .DatInbChan   (DatInbChan   )   
    );
    
    
   PseudoCPU #(
   .NUM_OF_TRANS    (NUM_OF_TRANS   ),
   .MAX_BytesToSend (MAX_BytesToSend)
   )myCPU(
     .RST          (RST          ) ,
     .Clk          (Clk          ) ,
     .ReadyArbProc (ReadyArbProc ) ,
     .BRAMdoutA    (BRAMdoutA    ) ,
     .weA          (weA          ) ,
     .addrA        (addrA        ) ,
     .dinA         (dinA         ) ,
     .ValidArbIn   (ValidArbIn   )  
    );
 
   CHI_Responser#(
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
  
   //@@@@@@@@@@@@@@@@@@@@@@@@@ Check of Scheduling  @@@@@@@@@@@@@@@@@@@@@@@@@
   // Vector that keeps information for ckecking the operation of module
   reg [BRAM_COL_WIDTH - 1 : 0]TestVectorBRAM[5 - 1 : 0][2**BRAM_ADDR_WIDTH - 1 : 0] ; // first dimention 0 : SrcAddr , 1 : DstAddr, 2 : BTS, 3 : SB, 4 : LastDescValid
   
   always_ff@(posedge Clk) begin
     if(RST)begin
       TestVectorBRAM     <= '{default:0};
     end
     else begin
       if(weA != 0 & ReadyArbProc & ValidArbIn)begin  // when store someting in Descriptor update TestVector's SrcAddr ,DstAddr ,BTS fields
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
             $display(" CORRECT Scheduling for Desc : %d",DMA.mySched.Command.DescAddr);
           end
           // if LastDescTrans and SB != BTS  or SB > BTS display Error 
           else if((DMA.mySched.Command.LastDescTrans & (TestVectorBRAM[3][DMA.mySched.Command.DescAddr] + DMA.mySched.Command.Length != TestVectorBRAM[2][DMA.mySched.Command.DescAddr]))| (TestVectorBRAM[3][DMA.mySched.Command.DescAddr] + DMA.mySched.Command.Length > TestVectorBRAM[2][DMA.mySched.Command.DescAddr]))begin
             $display("--Error :: Wrong Scheduling for Desc : %d (Not LastDescTrans or SB > BTS)",DMA.mySched.Command.DescAddr);
             $stop;
           end
         end
         else begin // if Expected ReadAddr is different from the real output ReadAddr display an Error
           $display("--ERROR :: Wrong ReadAddrOut or WriteAddrOut at Addr : %d, ExpReadAddr : %d , TrueReadAddr : %d" , DMA.mySched.Command.DescAddr,TestVectorBRAM[0][DMA.mySched.Command.DescAddr]+TestVectorBRAM[3][DMA.mySched.Command.DescAddr],DMA.mySched.Command.SrcAddr);
           $stop;
         end
       end
     end
   end
   //@@@@@@@@@@@@@@@@@@@@@@@@@ End of Scheduling Checking @@@@@@@@@@@@@@@@@@@@@@@@@
   
   
   //########################## Check CHI functionality ##########################
   int                           CTpointer        = 0                    ;
   reg [BRAM_ADDR_WIDTH - 1 : 0] CorrectTransfer  [NUM_OF_TRANS - 1 : 0] ;
   wire                          Dequeue                                 ;
   wire                          ReqEmptyR                               ;
   wire                          ReqFULLR                                ;
   ReqFlit                       SigTXREQFLITR                           ;
                                                                         ;
   wire                          ReqFULLW                                ;
   wire                          ReqEmptyW                               ;
   ReqFlit                       SigTXREQFLITW                           ;
                                                                         ;
   wire                          DataOutbFULL                            ;
   wire                          DataOutbEmpty                           ;
   DataFlit                      SigTXDATFLIT                            ;
                                                                         ;
   wire                          DataInbFULL                             ;
   wire                          DataInbEmpty                            ;
   DataFlit                      SigRXDATFLIT                            ;
                                                                         ;
   wire                          RspInbFULL                              ;
   wire                          RspInbEmpty                             ;
   RspFlit                       SigRXRSPFLIT                            ;
   
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
       .FIFO_LENGTH ( 2*Test_FIFO_Length                                                                     )     
   )myRFIFOReq      (     
       .RST         ( RST                                                                                    ) ,      
       .Clk         ( Clk                                                                                    ) ,      
       .Inp         ( CHI_Responser.ReqChan.TXREQFLIT                                                        ) , 
       .Enqueue     ( CHI_Responser.ReqChan.TXREQFLITV & CHI_Responser.ReqChan.TXREQFLIT.Opcode == `ReadOnce ) , 
       .Dequeue     ( Dequeue                                                                                ) , 
       .Outp        ( SigTXREQFLITR                                                                          ) , 
       .FULL        ( ReqFULLR                                                                               ) , 
       .Empty       ( ReqEmptyR                                                                              ) 
       );
       
   // Write Req FIFO 
   ReqFlitFIFO #(     
       .FIFO_LENGTH ( 2*Test_FIFO_Length                                                                           )
   )myWFIFOReq      (     
       .RST         ( RST                                                                                          ) ,
       .Clk         ( Clk                                                                                          ) ,
       .Inp         ( CHI_Responser.ReqChan.TXREQFLIT                                                              ) ,
       .Enqueue     ( CHI_Responser.ReqChan.TXREQFLITV & CHI_Responser.ReqChan.TXREQFLIT.Opcode == `WriteUniquePtl ) ,  
       .Dequeue     ( Dequeue                                                                                      ) ,
       .Outp        ( SigTXREQFLITW                                                                                ) ,
       .FULL        ( ReqFULLW                                                                                     ) ,
       .Empty       ( ReqEmptyW                                                                                    ) 
       );
    
   // Outbound Data Rsp FIFO 
   FIFO #(                                                                                                                    
       .FIFO_WIDTH  ( DAT_FLIT_WIDTH                                                                                          ),
       .FIFO_LENGTH ( 2*Test_FIFO_Length                                                                                      )
   )myOutbDataFIFO  (                                                                                                         
       .RST         ( RST                                                                                                     ),
       .Clk         ( Clk                                                                                                     ),
       .Inp         ( CHI_Responser.DatOutbChan.TXDATFLIT                                                                     ),
       .Enqueue     ( CHI_Responser.DatOutbChan.TXDATFLITV & CHI_Responser.DatOutbChan.TXDATFLIT.Opcode == `NonCopyBackWrData ),   
       .Dequeue     ( Dequeue                                                                                                 ),
       .Outp        ( SigTXDATFLIT                                                                                            ),
       .FULL        ( DataOutbFULL                                                                                            ),
       .Empty       ( DataOutbEmpty                                                                                           )
       );

   // Inbound Data Rsp FIFO 
   FIFO #(                                                                                                                    
       .FIFO_WIDTH  ( DAT_FLIT_WIDTH                                                                               ),
       .FIFO_LENGTH ( 2*Test_FIFO_Length                                                                           )
   )myInbDataFIFO   (                                                                                              
       .RST         ( RST                                                                                          ),
       .Clk         ( Clk                                                                                          ),
       .Inp         ( CHI_Responser.DatInbChan.RXDATFLIT                                                           ),
       .Enqueue     ( CHI_Responser.DatInbChan.RXDATFLITV & CHI_Responser.DatInbChan.RXDATFLIT.Opcode == `CompData ),   
       .Dequeue     ( Dequeue                                                                                      ),
       .Outp        ( SigRXDATFLIT                                                                                 ),
       .FULL        ( DataInbFULL                                                                                  ),
       .Empty       ( DataInbEmpty                                                                                 )
       );       
       
   // Inbound DBID Rsp FIFO 
   FIFO #(                                                                                                                    
       .FIFO_WIDTH  ( RSP_FLIT_WIDTH                                                                                                                                             ),
       .FIFO_LENGTH ( 2*Test_FIFO_Length                                                                                                                                         )
   )myInbDBIDFIFO   (                                                                                                                                                            
       .RST         ( RST                                                                                                                                                        ),
       .Clk         ( Clk                                                                                                                                                        ),
       .Inp         ( CHI_Responser.RspInbChan.RXRSPFLIT                                                                                                                         ),
       .Enqueue     ( CHI_Responser.RspInbChan.RXRSPFLITV & (CHI_Responser.RspInbChan.RXRSPFLIT.Opcode == `DBIDResp | CHI_Responser.RspInbChan.RXRSPFLIT.Opcode == `CompDBIDResp)),   
       .Dequeue     ( Dequeue                                                                                                                                                    ),
       .Outp        ( SigRXRSPFLIT                                                                                                                                               ),
       .FULL        ( RspInbFULL                                                                                                                                                 ),
       .Empty       ( RspInbEmpty                                                                                                                                                )
       );                                                                                                                                                                        
   
   // FIFOs should never be FULL because they are bigger than CHI_Responser 's FIFO and it wont give enough crds to make its FIFOs FULL    
   always_ff@(posedge Clk)begin
     if(RspInbFULL | DataInbFULL | DataOutbFULL | ReqFULLW | ReqFULLR)begin
       $display("FIFIO FULL problem ...... " );
       $stop;
     end
   end
   
   int lengthCount = 0;
   
   assign Dequeue     = !RspInbEmpty & !DataInbEmpty & !DataOutbEmpty & !ReqEmptyW & !ReqEmptyR ;
   assign DequeueCmnd = ((lengthCount + CHI_DATA_WIDTH >= SigCommand.Length) & Dequeue) ? 1 : 0 ;
   
   
   always_ff@(posedge Clk)begin
     if(Dequeue)begin
        if((SigTXREQFLITR.Opcode == `ReadOnce & (SigTXREQFLITR.Addr == (SigCommand.SrcAddr + lengthCount)))
        &(SigRXDATFLIT.Opcode == `CompData & (SigTXREQFLITR.TxnID == (SigRXDATFLIT.TxnID)))
        // if corect opcode and Addr of a Write Req and corect opcode TxnID of a DBID Rsp and corect Data Out Rsp opcode ,TxnID and BE then print corect
        &((SigTXREQFLITW.Opcode == `WriteUniquePtl & (SigTXREQFLITW.Addr == (SigCommand.DstAddr + lengthCount)))
        &(((SigRXRSPFLIT.Opcode == `DBIDResp) | (SigRXRSPFLIT.Opcode == `CompDBIDResp)) & (SigRXRSPFLIT.TxnID == (SigTXREQFLITW.TxnID)))
        &((SigTXDATFLIT.Opcode == `NonCopyBackWrData) & (SigRXRSPFLIT.DBID == SigTXDATFLIT.TxnID))))
          if(SigTXDATFLIT.BE != ~({CHI_DATA_WIDTH{1'b1}} << (SigCommand.Length - lengthCount)))begin
           // wrong Data Out BE
            $display("\n--Error :: BE is : %d and it should be :%d , TxnID : %d",SigTXDATFLIT.BE , ~({CHI_DATA_WIDTH{1'b1}} << (SigCommand.Length - lengthCount)),SigTXDATFLIT.TxnID);
            $stop;
          end
          else begin
            // Corect
            if(DequeueCmnd & SigCommand.LastDescTrans)begin
              CorrectTransfer[CTpointer] <= SigCommand.DescAddr;
              CTpointer <= CTpointer + 1 ;
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
   
   //Check for double used TxnID
   always_ff@(posedge Clk)begin
     if(myRFIFOReq.Enqueue | myWFIFOReq.Enqueue) begin
       for( int i = 0 ; i < 2*Test_FIFO_Length ; i++) begin
         // if there is a Request with the same TxnID in ReadReqFIFO and the corresponding DataRsp hasnt arrived the print error
         if(CHI_Responser.ReqChan.TXREQFLIT.TxnID == myRFIFOReq.MyQueue[i].TxnID & myRFIFOReq.MyQueue[i] != 0 & myInbDataFIFO.MyQueue[i] == 0)begin
           $display("\n--ERROR :: TXNID : %d is already used for ReadReq ", CHI_Responser.ReqChan.TXREQFLIT.TxnID);
           $stop;
         end
         // if there is a Request with the same TxnID in WriteReqFIFO and the corresponding DBIDRsp hasnt arrived the print error
         else if(CHI_Responser.ReqChan.TXREQFLIT.TxnID == myWFIFOReq.MyQueue[i].TxnID & myWFIFOReq.MyQueue[i] != 0 & myInbDBIDFIFO.MyQueue[i] == 0)begin
           $display("\n--ERROR :: TXNID : %d is already used for WriteReq", CHI_Responser.ReqChan.TXREQFLIT.TxnID);
           $stop;
         end
       end
     end
   end
   
   
   
   always_ff@(posedge Clk)begin
     if(CTpointer == NUM_OF_TRANS)begin
       CTpointer <= 0 ;
       for(int i = 0 ; i < NUM_OF_TRANS ; i++)begin
         $display("!!Correct Transfer for Desc : %d",CorrectTransfer[i]);
       end
     end
   end
   //########################## End of CHI functionality Checking ##########################
endmodule
