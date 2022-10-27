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
  parameter Chunck           = 5
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
   
    always_ff@(negedge Clk)
    begin
      if(RST)begin
        SrcAddrInput = $urandom_range(0,64*1000      ); 
        DstAddrInput = $urandom_range(64*1000+1,2**32);
        LengthInput  = $urandom_range(0,64*Chunck    );
      end
      else begin
        if(NextTrans)begin
          SrcAddrInput = $urandom_range(0,64*1000      ); 
          DstAddrInput = $urandom_range(64*1000+1,2**32);
          LengthInput  = $urandom_range(0,64*Chunck     );
        end                                            
      end
    end
    
    assign AlignedSrcAddr = {SrcAddrInput[BRAM_COL_WIDTH - 1 : SIZE_FIFO_WIDTH - 1],{SIZE_FIFO_WIDTH - 1{1'b0}}};
    assign AlignedDstAddr = {DstAddrInput[BRAM_COL_WIDTH - 1 : SIZE_FIFO_WIDTH - 1],{SIZE_FIFO_WIDTH - 1{1'b0}}};
    assign NextCountWrite = CountWriteTrans + ((DstAddrInput-AlignedDstAddr >= CHI_DATA_WIDTH) ? CHI_DATA_WIDTH : (DstAddrInput-AlignedDstAddr));
    assign NextCountRead  = CountReadTrans + ((SrcAddrInput-AlignedSrcAddr >= CHI_DATA_WIDTH) ? CHI_DATA_WIDTH : (SrcAddrInput-AlignedSrcAddr ));
    assign NextTrans      = (NextCountRead == LengthInput & NextCountWrite == LengthInput) ;
   
    always_ff@(negedge Clk)
    begin
      if(RST) begin
        CountWriteTrans <= 0 ;
        CountReadTrans  <= 0 ;
      end
      else begin
        if(NextCountWrite < LengthInput)
          CountWriteTrans <= NextCountWrite ;
        if(NextCountRead  < LengthInput)
          CountReadTrans = NextCountRead ;
        if(NextCountRead == LengthInput & NextCountWrite == LengthInput)begin
          CountWriteTrans <= 0 ;
          CountReadTrans  <= 0 ;
        end
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
        for(int j = 0 ; j < 20 ; j++)begin    
          RST             <= 0              ;
          SrcAddrIn       <= SrcAddrInput ;
          DstAddrIn       <= DstAddrInput ;
          if(NextCountRead == LengthInput)
            LastSrcTrans    <= 1              ;
          else 
            LastSrcTrans    <= 0              ;
          if(NextCountWrite == LengthInput)
            LastDstTrans    <= 1              ;
          else 
            LastDstTrans    <= 0              ;            
          if(CountReadTrans != LengthInput)
            EnqueueSrc      <= 1              ;
          else
            EnqueueSrc      <= 0              ;
          if(CountWriteTrans != LengthInput)
            EnqueueDst      <= 1              ;
          else
            EnqueueDst      <= 0              ;
          RXDATFLITV      <= 1                ;
          RXDATFLIT.Data  <= randVect         ;
          SizeIn          <= NextCountWrite   ;
   
        #(period*2); // wait for period
        end        
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
        
        #(period*30); // wait for period
        $stop;
        end
endmodule
