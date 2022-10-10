`timescale 1ns / 1ps
import DataPkg::*;
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06.10.2022 12:44:35
// Design Name: 
// Module Name: TestCompleter
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


module TestCompleter#(
//--------------------------------------------------------------------------
  parameter BRAM_ADDR_WIDTH   = 10 ,
  parameter FIFO_Length       = 5  ,
  parameter BRAM_NUM_COL      = 8    // As the Data_packet fields
//----------------------------------------------------------------------
);
  reg                                    RST          ;
  reg                                    Clk          ;
  reg         [BRAM_ADDR_WIDTH      : 0] DescAddr     ;
  reg         [`DBIDRespWidth   - 1 : 0] DBIDRespErr  ;
  reg         [`RspErrWidth     - 1 : 0] DataRespErr  ;
  reg                                    ValidUpdate  ;
  Data_packet                            DescData     ;
  reg                                    ReadyBRAM    ;
  wire                                   ValidBRAM    ;
  wire        [BRAM_ADDR_WIDTH  - 1 : 0] AddrOut      ;
  Data_packet                            DataOut      ;
  wire        [BRAM_NUM_COL     - 1 : 0] WE           ;
  wire                                   FULL         ;
    // duration for each bit = 20 * timescdoutBale = 20 * 1 ns  = 20ns
    localparam period = 20;  

    Completer#(
      BRAM_ADDR_WIDTH   ,
      FIFO_Length       ,
      BRAM_NUM_COL      
    ) UUT (
     . RST        (  RST         ) ,
     . Clk        (  Clk         ) ,
     . DescAddr   (  DescAddr    ) ,
     . DBIDRespErr(  DBIDRespErr ) ,
     . DataRespErr(  DataRespErr ) ,
     . ValidUpdate(  ValidUpdate ) ,
     . DescData   (  DescData    ) ,
     . ReadyBRAM  (  ReadyBRAM   ) ,
     . ValidBRAM  (  ValidBRAM   ) ,
     . AddrOut    (  AddrOut     ) ,
     . DataOut    (  DataOut     ) ,
     . WE         (  WE          ) ,
     .FULL        (  FULL        )
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
          // Reset
         RST                               = 1   ;
         DescAddr[BRAM_ADDR_WIDTH]         = 1   ;
         DescAddr[BRAM_ADDR_WIDTH - 1 : 0] = 'd5 ;
         DBIDRespErr                       = 'd3 ;
         DataRespErr                       = 'd0 ;
         ValidUpdate                       = 'd1 ;
         DescData.Status                   = 'd1 ;
         ReadyBRAM                         = 1   ;   
          
          #(period); // signals change at the negedge of Clk  
          #(period*2); // wait for period   
          
           // No Valid to Update
         RST                               = 0   ;
         DescAddr[BRAM_ADDR_WIDTH]         = 0   ;
         DescAddr[BRAM_ADDR_WIDTH - 1 : 0] = 'd5 ;
         DBIDRespErr                       = 'd3 ;
         DataRespErr                       = 'd0 ;
         ValidUpdate                       = 'd0 ;
         DescData.Status                   = 'd1 ;
         ReadyBRAM                         = 1   ;
          
          #(period*2); // wait for period             
           // enqueue a DBID error
         RST                               = 0   ;
         DescAddr[BRAM_ADDR_WIDTH]         = 0   ;
         DescAddr[BRAM_ADDR_WIDTH - 1 : 0] = 'd5 ;
         DBIDRespErr                       = 'd3 ;
         DataRespErr                       = 'd0 ;
         ValidUpdate                       = 'd1 ;
         DescData.Status                   = 'd1 ;
         ReadyBRAM                         = 1   ;  
         
          #(period*2); // wait for period   
          // enqueue a finished Desc . update error
         RST                               = 0   ;
         DescAddr[BRAM_ADDR_WIDTH]         = 1   ;
         DescAddr[BRAM_ADDR_WIDTH - 1 : 0] = 'd5 ;
         DBIDRespErr                       = 'd0 ;
         DataRespErr                       = 'd0 ;
         ValidUpdate                       = 'd1 ;
         DescData.Status                   = 'd1 ;
         ReadyBRAM                         = 1   ;    
          
          #(period*2); // wait for period 
          // Enqueue a Data Error . Read BRAM
         RST                               = 0   ;
         DescAddr[BRAM_ADDR_WIDTH]         = 0   ;
         DescAddr[BRAM_ADDR_WIDTH - 1 : 0] = 'd2 ;
         DBIDRespErr                       = 'd0 ;
         DataRespErr                       = 'd2 ;
         ValidUpdate                       = 'd1 ;
         DescData.Status                   = 'd1 ;
         ReadyBRAM                         = 1   ;    
          
          #(period*2); // wait for period 
          // Enqueue an DBID Error. update desc status to idle 
         RST                               = 0   ;
         DescAddr[BRAM_ADDR_WIDTH]         = 0   ;
         DescAddr[BRAM_ADDR_WIDTH - 1 : 0] = 'd1 ;
         DBIDRespErr                       = 'd3 ;
         DataRespErr                       = 'd0 ;
         ValidUpdate                       = 'd1 ;
         DescData.Status                   = 'd1 ;
         ReadyBRAM                         = 1   ; 
                            
          #(period*2); // wait for period 
         // Enqueue a finished Desc . NO BRAM con
         RST                               = 0   ;
         DescAddr[BRAM_ADDR_WIDTH]         = 1   ;
         DescAddr[BRAM_ADDR_WIDTH - 1 : 0] = 'd1 ;
         DBIDRespErr                       = 'd3 ;
         DataRespErr                       = 'd0 ;
         ValidUpdate                       = 'd1 ;
         DescData.Status                   = 'd1 ;
         ReadyBRAM                         = 0   ;                    
         
          #(period*2); // wait for period
          // Enqueue a lot of DBID errors while no BRAM con
         RST                               = 0   ;
         DescAddr[BRAM_ADDR_WIDTH]         = 0   ;
         DescAddr[BRAM_ADDR_WIDTH - 1 : 0] = 'd9 ;
         DBIDRespErr                       = 'd3 ;
         DataRespErr                       = 'd0 ;
         ValidUpdate                       = 'd1 ;
         DescData.Status                   = 'd1 ;
         ReadyBRAM                         = 0   ;                    
          
          #(period*10); // wait for period 
          // update all because . BRAM con
         RST                               = 0   ;
         DescAddr[BRAM_ADDR_WIDTH]         = 0   ;
         DescAddr[BRAM_ADDR_WIDTH - 1 : 0] = 'd9 ;
         DBIDRespErr                       = 'd3 ;
         DataRespErr                       = 'd0 ;
         ValidUpdate                       = 'd0 ;
         DescData.Status                   = 'd1 ;
         ReadyBRAM                         = 1   ;                    
          #(period*12); // wait for period 
        $stop;
        end
endmodule

