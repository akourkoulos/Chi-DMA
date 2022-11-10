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


module TestRegSpaceAndSched#(
  parameter BRAM_NUM_COL        = 8                           ,
  parameter BRAM_COL_WIDTH      = 32                          ,
  parameter BRAM_ADDR_WIDTH     = 10                          ,
  parameter DATA_WIDTH          = BRAM_NUM_COL*BRAM_COL_WIDTH ,
  parameter CHI_Word_Width      = 64                          ,
  parameter Chunk               = 5                           ,
  parameter MEMAddrWidth        = 32                          ,
  parameter NUM_OF_REPETITIONS  = 1000

);
    reg                             Clk                  ;
    reg                             RST                  ;
    reg                             enaA                 ;
    reg  [BRAM_NUM_COL    - 1 : 0]  weA                  ;
    reg  [BRAM_ADDR_WIDTH - 1 : 0]  addrA                ;
    Data_packet                     dinA                 ;
    reg                             ValidArbIn           ;
    wire                            ReadyArbProc         ;
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
    
    int flag     = 0 ;
    int varReady     ;
    int nextFULL = 0 ;
    
    always 
    begin
        Clk = 1'b1; 
        #20; // high for 20 * timescale = 20 ns
    
        Clk = 1'b0;
        #20; // low for 20 * timescale = 20 ns
    end
   
   
   always begin
     #(period)  
     if(flag == 1)begin   
       // manage ReadyBRAM
       InpReadyBRAM = ($urandom_range(2) != 0) ;  // // 67% to have control of BRAM
       // manage InpCmdFIFOFULL
       if(InpCmdFIFOFULL == 1)begin
         InpCmdFIFOFULL = ($urandom_range(2) != 0) ; // 67% chance to be full if it was full
         nextFULL       = 0                        ;
       end
       else 
         InpCmdFIFOFULL = nextFULL ;  // else not FULL
         if(OutIssueValid & InpReadyBRAM)begin
           nextFULL = ($urandom_range(3) != 0) ; //67% chance to be full on next cycle if issue a transaction
         end
         #(period) ;
      end
   end
    
    initial
        begin
        
        // Reset 
        RST              = 1        ;
        enaA             = 1        ;
        weA              = 'b0      ;
        addrA            = 'd0      ;
        dinA.SrcAddr     = 'd20     ;
        dinA.DstAddr     = 'd200    ;
        dinA.BytesToSend = 'd50     ;
        dinA.SentBytes   = 'd0      ;
        dinA.Status      = 'd0      ;
        ValidArbIn       = 0        ;
        InpReadyBRAM     = 1        ;
        InpCmdFIFOFULL   = 0        ;
        #period // signals change at the negedge of Clk
        #(period*2); // wait for period begin  
      /*  // Proc Writes 1st Desc
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
        InpCmdFIFOFULL   = 0        ; */
        flag             = 1        ; //enable flag to begin random ReadyBRAM and CmdFIFOFULL operation
         
        //#(period*120); // schedule every transaction of Descriptors 
         
        for(int j = 1 ; j < NUM_OF_REPETITIONS ; j++)begin //write NUM_OF_REPETITIONS transactions in Descriptors
        
          RST              = 0   ;                                       
          enaA             = 1   ;                            
          weA              = 'b0 ;                           
          addrA            = j   ;                                       
          dinA.SrcAddr     = 'd0 ;           
          dinA.DstAddr     = 'd0 ;           
          dinA.BytesToSend = 'd0 ;           
          dinA.SentBytes   = 'd0 ;                                            
          dinA.Status      = 'd0 ;                                       
          ValidArbIn       = 0   ;                           
          
        #(period * 2 * $urandom_range(5)); 
        
        
          RST              = 0                               ;            
          enaA             = 1                               ; 
          weA              = 'b111111                        ;
          addrA            = j                               ;            
          dinA.SrcAddr     = 'd10    * $urandom_range(10000) ;            
          dinA.DstAddr     = 'd10000 * $urandom_range(10000) ;            
          dinA.BytesToSend = 'd200   * $urandom_range(7)     ;            
          dinA.SentBytes   = 'd0                             ;                 
          dinA.Status      = 'd0                             ;            
          ValidArbIn       = 1                               ; 
          
        #(period*2);  
        end
        RST              = 0        ;            
        enaA             = 1        ; 
        weA              = 'b0      ;
        addrA            = 'd10     ;            
        dinA.SrcAddr     = 'd10     ;            
        dinA.DstAddr     = 'd10000  ;            
        dinA.BytesToSend = 'd2000   ;            
        dinA.SentBytes   = 'd0      ;                 
        dinA.Status      = 'd0      ;            
        ValidArbIn       = 0        ; 
        #(period*2);   // shcedule every transaction of Descriptors      
        end
        
         //@@@@@@@@@@@@@@@@@@@@@@@@@Check functionality@@@@@@@@@@@@@@@@@@@@@@@@@
        // Vector that keeps information for ckecking the operation of module
        reg [BRAM_COL_WIDTH - 1 : 0]TestVector[5 - 1 : 0][2**BRAM_ADDR_WIDTH - 1 : 0] ; // first dimention 0 : SrcAddr , 1 : DstAddr, 2 : BTS, 3 : SB, 4 : LastDescValid
        
        always_ff@(posedge Clk) begin
          if(RST)begin
            TestVector     <= '{default:0};
          end
          else begin
            if(enaA == 1 & weA != 0 & ReadyArbProc & ValidArbIn)begin  // when store someting in Descriptor update TestVector's SrcAddr ,DstAddr ,BTS fields
              for(int i = 0 ; i < 4 ; i++)begin
                if(weA[i])begin
                  TestVector[i][addrA] <= dinA[i*BRAM_COL_WIDTH +: BRAM_COL_WIDTH] ;
                  end
              end
            end
            
            if(!InpCmdFIFOFULL & OutIssueValid) begin //When scheduler send command to the CHI-Converter Check correctness and update TestVector's SB and LastDescValid field 
              // if ReadAddr in command is SrcAddr+SB and WriteAddr = DstAddr + SB
              if((TestVector[0][OutFinishedDescAddr] + TestVector[3][OutFinishedDescAddr] == OutReadAddr) & (TestVector[1][OutFinishedDescAddr] + TestVector[3][OutFinishedDescAddr] == OutWriteAddr))begin
                TestVector[3][OutFinishedDescAddr] <= TestVector[3][OutFinishedDescAddr]+OutReadLength ;
                TestVector[4][OutFinishedDescAddr] <= OutFinishedDescValid ;
              end
              else begin // if Expected ReadAddr is different from the real output ReadAddr display an Error
                $display("--ERROR :: Wrong ReadAddrOut or WriteAddrOut at Addr : %d, ExpReadAddr : %d , TrueReadAddr : %d" , OutFinishedDescAddr,TestVector[0][OutFinishedDescAddr]+TestVector[3][OutFinishedDescAddr],OutReadAddr);
                $stop;
              end
            end
            // if every Descriptor has been scheduled then call task that checks the results
            if(OutFinishedDescValid & UUT.DequeueFIFO & UUT.AddrPointerFIFO.state == 1) begin
              printCheckList ;
            end
          end
        end

     
     //task that checks if results are corect
      int errorflag = 0;
      task printCheckList ;
      begin
        #(period*3);
        if(UUT.AddrPointerFIFO.Empty)begin
          for(int i = 0 ; i < 2**BRAM_ADDR_WIDTH ; i++)  begin // for every addr of testVector
           //Check if every non-Empty Descriptor's fields BTS == SB and lastDescValid is on .(If Desc has 0 BTS then lastDescValid field should be 0)
            if((TestVector[2][i] == TestVector[3][i]) & (TestVector[4][i] & (TestVector[0][i] != 0 | TestVector[1][i] != 0 | TestVector[2][i] != 0)) | (!TestVector[4][i] & ((TestVector[0][i] != 0 | TestVector[1][i] != 0) & TestVector[2][i] == 0))) begin
              $display("Correct :: At Addr -> %d  BTS -> %d == SB -> %d and FinishedDescriptor == %d ", i ,  TestVector[2][i],  TestVector[3][i] ,TestVector[4][i]);
            end
            //if every non-Empty Descriptor's fields BTS != SB print Error
            else if((TestVector[2][i] != TestVector[3][i]) & (TestVector[0][i] != 0 | TestVector[1][i] != 0 | TestVector[2][i] != 0)) begin
              $display("--ERROR :: At Addr -> %d  BTS -> %d != SB -> %d ", i ,  TestVector[2][i],  TestVector[3][i]);
              $stop;
            end
            // if an non-Empty Descriptor has LastDescValid 0 then print error message
            else if(!TestVector[4][i] & (TestVector[0][i] != 0 | TestVector[1][i] != 0 | TestVector[2][i] != 0)) begin
              $display("--ERROR :: At Addr -> %d  Descriptor is not Finished ", i);
              $stop;
            end
          end
          //Check corectness of BRAM
          for(int i = 0 ; i < 2**BRAM_ADDR_WIDTH ; i++)  begin// Check if Every BRAM's fields BTS==SB and status is 0
            if(UUT.myBRAM.ram_block[i][BRAM_COL_WIDTH*3 - 1 : BRAM_COL_WIDTH*2] != UUT.myBRAM.ram_block[i][BRAM_COL_WIDTH*4 - 1 : BRAM_COL_WIDTH*3] | UUT.myBRAM.ram_block[i][BRAM_COL_WIDTH*5 - 1 : BRAM_COL_WIDTH*4] != 0)begin
              errorflag = 1;
              $display("--ERROR :: BRAM addr :%d SecAdr:%d , DstAddr : %d , BTS : %d , SB : %d , Status : %d",i,UUT.myBRAM.ram_block[i][BRAM_COL_WIDTH*1 - 1 : BRAM_COL_WIDTH*0],UUT.myBRAM.ram_block[i][BRAM_COL_WIDTH*2 - 1 : BRAM_COL_WIDTH*1],UUT.myBRAM.ram_block[i][BRAM_COL_WIDTH*3 - 1 : BRAM_COL_WIDTH*2],UUT.myBRAM.ram_block[i][BRAM_COL_WIDTH*4 - 1 : BRAM_COL_WIDTH*3],UUT.myBRAM.ram_block[i][BRAM_COL_WIDTH*5 - 1 : BRAM_COL_WIDTH*4]);  
              $stop;
            end
          end
          if(errorflag == 0)
            $display("Corect BRAM");
            $stop;
        end
      end         
      endtask      
endmodule