import DataPkg::*; 


/*As Descriptor, we refer to the full set of registers, containing the info
  src,dst, and so on. a typical lenght is 128bit. This can be further divided
  to 4registers of 32bit each, since the software usually does 32bit writes.
  Some times it can do MAX 128bit , and hence the 128bit total lenght. 
  
  The controler which handles the CPU comuniucation should be able to understand
  if a write is 32 or 64 or 128bit, and assert the appropriate WEs*/


module Descriptor #( 
  parameter DescWidth        = 256         , 
  parameter RegWidth         = 32          , 
  parameter NumOfRegInDesc   = 5           
)(
    input  logic                              Clk        , 
    input  logic                              RST        ,
    input  logic       [NumOfRegInDesc-1:0]   WE         ,
    input  Data_packet                        DescDataIn ,
    output Data_packet                        DescDataOut
    );  

    reg  [RegWidth-1:0]DescReg[NumOfRegInDesc-1:0] ;
    
    genvar i;
    generate
    for(i=0 ; i<NumOfRegInDesc ; i++) begin
      assign DescDataOut[(i+1)*RegWidth-1:i*RegWidth] = DescReg[i] ;
    end
    endgenerate 
    
    genvar j;
    generate
    for( j=0 ; j<NumOfRegInDesc ; j++) begin 
      always_ff @(posedge Clk) begin
        if(RST)begin                                    // reset all Registers in descritpor 
          DescReg[j] <= 'd0;    
        end
        else begin
          if(WE[j]) begin
             DescReg[j] <= DescDataIn[(j+1)*RegWidth-1:j*RegWidth];
          end
        end
      end
    end
    endgenerate
endmodule