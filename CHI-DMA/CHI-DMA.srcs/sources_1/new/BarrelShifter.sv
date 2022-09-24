`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07.09.2022 19:50:51
// Design Name: 
// Module Name: BarrelShifter
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


module BarrelShifter#(
  DataWidth  = 32 ,
  ShiftWidth = 5   //log base2 (DataWudth) 
) ( 
    input  logic [DataWidth  - 1 :0] inp   ,
    input  logic [ShiftWidth - 1 :0] shift ,
    output logic [DataWidth  - 1 :0] outp
    );
    
    wire  [DataWidth - 1 : 0] muxout [ShiftWidth - 1 : 0];
    
    assign muxout[0] = shift[0] ? ({inp[0],inp[DataWidth  - 1 :1]}): inp ;

    genvar i ;
    generate 
    for(i = 1 ; i < ShiftWidth ; i++)
      assign muxout[i] = shift[i] ? ({muxout[i-1][2**i - 1 : 0],muxout[i-1][DataWidth  - 1 : 2**i]}): muxout[i-1] ;
    endgenerate
    
    assign outp = muxout[ShiftWidth - 1];
    
endmodule
