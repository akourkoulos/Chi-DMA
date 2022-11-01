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

`define MaxCrds           15
`define CrdRegWidth       4  // log2(MaxCrds)

module TestBarrelShifte#(
//--------------------------------------------------------------------------
  parameter CHI_DATA_WIDTH      = 64                    , // Bytes
  parameter ADDR_WIDTH_OF_DATA  = 7                     , // log2(CHI_DATA_WIDTH) + 1 
  parameter SHIFT_WIDTH         = 9                     , // log2(CHI_DATA_WIDTH*8)
  parameter BRAM_COL_WIDTH      = 32                    ,
  parameter FIFO_LENGTH         = 32                    ,
  parameter DATA_FIFO_LENGTH    = 32                    ,
  parameter COUNTER_WIDTH       = 6                     , // log2(FIFO_LENGTH) + 1
  parameter Chunk               = 5                     ,
  parameter NUM_OF_REPETITIONS  = 50
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
    //count Credits
    reg [`CrdRegWidth - 1 : 0]CntCrds ;
    
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
    
    // CLk
    always 
    begin
        Clk = 1'b1; 
        #20; // high for 20 * timescale = 20 ns
    
        Clk = 1'b0;
        #20; // low for 20 * timescale = 20 ns
    end 
    
    // manage Count Crds Counter
    always_ff@(posedge Clk)begin
      if(RST)
        CntCrds = 0 ;
      else  
        if(RXDATLCRDV & !RXDATFLITV)
          CntCrds = CntCrds + 1 ;
        else if(!RXDATLCRDV & RXDATFLITV)
          CntCrds = CntCrds - 1 ;
    end
    
    // Manage Data In
    always begin
      if(RST)begin
        RXDATFLITV = 0 ;
        RXDATFLIT  = 0 ;
        #(period);
      end
      else begin
        RXDATFLITV = 0 ;
        RXDATFLIT  = 0 ;
        #(period*2*$urandom_range(0,3) + period); // wait for random delay for the next enqueue
        if(CntCrds != 0 & !(UUT.EmptySrc))begin
          RXDATFLITV      = 1        ;
          RXDATFLIT.Data  = randVect ;
          #(period*2);
        end 
        RXDATFLITV      = 0 ;
        RXDATFLIT.Data  = 0 ;
        #period;
      end
    end
    
    // Dequeue a write from BS when it is non-Empty
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
        
        for( int j=0 ; j < NUM_OF_REPETITIONS ; j=j+0)begin       
          if(!BSFULL) begin
          RST            <= 0                                                            ;
          SrcAddrIn      <= 'd64*$urandom_range(0,10**6) + $urandom_range(0,64)          ;
          DstAddrIn      <= 'd64*$urandom_range(10**6,2**32 - 1) + $urandom_range(0,64)  ;
          LengthIn       <= $urandom_range(0,Chunk*CHI_DATA_WIDTH)                       ;
          EnqueueIn      <= 1                                                            ;
          j++;
          end
          #(period*2); // wait for random delay for the next enqueue
          
          RST            <= 0 ;
          SrcAddrIn      <= 0 ;
          DstAddrIn      <= 0 ;
          LengthIn       <= 0 ;
          EnqueueIn      <= 0 ;
          
          #(period*2*$urandom_range(0,3)); // wait for random delay for the next enqueue
        end
        
        #(period*2000); // wait for period
        $stop;
        end
endmodule
