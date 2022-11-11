`timescale 1ns / 1ps
// DescBRAM Data packet
package DataPkg;
`define RspErrWidth       2
   parameter BRAM_COL_WIDTH    = 32 ;
   typedef struct packed {
     bit [BRAM_COL_WIDTH  - 1 : 0]  Reserved3   ;  // not used 
     bit [BRAM_COL_WIDTH  - 1 : 0]  Reserved2   ;  // not used 
     bit [BRAM_COL_WIDTH  - 1 : 0]  Reserved1   ;  // not used 
     bit [BRAM_COL_WIDTH  - 1 : 0]  Status      ; 
     bit [BRAM_COL_WIDTH  - 1 : 0]  SentBytes   ;
     bit [BRAM_COL_WIDTH  - 1 : 0]  BytesToSend ;
     bit [BRAM_COL_WIDTH  - 1 : 0]  DstAddr     ;
     bit [BRAM_COL_WIDTH  - 1 : 0]  SrcAddr     ;
 } Data_packet;
 endpackage

// Packets for Completer module
package CompleterPkg;
   parameter BRAM_ADDR_WIDTH   = 10 ;
   typedef struct packed {
     bit                            LastDescTrans ; // Indicates that this is the last transaction of Descriptor and when it finish status must be updated 
     bit [BRAM_ADDR_WIDTH - 1 : 0]  DescAddr      ; // BRAM_ADDR_WIDTH
     bit [`RspErrWidth    - 1 : 0]  DBIDRespErr    ;
     bit [`RspErrWidth    - 1 : 0]  DataRespErr    ;
 } Completer_Packet;
 endpackage
 
// Packets for Chi-Converter FIFOs
package CHIFIFOsPkg;
   parameter BRAM_ADDR_WIDTH   = 10 ;
   parameter BRAM_COL_WIDTH    = 32 ;
   typedef struct packed {
     bit                            LastDescTrans ; // Indicates that this is the last transaction of Descriptor and when it finish status must be updated 
     bit [BRAM_ADDR_WIDTH - 1 : 0]  DescAddr      ;
     bit [BRAM_COL_WIDTH  - 1 : 0]  Length        ;
     bit [BRAM_COL_WIDTH  - 1 : 0]  DstAddr       ;
     bit [BRAM_COL_WIDTH  - 1 : 0]  SrcAddr       ;
 } CHI_Command; // Width = 129
 
 
   typedef struct packed {
     bit [7                : 0]  DBID    ;
     bit [`RspErrWidth - 1 : 0]  RespErr ;
 } CHI_FIFO_DBID_Packet;
 
 
   typedef struct packed {
     bit [511              : 0]  Data    ;
     bit [`RspErrWidth - 1 : 0]  RespErr ;
 } CHI_FIFO_Data_Packet;
 
    typedef struct packed {
     bit                            LastDescTrans ; // Indicates that this is the last transaction of Descriptor and when it finish status must be updated 
     bit [BRAM_ADDR_WIDTH - 1 : 0]  DescAddr      ; // BRAM_ADDR_WIDTH
     bit [7               - 1 : 0]  Size          ; // log2(512/8)+1 (64Bytes)
 } CHI_FIFO_Size_Packet;
 
 endpackage

// CHI FLits
package CHIFlitsPkg;
   typedef struct packed {
     bit [3 : 0] QoS           ; 
     bit [6 : 0] TgtID         ;  // Width can be 7 to 11. Width determined by NodeID_Width
     bit [6 : 0] SrcID         ;  // Width can be 7 to 11. Width determined by NodeID_Width
     bit [7 : 0] TxnID         ;
     bit [6 : 0] ReturnNID     ;  // This is StashNID field for Stash transactions. ReturnNID used for DMT
     bit         StashNIDValid ;  // This is Endian field for Atomic transactions 
     bit [7 : 0] ReturnTxnID   ;  // This is {0b00,StashLPIDValid,StashLPID[4:0]} for Stash transactions. ReturnTxnID used for DMT
     bit [5 : 0] Opcode        ;  
     bit [2 : 0] Size          ;
     bit [43: 0] Addr          ;  // Width can be 44 to 52 bit .Width determined by Req_Addr_Width
     bit         NS            ;
     bit         LikelyShared  ;
     bit         AllowRetry    ;
     bit [1 : 0] Order         ;
     bit [3 : 0] PCrdType      ;
     bit [3 : 0] MemAttr       ;
     bit         SnpAttr       ;
     bit [4 : 0] LPID          ;
     bit         Excl          ;  // This is SnoopMe filed in Atomic transactions
     bit         ExpCompAck    ;
     bit         TraceTag      ;
     //RSVDC   X = 0 No RSVDC bus . Reserved for customer use : X = 4, 12, 16, 24, 32 Permitted RSVDC bus widths
   // Total bit: R=117 used
 } ReqFlit;
 
   typedef struct packed {
     bit [3 : 0] QoS      ; 
     bit [6 : 0] TgtID    ;  // Width can be 7 to 11 Width determined by NodeID_Width
     bit [6 : 0] SrcID    ;  // Width can be 7 to 11 Width determined by NodeID_Width
     bit [7 : 0] TxnID    ; 
     bit [3 : 0] Opcode   ; 
     bit [1 : 0] RespErr  ; 
     bit [2 : 0] Resp     ; 
     bit [2 : 0] FwdState ;  // This is DataPull field for Stash transactions. FwdState Used for DCT
     bit [7 : 0] DBID     ; 
     bit [3 : 0] PCrdType ; 
     bit         TraceTag ;
   //Total bit : T = 51 
 } RspFlit;
  
   typedef struct packed {
     bit [3  : 0] QoS        ;
     bit [6  : 0] TgtID      ;  // Width can be 7 to 11 Width determined by NodeID_Width
     bit [6  : 0] SrcID      ;  // Width can be 7 to 11 Width determined by NodeID_Width 
     bit [7  : 0] TxnID      ;
     bit [6  : 0] HomeNID    ;  // Width can be 7 to 11 Width determined by NodeID_Width
     bit [3  : 0] Opcode     ;  // This field was 3-bits prior to Issue C
     bit [1  : 0] RespErr    ; 
     bit [2  : 0] Resp       ; 
     bit [2  : 0] DataSource ;  // This is DataPull field for Stash transactions ot FwdState field used for DCT. DataSource indicates Data source in a response
     bit [7  : 0] DBID       ;
     bit [1  : 0] CCID       ;
     bit [1  : 0] DataID     ;
     bit          TraceTag   ;
     //RSVDC  Y = 0 No RSVDC bus . Reserved for customer use : Y = 4, 12, 16, 24, 32 Permitted RSVDC bus widths
     bit [63 : 0] BE         ; // it can be 16, 32, 64 it depends on bus
     bit [511: 0] Data       ; // it can be 128, 256, 512 it depends on bus
     bit [63 : 0] DataCheck  ; // it can be 0, 16, 32, 64
     bit [7  : 0] Poison     ; // It can be 0, 2, 4, 8 
    //Total bit : D = 706 = 512(Data) + 122 + 64(DataCheck) + 8(Poison) bit Data
 } DataFlit;
 
 endpackage
