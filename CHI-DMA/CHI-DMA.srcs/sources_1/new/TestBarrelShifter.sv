`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08.09.2022 11:28:43
// Design Name: 
// Module Name: TestBarrelShifter
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


module TestBarrelShifte#(
//--------------------------------------------------------------------------
  parameter CHI_DATA_WIDTH   = 64                    , // Bytes
  parameter SIZE_FIFO_WIDTH  = 7                     , // log2(CHI_DATA_WIDTH) + 1 
  parameter SHIFT_WIDTH      = 9                     , // log2(CHI_DATA_WIDTH*8)
  parameter BRAM_COL_WIDTH   = 32                    ,
  parameter FIFO_LENGTH      = 32                    ,
  parameter COUNTER_WIDTH    = 6                       // log2(FIFO_LENGTH) + 1
//--------------------------------------------------------------------------
);
     reg                                   RST         ;
     reg                                   Clk         ;
     reg         [BRAM_COL_WIDTH   - 1 :0] SrcAddrIn   ;
     reg         [BRAM_COL_WIDTH   - 1 :0] DstAddrIn   ;
     reg         [BRAM_COL_WIDTH   - 1 :0] LengthIn    ;
     reg                                   EnqueueIn   ;
     reg                                   DequeueBS   ;
     reg                                   RXDATFLITV  ;
     DataFlit                              RXDATFLIT   ;
     wire                                  RXDATLCRDV  ;
     wire       [CHI_DATA_WIDTH   - 1 : 0] BEOut       ;
     wire       [CHI_DATA_WIDTH*8 - 1 : 0] DataOut     ;
     wire                                  EmptyBS     ;
     wire                                  BSFULL      ;
                                                     

    localparam period           = 20   ;   // duration for each bit = 20 * timescale = 20 * 1 ns  = 20ns  
    
    BarrelShifter UUT (
     .  RST           (  RST          ),
     .  Clk           (  Clk          ),
     .  SrcAddrIn     (  SrcAddrIn    ),
     .  DstAddrIn     (  DstAddrIn    ),
     .  LengthIn      (  LengthIn     ),
     .  EnqueueIn     (  EnqueueIn    ),
     .  DequeueBS     (  DequeueBS    ),
     .  RXDATFLITV    (  RXDATFLITV   ),
     .  RXDATFLIT     (  RXDATFLIT    ),
     .  RXDATLCRDV    (  RXDATLCRDV   ),
     .  BEOut         (  BEOut        ),
     .  DataOut       (  DataOut      ),
     .  EmptyBS       (  EmptyBS      ),
     .  BSFULL        (  BSFULL       )
    );                
    
    
    //generate a random vector of CHI_DATA_WIDTH bits
    reg [CHI_DATA_WIDTH*8 - 1 : 0]randVect;
    genvar i ;
    generate 
    for(i = 0 ; i < CHI_DATA_WIDTH ; i++)
      always 
          begin
          #period;
            randVect[(i+1)*8 - 1:i*8] = $urandom();
          #period; // high for 20 * timescale = 20 ns
      end 
    endgenerate;
    
    always 
    begin
        Clk = 1'b1; 
        #20; // high for 20 * timescale = 20 ns
    
        Clk = 1'b0;
        #20; // low for 20 * timescale = 20 ns
    end 
    
    always begin
      DequeueBS = !EmptyBS;
      #period;
    end
    
    always@(posedge Clk)
        begin       
        RST            <= 1 ;
        SrcAddrIn      <= 0 ;
        DstAddrIn      <= 0 ;
        LengthIn       <= 0 ;
        EnqueueIn      <= 0 ;
        RXDATFLITV     <= 0 ;
        RXDATFLIT.Data <= 0 ;
        
        #(period*2); // wait for period
        # period   ; // wait for period
        
        RST            <= 0           ;
        SrcAddrIn      <= 'd10        ;
        DstAddrIn      <= 'd64*5 +35  ;
        LengthIn       <= 'd20        ;
        EnqueueIn      <= 1           ;
        RXDATFLITV     <= 0           ;
        RXDATFLIT.Data <= randVect    ;
        
        #(period*2); // wait for period
        
        for( int j=0 ; j < 15 ; j++)begin       
          RST            <= 0           ;
          SrcAddrIn      <= 0           ;
          DstAddrIn      <= 0           ;
          LengthIn       <= 0           ;
          EnqueueIn      <= 0           ;
          RXDATFLITV     <= 1           ;
          RXDATFLIT.Data <= randVect    ;
          
          #(period*2); // wait for period
        end
        $stop;
        end
endmodule
