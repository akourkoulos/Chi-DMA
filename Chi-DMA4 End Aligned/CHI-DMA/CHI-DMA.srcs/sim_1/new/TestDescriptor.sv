`timescale 1ns / 1ps
//`include "RSParameters.vh"
import DataPkg::*; 

//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 19.06.2022 18:48:10
// Design Name: 
// Module Name: TestDescriptor
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


module TestDescriptor#(parameter NumOfRegInDesc=5);
     reg                         Clk          ;
     reg                         RST          ;
     reg  [NumOfRegInDesc-1:0]   WE           ;
     Data_packet                 DescDataIn   ;
     Data_packet                 DescDataOut  ;
     
      localparam period           = 20        ;  // duration for each bit = 20 * timescale = 20 * 1 ns  = 20ns  

    Descriptor UUT (
      . Clk         ( Clk         )
    , . RST         ( RST         )
    , . WE          ( WE          )
    , . DescDataIn  ( DescDataIn  )
    , . DescDataOut ( DescDataOut )
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
        RST        = 1                                ;       
        WE         = 1                                ;
        DescDataIn = 'h323472394623948890909823764238 ;
        
        #(period*2); // wait for period
        
        RST        = 0                                  ;       
        WE         = 0011                               ;
        DescDataIn = 'h387009872347239462394823764238   ;
         
        #(period*2); // wait for period   
        
        RST        = 0                                  ;       
        WE         = 1001                               ;
        DescDataIn = 'h3234676979807239462394823764238  ;
        
        #(period*2); // wait for period
           
        
        RST        = 0                                  ;       
        WE         = 1111                               ;
        DescDataIn = 'h32347239462394828888888883764238 ;
        
        #(period*2); // wait for period           
        
        RST        = 1                                  ;       
        WE         = 1                                  ;
        DescDataIn = 'h32347239462397987978884823764238 ;
        
        #(period*2); // wait for period
        #(period*2); // wait for period

        $stop;
        end
endmodule
