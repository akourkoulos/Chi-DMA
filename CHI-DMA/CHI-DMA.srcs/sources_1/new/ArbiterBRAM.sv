`timescale 1ns / 1ps
import DataPkg::*;
//////////////////////////////////////////////////////////////////////////////////
/*Arbiter of BRAM. Takes 2 request by the Valid signals and returns one Ready
Response that indicates that the module has the permission to access the BRAM.
Arbiter gives always priority to A Chanenel */
//////////////////////////////////////////////////////////////////////////////////

module ArbiterBRAM#(
//-----------------------------------------------
  parameter BRAM_NUM_COL      = 8  ,
  parameter BRAM_ADDR_WIDTH   = 10                   
//-----------------------------------------------       
)(
    input                                        ValidA   ,//--- A Channel ---
    input              [BRAM_NUM_COL    - 1 : 0] weA      ,
    input              [BRAM_ADDR_WIDTH - 1 : 0] addrA    ,
    input Data_packet                            dinA     ,
    output wire                                  ReadyA   ,//-----------------
    input                                        ValidB   ,//--- B Channel ---
    input              [BRAM_NUM_COL    - 1 : 0] weB      ,                   
    input              [BRAM_ADDR_WIDTH - 1 : 0] addrB    ,                   
    input Data_packet                            dinB     ,                   
    output wire                                  ReadyB   ,//-----------------
    output             [BRAM_NUM_COL    - 1 : 0] weOut    ,//--- Arb Out ---
    output             [BRAM_ADDR_WIDTH - 1 : 0] addrOut  ,
    output Data_packet                           dOut      //---------------
    );
    
    assign ReadyA  = ValidA                               ;
    assign ReadyB  = (!ValidA)& ValidB                    ;
    assign weOut   = ValidA ? weA :(ValidB ? weB : 0)     ;
    assign addrOut = ValidA ? addrA :(ValidB ? addrB : 0) ;
    assign dOut    = ValidA ? dinA :(ValidB ? dinB : 0)   ;
endmodule
