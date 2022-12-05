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

import DataPkg     ::*; 
import CompleterPkg::*; 
// Indexes of Descriptor's fields
`define SRCRegIndx        0
`define DSTRegIndx        1
`define BTSRegIndx        2
`define SBRegIndx         3
`define StatusRegIndx     4
// Status state
`define StatusIdle        0
`define StatusActive      1
`define StatusError       2
`define TempStatusError   3

`define RspErrWidth       2
`define NoError           0

module TestCompleter#(
//--------------------------------------------------------------------------
  parameter NUM_OF_REPETITIONS = 500                                  ,
  parameter BRAM_ADDR_WIDTH    = 10                                   ,
  parameter BRAM_NUM_COL       = 8                                    ,  // As the Data_packet fields
  parameter FIFO_Length        = 32                                   ,
  parameter FIFO_WIDTH         = BRAM_ADDR_WIDTH + `RspErrWidth*2 + 1    // Width is DescAdd + RespErrorWidth + LastDescTrans
//----------------------------------------------------------------------
);
   reg                                            RST          ;
   reg                                            Clk          ;
   Completer_Packet                               CompDataPack ;
   reg                                            ValidUpdate  ;
   Data_packet                                    DescData     ;
   reg                                            ReadyBRAM    ;
   wire                                           ValidBRAM    ;
   wire              [BRAM_ADDR_WIDTH   - 1 : 0]  AddrOut      ;
   Data_packet                                    DataOut      ;
   wire              [BRAM_NUM_COL      - 1 : 0]  WE           ;
   wire                                           FULL         ;
                                                 
                                                 
    // duration for each bit = 20 * timescdoutBale = 20 * 1 ns  = 20ns
    localparam period = 20;  

    Completer#(
       BRAM_ADDR_WIDTH   ,
       BRAM_NUM_COL      ,
       FIFO_Length       ,
       FIFO_WIDTH          
    ) UUT (
     .RST         ( RST           ) ,
     .Clk         ( Clk           ) ,
     .CompDataPack( CompDataPack  ) ,
     .ValidUpdate ( ValidUpdate   ) ,
     .DescData    ( DescData      ) ,
     .ReadyBRAM   ( ReadyBRAM     ) ,
     .ValidBRAM   ( ValidBRAM     ) ,
     .AddrOut     ( AddrOut       ) ,
     .DataOut     ( DataOut       ) ,
     .WE          ( WE            ) ,
     .FULL        ( FULL          ) 
    );
    
    always
    begin
        Clk = 1'b1; 
        #20; // high for 20 * timescale = 20 ns
    
        Clk = 1'b0;
        #20; // low for 20 * timescale = 20 ns
    end
    
    always begin
      #(period + 2*period*$urandom_range(2));
      if(ValidBRAM)begin
        ReadyBRAM = 1                        ;
        if($urandom_range(1,2) == 1 )
          DescData.Status = `StatusActive    ;
        else
          DescData.Status = `TempStatusError ;
        #(period*2*$urandom_range(2))        ;
        ReadyBRAM = 0                        ;
        DescData.Status = 0                  ;
      end
      #period;
    end
    
    initial
       begin
          // Reset
         RST             = 1 ;
         CompDataPack    = 0 ;
         ValidUpdate     = 0 ;
         DescData        = 0 ;
         ReadyBRAM       = 0 ;   
          
         #(period); // signals change at the negedge of Clk  
         #(period*2); // wait for period   
         
         for(int i = 0 ; i < NUM_OF_REPETITIONS ; i=i) begin
           if(!FULL)begin
             RST                          = 0                                  ;
             CompDataPack.DescAddr        = $urandom_range(2**BRAM_ADDR_WIDTH) ;
             CompDataPack.LastDescTrans   = $urandom()                         ;
             CompDataPack.DBIDRespErr     = $urandom_range(2)                  ;
             CompDataPack.DataRespErr     = $urandom_range(2)                  ;
             ValidUpdate                  = 1                                  ;
             i = i + 1                                                         ;
             #(period*2);
             RST                          = 0 ;
             CompDataPack.LastDescTrans   = 0 ;
             CompDataPack.DescAddr        = 0 ;
             CompDataPack.DBIDRespErr     = 0 ;
             CompDataPack.DataRespErr     = 0 ;
             ValidUpdate                  = 0 ;
           end
           #(period*2*$urandom_range(2));
         end
       end
       
      //@@@@@@@@@@@@@@@@@@@@@@@@@Check functionality@@@@@@@@@@@@@@@@@@@@@@@@@
      // Vectors that keep information for ckecking the operation of Completer
       Completer_Packet                             TestVectorPackIn   [NUM_OF_REPETITIONS - 1 : 0] ; 
       reg             [BRAM_ADDR_WIDTH    - 1 : 0] TestVectorAddrOut  [NUM_OF_REPETITIONS - 1 : 0] ;
       Data_packet                                  TestVectorDataOut  [NUM_OF_REPETITIONS - 1 : 0] ;
       reg             [BRAM_NUM_COL       - 1 : 0] TestVectorWE       [NUM_OF_REPETITIONS - 1 : 0] ;
       Data_packet                                  TestVectorDescData [NUM_OF_REPETITIONS - 1 : 0] ;
       reg             [NUM_OF_REPETITIONS - 1 : 0] pointerInp                                      ;
       reg             [NUM_OF_REPETITIONS - 1 : 0] pointerOutp                                     ;
       int                                          RepetPointer                                    ;
       always_ff@(posedge Clk) begin
         if(RST)begin
           TestVectorPackIn  <= '{default : 0} ;
           TestVectorAddrOut <= '{default : 0} ;
           TestVectorDataOut <= '{default : 0} ;
           TestVectorWE      <= '{default : 0} ;
           pointerInp        <= 0              ;
           pointerOutp       <= 0              ;
           RepetPointer      <= 0              ;
         end     
         else begin // if a Valid non-Empty DataPacket update testvector 
           if(ValidUpdate & (CompDataPack.LastDescTrans != 0 | CompDataPack.DBIDRespErr != 0 | CompDataPack.DataRespErr != 0))begin
             TestVectorPackIn[pointerInp] <= CompDataPack   ;
             pointerInp                   <= pointerInp + 1 ;      
           end // if write DescBRAM or read it but not write it because it is already written update testvectors
           if((ValidBRAM & ReadyBRAM & WE != 0))begin
             TestVectorAddrOut  [pointerOutp] <= AddrOut         ;
             TestVectorDataOut  [pointerOutp] <= DataOut         ;
             TestVectorWE       [pointerOutp] <= WE              ;
             TestVectorDescData [pointerOutp] <= DescData        ;
             pointerOutp                      <= pointerOutp + 1 ;
           end
           // count finished CompDataPacket that came as input
           if(UUT.Dequeue & ValidUpdate & CompDataPack.LastDescTrans == 0 & CompDataPack.DBIDRespErr == 0 & CompDataPack.DataRespErr == 0)begin
             RepetPointer <= RepetPointer + 2 ;
           end
           else if(ValidUpdate & CompDataPack.LastDescTrans == 0 & CompDataPack.DBIDRespErr == 0 & CompDataPack.DataRespErr == 0)begin
             RepetPointer <= RepetPointer + 1 ;
           end
           else if(UUT.Dequeue )begin
             RepetPointer <= RepetPointer + 1 ;
           end
           // When all CompDataPacket In are finished check corectness of module
           if(RepetPointer == NUM_OF_REPETITIONS)begin
             RepetPointer <= 0 ;
             printCheckList;
           end
         end
       end
       
       //task that checks if results are corect
      task printCheckList ;
      begin
        for(int i = 0 ; i < NUM_OF_REPETITIONS ; i++)begin
          if(TestVectorPackIn[i] != 0)begin
            // for every repetition if addrOut is the same with DescAddr , WE is on when or WE is of but Desc is already written with error and StatusOut is idle when desc is not written and 0 when it is already written with error then corect process
            if(TestVectorPackIn[i].DescAddr == TestVectorAddrOut[i] & ((TestVectorWE[i] == ('d1 << `StatusRegIndx)))
             & ((TestVectorDescData[i].Status != `TempStatusError & TestVectorDataOut[i].Status == `StatusIdle & TestVectorPackIn[i].DBIDRespErr == 0 & TestVectorPackIn[i].DataRespErr == 0 & TestVectorPackIn[i].LastDescTrans) 
             | (TestVectorDescData[i].Status == `TempStatusError &  TestVectorDataOut[i].Status == `StatusError & TestVectorPackIn[i].LastDescTrans))
             | (TestVectorDataOut[i].Status == `TempStatusError & (TestVectorPackIn[i].DBIDRespErr != 0 | TestVectorPackIn[i].DataRespErr != 0 ))
             | (TestVectorDescData[i].Status != `TempStatusError & TestVectorDataOut[i].Status == `StatusError & (TestVectorPackIn[i].DBIDRespErr != 0 | TestVectorPackIn[i].DataRespErr != 0) & TestVectorPackIn[i].LastDescTrans))
              $display("%d. Correct",i);
            // if DataPack Addr is Different from AddrOut Wrong
            else if (TestVectorPackIn[i].DescAddr != TestVectorAddrOut[i])begin
              $display("%d. --Error:: Wrong Addr. Expected :%d but Addr was %d ",i,TestVectorPackIn[i].DescAddr,TestVectorAddrOut[i]);
              $stop;
            end
            // Wrong WE
            else if ((TestVectorWE[i] != ('d1 << `StatusRegIndx)))begin
              $display("%d. --Error:: Wrong WE. Expected :%d but WE was %d ",i,('d1 << `StatusRegIndx),TestVectorWE[i]);
              $stop;
            end
            // Wrong DataOut
            else begin
              $display("%d. --Error:: Wrong Status Out . Status shouldnt be %d ",i,TestVectorDataOut[i].Status,TestVectorDescData[i].Status);
              $stop;
            end
          end
        end
      end
      endtask
endmodule

