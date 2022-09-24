`timescale 1ns / 1ps
import DataPkg::*; 

//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09.07.2022 17:12:50
// Design Name: 
// Module Name: TestRegSpace
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

module TestRegSpace#(
//--------------------------------------------------------------------------
  parameter NUM_COL   =  8                ,
  parameter COL_WIDTH =  32               ,
  parameter ADDR_WIDTH = 10               , // Addr Width in bits : 2 *ADDR_WIDTH = RAM Depth
  parameter DATA_WIDTH = NUM_COL*COL_WIDTH  // Data Width in bits
//----------------------------------------------------------------------
);
 reg                                   clkA  ;
 reg                                   enaA  ;
 reg         [NUM_COL    -1 : 0]       weA   ;
 reg         [ADDR_WIDTH -1 : 0]       addrA ;
 Data_packet                           dinA  ;
 reg                                   clkB  ;
 reg                                   enaB  ;
 reg         [NUM_COL    -1 : 0]       weB   ;
 reg         [ADDR_WIDTH -1 : 0]       addrB ;
 Data_packet                           dinB  ;
 Data_packet                           doutA ;
 Data_packet                           doutB ;
                                   
    // duration for each bit = 20 * timescdoutBale = 20 * 1 ns  = 20ns
    localparam period = 20;  

    bytewrite_tdp_ram_rf UUT (
     .clkA  ( clkA  ) ,
     .enaA  ( enaA  ) ,
     .weA   ( weA   ) ,
     .addrA ( addrA ) ,
     .dinA  ( dinA  ) ,
     .clkB  ( clkB  ) ,
     .enaB  ( enaB  ) ,
     .weB   ( weB   ) ,
     .addrB ( addrB ) ,
     .dinB  ( dinB  ) ,
     .doutA ( doutA ) ,
     .doutB ( doutB )
    );
    
    always 
    begin
        clkA = 1'b1; 
        #20; // high for 20 * timescale = 20 ns
    
        clkA = 1'b0;
        #20; // low for 20 * timescale = 20 ns
    end
   
    always 
    begin
        clkB = 1'b1; 
        #20; // high for 20 * timescale = 20 ns
    
        clkB = 1'b0;
        #20; // low for 20 * timescale = 20 ns
    end
    
    always @(posedge clkA ,posedge clkB)
        begin
          #(period); // wait for period   
          enaA             = 1              ;
          weA              = 'd15           ;
          addrA            = 'd0            ;
          enaB             = 1              ;
          weB              = 'd15           ;
          addrB            = 'd0            ;
          dinA.SrcAddr     = 'd10           ;
          dinA.DstAddr     = 'd100          ;    
          dinA.BytesToSend = 'd200          ;     
          dinA.SentBytes   = 'd74           ;     
          dinB.SrcAddr     = 'd20           ; 
          dinB.DstAddr     = 'd200          ; 
          dinB.BytesToSend = 'd300          ; 
          dinB.SentBytes   = 'd0            ; 
          
          #(period*2); // wait for period   
          
          enaA             = 1              ;
          weA              = 'd15           ;
          addrA            = 'd0            ;
          enaB             = 0              ;
          weB              = 'd15           ;
          addrB            = 'd0            ;
          dinA.SrcAddr     = 'd10           ;
          dinA.DstAddr     = 'd100          ;    
          dinA.BytesToSend = 'd200          ;     
          dinA.SentBytes   = 'd74           ;     
          dinB.SrcAddr     = 'd20           ; 
          dinB.DstAddr     = 'd200          ; 
          dinB.BytesToSend = 'd300          ; 
          dinB.SentBytes   = 'd0            ;  
          
          #(period*2); // wait for period   
          
          enaA             = 1              ;
          weA              = 'd15            ;
          addrA            = 'd1            ;
          enaB             = 0              ;
          weB              = 'd1            ;
          addrB            = 'd1            ;
          dinA.SrcAddr     = 'd10           ;
          dinA.DstAddr     = 'd100          ;    
          dinA.BytesToSend = 'd200          ;     
          dinA.SentBytes   = 'd74           ;     
          dinB.SrcAddr     = 'd20           ; 
          dinB.DstAddr     = 'd200          ; 
          dinB.BytesToSend = 'd300          ; 
          dinB.SentBytes   = 'd0            ;   
          
          #(period*2); // wait for period 
          
          enaA             = 1              ;
          weA              = 'd31           ;
          addrA            = 'd0            ;
          enaB             = 0              ;
          weB              = 'd1            ;
          addrB            = 'd1            ;
          dinA.SrcAddr     = 'd10           ;
          dinA.DstAddr     = 'd100          ;    
          dinA.BytesToSend = 'd200          ;     
          dinA.SentBytes   = 'd74           ;     
          dinB.SrcAddr     = 'd20           ; 
          dinB.DstAddr     = 'd200          ; 
          dinB.BytesToSend = 'd300          ; 
          dinB.SentBytes   = 'd0            ;   
          
          #(period*2); // wait for period 
                            
          #(period*2); // wait for period 
          
        $stop;
        end
endmodule
