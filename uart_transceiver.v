/***************************************************************************************************************
--Module Name:  uart_transceiver
--Author     :  Jin
--Description:  uart transceiver,transmit and receive serial data from external RS232/RS422 transceiver chip
                default MSB first ,define LSB_FIRST if you want to transmit data LSB first
                1 start bit,8 bits data,no parity,1 stop bit
--History    :  2016-04-03  Created by Jin.                          

***************************************************************************************************************/
`timescale 1ns/100ps
`include "define.v"
//`define LSB_FIRST

module uart_transceiver(
   output reg  [7:0]  uart_rx_data,  
	output wire        uart_rx_data_ready, //high level pulse active,one clk cycle
   output wire        uart_rx_err,	      //high level pulse active,one clk cycle
	                
	output reg         uart_tx_status,      //high level means tx is in progress
	output reg         uart_tx_over,        //high level pulse active,one clk cycle
	input  wire [7:0]  uart_tx_data,  
	input  wire        uart_tx_data_ready,   
	                
	output reg         uart_chip_de,      //uart transceiver chip transmit enable
	output wire        uart_chip_re_n,    //uart transceiver chip receive enable
	output reg         uart_chip_di,      //uart transceiver chip transmit input
	input  wire        uart_chip_ro,      //uart transceiver chip receive output
	                
	input  wire        clk,  
   input  wire        uart_clk,          //uart sampling clock	,baudrate is calcurated according this clock
	input  wire        rst_n          
	);
/*------------------------------------------------------------------*/
reg           uart_rx;
reg           uart_rx_d1;
reg           uart_rx_d2;
reg           uart_rx_d3;

reg           uart_tx;  
reg           uart_tx_en;
reg  [1:0]    uart_tx_state;
reg  [12:0]   uart_tx_sample_timer;
reg  [2:0]    uart_tx_bit_counter;
reg  [7:0]    uart_tx_data_reg;

reg  [1:0]    uart_rx_state;
reg  [12:0]   uart_rx_sample_timer;
reg  [2:0]    uart_rx_bit_counter;
reg  [7:0]    uart_rx_data_reg;

/*------------------------------------------------------------------*/
   //baudrate= (UART_BAUDRATE+1)*uart_clk
`ifdef SIM
parameter     UART_BAUDRATE = 8 - 1;
parameter     UART_BAUDRATE_HALF = 4 - 1;
`else
parameter     UART_BAUDRATE = 8 - 1;  
parameter     UART_BAUDRATE_HALF = 4 - 1;
`endif

parameter     IDLE = 0, START = 1, DATA = 2, STOP = 3;
/*------------------------------------------------------------------*/
assign        uart_chip_re_n = 0;

/*------------------------------------------------------------------*/

always@(posedge clk)
	if(!rst_n) begin
		uart_chip_di <= #`D 1;
		uart_chip_de <= #`D 1; 
		uart_rx      <= #`D 1;
		uart_rx_d1   <= #`D 1;
		uart_rx_d2   <= #`D 1;
		uart_rx_d3   <= #`D 1;
	end else if(uart_clk)begin  //buffer the rx from transceiver output
		uart_chip_di <= #`D uart_tx;
		uart_chip_de <= #`D uart_tx_en; 
		uart_rx      <= #`D uart_chip_ro;
		uart_rx_d1   <= #`D uart_rx;
		uart_rx_d2   <= #`D uart_rx_d1;
		uart_rx_d3   <= #`D uart_rx_d2;
	end

/*------------------------uart transmit-----------------------------*/
always@(posedge clk)
	if(!rst_n) begin
			uart_tx              <= #`D 1; 
			uart_tx_en           <= #`D 1; 
			uart_tx_status       <= #`D 0;
			uart_tx_state        <= #`D IDLE;
			uart_tx_sample_timer <= #`D 0;
			uart_tx_bit_counter  <= #`D 0;
			uart_tx_data_reg     <= #`D 0;
			uart_tx_over         <= #`D 0;
	end else begin
		case(uart_tx_state)
			IDLE:
				begin
					uart_tx              <= #`D 1; 
					uart_tx_en           <= #`D 1; 
					uart_tx_status       <= #`D 0;
					uart_tx_sample_timer <= #`D 0; 
					uart_tx_bit_counter  <= #`D 0;
					uart_tx_over         <= #`D 0;
					if(uart_tx_data_ready) begin 
						uart_tx_state    <= #`D START;
						uart_tx_data_reg <= #`D uart_tx_data;
						uart_tx_status   <= #`D 1;
					end
				end
			START:
				begin
					uart_tx    <= #`D 0;
					uart_tx_en <= #`D 1; 
					if(uart_tx_sample_timer == UART_BAUDRATE) begin 
						uart_tx_sample_timer <= #`D 0;
						uart_tx_state        <= #`D DATA; 
					end else begin 
						uart_tx_sample_timer <= #`D uart_tx_sample_timer + 1; 
					end
				end
			DATA:
				begin
				   `ifdef LSB_FIRST
					    uart_tx <= #`D uart_tx_data_reg[0];
				   `else
						 uart_tx <= #`D uart_tx_data_reg[7];
					`endif
					uart_tx_en <= #`D 1; 
					if(uart_tx_sample_timer == UART_BAUDRATE) begin 
						uart_tx_sample_timer <= #`D 0;
						uart_tx_bit_counter  <= #`D uart_tx_bit_counter + 1;
						`ifdef LSB_FIRST
						   uart_tx_data_reg <= #`D {1'b0,uart_tx_data_reg[7:1]};
						`else
				         uart_tx_data_reg <= #`D {uart_tx_data_reg[6:0],1'b0};
						`endif
						if(uart_tx_bit_counter == 7) begin 
							uart_tx_state <= #`D STOP; 
						end 
					end else begin 
						uart_tx_sample_timer <= #`D uart_tx_sample_timer + 1; 
					end
				end
			STOP:
				begin
					uart_tx    <= #`D 1;
					uart_tx_en <= #`D 1; 
					/*
					if(uart_tx_sample_timer == 0) begin 
						uart_tx_status <= #`D 1; 
					end else begin
						uart_tx_status <= #`D 0; 						
					end
               */					
					if(uart_tx_sample_timer == UART_BAUDRATE) begin 
						uart_tx_sample_timer <= #`D 0;
						uart_tx_state        <= #`D IDLE;
						uart_tx_over         <= #`D 1;
						uart_tx_status       <= #`D 0; 
					end else begin 
						uart_tx_sample_timer <= #`D uart_tx_sample_timer + 1; 
					end
				end
			default:
				begin
					uart_tx_state <= #`D IDLE;
				end
		endcase
	end	

	
/*---------------------------------------------------------------*/
reg  		uart_rx_data_ready_d1;	
reg		uart_rx_err_d1 ; 
reg  		uart_rx_data_ready_d2;	
reg		uart_rx_err_d2 ;

always@(posedge clk)//make sure uart_rx_data_ready and uart_rx_err
   if(!rst_n)begin  //are one clk cycle pulse rather than one uart_clk cycle pulse
		uart_rx_data_ready_d2<= #`D 0;	
		uart_rx_err_d2       <= #`D 0; 
   end else begin
		uart_rx_data_ready_d2<= uart_rx_data_ready_d1;	
		uart_rx_err_d2       <= uart_rx_err_d1; 
 end
assign 	uart_rx_data_ready=(~uart_rx_data_ready_d2)&uart_rx_data_ready_d1;
assign 	uart_rx_err       =(~uart_rx_err_d2)&uart_rx_err_d1;	
/*----------------------uart receive------------------------------*/
always@(posedge clk)
	if(!rst_n) begin
		uart_rx_data_ready_d1<= #`D 0;	
		uart_rx_err_d1       <= #`D 0; 
		uart_rx_state        <= #`D IDLE;
		uart_rx_sample_timer <= #`D 0;
		uart_rx_bit_counter  <= #`D 0;
		uart_rx_data_reg     <= #`D 0;
		uart_rx_data         <= #`D 0;
	end else if(uart_clk)begin
		case(uart_rx_state)
			IDLE:
				begin
					uart_rx_data_ready_d1 <= #`D 0;
					uart_rx_err_d1       <= #`D 0;
					uart_rx_sample_timer <= #`D 0;
					uart_rx_bit_counter  <= #`D 0;
					uart_rx_data_reg     <= #`D 0;
					//uart_rx_data         <= #`D 0;
					if({uart_rx_d1, uart_rx_d2} == 2'b01) begin
						uart_rx_state        <= #`D START;				
						
					end
				end
			START:
				begin// sample rx at middle of bit,3 consecutive low level as a success start bit
					if(uart_rx_sample_timer == UART_BAUDRATE_HALF && {uart_rx_d1, uart_rx_d2, uart_rx_d3} == 3'b000) begin
						uart_rx_state        <= #`D DATA;
						uart_rx_sample_timer <= #`D 0;
						uart_rx_bit_counter  <= #`D 0;
					end else if(uart_rx_sample_timer == UART_BAUDRATE_HALF && {uart_rx_d1, uart_rx_d2, uart_rx_d3} != 3'b000) begin
						uart_rx_state        <= #`D IDLE;
						uart_rx_sample_timer <= #`D 0;
						uart_rx_bit_counter  <= #`D 0;
					end else begin
						uart_rx_sample_timer <= #`D uart_rx_sample_timer+1;
					end
				end
			DATA:
				begin
					if(uart_rx_sample_timer == UART_BAUDRATE) begin
					// sample rx at middle of bit,2 high level out of 3 sample as bit 1
						case({uart_rx_d1, uart_rx_d2, uart_rx_d3})
						`ifdef LSB_FIRST
							3'b111: uart_rx_data_reg[7]  <= #`D 1;
							3'b011: uart_rx_data_reg[7]  <= #`D 1;
							3'b101: uart_rx_data_reg[7]  <= #`D 1;
							3'b110: uart_rx_data_reg[7]  <= #`D 1;
							default: uart_rx_data_reg[7] <= #`D 0;
					   `else
							3'b111: uart_rx_data_reg[0] <= #`D 1;
					    	3'b011: uart_rx_data_reg[0] <= #`D 1;
					   	3'b101: uart_rx_data_reg[0] <= #`D 1;
					   	3'b110: uart_rx_data_reg[0] <= #`D 1;
					   	default: uart_rx_data_reg[0] <= #`D 0;	
                  `endif						
						endcase
						`ifdef LSB_FIRST
						   uart_rx_data_reg[6:0] <= #`D uart_rx_data_reg[7:1];
						`else
						   uart_rx_data_reg[7:1] <= #`D uart_rx_data_reg[6:0];
	               `endif						
						uart_rx_sample_timer  <= #`D 0;
						uart_rx_bit_counter   <= #`D uart_rx_bit_counter + 1;
						if(uart_rx_bit_counter == 7) begin
							uart_rx_state <= #`D STOP;
						end
					end else begin
						uart_rx_sample_timer <= #`D uart_rx_sample_timer + 1;
					end
				end
			STOP:
				begin
					uart_rx_data <= #`D uart_rx_data_reg;	
					if(uart_rx_sample_timer == UART_BAUDRATE && {uart_rx_d1, uart_rx_d2, uart_rx_d3}==3'b111) begin  
						uart_rx_state        <= #`D IDLE;
						uart_rx_data_ready_d1<= #`D 1;
						uart_rx_err_d1       <= #`D 0;
					end else if(uart_rx_sample_timer == UART_BAUDRATE && {uart_rx_d1, uart_rx_d2, uart_rx_d3}!=3'b111) begin
						uart_rx_state         <= #`D IDLE;
						uart_rx_data_ready_d1 <= #`D 1;
						uart_rx_err_d1        <= #`D 1;
					end else begin
						uart_rx_sample_timer <= #`D uart_rx_sample_timer + 1;
					end
				end
			default:
				begin
					uart_rx_state <= #`D IDLE;
				end
		endcase
	end
/*------------------------------------------------------------------*/

/*------------------------------------------------------------------*/
endmodule