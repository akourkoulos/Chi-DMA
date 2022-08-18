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
  NumOfDesc         = 8,
  NumOfRegInDesc    = 5,
  RegSpaceAddrWidth = 32
);
    reg                                   RST       ;
    reg                                   Clk       ;
    reg        [NumOfRegInDesc    -1 :0]  WE_1      ;
    reg        [NumOfRegInDesc    -1 :0]  WE_2      ;
    reg        [RegSpaceAddrWidth -1 :0]  AddrIn_1  ;
    reg        [RegSpaceAddrWidth -1 :0]  AddrIn_2  ;
    Data_packet                           DataIn_1  ;
    Data_packet                           DataIn_2  ;
    Data_packet                           DataOut_1 ;
    Data_packet                           DataOut_2 ;

    // duration for each bit = 20 * timescale = 20 * 1 ns  = 20ns
    localparam period = 20;  

    RegSpace UUT (
     .RST       ( RST       ) ,
     .Clk       ( Clk       ) ,
     .WE_1      ( WE_1      ) ,
     .WE_2      ( WE_2      ) ,
     .AddrIn_1  ( AddrIn_1  ) ,
     .AddrIn_2  ( AddrIn_2  ) ,
     .DataIn_1  ( DataIn_1  ) ,
     .DataIn_2  ( DataIn_2  ) ,
     .DataOut_1 ( DataOut_1 ) ,
     .DataOut_2 ( DataOut_2 )
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
          RST       = 1                         ;
          WE_1      = 1                         ;
          WE_2      = 1                         ;
          AddrIn_1  = 'd0                       ;
          AddrIn_2  = 'd2                       ;
          DataIn_1.SrcAddr     = 'd10           ;
          DataIn_1.DstAddr     = 'd100          ;    
          DataIn_1.BytesToSend = 'd200          ;     
          DataIn_1.SentBytes   = 'd74           ;     
          DataIn_2.SrcAddr     = 'd20           ; 
          DataIn_2.DstAddr     = 'd200          ; 
          DataIn_2.BytesToSend = 'd300          ; 
          DataIn_2.SentBytes   = 'd0            ; 
          
          #(period*2); // wait for period   
          
          RST       = 0                         ;
          WE_1      = 1                         ;
          WE_2      = 1                         ;
          AddrIn_1  = 'd0                       ;
          AddrIn_2  = 'd2                       ;
          DataIn_1.SrcAddr     = 'd10           ;
          DataIn_1.DstAddr     = 'd100          ;    
          DataIn_1.BytesToSend = 'd200          ;     
          DataIn_1.SentBytes   = 'd74           ;     
          DataIn_2.SrcAddr     = 'd20           ; 
          DataIn_2.DstAddr     = 'd200          ; 
          DataIn_2.BytesToSend = 'd300          ; 
          DataIn_2.SentBytes   = 'd0            ; 
          
          #(period*2); // wait for period   
         
          RST       = 0                         ;
          WE_1      = 0                         ;
          WE_2      = 0                         ;
          AddrIn_1  = 'd1                       ;
          AddrIn_2  = 'd3                       ;
          DataIn_1.SrcAddr     = 'd10           ;
          DataIn_1.DstAddr     = 'd100          ;    
          DataIn_1.BytesToSend = 'd200          ;     
          DataIn_1.SentBytes   = 'd74           ;     
          DataIn_2.SrcAddr     = 'd20           ; 
          DataIn_2.DstAddr     = 'd200          ; 
          DataIn_2.BytesToSend = 'd300          ; 
          DataIn_2.SentBytes   = 'd0            ; 
          
          #(period*2); // wait for period 
          
          RST       = 0                         ;
          WE_1      = 0                         ;
          WE_2      = 0                         ;
          AddrIn_1  = 'd0                       ;
          AddrIn_2  = 'd3                       ;
          DataIn_1.SrcAddr     = 'd10           ;
          DataIn_1.DstAddr     = 'd100          ;    
          DataIn_1.BytesToSend = 'd200          ;     
          DataIn_1.SentBytes   = 'd74           ;     
          DataIn_2.SrcAddr     = 'd20           ; 
          DataIn_2.DstAddr     = 'd200          ; 
          DataIn_2.BytesToSend = 'd300          ; 
          DataIn_2.SentBytes   = 'd0            ; 
          
          #(period*2); // wait for period 
                            
          RST       = 0                         ;
          WE_1      = ~0                        ;
          WE_2      = ~0                        ;
          AddrIn_1  = 'd0                       ;
          AddrIn_2  = 'd3                       ;
          DataIn_1.SrcAddr     = 'd10           ;
          DataIn_1.DstAddr     = 'd100          ;    
          DataIn_1.BytesToSend = 'd200          ;     
          DataIn_1.SentBytes   = 'd74           ;     
          DataIn_2.SrcAddr     = 'd20           ; 
          DataIn_2.DstAddr     = 'd200          ; 
          DataIn_2.BytesToSend = 'd300          ; 
          DataIn_2.SentBytes   = 'd0            ; 
          
          #(period*2); // wait for period   
          
                   
          RST       = 1                         ;
          WE_1      = 0                         ;
          WE_2      = 0                         ;
          AddrIn_1  = 'd1                       ;
          AddrIn_2  = 'd3                       ;
          DataIn_1.SrcAddr     = 'd10           ;
          DataIn_1.DstAddr     = 'd100          ;    
          DataIn_1.BytesToSend = 'd200          ;     
          DataIn_1.SentBytes   = 'd74           ;     
          DataIn_2.SrcAddr     = 'd20           ; 
          DataIn_2.DstAddr     = 'd200          ; 
          DataIn_2.BytesToSend = 'd300          ; 
          DataIn_2.SentBytes   = 'd0            ; 
          
          #(period*2); // wait for period 
        $stop;
        end
endmodule
