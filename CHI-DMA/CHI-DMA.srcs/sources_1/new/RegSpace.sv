`timescale 1ns / 1ps
import DataPkg::*; 

//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02.07.2022 21:06:39
// Design Name: 
// Module Name: RegSpace
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


module RegSpace#(
  NumOfDesc         = 8,
  NumOfRegInDesc    = 5,
  RegSpaceAddrWidth = 32
)(
    input  wire                                  RST        , 
    input  wire                                  Clk        ,
    input  wire        [NumOfRegInDesc    -1 :0] WE_1       ,
    input  wire        [NumOfRegInDesc    -1 :0] WE_2       ,
    input  wire        [RegSpaceAddrWidth -1 :0] AddrIn_1   ,      
    input  wire        [RegSpaceAddrWidth -1 :0] AddrIn_2   ,
    input  Data_packet                           DataIn_1   , 
    input  Data_packet                           DataIn_2   , 
    output Data_packet                           DataOut_1  ,
    output Data_packet                           DataOut_2
    );
    
    wire        [NumOfRegInDesc - 1 : 0 ] MuxOut_WE   [NumOfDesc - 1 : 0 ] ;
    wire        [NumOfDesc      - 1 : 0 ] DecoderOut_1                     ;
    wire        [NumOfDesc      - 1 : 0 ] DecoderOut_2                     ;
    Data_packet [NumOfDesc      - 1 : 0 ] MuxOut_Data                      ;
    Data_packet [NumOfDesc      - 1 : 0 ] SigDescOut                       ;
    
    genvar i;
    generate
    for (i = 0 ; i < NumOfDesc ; i++) begin
      Descriptor UUT   (                
         . Clk         ( Clk            ) 
       , . RST         ( RST            ) 
       , . WE          ( MuxOut_WE  [i] ) 
       , . DescDataIn  ( MuxOut_Data[i] ) 
       , . DescDataOut ( SigDescOut [i] ) 
       );                                
    
    // muxes for Descriptors
    assign MuxOut_WE  [i] = DecoderOut_1[i] ? WE_1     : (DecoderOut_2[i] ? WE_2     : 'b0 );
    assign MuxOut_Data[i] = DecoderOut_1[i] ? DataIn_1 : (DecoderOut_2[i] ? DataIn_2 : 'b0 );
    
    always_comb begin // muxes for outputs
      if(AddrIn_1 == i)
        DataOut_1 = SigDescOut[i] ;
        
      if(AddrIn_2 == i)
        DataOut_2 = SigDescOut[i] ;
    end
    
    //decoders
    assign DecoderOut_1[i] = (AddrIn_1 == i) ? 1 : 0 ;
    assign DecoderOut_2[i] = (AddrIn_2 == i) ? 1 : 0 ;
    
    end
    
    
    
    endgenerate
endmodule
