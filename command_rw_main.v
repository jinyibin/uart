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
   output reg [7:0]   command_rx,
   output reg [31:0]  data_field_rx, 
	
	output reg         command_tx_over,   //high pulse signals new command can be transmitted
	output reg         command_tx_status, //high level means command is trasmitting
   input  wire        command_tx_ready,  //high level signal a new command has arrived for transmiting
   input  wire[7:0]   command_tx,
   input  wire[31:0]  data_field_tx,	
 
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
				FRAME_END   = 8'hEF;
parameter   IDLE        = 0,
            HEAD1       = 1,
            HEAD2       = 2,
            COMMAND     = 3,
            BYTE1       = 4,
            BYTE2       = 5,
            BYTE3       = 6,
            BYTE4       = 7,
            PARITY      = 8,
            END         = 9;		
parameter   RX_TIME_OUT_PROTECTION = 32'd100000,	//guarding time between consecutive rx bytes,
                                                //guarding time=RX_TIME_OUT_PROTECTION * clk cycles
            TX_GUARDING_TIME       = 32'd50000000;    //wait TX_GUARDING_TIME * clk cycles before new transmit
//-----------------------------------command transmit----------------------------------------------------------
reg  [3:0]   state_tx;
wire [7:0]   parity_tx_calc;	
reg  [31:0]  tx_guarding_time_cnt;

reg  [7:0]   cmd_tx;
reg  [31:0]  data_tx;

assign       parity_tx_calc = cmd_tx^data_tx[7:0]^data_tx[15:8]^data_tx[23:16]^data_tx[31:24];	    
/*-------------------------------------------------------*/
always @ (posedge clk)
   if((!rst_n)|uart_transmitting)begin
	    tx_guarding_time_cnt    <= #`D 0;
	end else begin//insert TX_GUARDING_TIME between 2 consecutive bytes
       if(tx_guarding_time_cnt==TX_GUARDING_TIME)
		    tx_guarding_time_cnt   <= tx_guarding_time_cnt;
		 else
		    tx_guarding_time_cnt    <= tx_guarding_time_cnt + 8'd1;
   end	

/*--------------------------------------------------------*/
always @ (posedge clk)
   if(!rst_n)begin
	    state_tx          <= #`D IDLE;
		 command_tx_over   <= #`D 0;
		 command_tx_status <= #`D 0;
		 uart_tx_ready     <= #`D 0;
		 uart_tx_data      <= #`D 0;
		 cmd_tx            <= #`D 0;
		 data_tx           <= #`D 0;
   end else begin
	    case(state_tx)
		 IDLE   :begin
		 			  if(command_tx_ready&(!uart_transmitting))begin
		              state_tx     <= #`D HEAD1;
						  cmd_tx       <= command_tx;
						  data_tx      <= data_field_tx;
				        command_tx_status <= #`D 1;	
				        command_tx_over   <= #`D 0;	  
					  end else begin
						  state_tx          <= #`D IDLE;
						  command_tx_over   <= #`D 0;
						  command_tx_status <= #`D 0;
						  uart_tx_ready     <= #`D 0;
						  uart_tx_data      <= #`D 0;
                 end
		         end
		 HEAD1  :begin
		           if(uart_transmitting)
					      uart_tx_ready<= #`D 0;
					  else if(tx_guarding_time_cnt==TX_GUARDING_TIME)begin//uart transceiver is idle,and guarding time out
    					  uart_tx_data <= #`D FRAME_HEAD1;
						  uart_tx_ready<= #`D 1;
					  end 
                 if(uart_tx_over)
					     state_tx     <= #`D HEAD2;		 
		         end
		 HEAD2  :begin
		           if(uart_transmitting)
					      uart_tx_ready<= #`D 0;
					  else if(tx_guarding_time_cnt==TX_GUARDING_TIME)begin//uart transceiver is idle,and guarding time out
    					  uart_tx_data <= #`D FRAME_HEAD2;
						  uart_tx_ready<= #`D 1;
					  end 
                 if(uart_tx_over)
					     state_tx     <= #`D COMMAND;		  
		         end
		 COMMAND:begin
		           if(uart_transmitting)
					      uart_tx_ready<= #`D 0;
					  else if(tx_guarding_time_cnt==TX_GUARDING_TIME)begin//uart transceiver is idle,and guarding time out
    					  uart_tx_data <= #`D cmd_tx;
						  uart_tx_ready<= #`D 1;
					  end 
                 if(uart_tx_over)begin
					     state_tx     <= #`D BYTE1;		 
		         end
		         end
		 BYTE1  :begin
		           if(uart_transmitting)
					      uart_tx_ready<= #`D 0;
					  else if(tx_guarding_time_cnt==TX_GUARDING_TIME)begin//uart transceiver is idle,and guarding time out
					  `ifdef LSB
    					  uart_tx_data <= #`D data_tx[7:0];
					  `else
					     uart_tx_data <= #`D data_tx[31:24];
					  `endif
						  uart_tx_ready<= #`D 1;
					  end 
                 if(uart_tx_over)begin
					     state_tx     <= #`D BYTE2;
						end		  
		         end
		 BYTE2  :begin
		           if(uart_transmitting)
					      uart_tx_ready<= #`D 0;
					  else if(tx_guarding_time_cnt==TX_GUARDING_TIME)begin//uart transceiver is idle,and guarding time out
					  `ifdef LSB
    					  uart_tx_data <= #`D data_tx[15:8];
					  `else
					     uart_tx_data <= #`D data_tx[23:16];
					  `endif
						  uart_tx_ready<= #`D 1;
					  end 
                 if(uart_tx_over)begin
					     state_tx     <= #`D BYTE3;
						end		 
		         end
		 BYTE3   :begin
		           if(uart_transmitting)
					      uart_tx_ready<= #`D 0;
					  else if(tx_guarding_time_cnt==TX_GUARDING_TIME)begin//uart transceiver is idle,and guarding time out
					  `ifdef LSB
    					  uart_tx_data <= #`D data_tx[23:16];
					  `else
					     uart_tx_data <= #`D data_tx[15:8];
					  `endif
						  uart_tx_ready<= #`D 1;
					  end 
                 if(uart_tx_over)begin
					     state_tx     <= #`D BYTE4;
						end		  
		         end
		 BYTE4  :begin
		           if(uart_transmitting)
					      uart_tx_ready<= #`D 0;
					  else if(tx_guarding_time_cnt==TX_GUARDING_TIME)begin//uart transceiver is idle,and guarding time out
					  `ifdef LSB
    					  uart_tx_data <= #`D data_tx[31:24];
					  `else
					     uart_tx_data <= #`D data_tx[7:0];
					  `endif
						  uart_tx_ready<= #`D 1;
					  end 
                 if(uart_tx_over)begin
					     state_tx     <= #`D PARITY;
						end		 
		         end
		 PARITY :begin
		           if(uart_transmitting)
					      uart_tx_ready<= #`D 0;
					  else if(tx_guarding_time_cnt==TX_GUARDING_TIME)begin//uart transceiver is idle,and guarding time out
    					  uart_tx_data <= #`D parity_tx_calc;
						  uart_tx_ready<= #`D 1;
					  end 
                 if(uart_tx_over)begin
					     state_tx     <= #`D END;
						end
		         end
		 END    :begin
		           if(uart_transmitting)
					      uart_tx_ready<= #`D 0;
					  else if(tx_guarding_time_cnt==TX_GUARDING_TIME)begin//uart transceiver is idle,and guarding time out
    					  uart_tx_data <= #`D FRAME_END;
						  uart_tx_ready<= #`D 1;
					  end 
                 if(uart_tx_over)begin
					     state_tx          <= #`D IDLE;
						  command_tx_over   <= #`D 1; 
						  command_tx_status <= #`D 0;	
						end
		         end
       default:state_tx  <= #`D IDLE;	
     endcase				
	end
//-----------------------------------command receive-----------------------------------------------------------

reg [7:0]   data_byte_rx;
reg [3:0]   state_rx;
reg [7:0]   parity_rx;        //parity byte received
wire[7:0]   parity_rx_calc;	//parity byte calculated according to bytes received
reg [31:0]  rx_time_out_cnt;

assign      parity_rx_calc = command_rx^data_field_rx[7:0]^data_field_rx[15:8]^data_field_rx[23:16]^data_field_rx[31:24];

always @ (posedge clk)
   if(!rst_n)begin
	    state_rx        <= #`D IDLE;
		 command_rx      <= #`D 0;
		 data_field_rx   <= #`D 0;
		 data_byte_rx         <= #`D 0;
		 command_rx_ready <= #`D 0;
		 rx_time_out_cnt <= #`D 0;
		 parity_rx       <= #`D 0;
   end else begin
	    case(state_rx)
		 IDLE   :begin
                 if(uart_rx_ready)begin
					     data_byte_rx      <= uart_rx_data;
		              state_rx     <= #`D HEAD1;
					  end else begin
						  command_rx      <= #`D 0;
						  command_rx_ready <= #`D 0;
						  data_field_rx   <= #`D 0;
						  data_byte_rx    <= #`D 0;
						  rx_time_out_cnt <= #`D 0;
					  end
		         end
		 HEAD1  :begin
		            if((data_byte_rx!=FRAME_HEAD1)||(rx_time_out_cnt == RX_TIME_OUT_PROTECTION))
						//go back to IDLE if next byte does not show up in RX_TIME_OUT_PROTECTION time
						    state_rx        <= #`D IDLE;
						else begin
					   	if(uart_rx_ready)begin //find frame head1,wait for frame head2
						        state_rx        <= #`D HEAD2;
							     data_byte_rx         <= uart_rx_data;
								  rx_time_out_cnt <= #`D 0;
						    end else 
							 	  rx_time_out_cnt <= rx_time_out_cnt + 32'd1;
				       end		 
		         end
		 HEAD2  :begin
		            if((data_byte_rx!=FRAME_HEAD2)||(rx_time_out_cnt == RX_TIME_OUT_PROTECTION))
						    state_rx        <= #`D IDLE;
						else begin

							 if(uart_rx_ready)begin//find frame head2
						        state_rx        <= #`D COMMAND;
							     command_rx      <= uart_rx_data;
								  rx_time_out_cnt <= #`D 0;
							 end else
							 	  rx_time_out_cnt <= rx_time_out_cnt + 32'd1;
						end		  
		         end
		 COMMAND:begin
		            if(rx_time_out_cnt == RX_TIME_OUT_PROTECTION)
						    state_rx        <= #`D IDLE;
						else begin

						    if(uart_rx_ready)begin
						        state_rx           <= #`D BYTE1;
							 `ifdef LSB	  
							     data_field_rx[7:0] <= uart_rx_data;
							 `else
							     data_field_rx[31:24] <= uart_rx_data;
							 `endif
								  rx_time_out_cnt    <= #`D 0;
							 end else
							 	  rx_time_out_cnt <= rx_time_out_cnt + 32'd1;
						end		 
		         end
		 BYTE1  :begin
		            if(rx_time_out_cnt == RX_TIME_OUT_PROTECTION)
						    state_rx        <= #`D IDLE;
						else begin
						    if(uart_rx_ready)begin
						       state_rx            <= #`D BYTE2;
							 `ifdef LSB	  
							     data_field_rx[15:8] <= uart_rx_data;
							 `else
							     data_field_rx[23:16] <= uart_rx_data;
							 `endif							    
								 rx_time_out_cnt    <= #`D 0;
							 end else
							 	  rx_time_out_cnt <= rx_time_out_cnt + 32'd1;
						end		  
		         end
		 BYTE2  :begin
		            if(rx_time_out_cnt == RX_TIME_OUT_PROTECTION)
						    state_rx        <= #`D IDLE;
						else begin
		                if(uart_rx_ready)begin
						        state_rx             <= #`D BYTE3;
							 `ifdef LSB	  
							     data_field_rx[23:16] <= uart_rx_data;
							 `else
							     data_field_rx[15:8] <= uart_rx_data;
							 `endif								  
								  rx_time_out_cnt    <= #`D 0;
							 end else
							 	  rx_time_out_cnt <= rx_time_out_cnt + 32'd1;						
						end		 
		         end
		 BYTE3   :begin
		            if(rx_time_out_cnt == RX_TIME_OUT_PROTECTION)
						    state_rx        <= #`D IDLE;
						else begin
  		                if(uart_rx_ready)begin
						        state_rx             <= #`D BYTE4;
							 `ifdef LSB	  
							     data_field_rx[31:24] <= uart_rx_data;
							 `else
							     data_field_rx[7:0] <= uart_rx_data;
							 `endif								  
								  rx_time_out_cnt    <= #`D 0;
							 end else
							 	  rx_time_out_cnt <= rx_time_out_cnt + 32'd1;
						end		  
		         end
		 BYTE4  :begin
		            if(rx_time_out_cnt == RX_TIME_OUT_PROTECTION)
						    state_rx        <= #`D IDLE;
						else begin	 
		                if(uart_rx_ready)begin
						        state_rx         <= #`D PARITY;
							     parity_rx        <= uart_rx_data;
								  rx_time_out_cnt    <= #`D 0;
							 end else
							 	  rx_time_out_cnt <= rx_time_out_cnt + 32'd1;
						end		 
		         end
		 PARITY :begin
		            if(rx_time_out_cnt == RX_TIME_OUT_PROTECTION)
						    state_rx        <= #`D IDLE;
						else begin           
					       if(uart_rx_ready)begin
						        state_rx    <= #`D END;
							     data_byte_rx     <= uart_rx_data;
								  rx_time_out_cnt    <= #`D 0;
							 end else
							 	  rx_time_out_cnt <= rx_time_out_cnt + 32'd1;						
						end
		         end
		 END    :begin
		            state_rx         <= #`D IDLE;
		            if((parity_rx_calc==parity_rx)&&(data_byte_rx==FRAME_END))begin						    
							 command_rx_ready  <= #`D 1;
		            end
		         end
       default:state_rx  <= #`D IDLE;	
     endcase				
	end
//-------------------------------------------------------------------------------------------------------------
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