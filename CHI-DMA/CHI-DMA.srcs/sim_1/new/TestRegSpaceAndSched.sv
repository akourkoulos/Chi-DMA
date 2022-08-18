`timescale 1ns / 1ps
`include "RSParameters.vh"

//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 19.07.2022 18:00:48
// Design Name: 
// Module Name: TestRegSpaceAndSched
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


module TestRegSpaceAndSched;
    reg Clk;
    reg RST;
    reg WE;
    reg [AddrWidth-1:0] SrcAddrIn;
    reg [AddrWidth-1:0] DstAddrIn; 
    reg [BTSWidth-1:0] BytesToSendIn;
    reg [DataWidth-1:0] ReadData;
    reg DoneRead;
    reg DoneWrite;
    wire [AddrWidth-1:0] SrcAddrOut;
    wire [AddrWidth-1:0] DstAddrOut;
    wire [BTSWidth-1:0] BytesToReadOut;
    wire [BTSWidth-1:0] BytesToWriteOut;
    wire [DataWidth-1:0]WriteData;
    wire FULL;
    wire StartRead;
    wire StartWrite;
    // duration for each bit = 20 * timescale = 20 * 1 ns  = 20ns
    localparam period = 20;  

    RegSpaceAndSched UUT (
    .Clk(Clk),.RST(RST),.SrcAddrIn(SrcAddrIn),.WE(WE)
    ,.DstAddrIn(DstAddrIn), .BytesToSendIn(BytesToSendIn), .ReadData(ReadData)
    ,.DoneRead(DoneRead),.DoneWrite(DoneWrite), .SrcAddrOut(SrcAddrOut), .DstAddrOut(DstAddrOut), .BytesToReadOut(BytesToReadOut)
    , .BytesToWriteOut(BytesToWriteOut),.WriteData(WriteData)
    , .FULL(FULL),.StartRead(StartRead),.StartWrite(StartWrite));
    
    always 
    begin
        Clk = 1'b1; 
        #20; // high for 20 * timescale = 20 ns
    
        Clk = 1'b0;
        #20; // low for 20 * timescale = 20 ns
    end
   
    
    always @(posedge Clk)
        begin
        RST=1;
        WE=1;
        SrcAddrIn='d0;
        DstAddrIn='d0; 
        BytesToSendIn='d0;
        ReadData='d0;
        DoneRead=0;
        DoneWrite=0;
        #(period*2); // wait for period begin
        RST=0;
        WE=1;
        SrcAddrIn='d10;
        DstAddrIn='d100; 
        BytesToSendIn='d10;
        ReadData='d0;
        DoneRead=0;
        DoneWrite=0;
        #(period*2); // wait for period begin
        WE=1;
        SrcAddrIn='d20;
        DstAddrIn='d200; 
        BytesToSendIn='d20;
        ReadData='d0;
        DoneRead=0;
        DoneWrite=0;
        #(period*2); // wait for period beginWE=1;
        SrcAddrIn='d40;
        DstAddrIn='d400; 
        BytesToSendIn='d50;
        ReadData='d0;
        DoneRead=0;
        DoneWrite=0;
        #(period*2); // wait for period begin
        WE=0;
        SrcAddrIn='d50;
        DstAddrIn='d500; 
        BytesToSendIn='d50;
        ReadData='d69;
        DoneRead=1;
        DoneWrite=0;
        #(period*2); // wait for period begin
        WE=0;
        SrcAddrIn='d00;
        DstAddrIn='d000; 
        BytesToSendIn='d00;
        ReadData='d86;
        DoneRead=0;
        DoneWrite=1;
        #(period*2); // wait for period begin
        WE=0;
        SrcAddrIn='d00;
        DstAddrIn='d000; 
        BytesToSendIn='d00;
        ReadData='d0;
        DoneRead=0;
        DoneWrite=0;
        #(period*2); // wait for period begin
        WE=0;
        SrcAddrIn='d00;
        DstAddrIn='d000; 
        BytesToSendIn='d00;
        ReadData='d99;
        DoneRead=1;
        DoneWrite=0;
        #(period*2); // wait for period begin
        WE=0;
        SrcAddrIn='d00;
        DstAddrIn='d000; 
        BytesToSendIn='d00;
        ReadData='d0;
        DoneRead=0;
        DoneWrite=1;
        #(period*2); // wait for period begin
        WE=0;
        SrcAddrIn='d00;
        DstAddrIn='d000; 
        BytesToSendIn='d00;
        ReadData='d0;
        DoneRead=0;
        DoneWrite=0;
        #(period*2); // wait for period begin
        
        $stop;
        end
        

endmodule