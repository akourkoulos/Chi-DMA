`timescale 1ns / 1ps
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


module TestFULLSystem#(
//--------------------------------------------------------------------------
  parameter BRAM_NUM_COL      = 8   ,
  parameter BRAM_ADDR_WIDTH   = 10                                
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
    
    
   PseudoCPU myCPU (
     .RST          (RST          ) ,
     .Clk          (Clk          ) ,
     .ReadyArbProc (ReadyArbProc ) ,
     .BRAMdoutA    (BRAMdoutA    ) ,
     .weA          (weA          ) ,
     .addrA        (addrA        ) ,
     .dinA         (dinA         ) ,
     .ValidArbIn   (ValidArbIn   )  
    );
 
   CHI_Responser CHI_RSP  (
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
      Clk = 1'b0; 
      #20; // high for 20 * timescale = 20 ns
  
      Clk = 1'b1;
      #20; 
  end

// duration for each bit = 20 * timescdoutBale = 20 * 1 ns  = 20ns
  localparam period = 20;  
  
  initial begin
    RST = 1 ;
    #(period*2)
    #(period)
    RST = 0 ;
  end
endmodule
