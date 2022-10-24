//////////////////////////////////////////////////////////////////////////////////
/*This is the BRAM(it can be referenced as RegisterSpace) of the system. BRAM has
2^BRAM_ADDR_WIDTH number of rows and addresses .Each row of BRAM is one Descriptor 
which is 256bit/32Byte(DATA_WIDTH) andand each column of Descriptor is one 
field. Every Descriptor has 8(BRAM_NUM_COL) fields of 32 bit(BRAM_COL_WIDTH) each.
BRAM stores information for every transaction(in Descriptors). Processor in order
to schedule a new transaction in DMA should read Descriptors of BRAM and when it
finds an empty one(by looking its Status field) it writes the information of 
transaction in Descriptor. When the transaction is written in BRAM and the 
corresponding address pointer is written in the FIFO of the system then DMA is 
responsible of executing the transaction.*/
//////////////////////////////////////////////////////////////////////////////////

module bytewrite_tdp_ram_rf#(
//--------------------------------------------------------------------------
  parameter BRAM_NUM_COL    = 8                          , // As the Data_packet fields
  parameter BRAM_COL_WIDTH  = 32                         , // As the Data_packet field width
  parameter BRAM_ADDR_WIDTH = 10                         , // Addr Width in bits : 2 **BRAM_ADDR_WIDTH = RAM Depth
  parameter DATA_WIDTH      = BRAM_NUM_COL*BRAM_COL_WIDTH  // Data Width in bits. It should be as big as Data_packet Width
//----------------------------------------------------------------------
) (
  input                                clkA  ,
  input                                enaA  ,
  input      [BRAM_NUM_COL    -1 : 0]  weA   ,
  input      [BRAM_ADDR_WIDTH -1 : 0]  addrA ,
  input      [DATA_WIDTH      -1 : 0]  dinA  ,
  input                                clkB  ,
  input                                enaB  ,
  input      [BRAM_NUM_COL    -1 : 0]  weB   ,
  input      [BRAM_ADDR_WIDTH -1 : 0]  addrB ,
  input      [DATA_WIDTH      -1 : 0]  dinB  ,
  output reg [DATA_WIDTH      -1 : 0]  doutA ,
  output reg [DATA_WIDTH      -1 : 0]  doutB
  );
  // Core Memory
  reg [DATA_WIDTH-1:0] ram_block [(2**BRAM_ADDR_WIDTH)-1:0];
  
  // index of for loops
  integer i;
  
  // Port-A Operation
  always @ (posedge clkA) begin
    if(enaA) begin
      for(i=0 ; i<BRAM_NUM_COL ; i=i+1) begin
        if(weA[i]) begin
          ram_block[addrA][i*BRAM_COL_WIDTH +: BRAM_COL_WIDTH] <= dinA[i*BRAM_COL_WIDTH +:BRAM_COL_WIDTH];
        end
      end
      doutA <= ram_block[addrA];
    end
  end
  
  // Port-B Operation:
  always @ (posedge clkB) begin
    if(enaB) begin
      for(i=0 ; i<BRAM_NUM_COL ; i=i+1) begin
        if(weB[i]) begin
          ram_block[addrB][i*BRAM_COL_WIDTH +: BRAM_COL_WIDTH] <= dinB[i*BRAM_COL_WIDTH +:BRAM_COL_WIDTH];
        end
      end
      doutB <= ram_block[addrB];
    end
  end
endmodule // bytewrite_tdp_ram_rf