`timescale 1ns / 1ps
import DataPkg::*;
import CHIFlitsPkg::*; 
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
   wire     Dequeue       ;
   wire     ReqEmptyR     ;
   wire     ReqFULLR      ;
   ReqFlit  SigTXREQFLITR ;
   
   wire     ReqFULLW      ;
   wire     ReqEmptyW     ;
   ReqFlit  SigTXREQFLITW ;
   
   wire     DataOutbFULL   ;
   wire     DataOutbEmpty ;
   DataFlit SigTXDATFLIT  ;
   
   wire     DataInbFULL   ;
   wire     DataInbEmpty  ;
   DataFlit SigRXDATFLIT  ;
   
   wire     RspInbFULL    ;
   wire     RspInbEmpty   ;
   RspFlit  SigRXRSPFLIT  ;
   
   // Read Req FIFO 
   FIFO #(     
       .FIFO_WIDTH  ( REQ_FLIT_WIDTH                                                                         ) ,       
       .FIFO_LENGTH ( 2*Test_FIFO_Length                                                                     )     
   )myRFIFOReq      (     
       .RST         ( RST                                                                                    ) ,      
       .Clk         ( Clk                                                                                    ) ,      
       .Inp         ( CHI_Responser.ReqChan.TXREQFLIT                                                        ) , 
       .Enqueue     ( CHI_Responser.ReqChan.TXREQFLITV & CHI_Responser.ReqChan.TXREQFLIT.Opcode == `ReadOnce ) , 
       .Dequeue     ( Dequeue                                                                                ) , 
       .Outp        ( TXREQFLITR                                                                             ) , 
       .FULL        ( ReqFULLR                                                                               ) , 
       .Empty       ( ReqEmptyR                                                                              ) 
       );
       
   // Write Req FIFO 
   FIFO #(     
       .FIFO_WIDTH  ( REQ_FLIT_WIDTH                                                                               ),
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
       .FIFO_WIDTH  ( RSP_FLIT_WIDTH                                                                               ),
       .FIFO_LENGTH ( 2*Test_FIFO_Length                                                                           )
   )myInbDBIDFIFO   (                                                                                              
       .RST         ( RST                                                                                          ),
       .Clk         ( Clk                                                                                          ),
       .Inp         ( CHI_Responser.RspInbChan.RXDATFLIT                                                           ),
       .Enqueue     ( CHI_Responser.RspInbChan.RXDATFLITV & CHI_Responser.RspInbChan.RXDATFLIT.Opcode == `DBIDResp ),   
       .Dequeue     ( Dequeue                                                                                      ),
       .Outp        ( SigRXRSPFLIT                                                                                 ),
       .FULL        ( RspInbFULL                                                                                   ),
       .Empty       ( RspInbEmpty                                                                                  )
       );    
   
   // FIFOs should never be FULL because they are bigger than CHI_Responser 's FIFO and it wont give enough crds to make its FIFOs FULL    
   always_ff@(posedge Clk)begin
     if(RspInbFULL | DataInbFULL | DataOutbFULL | ReqFULLW | ReqFULLR)begin
       $display("FIFIO FULL problem ...... " );
       $stop;
     end
   end
   
   always_ff@(posedge Clk)begin
     if(!RspInbEmpty & !DataInbEmpty & !DataOutbEmpty & !ReqEmptyW & !ReqEmptyR)begin
     end
   end
   
   //########################## End of CHI functionality Checking ##########################
endmodule
