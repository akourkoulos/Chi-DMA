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
  parameter COUNTER_WIDTH    = 6                     , // log2(FIFO_LENGTH) + 1
  parameter Chunk            = 5
//--------------------------------------------------------------------------
);
     reg                                   RST          ;
     reg                                   Clk          ;
     reg         [BRAM_COL_WIDTH   - 1 :0] SrcAddrIn    ;
     reg         [BRAM_COL_WIDTH   - 1 :0] DstAddrIn    ;
     reg                                   LastSrcTrans ;
     reg                                   LastDstTrans ;
     reg                                   EnqueueSrc   ;
     reg                                   EnqueueDst   ;
     reg                                   RXDATFLITV   ;
     DataFlit                              RXDATFLIT    ;
     wire                                  RXDATLCRDV   ;
     reg                                   DequeueBS    ;
     reg        [SIZE_FIFO_WIDTH  - 1 : 0] SizeIn       ;
     wire       [CHI_DATA_WIDTH   - 1 : 0] BEOut        ;
     wire       [CHI_DATA_WIDTH*8 - 1 : 0] DataOut      ;
     wire                                  EmptyBS      ;
     wire                                  BSFULLSrc    ;
     wire                                  BSFULLDst    ;

    localparam period           = 20   ;   // duration for each bit = 20 * timescale = 20 * 1 ns  = 20ns  
    
    BarrelShifter     UUT (
     .  RST          (  RST           ),
     .  Clk          (  Clk           ),
     .  SrcAddrIn    (  SrcAddrIn     ),
     .  DstAddrIn    (  DstAddrIn     ),
     .  LastSrcTrans (  LastSrcTrans  ),
     .  LastDstTrans (  LastDstTrans  ),
     .  EnqueueSrc   (  EnqueueSrc    ),
     .  EnqueueDst   (  EnqueueDst    ),
     .  RXDATFLITV   (  RXDATFLITV    ),
     .  RXDATFLIT    (  RXDATFLIT     ),
     .  RXDATLCRDV   (  RXDATLCRDV    ),
     .  DequeueBS    (  DequeueBS     ),
     .  SizeIn       (  SizeIn        ),
     .  BEOut        (  BEOut         ),
     .  DataOut      (  DataOut       ),
     .  EmptyBS      (  EmptyBS       ),
     .  BSFULLSrc    (  BSFULLSrc     ),
     .  BSFULLDst    (  BSFULLDst     )
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
    
    reg                           NextTrans       ;
    reg [BRAM_COL_WIDTH   - 1 :0] SrcAddrInput    ;
    reg [BRAM_COL_WIDTH   - 1 :0] DstAddrInput    ;
    reg [BRAM_COL_WIDTH   - 1 :0] LengthInput     ;
    reg [BRAM_COL_WIDTH   - 1 :0] CountReadTrans  ;
    reg [BRAM_COL_WIDTH   - 1 :0] CountWriteTrans ;
   
    always
    begin
      if(RST)begin
        SrcAddrInput = $urandom_range(0,64*1000      ); 
        DstAddrInput = $urandom_range(64*1000+1,2**32);
        LengthInput  = $urandom_range(0,64*Chuck     );
      end
      else begin
        if(NextTrans)begin
          SrcAddrInput = $urandom_range(0,64*1000      ); 
          DstAddrInput = $urandom_range(64*1000+1,2**32);
          LengthInput  = $urandom_range(0,64*Chuck     );
        end                                            
      end
      #period;
    end
    
    
    always
    begin
      if(RST) begin
        NextTrans       = 0;
        CountWriteTrans = 0 ;
        CountReadTrans  = 0 ;
      end
      else begin
        if(CountWriteTrans < LengthInput)
          CountWriteTrans = CountWriteTrans + ((LengthInput-CountWriteTrans > CHI_DATA_WIDTH) ? CHI_DATA_WIDTH : (LengthInput-CountWriteTrans));
        if(CountReadTrans < LengthInput)
          CountReadTrans = CountReadTrans + ((LengthInput-CountReadTrans > CHI_DATA_WIDTH) ? CHI_DATA_WIDTH : (LengthInput-CountReadTrans));
      end      
    end
    
    always 
    begin
        Clk = 1'b1; 
        #20; // high for 20 * timescale = 20 ns
    
        Clk = 1'b0;
        #20; // low for 20 * timescale = 20 ns
    end 
    
    always begin
      DequeueBS = !EmptyBS;
      #20;
    end
    
    always@(posedge Clk)
        begin       
        RST          <= 1 ;
        SrcAddrIn    <= 0 ;
        DstAddrIn    <= 0 ;
        LastSrcTrans <= 0 ;
        LastDstTrans <= 1 ;
        EnqueueSrc   <= 1 ;
        EnqueueDst   <= 1 ;
        RXDATFLITV   <= 1 ;
        RXDATFLIT    <= 0 ;
        SizeIn       <= 0 ;
        
        #(period*2); // wait for period
        # period   ; // wait for period
        
        RST             <= 0              ;
        SrcAddrIn       <= 'd64 + 'd9     ;
        DstAddrIn       <= 'd64*'d15 + 'd1;
        LastSrcTrans    <= 0              ;
        LastDstTrans    <= 1              ;
        EnqueueSrc      <= 1              ;
        EnqueueDst      <= 1              ;
        RXDATFLITV      <= 0              ;
        RXDATFLIT.Data  <= randVect       ;
        SizeIn          <= 'd63           ;
        
        #(period*2); // wait for period
        
        RST             <= 0              ;
        SrcAddrIn       <= 'd64 + 'd9     ;
        DstAddrIn       <= 'd64*'d15 + 'd1;
        LastSrcTrans    <= 1              ;
        LastDstTrans    <= 0              ;
        EnqueueSrc      <= 1              ;
        EnqueueDst      <= 0              ;
        RXDATFLITV      <= 1              ;
        RXDATFLIT.Data  <= randVect       ;
        SizeIn          <= 'd0            ;
        
         #(period*2); // wait for period
        
        RST             <= 0              ;
        SrcAddrIn       <= 'd64 + 'd9     ;
        DstAddrIn       <= 'd64*'d15 + 'd1;
        LastSrcTrans    <= 0              ;
        LastDstTrans    <= 0              ;
        EnqueueSrc      <= 0              ;
        EnqueueDst      <= 0              ;
        RXDATFLITV      <= 1              ;
        RXDATFLIT.Data  <= randVect       ;
        SizeIn          <= 'd0            ;
        
        #(period*2); // wait for period
                
        RST             <= 0              ;
        SrcAddrIn       <= 'd64           ;
        DstAddrIn       <= 'd64*'d15 + 'd1;
        LastSrcTrans    <= 0              ;
        LastDstTrans    <= 0              ;
        EnqueueSrc      <= 0              ;
        EnqueueDst      <= 0              ;
        RXDATFLITV      <= 0              ;
        RXDATFLIT.Data  <= randVect       ;
        SizeIn          <= 0              ;
        
        #(period*10); // wait for period
        $stop;
        end
endmodule
