/***************************************************************************************************************
--Module Name:  CRC_16
--Author     :  Jin
--Description:  
                
--History    :  2016-04-03  Created by Jin.                          

***************************************************************************************************************/
`timescale 1ns/100ps

module crc_16(
	input  wire        clk,    
	input  wire        rst_n ,
	input  wire        crc_en,
	input  wire[7:0]   data_in,
	output reg [15:0]  crc_reg,
	output reg         crc_ready

);
//-------------------------------------------------------------------------------------------------------------

parameter  POLY = 16'hA001;
//-------------------------------------------------------------------------------------------------------------
reg [3:0]   crc_cnt;
wire        carry;

assign carry = crc_reg[0];

always @ (posedge clk)
   if(!rst_n)begin
	   crc_reg   <= 16'hFFFF;
		crc_cnt   <= 4'd8;
		crc_ready <= 1'b0;
	end else if(crc_en)begin
	   crc_reg <= crc_reg^{8'd0,data_in};
		crc_cnt   <= 4'd0;
		crc_ready <= 1'b0;
	end else if(crc_cnt!=4'd8)begin
	   crc_cnt  <= crc_cnt + 4'd1;
		if(carry)begin
		   crc_reg <= (crc_reg>>1)^POLY;
		end else begin
		   crc_reg <= crc_reg >>1;
		end		
	end else if(crc_cnt==4'd8)
	   crc_ready <= 1'b1;
	
endmodule