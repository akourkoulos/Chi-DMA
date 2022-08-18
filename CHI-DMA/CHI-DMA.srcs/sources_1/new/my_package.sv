`timescale 1ns / 1ps

package DataPkg;
   typedef struct packed {
   bit [95:0]  Reserved    ;  // not used 
   bit [31:0]  Status      ; 
   bit [31:0]  SentBytes   ;
   bit [31:0]  BytesToSend ;
   bit [31:0]  DstAddr     ;
   bit [31:0]  SrcAddr     ;
 } Data_packet;
 endpackage

