/***************************************************************************************************************
--Module Name:  command_rw_main
--Author     :  Jin
--Description:  read data stream from uart,extract command,and excecute
                write command to main by uart
					 default MSB first
					 define LSB if want transmit/receive data LSB first
					 there is TX_GUARDING_TIME time between consecutive bytes transmitted,one byte period minimum
					 logic state reset if next byte do not arrived  RX_TIME_OUT_PROTECTION time later after last byte
                
--History    :  2016-04-03  Created by Jin.                          

***************************************************************************************************************/
`timescale 1ns/100ps
`include "define.v"
`define LSB

module command_rw_main(
	output wire         uart_chip_de,      //uart transceiver chip transmit enable
	output wire         uart_chip_re_n,    //uart transceiver chip receive enable
	output wire        uart_chip_di,      //uart transceiver chip transmit input
	input  wire        uart_chip_ro,      //uart transceiver chip receive output

   output reg         command_rx_ready,   //high level pulse signals a received command
   output reg [15:0]  command_rx,
   output reg [47:0]  data_field_rx, 
	
	output reg         command_tx_over,   //high pulse signals new command can be transmitted
	output reg         command_tx_status, //high level means command is trasmitting
   input  wire        command_tx_ready,  //high level signal a new command has arrived for transmiting
   input  wire[15:0]  command_tx,
   input  wire[47:0]  data_field_tx,	
 
   input  wire        uart_clk,          //uart sampling clock	,baudrate is calcurated according this clock
	
	input  wire  [31:0]version,
	
	input  wire        clk,    
	input  wire        rst_n          
);


wire  [7:0]   uart_rx_data;  
wire          uart_rx_data_ready;
wire          uart_rx_err;	
	                
wire          uart_transmitting;  
wire          uart_tx_over; 
reg  [7:0]    uart_tx_data;  
reg           uart_tx_ready;	

wire          uart_rx_ready;

assign  uart_rx_ready = uart_rx_data_ready&(!uart_rx_err);
//-------------------------------------------------------------------------------------------------------------
parameter 	FRAME_HEAD1 = 8'hAA,
            FRAME_HEAD2 = 8'h55,
				FRAME_HEAD3 = 8'hEB,
            FRAME_HEAD4 = 8'h90,
				FRAME_HEAD5 = 8'h1D,
            FRAME_HEAD6 = 8'h1B,
				FRAME_END   = 8'hEF;
parameter   IDLE        = 5'd0,
            HEAD1       = 5'd1,
            HEAD2       = 5'd2,
				HEAD3       = 5'd3,
            HEAD4       = 5'd4,
				HEAD5       = 5'd5,
            HEAD6       = 5'd6,
            COMMAND_H   = 5'd7,
            COMMAND_L   = 5'd8,				
            BYTE1       = 5'd9,
            BYTE2       = 5'd10,
            BYTE3       = 5'd11,
            BYTE4       = 5'd12,
				BYTE5       = 5'd13,
				BYTE6       = 5'd14,
            CRC_H       = 5'd15,
            CRC_L       = 5'd16;		
parameter   RX_TIME_OUT_PROTECTION = 32'd100000,	//guarding time between consecutive rx bytes,
                                                   //guarding time=RX_TIME_OUT_PROTECTION * clk cycles
`ifdef SIM
				TX_GUARDING_TIME       = 32'd500;
`else 				
            TX_GUARDING_TIME       = 32'd5000;    //wait TX_GUARDING_TIME * clk cycles before new transmit
`endif				
//-----------------------------------command transmit----------------------------------------------------------
reg  [4:0]   state_tx;
wire [7:0]   parity_tx_calc;	
reg  [31:0]  tx_guarding_time_cnt;

reg  [15:0]  cmd_tx;
reg  [47:0]  data_tx;

reg          crc_en_tx;
reg          crc_reset_tx;
wire [15:0]  crc_tx;
wire         crc_ready_tx;
	    
/*-------------------------------------------------------*/
always @ (posedge clk)
   if((!rst_n)|uart_transmitting)begin
	    tx_guarding_time_cnt    <= 32'd0;
	end else begin//insert TX_GUARDING_TIME between 2 consecutive bytes
       if(tx_guarding_time_cnt==TX_GUARDING_TIME)
		    tx_guarding_time_cnt   <= tx_guarding_time_cnt;
		 else
		    tx_guarding_time_cnt    <= tx_guarding_time_cnt + 8'd1;
   end	

/*--------------------------------------------------------*/
always @ (posedge clk)
   if(!rst_n)begin
	    state_tx          <= IDLE;
		 command_tx_over   <= 1'd0;
		 command_tx_status <= 1'd0;
		 uart_tx_ready     <= 1'd0;
		 uart_tx_data      <= 8'd0;
		 cmd_tx            <= 16'd0;
		 data_tx           <= 48'd0;
		 crc_en_tx         <= 1'b0;
		 crc_reset_tx      <= 1'b1;
   end else begin
	    case(state_tx)
		 IDLE   :begin
		 			  if(command_tx_ready&(!uart_transmitting))begin
		              state_tx     <=  HEAD1;
						  cmd_tx       <= command_tx;
						  data_tx      <= data_field_tx;
				        command_tx_status <= 1'd1;	
				        command_tx_over   <= 1'd0;	  
					  end else begin
						  state_tx          <=  IDLE;
						  command_tx_over   <= 1'd0;
						  command_tx_status <= 1'd0;
						  uart_tx_ready     <= 1'd0;
						  uart_tx_data      <= 8'd0;
						  crc_en_tx         <= 1'b0;
		              crc_reset_tx      <= 1'b1;
                 end
		         end
		 HEAD1  :begin
		           if(uart_transmitting)
					      uart_tx_ready<= 1'd0;
					  else if(tx_guarding_time_cnt==TX_GUARDING_TIME)begin//uart transceiver is idle,and guarding time out
    					  uart_tx_data <= FRAME_HEAD1;
						  uart_tx_ready<= 1'd1;
					  end 
                 if(uart_tx_over)
					     state_tx     <= HEAD2;		 
		         end
		 HEAD2  :begin
		           if(uart_transmitting)
					      uart_tx_ready<= 1'd0;
					  else if(tx_guarding_time_cnt==TX_GUARDING_TIME)begin//uart transceiver is idle,and guarding time out
    					  uart_tx_data <= FRAME_HEAD2;
						  uart_tx_ready<= 1'd1;
					  end 
                 if(uart_tx_over)
					     state_tx     <= HEAD3;		  
		         end
		 HEAD3  :begin
		           if(uart_transmitting)
					      uart_tx_ready<= 1'd0;
					  else if(tx_guarding_time_cnt==TX_GUARDING_TIME)begin//uart transceiver is idle,and guarding time out
    					  uart_tx_data <= FRAME_HEAD3;
						  uart_tx_ready<= 1'd1;
					  end 
                 if(uart_tx_over)
					     state_tx     <= HEAD4;		 
		         end
		 HEAD4  :begin
		           if(uart_transmitting)
					      uart_tx_ready<= 1'd0;
					  else if(tx_guarding_time_cnt==TX_GUARDING_TIME)begin//uart transceiver is idle,and guarding time out
    					  uart_tx_data <= FRAME_HEAD4;
						  uart_tx_ready<= 1'd1;
					  end 
                 if(uart_tx_over)
					     state_tx     <= HEAD5;		  
		         end
		 HEAD5  :begin
		           if(uart_transmitting)
					      uart_tx_ready<= 1'd0;
					  else if(tx_guarding_time_cnt==TX_GUARDING_TIME)begin//uart transceiver is idle,and guarding time out
    					  uart_tx_data <= FRAME_HEAD5;
						  uart_tx_ready<= 1'd1;
					  end 
                 if(uart_tx_over)
					     state_tx     <= HEAD6;		 
		         end
		 HEAD6  :begin
		           crc_reset_tx      <= 1'b0; //pull crc out of reset
					  if(uart_transmitting)
					      uart_tx_ready<= 1'd0;
					  else if(tx_guarding_time_cnt==TX_GUARDING_TIME)begin//uart transceiver is idle,and guarding time out
    					  uart_tx_data <= FRAME_HEAD6;
						  uart_tx_ready<= 1'd1;						  
					  end 
                 if(uart_tx_over)
					     state_tx     <= COMMAND_H;		  
		         end					
		 COMMAND_H:begin
		           if(uart_transmitting) begin
					      uart_tx_ready<= 1'd0;
							crc_en_tx    <= 1'b0;
					  end
					  else if(tx_guarding_time_cnt==TX_GUARDING_TIME)begin//uart transceiver is idle,and guarding time out
    					  uart_tx_data <= cmd_tx[15:8];
						  uart_tx_ready<= 1'd1;
						  crc_en_tx    <= 1'b1;
					  end 
                 if(uart_tx_over)begin
					     state_tx     <= COMMAND_L;		 
		           end
		         end
		 COMMAND_L:begin
		           if(uart_transmitting) begin
					      uart_tx_ready<= 1'd0;
							crc_en_tx    <= 1'b0;
					  end
					  else if(tx_guarding_time_cnt==TX_GUARDING_TIME)begin//uart transceiver is idle,and guarding time out
    					  uart_tx_data <= cmd_tx[7:0];
						  uart_tx_ready<= 1'd1;
						  crc_en_tx    <= 1'b1;						  
					  end 
                 if(uart_tx_over)begin
					     state_tx     <= BYTE1;		 
		           end
		          end					
		 BYTE1  :begin
		           if(uart_transmitting) begin
					      uart_tx_ready<= 1'd0;
							crc_en_tx    <= 1'b0;
					  end
					  else if(tx_guarding_time_cnt==TX_GUARDING_TIME)begin//uart transceiver is idle,and guarding time out
					  `ifdef LSB
    					  uart_tx_data <=  data_tx[7:0];
					  `else
					     uart_tx_data <=  data_tx[47:40];
					  `endif
						  uart_tx_ready<= 1'd 1;
						  crc_en_tx    <= 1'b1;
					  end 
                 if(uart_tx_over)begin
					     state_tx     <= BYTE2;
						end		  
		         end
		 BYTE2  :begin
		           if(uart_transmitting) begin
					      uart_tx_ready<= 1'd0;
							crc_en_tx    <= 1'b0;
					  end
					  else if(tx_guarding_time_cnt==TX_GUARDING_TIME)begin//uart transceiver is idle,and guarding time out
					  `ifdef LSB
    					  uart_tx_data <= data_tx[15:8];
					  `else
					     uart_tx_data <=  data_tx[39:32];
					  `endif
						  uart_tx_ready<= 1'd1;
						  crc_en_tx    <= 1'b1;
					  end 
                 if(uart_tx_over)begin
					     state_tx     <= BYTE3;
						end		 
		         end
		 BYTE3   :begin
		           if(uart_transmitting) begin
					      uart_tx_ready<= 1'd0;
							crc_en_tx    <= 1'b0;
					  end
					  else if(tx_guarding_time_cnt==TX_GUARDING_TIME)begin//uart transceiver is idle,and guarding time out
					  `ifdef LSB
    					  uart_tx_data <=  data_tx[23:16];
					  `else
					     uart_tx_data <=  data_tx[31:24];
					  `endif
						  uart_tx_ready<= 1'd 1;
						  crc_en_tx    <= 1'b1;
					  end 
                 if(uart_tx_over)begin
					     state_tx     <=  BYTE4;
						end		  
		         end
		 BYTE4  :begin
		           if(uart_transmitting) begin
					      uart_tx_ready<= 1'd0;
							crc_en_tx    <= 1'b0;
					  end
					  else if(tx_guarding_time_cnt==TX_GUARDING_TIME)begin//uart transceiver is idle,and guarding time out
					  `ifdef LSB
    					  uart_tx_data <=  data_tx[31:24];
					  `else
					     uart_tx_data <=  data_tx[23:16];
					  `endif
						  uart_tx_ready<= 1'd 1;
						  crc_en_tx    <= 1'b1;
					  end 
                 if(uart_tx_over)begin
					     state_tx     <=  BYTE5;
						end		 
		         end
		 BYTE5  :begin
		           if(uart_transmitting) begin
					      uart_tx_ready<= 1'd0;
							crc_en_tx    <= 1'b0;
					  end
					  else if(tx_guarding_time_cnt==TX_GUARDING_TIME)begin//uart transceiver is idle,and guarding time out
					  `ifdef LSB
    					  uart_tx_data <=  data_tx[39:32];
					  `else
					     uart_tx_data <=  data_tx[15:8];
					  `endif
						  uart_tx_ready<= 1'd 1;
						  crc_en_tx    <= 1'b1;
					  end 
                 if(uart_tx_over)begin
					     state_tx     <=  BYTE6;
						end		 
		         end
		 BYTE6  :begin
		           if(uart_transmitting) begin
					      uart_tx_ready<= 1'd0;
							crc_en_tx    <= 1'b0;
					  end
					  else if(tx_guarding_time_cnt==TX_GUARDING_TIME)begin//uart transceiver is idle,and guarding time out
					  `ifdef LSB
    					  uart_tx_data <=  data_tx[47:40];
					  `else
					     uart_tx_data <=  data_tx[7:0];
					  `endif
						  uart_tx_ready<= 1'd 1;
						  crc_en_tx    <= 1'b1;
					  end 
                 if(uart_tx_over)begin
					     state_tx     <=  CRC_H;
						end		 
		         end					
		 CRC_H :begin
		           if(uart_transmitting)
					      uart_tx_ready<= 1'd 0;
					  else if((tx_guarding_time_cnt==TX_GUARDING_TIME)&&(crc_ready_tx==1'b1))begin//uart transceiver is idle,and guarding time out
    					  uart_tx_data <=  crc_tx[15:8];
						  uart_tx_ready<= 1'd 1;
					  end 
                 if(uart_tx_over)begin
					     state_tx     <=  CRC_L;
						end
		         end
		 CRC_L   :begin
		           if(uart_transmitting)
					      uart_tx_ready<= 1'd 0;
					  else if((tx_guarding_time_cnt==TX_GUARDING_TIME)&&(crc_ready_tx==1'b1))begin//uart transceiver is idle,and guarding time out
    					  uart_tx_data <= crc_tx[7:0];
						  uart_tx_ready<= 1'd 1;
					  end 
                 if(uart_tx_over)begin
					     state_tx          <=  IDLE;
						  command_tx_over   <= 1'd 1; 
						  command_tx_status <= 1'd 0;	
						end
		         end
       default:state_tx  <=  IDLE;	
     endcase				
	end
//-----------------------------------command receive-----------------------------------------------------------

reg [7:0]   data_byte_rx;
reg [4:0]   state_rx;

reg [31:0]  rx_time_out_cnt;
reg         crc_en_rx;
reg         crc_reset_rx;
wire[15:0]  crc_calculated_rx;
reg [15:0]  crc_rx;


always @ (posedge clk)
   if(!rst_n)begin
	    state_rx        <= IDLE;
		 command_rx      <= 16'd0;
		 data_field_rx   <= 48'd0;
		 data_byte_rx    <= 8'd0;
		 command_rx_ready <= 1'd0;
		 rx_time_out_cnt <= 32'd0;
		 crc_en_rx       <= 1'b0;
		 crc_reset_rx    <= 1'b1;
		 crc_rx          <= 16'd0;
   end else begin
	    case(state_rx)
		 IDLE   :begin
                 if(uart_rx_ready)begin
					     data_byte_rx <= uart_rx_data;
		              state_rx     <=  HEAD1;
					  end else begin
						  command_rx      <= 16'd0;
						  command_rx_ready <= 1'd0;
						  data_field_rx   <= 48'd 0;
						  data_byte_rx    <= 8'd0;
						  rx_time_out_cnt <= 32'd0;
						  crc_en_rx       <= 1'b0;
		              crc_reset_rx    <= 1'b1;
						  crc_rx          <= 16'd0;
					  end
		         end
		 HEAD1  :begin
		            if((data_byte_rx!=FRAME_HEAD1)||(rx_time_out_cnt == RX_TIME_OUT_PROTECTION))
						//go back to IDLE if next byte does not show up in RX_TIME_OUT_PROTECTION time
						    state_rx        <=  IDLE;
						else begin
					   	if(uart_rx_ready)begin //find frame head1,wait for frame head2
						        state_rx        <=  HEAD2;
							     data_byte_rx    <= uart_rx_data;
								  rx_time_out_cnt <= 32'd0;
						    end else 
							 	  rx_time_out_cnt <= rx_time_out_cnt + 32'd1;
				       end		 
		         end
		 HEAD2  :begin
		            if((data_byte_rx!=FRAME_HEAD2)||(rx_time_out_cnt == RX_TIME_OUT_PROTECTION))
						    state_rx        <= IDLE;
						else begin
							 if(uart_rx_ready)begin//find frame head2
						        state_rx        <= HEAD3;
							     data_byte_rx    <= uart_rx_data;
								  rx_time_out_cnt <= 32'd0;
							 end else
							 	  rx_time_out_cnt <= rx_time_out_cnt + 32'd1;
						end		  
		         end
		 HEAD3  :begin
		            if((data_byte_rx!=FRAME_HEAD3)||(rx_time_out_cnt == RX_TIME_OUT_PROTECTION))
						    state_rx        <= IDLE;
						else begin
							 if(uart_rx_ready)begin//find frame head3
						        state_rx        <= HEAD4;
							     data_byte_rx    <= uart_rx_data;
								  rx_time_out_cnt <= 32'd0;
							 end else
							 	  rx_time_out_cnt <= rx_time_out_cnt + 32'd1;
						end		  
		         end
		 HEAD4  :begin
		            if((data_byte_rx!=FRAME_HEAD4)||(rx_time_out_cnt == RX_TIME_OUT_PROTECTION))
						    state_rx        <= IDLE;
						else begin
							 if(uart_rx_ready)begin//find frame head4
						        state_rx        <= HEAD5;
							     data_byte_rx    <= uart_rx_data;
								  rx_time_out_cnt <= 32'd0;
							 end else
							 	  rx_time_out_cnt <= rx_time_out_cnt + 32'd1;
						end		  
		         end
		 HEAD5  :begin
		            if((data_byte_rx!=FRAME_HEAD5)||(rx_time_out_cnt == RX_TIME_OUT_PROTECTION))
						    state_rx        <= IDLE;
						else begin
							 if(uart_rx_ready)begin//find frame head5
						        state_rx        <= HEAD6;
							     data_byte_rx    <= uart_rx_data;
								  rx_time_out_cnt <= 32'd0;
							 end else
							 	  rx_time_out_cnt <= rx_time_out_cnt + 32'd1;
						end		  
		         end
		 HEAD6  :begin
		            crc_reset_rx <= 1'b0; // pull crc out of reset
						if((data_byte_rx!=FRAME_HEAD6)||(rx_time_out_cnt == RX_TIME_OUT_PROTECTION))
						    state_rx        <= IDLE;
						else begin
							 if(uart_rx_ready)begin//find frame head6
						        state_rx         <= COMMAND_H;
							     command_rx[15:8] <= uart_rx_data;
								  rx_time_out_cnt  <= 32'd0;
								  crc_en_rx        <= 1'b1;
							 end else
							 	  rx_time_out_cnt <= rx_time_out_cnt + 32'd1;
						end		  
		         end					
		 COMMAND_H:begin
		            
		            if(rx_time_out_cnt == RX_TIME_OUT_PROTECTION)
						    state_rx        <= IDLE;
						else begin
							 if(uart_rx_ready)begin
						        state_rx         <= COMMAND_L;
							     command_rx[7:0]  <= uart_rx_data;
								  rx_time_out_cnt  <= 32'd0;
								  crc_en_rx        <= 1'b1;
							 end else begin
							 	  rx_time_out_cnt <= rx_time_out_cnt + 32'd1;
								  crc_en_rx       <= 1'b0;
							end
						end 
		         end
		 COMMAND_L:begin
		            if(rx_time_out_cnt == RX_TIME_OUT_PROTECTION)
						    state_rx        <= IDLE;
						else begin

						    if(uart_rx_ready)begin
						        state_rx           <= BYTE1;
							 `ifdef LSB	  
							     data_field_rx[7:0] <= uart_rx_data;
							 `else
							     data_field_rx[47:40] <= uart_rx_data;
							 `endif
								  rx_time_out_cnt    <= 32'd0;
								  crc_en_rx        <= 1'b1;
							 end else begin
							 	  rx_time_out_cnt <= rx_time_out_cnt + 32'd1;
								  crc_en_rx       <= 1'b0;
							end
						end		 
		         end					
		 BYTE1  :begin
		            if(rx_time_out_cnt == RX_TIME_OUT_PROTECTION)
						    state_rx        <= IDLE;
						else begin
						    if(uart_rx_ready)begin
						       state_rx            <= BYTE2;
							 `ifdef LSB	  
							     data_field_rx[15:8] <= uart_rx_data;
							 `else
							     data_field_rx[39:32] <= uart_rx_data;
							 `endif							    
								 rx_time_out_cnt    <=32'd0;
								  crc_en_rx        <= 1'b1;
							 end else begin
							 	  rx_time_out_cnt <= rx_time_out_cnt + 32'd1;
								  crc_en_rx       <= 1'b0;
							end
						end		  
		         end
		 BYTE2  :begin
		            if(rx_time_out_cnt == RX_TIME_OUT_PROTECTION)
						    state_rx        <= IDLE;
						else begin
		                if(uart_rx_ready)begin
						        state_rx             <= BYTE3;
							 `ifdef LSB	  
							     data_field_rx[23:16] <= uart_rx_data;
							 `else
							     data_field_rx[31:24] <= uart_rx_data;
							 `endif								  
								  rx_time_out_cnt    <= 32'd0;
								  crc_en_rx        <= 1'b1;
							 end else begin
							 	  rx_time_out_cnt <= rx_time_out_cnt + 32'd1;
								  crc_en_rx       <= 1'b0;
							end						
						end		 
		         end
		 BYTE3   :begin
		            if(rx_time_out_cnt == RX_TIME_OUT_PROTECTION)
						    state_rx        <=  IDLE;
						else begin
  		                if(uart_rx_ready)begin
						        state_rx             <= BYTE4;
							 `ifdef LSB	  
							     data_field_rx[31:24] <= uart_rx_data;
							 `else
							     data_field_rx[23:16] <= uart_rx_data;
							 `endif								  
								  rx_time_out_cnt    <= 32'd0;
								  crc_en_rx        <= 1'b1;
							 end else begin
							 	  rx_time_out_cnt <= rx_time_out_cnt + 32'd1;
								  crc_en_rx       <= 1'b0;
							end
						end		  
		         end
		 BYTE4  :begin
		            if(rx_time_out_cnt == RX_TIME_OUT_PROTECTION)
						    state_rx        <=  IDLE;
						else begin
  		                if(uart_rx_ready)begin
						        state_rx             <= BYTE5;
							 `ifdef LSB	  
							     data_field_rx[39:32] <= uart_rx_data;
							 `else
							     data_field_rx[15:8] <= uart_rx_data;
							 `endif								  
								  rx_time_out_cnt    <= 32'd0;
								  crc_en_rx        <= 1'b1;
							 end else begin
							 	  rx_time_out_cnt <= rx_time_out_cnt + 32'd1;
								  crc_en_rx       <= 1'b0;
							end
						end		 
		         end
		 BYTE5  :begin
		            if(rx_time_out_cnt == RX_TIME_OUT_PROTECTION)
						    state_rx        <=  IDLE;
						else begin
  		                if(uart_rx_ready)begin
						        state_rx             <= BYTE6;
							 `ifdef LSB	  
							     data_field_rx[47:40] <= uart_rx_data;
							 `else
							     data_field_rx[7:0] <= uart_rx_data;
							 `endif								  
								  rx_time_out_cnt    <= 32'd0;
								  crc_en_rx        <= 1'b1;
							 end else begin
							 	  rx_time_out_cnt <= rx_time_out_cnt + 32'd1;
								  crc_en_rx       <= 1'b0;
							end
						end		 
		         end
		 BYTE6  :begin
		            if(rx_time_out_cnt == RX_TIME_OUT_PROTECTION)
						    state_rx        <= IDLE;
						else begin	 
		                if(uart_rx_ready)begin
						        state_rx         <= CRC_H;
							     crc_rx[15:8]     <= uart_rx_data;
								  rx_time_out_cnt  <= 32'd0;
							 end else begin
							 	  rx_time_out_cnt <= rx_time_out_cnt + 32'd1;
								  crc_en_rx       <= 1'b0;
							end
						end		 
		         end					
		 CRC_H :begin
		            if(rx_time_out_cnt == RX_TIME_OUT_PROTECTION)
						    state_rx        <= IDLE;
						else begin           
					       if(uart_rx_ready)begin
						        state_rx    <= CRC_L;
							     crc_rx[7:0] <= uart_rx_data;
								  rx_time_out_cnt    <= 32'd0;
							 end else
							 	  rx_time_out_cnt <= rx_time_out_cnt + 32'd1;						
						end
		         end
		 CRC_L   :begin
		            state_rx         <= IDLE;
		            if(crc_rx == crc_calculated_rx)begin						    
							 command_rx_ready  <= 1'd 1;
		            end
		         end
       default:state_rx  <= IDLE;	
     endcase				
	end
//------------------------------CRC 16-------------------------------------------------------------------
crc_16  crc16_tx(
					.clk(clk),    
					.rst_n(!crc_reset_tx) ,
					.crc_en(crc_en_tx),
					.data_in(uart_tx_data),
					.crc_reg(crc_tx),
					.crc_ready(crc_ready_tx)
);

crc_16  crc16_rx(
					.clk(clk),    
					.rst_n(!crc_reset_rx) ,
					.crc_en(crc_en_rx),
					.data_in(uart_rx_data),
					.crc_reg(crc_calculated_rx),
					.crc_ready(crc_ready_rx)
);
//-------------------------------------------------------------------------------------------------------------

 uart_transceiver  rs422_main(
										.uart_rx_data(uart_rx_data),  
										.uart_rx_data_ready(uart_rx_data_ready), 
										.uart_rx_err(uart_rx_err),	
															 
										.uart_tx_status(uart_transmitting),  
									   .uart_tx_over(uart_tx_over),	
										.uart_tx_data(uart_tx_data),  
										.uart_tx_data_ready(uart_tx_ready),   
															 
										.uart_chip_de(uart_chip_de),      //uart transceiver chip transmit enable
										.uart_chip_re_n(uart_chip_re_n),    //uart transceiver chip receive enable
										.uart_chip_di(uart_chip_di),      //uart transceiver chip transmit input
										.uart_chip_ro(uart_chip_ro),      //uart transceiver chip receive output
															 
										.clk(clk),  
										.uart_clk(uart_clk),          //uart sampling clock	,baudrate is calcurated according this clock
										.rst_n(rst_n)          
	);
endmodule