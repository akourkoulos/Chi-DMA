`timescale 1ns / 1ps
`include "RSParameters.vh"
import DataPkg::*; 
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 14.07.2022 18:55:18
// Design Name: 
// Module Name: TestScheduler
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

module TestScheduler#(
  BRAM_ADDR_WIDTH   = 10 ,
  BRAM_NUM_COL      = 8  , // num of Reg in Descriptor
  BRAM_COL_WIDTH    = 32 , // width of a Reg in Descriptor 
  CHI_Word_Width    = 32 ,  
  Chunk             = 5  , // number of CHI-Words
  MEMAddrWidth      = 32 ,
  Done_Status       = 1  ,
  Idle_Status       = 0   
 );
    reg                                RST               ;                               
    reg                                Clk               ;                               
    Data_packet                        DescDataIn        ; //sig from BRAM               
    reg                                ReadyBRAM         ; //sig from BRAM's Arbiter     
    reg                                ReadyFIFO         ; //sig from FIFO's Arbiter     
    reg        [BRAM_ADDR_WIDTH  -1:0] FIFO_Addr         ; //sig from FIFO               
    reg                                Empty             ;                               
    reg                                CmdFIFOFULL       ; //sig from chi-converter      
    Data_packet                        DescDataOut       ; //sig for BRAM                
    wire       [BRAM_NUM_COL     -1:0] WE                ;                               
    wire       [BRAM_ADDR_WIDTH  -1:0] BRAMAddrOut       ;                               
    wire                               ValidBRAM         ; //sig for BRAM's Arbiter      
    wire                               Dequeue           ; //sig for FIFO                
    wire                               ValidFIFO         ; //sig for FIFO 's Arbiter     
    wire       [BRAM_ADDR_WIDTH  -1:0] DescAddrPointer   ;                               
    wire                               IssueValid        ; //sig for chi-converter       
    wire       [MEMAddrWidth     -1:0] ReadAddr          ;                               
    wire       [MEMAddrWidth     -1:0] ReadLength        ;                               
    wire       [MEMAddrWidth     -1:0] WriteAddr         ;                               
    wire       [MEMAddrWidth     -1:0] WriteLength       ;                               
    wire       [BRAM_ADDR_WIDTH  -1:0] FinishedDescAddr  ;                               
    wire                               FinishedDescValid ;                               
    
    // duration for each bit = 20 * timescale = 20 * 1 ns  = 20ns
    localparam period = 20;  

    Scheduler UUT (
    .RST              (RST              ) ,
    .Clk              (Clk              ) ,
    .DescDataIn       (DescDataIn       ) ,
    .ReadyBRAM        (ReadyBRAM        ) ,
    .ReadyFIFO        (ReadyFIFO        ) ,
    .FIFO_Addr        (FIFO_Addr        ) ,
    .Empty            (Empty            ) ,
    .CmdFIFOFULL      (CmdFIFOFULL      ) ,
    .DescDataOut      (DescDataOut      ) ,
    .WE               (WE               ) , 
    .BRAMAddrOut      (BRAMAddrOut      ) ,
    .ValidBRAM        (ValidBRAM        ) ,
    .Dequeue          (Dequeue          ) ,
    .ValidFIFO        (ValidFIFO        ) ,
    .DescAddrPointer  (DescAddrPointer  ) ,
    .IssueValid       (IssueValid       ) ,
    .ReadAddr         (ReadAddr         ) , 
    .ReadLength       (ReadLength       ) ,    
    .WriteAddr        (WriteAddr        ) , 
    .WriteLength      (WriteLength      ) ,
    .FinishedDescAddr (FinishedDescAddr ) ,
    .FinishedDescValid(FinishedDescValid)
    );
    
    always 
    begin
        Clk = 1'b1; 
        #20; // high for 20 * timescale = 20 ns
    
        Clk = 1'b0;
        #20; // low for 20 * timescale = 20 ns
    end
    

    always @(posedge Clk)
        begin
    
         RST           = 1              ;       
         DescDataIn    = 'd10           ;
         ReadyBRAM     = 1              ;    
         ReadyFIFO     = 0              ;     
         FIFO_Addr     = 0              ;     
         Empty         = 1              ;       
         CmdFIFOFULL   = 0              ;
        
        #(period*2); // wait for period begin
        #1
        
         RST                    =  0             ;       
         DescDataIn.SrcAddr     = 'd10           ;
         DescDataIn.DstAddr     = 'd100          ;
         DescDataIn.BytesToSend = 'd100          ;
         DescDataIn.SentBytes   = 'd0            ;
         DescDataIn.Status      = 'd0            ;
         ReadyBRAM              = 0              ;    
         ReadyFIFO              = 0              ;     
         FIFO_Addr              = 'd2            ;     
         Empty                  = 0              ;       
         CmdFIFOFULL            = 0              ;
      
        #(period*2); // wait for period begin
        
         RST                    = 0              ;       
         DescDataIn.SrcAddr     = 'd10           ;
         DescDataIn.DstAddr     = 'd100          ;
         DescDataIn.BytesToSend = 'd100          ;
         DescDataIn.SentBytes   = 'd0            ;
         DescDataIn.Status      = 'd0            ;
         ReadyBRAM              = 1              ;    
         ReadyFIFO              = 0              ;     
         FIFO_Addr              = 'd2            ;     
         Empty                  = 0              ;       
         CmdFIFOFULL            = 0              ;
      
        #(period*2); // wait for period begin
        
         RST                    = 0              ;       
         DescDataIn.SrcAddr     = 'd10           ;
         DescDataIn.DstAddr     = 'd100          ;
         DescDataIn.BytesToSend = 'd200          ;
         DescDataIn.SentBytes   = 'd0            ;
         DescDataIn.Status      = 'd0            ;
         ReadyBRAM              = 1              ;    
         ReadyFIFO              = 0              ;     
         FIFO_Addr              = 'd3            ;     
         Empty                  = 0              ;       
         CmdFIFOFULL            = 0              ;
      
        #(period*2); // wait for period begin
         
         RST                    = 0              ;       
         DescDataIn.SrcAddr     = 'd10           ;
         DescDataIn.DstAddr     = 'd100          ;
         DescDataIn.BytesToSend = 'd200          ;
         DescDataIn.SentBytes   = 'd0            ;
         DescDataIn.Status      = 'd0            ;
         ReadyBRAM              = 1              ;    
         ReadyFIFO              = 0              ;     
         FIFO_Addr              = 'd0            ;     
         Empty                  = 1              ;       
         CmdFIFOFULL            = 0              ;
      
        #(period*2); // wait for period begin
         
         RST                    = 0              ;       
         DescDataIn.SrcAddr     = 'd10           ;
         DescDataIn.DstAddr     = 'd100          ;
         DescDataIn.BytesToSend = 'd200          ;
         DescDataIn.SentBytes   = 'd160          ;
         DescDataIn.Status      = 'd0            ;
         ReadyBRAM              = 1              ;    
         ReadyFIFO              = 0              ;     
         FIFO_Addr              = 'd3            ;     
         Empty                  = 0              ;       
         CmdFIFOFULL            = 0              ;
      
        #(period*2); // wait for period begin
        
         RST                    = 0              ;       
         DescDataIn.SrcAddr     = 'd10           ;
         DescDataIn.DstAddr     = 'd100          ;
         DescDataIn.BytesToSend = 'd200          ;
         DescDataIn.SentBytes   = 'd100          ;
         DescDataIn.Status      = 'd0            ;
         ReadyBRAM              = 1              ;    
         ReadyFIFO              = 0              ;     
         FIFO_Addr              = 'd5            ;     
         Empty                  = 0              ;       
         CmdFIFOFULL            = 0              ;
      
       #(period*2); // wait for period begin
        
         RST                    = 0              ;       
         DescDataIn.SrcAddr     = 'd10           ;
         DescDataIn.DstAddr     = 'd100          ;
         DescDataIn.BytesToSend = 'd200          ;
         DescDataIn.SentBytes   = 'd132          ;
         DescDataIn.Status      = 'd0            ;
         ReadyBRAM              = 1              ;    
         ReadyFIFO              = 0              ;     
         FIFO_Addr              = 'd5            ;     
         Empty                  = 0              ;       
         CmdFIFOFULL            = 0              ;
         
        #(period*2); // wait for period begin
         RST                    = 0              ;       
         DescDataIn.SrcAddr     = 'd10           ;
         DescDataIn.DstAddr     = 'd100          ;
         DescDataIn.BytesToSend = 'd200          ;
         DescDataIn.SentBytes   = 'd164          ;
         DescDataIn.Status      = 'd0            ;
         ReadyBRAM              = 1              ;    
         ReadyFIFO              = 0              ;     
         FIFO_Addr              = 'd5            ;     
         Empty                  = 0              ;       
         CmdFIFOFULL            = 0              ;
         
        #(period*2); // wait for period begin
         
         RST                    = 0              ;       
         DescDataIn.SrcAddr     = 'd10           ;
         DescDataIn.DstAddr     = 'd100          ;
         DescDataIn.BytesToSend = 'd200          ;
         DescDataIn.SentBytes   = 'd164          ;
         DescDataIn.Status      = 'd0            ;
         ReadyBRAM              = 1              ;    
         ReadyFIFO              = 1              ;     
         FIFO_Addr              = 'd5            ;     
         Empty                  = 0              ;       
         CmdFIFOFULL            = 0              ;
        $stop;
        end
    
  
  
endmodule

