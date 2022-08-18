`timescale 1ns / 1ps
`include "RSParameters.vh"

//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 19.07.2022 17:28:27
// Design Name: 
// Module Name: RegSpace+Sched
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


module RegSpaceAndSched(
    input logic RST,
    input logic Clk,
    input logic WE,    
    input logic [AddrWidth-1:0] SrcAddrIn,
    input logic [AddrWidth-1:0] DstAddrIn,
    input logic [BTSWidth-1:0] BytesToSendIn,
    input logic [DataWidth-1:0] ReadData,
    input logic DoneRead,
    input logic DoneWrite,
    output logic [AddrWidth-1:0] SrcAddrOut,
    output logic [AddrWidth-1:0] DstAddrOut,
    output logic [BTSWidth-1:0] BytesToReadOut,
    output logic [BTSWidth-1:0] BytesToWriteOut,
    output logic StartRead,
    output logic StartWrite,
    output logic [DataWidth-1:0]WriteData,
    output logic FULL
    );
    
    wire [BTSWidth-1:0] SigSentBytesIn,SigSentBytesOut,SigBytesToSend;
    wire [AddrWidth-1:0] SigSrcAddr,SigDstAddr;
    wire WE_SB,finish,Next;
    
    RegSpace myRegSpace (
    .Clk(Clk),.RST(RST),.WE(WE),.Next(Next) ,.SrcAddrIn(SrcAddrIn)
    ,.DstAddrIn(DstAddrIn), .BytesToSendIn(BytesToSendIn), .SentBytesIn(SigSentBytesIn), .WE_SB(WE_SB)
    , .finish(finish), .SrcAddrOut(SigSrcAddr), .DstAddrOut(SigDstAddr), .BytesToSendOut(SigBytesToSend)
    , .SentBytesOut(SigSentBytesOut),.FULL(FULL));
    
    Scheduler mySched (
    .Clk(Clk),.RST(RST),.SrcAddrIn(SigSrcAddr)
    ,.DstAddrIn(SigDstAddr), .BytesToSendIn(SigBytesToSend), .SentBytesIn(SigSentBytesOut), .ReadData(ReadData)
    ,.DoneRead(DoneRead),.DoneWrite(DoneWrite), .SrcAddrOut(SrcAddrOut), .DstAddrOut(DstAddrOut), .BytesToReadOut(BytesToReadOut)
    , .BytesToWriteOut(BytesToWriteOut), .SentBytesOut(SigSentBytesIn),.WriteData(WriteData),.WE_SB(WE_SB)
    ,.Next(Next), .finish(finish),.StartRead(StartRead),.StartWrite(StartWrite));
    
endmodule
