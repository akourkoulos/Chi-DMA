`timescale 1ns / 1ps
import DataPkg::*;

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


module TestBRAMAndSched#(
  parameter BRAM_NUM_COL      = 8                           ,
  parameter BRAM_COL_WIDTH    = 32                          ,
  parameter BRAM_ADDR_WIDTH   = 10                          ,
  parameter DATA_WIDTH        = BRAM_NUM_COL*BRAM_COL_WIDTH ,
  parameter CHI_Word_Width    = 64                          ,
  parameter Chunk             = 5                           ,
  parameter MEMAddrWidth      = 32                          
);
    reg                             Clk                  ;
    reg                             RST                  ;
    reg                             enaA                 ;
    reg  [BRAM_NUM_COL    - 1 : 0]  weA                  ;
    reg  [BRAM_ADDR_WIDTH - 1 : 0]  addrA                ;
    Data_packet                     dinA                 ;
    reg                             ValidArbIn           ;
    reg                             ReadyArbProc         ;
    reg                             InpReadyBRAM         ; // From Arbiter BRAM
    reg                             InpCmdFIFOFULL       ; // From CHI-convert 
    Data_packet                     BRAMdoutA            ;
    wire                            OutIssueValid        ;
    wire [BRAM_COL_WIDTH  - 1 : 0]  OutReadAddr          ;
    wire [BRAM_COL_WIDTH  - 1 : 0]  OutReadLength        ;
    wire [BRAM_COL_WIDTH  - 1 : 0]  OutWriteAddr         ;
    wire [BRAM_COL_WIDTH  - 1 : 0]  OutWriteLength       ;
    wire [BRAM_ADDR_WIDTH - 1 : 0]  OutFinishedDescAddr  ;
    wire                            OutFinishedDescValid ;
    wire                            OutValidBRAM         ;
    // duration for each bit = 20 * timescale = 20 * 1 ns  = 20ns
    localparam period = 20;  

    BRAMAndSched        UUT (
      .Clk                  (Clk                 ),
      .RST                  (RST                 ),
      .enaA                 (enaA                ),
      .weA                  (weA                 ),
      .addrA                (addrA               ),
      .dinA                 (dinA                ),
      .ValidArbIn           (ValidArbIn          ),
      .ReadyArbProc         (ReadyArbProc        ),
      .InpReadyBRAM         (InpReadyBRAM        ),
      .InpCmdFIFOFULL       (InpCmdFIFOFULL      ),
      .BRAMdoutA            (BRAMdoutA           ),
      .OutIssueValid        (OutIssueValid       ),
      .OutReadAddr          (OutReadAddr         ),
      .OutReadLength        (OutReadLength       ),
      .OutWriteAddr         (OutWriteAddr        ),
      .OutWriteLength       (OutWriteLength      ),
      .OutFinishedDescAddr  (OutFinishedDescAddr ),
      .OutFinishedDescValid (OutFinishedDescValid),
      .OutValidBRAM         (OutValidBRAM        )
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
        
        #period // signals change at the negedge of Clk
        // Reset 
        RST              = 1        ;
        enaA             = 1        ;
        weA              = 'b111111 ;
        addrA            = 'd0      ;
        dinA.SrcAddr     = 'd20     ;
        dinA.DstAddr     = 'd200    ;
        dinA.BytesToSend = 'd50     ;
        dinA.SentBytes   = 'd0      ;
        dinA.Status      = 'd0      ;
        ValidArbIn       = 0        ;
        InpReadyBRAM     = 1        ;
        InpCmdFIFOFULL   = 0        ;
         
        #(period*2); // wait for period begin  
        // Proc Writes 1st Desc
        RST              = 0        ;            
        enaA             = 1        ; 
        weA              = 'b111111 ;
        addrA            = 'd1      ;            
        dinA.SrcAddr     = 'd10     ;            
        dinA.DstAddr     = 'd10000  ;            
        dinA.BytesToSend = 'd2000   ;            
        dinA.SentBytes   = 'd0      ;                 
        dinA.Status      = 'd0      ;            
        ValidArbIn       = 1        ; 
        InpReadyBRAM     = 1        ;
        InpCmdFIFOFULL   = 0        ;       
            
        #(period*2); // wait for period begin  
        // Proc Writes 2nd Desc 
        RST              = 0        ;            
        enaA             = 1        ; 
        weA              = 'b111111 ;
        addrA            = 'd2      ;            
        dinA.SrcAddr     = 'd10     ;            
        dinA.DstAddr     = 'd20000  ;            
        dinA.BytesToSend = 'd500    ;            
        dinA.SentBytes   = 'd0      ;                 
        dinA.Status      = 'd0      ;            
        ValidArbIn       = 1        ;  
        InpReadyBRAM     = 1        ;
        InpCmdFIFOFULL   = 0        ; 
        
        #(period*2); // wait for period begin 
        // Proc Writes 3rd Desc
        RST              = 0        ;            
        enaA             = 1        ;   
        weA              = 'b111111 ;
        addrA            = 'd3      ;            
        dinA.SrcAddr     = 'd120    ;            
        dinA.DstAddr     = 'd1000   ;            
        dinA.BytesToSend = 'd500    ;            
        dinA.SentBytes   = 'd0      ;                 
        dinA.Status      = 'd0      ;            
        ValidArbIn       = 1        ; 
        InpReadyBRAM     = 1        ;
        InpCmdFIFOFULL   = 0        ;           
       
        #(period*2); // wait for period begin 
        // Proc Writes 4th Desc . Conflict on FIFO : Arbiter allows proc access 
        RST              = 0        ;            
        enaA             = 1        ;  
        weA              = 'b111111 ;
        addrA            = 'd4      ;            
        dinA.SrcAddr     = 'd320    ;            
        dinA.DstAddr     = 'd2500   ;            
        dinA.BytesToSend = 'd500    ;            
        dinA.SentBytes   = 'd0      ;                 
        dinA.Status      = 'd0      ;            
        ValidArbIn       = 1        ;  
        InpReadyBRAM     = 1        ;
        InpCmdFIFOFULL   = 1        ;          
       
        #(period*2); // wait for period begin 
        // Write Back completed. 
        RST              = 0        ;            
        enaA             = 1        ;  
        weA              = 'b0      ;
        addrA            = 'd1      ;            
        dinA.SrcAddr     = 'd12     ;            
        dinA.DstAddr     = 'd6000   ;            
        dinA.BytesToSend = 'd10     ;            
        dinA.SentBytes   = 'd0      ;                 
        dinA.Status      = 'd0      ;            
        ValidArbIn       = 0        ;    
        InpReadyBRAM     = 1        ;
        InpCmdFIFOFULL   = 1        ;           
        
        #(period*2); // wait for period begin 
        // Command FIFO FULL is set so an issue cant be done (wait)
        RST              = 0        ;            
        enaA             = 1        ;  
        weA              = 'b0      ;
        addrA            = 'd1      ;            
        dinA.SrcAddr     = 'd12     ;            
        dinA.DstAddr     = 'd6000   ;            
        dinA.BytesToSend = 'd10     ;            
        dinA.SentBytes   = 'd0      ;                 
        dinA.Status      = 'd0      ;            
        ValidArbIn       = 0        ;  
        InpReadyBRAM     = 1        ;
        InpCmdFIFOFULL   = 1        ;          
       
        
        #(period*2); // wait for period begin 
        // Issue Completed
        RST              = 0        ;            
        enaA             = 1        ;  
        weA              = 'b0      ;
        addrA            = 'd1      ;            
        dinA.SrcAddr     = 'd12     ;            
        dinA.DstAddr     = 'd6000   ;            
        dinA.BytesToSend = 'd10     ;            
        dinA.SentBytes   = 'd0      ;                 
        dinA.Status      = 'd0      ;            
        ValidArbIn       = 0        ;  
        InpReadyBRAM     = 1        ;
        InpCmdFIFOFULL   = 0        ;          
       
       #(period*2); // wait for period begin 
        // Write Back + No BRAM control = Idle State
        RST              = 0        ;            
        enaA             = 1        ;  
        weA              = 'b0      ;
        addrA            = 'd1      ;            
        dinA.SrcAddr     = 'd12     ;            
        dinA.DstAddr     = 'd6000   ;            
        dinA.BytesToSend = 'd10     ;            
        dinA.SentBytes   = 'd0      ;                 
        dinA.Status      = 'd0      ;            
        ValidArbIn       = 0        ;  
        InpReadyBRAM     = 0        ;
        InpCmdFIFOFULL   = 0        ; 
        
        #(period*4); // wait for period begin 
        // transition to issue because BRAM's control reobtained
        RST              = 0        ;            
        enaA             = 1        ;  
        weA              = 'b0      ;
        addrA            = 'd1      ;            
        dinA.SrcAddr     = 'd12     ;            
        dinA.DstAddr     = 'd6000   ;            
        dinA.BytesToSend = 'd10     ;            
        dinA.SentBytes   = 'd0      ;                 
        dinA.Status      = 'd0      ;            
        ValidArbIn       = 0        ;  
        InpReadyBRAM     = 1        ;
        InpCmdFIFOFULL   = 0        ; 
        
        #(period*2); // wait for period begin 
        // BRAM control lost again --> go to Idle state
        RST              = 0        ;            
        enaA             = 1        ;  
        weA              = 'b0      ;
        addrA            = 'd1      ;            
        dinA.SrcAddr     = 'd12     ;            
        dinA.DstAddr     = 'd6000   ;            
        dinA.BytesToSend = 'd10     ;            
        dinA.SentBytes   = 'd0      ;                 
        dinA.Status      = 'd0      ;            
        ValidArbIn       = 0        ;  
        InpReadyBRAM     = 0        ;
        InpCmdFIFOFULL   = 0        ; 
        
         #(period*2); // wait for period begin 
        //  transition to issue because BRAM's control reobtained 
        RST              = 0        ;            
        enaA             = 1        ;  
        weA              = 'b0      ;
        addrA            = 'd1      ;            
        dinA.SrcAddr     = 'd12     ;            
        dinA.DstAddr     = 'd6000   ;            
        dinA.BytesToSend = 'd10     ;            
        dinA.SentBytes   = 'd0      ;                 
        dinA.Status      = 'd0      ;            
        ValidArbIn       = 0        ;  
        InpReadyBRAM     = 1        ;
        InpCmdFIFOFULL   = 0        ; 
        
        // schedule every transaction of Descriptors 
        #(period*80); // wait for period begin 
        
        $stop;
        end
        

endmodule