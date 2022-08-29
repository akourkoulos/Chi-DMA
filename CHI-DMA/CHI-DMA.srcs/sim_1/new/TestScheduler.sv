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
 RegSpaceAddrWidth = 32 ,
 NumOfRegInDesc    = 5  ,
 CHI_Word_Width    = 32 ,
 CounterWidth      = 32 ,
 Done_Status       = 1  ,
 Idle_Status       = 0  ,
 Chunk             = 64 ,
 MEMAddrWidth      = 32 ,
 StateWidth        = 8   
 );
    reg                                RST               ;
    reg                                Clk               ;
    Data_packet                        DescDataIn        ;
    reg                                ReadyRegSpace     ;
    reg                                ReadyFIFO         ;
    reg        [RegSpaceAddrWidth-1:0] FIFO_Addr         ;
    reg                                Empty             ;
    reg                                CmdFIFOFULL       ;
    Data_packet                        DescDataOut       ;
    wire       [NumOfRegInDesc   -1:0] WE                ;
    wire       [RegSpaceAddrWidth-1:0] RegSpaceAddrOut   ;
    wire                               ValidRegSpace     ;
    wire                               Dequeue           ;
    wire                               ValidFIFO         ;
    wire       [RegSpaceAddrWidth-1:0] DescAddrPointer   ;
    wire                               Read              ;
    wire       [MEMAddrWidth     -1:0] ReadAddr          ;
    wire       [MEMAddrWidth     -1:0] ReadLength        ;
    wire       [MEMAddrWidth     -1:0] WriteAddr         ;
    wire       [MEMAddrWidth     -1:0] WriteLength       ;
    wire       [RegSpaceAddrWidth-1:0] FinishedDescAddr  ;
    wire                               FinishedDescValid ;
    
    // duration for each bit = 20 * timescale = 20 * 1 ns  = 20ns
    localparam period = 20;  

    Scheduler UUT (
    .RST                (RST              ) ,
    .Clk                (Clk              ) ,
    .DescDataIn         (DescDataIn       ) ,
    .ReadyRegSpace      (ReadyRegSpace    ) ,
    .ReadyFIFO          (ReadyFIFO        ) ,
    .FIFO_Addr          (FIFO_Addr        ) ,
    .Empty              (Empty            ) ,
    .CmdFIFOFULL        (CmdFIFOFULL      ) ,
    .DescDataOut        (DescDataOut      ) ,
    .WE                 (WE               ) , 
    .RegSpaceAddrOut    (RegSpaceAddrOut  ) ,
    .ValidRegSpace      (ValidRegSpace    ) ,
    .Dequeue            (Dequeue          ) ,
    .ValidFIFO          (ValidFIFO        ) ,
    .DescAddrPointer    (DescAddrPointer  ) ,
    .Read               (Read             ) ,
    .ReadAddr           (ReadAddr         ) , 
    .ReadLength         (ReadLength       ) ,    
    .WriteAddr          (WriteAddr        ) , 
    .WriteLength        (WriteLength      ) ,
     .FinishedDescAddr  (FinishedDescAddr ) ,
     .FinishedDescValid (FinishedDescValid)
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
    
         RST           =  1             ;       
         DescDataIn    = 'd10           ;
         ReadyRegSpace = 'd100          ;    
         ReadyFIFO     = 'd100          ;     
         FIFO_Addr     = 0              ;     
         Empty         = 0              ;       
         CmdFIFOFULL   = 0              ;
        
        #(period*2); // wait for period begin
        #(period); // wait for period begin
        
         RST           =  1             ;       
         DescDataIn    = 'd10           ;
         ReadyRegSpace = 0              ;    
         ReadyFIFO     = 0              ;     
         FIFO_Addr     = 'd2            ;     
         Empty         = 0              ;       
         CmdFIFOFULL   = 0              ;
      
        #(period*2); // wait for period begin
        
         RST           =  1             ;       
         DescDataIn    = 'd10           ;
         ReadyRegSpace = 1              ;    
         ReadyFIFO     = 0              ;     
         FIFO_Addr     = 'd2            ;     
         Empty         = 0              ;       
         CmdFIFOFULL   = 0              ;
      
        #(period*2); // wait for period begin
        
         RST           =  1             ;       
         DescDataIn    = 'd10           ;
         ReadyRegSpace = 1              ;    
         ReadyFIFO     = 0              ;     
         FIFO_Addr     = 'd2            ;     
         Empty         = 0              ;       
         CmdFIFOFULL   = 0              ;
      
        #(period*2); // wait for period begin
         
         RST           =  1             ;       
         DescDataIn    = 'd10           ;
         ReadyRegSpace = 1              ;    
         ReadyFIFO     = 0              ;     
         FIFO_Addr     = 'd2            ;     
         Empty         = 0              ;       
         CmdFIFOFULL   = 1              ;
      
        #(period*2); // wait for period begin
        
        
        $stop;
        end
    
  
  
endmodule

