`timescale 1ns/100ps
`include "define.v"
`define SIM
module top(  
            
                                 
   rs422_de_main,                    
   rs422_re_n_main,                  
   rs422_di_main,          
   rs422_ro_main, 
                                 
   clk_in,              
   rst_in_n                     
	);
//-------------------------------------------------------------------------------------------------------------
output       rs422_de_main;  
output       rs422_re_n_main;
output       rs422_di_main; 
input        rs422_ro_main;



input        clk_in; //16MHz
input        rst_in_n;


reg [31:0]   rst_cnt = 0;
reg          rst_in_n_tmp = 0;
reg          rst_in_n_d1 = 0;
reg          rst_n = 0;
wire         clk;
wire         locked;

wire         rs422_rx_data_main;
wire         rs422_rx_ready_main;
wire         rs422_rx_err_main;
wire         rs422_tx_data_main;
wire         rs422_tx_ready_main;
wire         rs422_tx_over_main;
wire         command_rx_flag_main;   //high level pulse signal a received command
wire [7:0]   command_rx_main;
wire [31:0]  data_field_rx_main;
wire         command_tx_over;
wire         command_tx_status;
wire         command_tx_flag_main;   //high level pulse signal a new command has arrived for transmiting
wire [7:0]   command_tx_main;
wire [31:0]  data_field_tx_main;

wire [31:0]  version;
//-------------------------------------------------------------------------------------------------------------
`ifdef SIM
parameter     RST_CNT_LIMIT = 100;
`else
parameter     RST_CNT_LIMIT = 2<<26;
`endif
parameter     UART_CLK_DIVIDER = 8'd2;   // uart sampling clock=clk/UART_CLK_DIVIDER
//---------------------generate global reset signal ------------------------------------------------------------

always@(posedge clk)
	if((rst_cnt != RST_CNT_LIMIT) && locked) begin
		rst_cnt <= #`D rst_cnt + 1;
	end else begin
		rst_cnt <= #`D rst_cnt;
	end
	
always@(posedge clk)
	if((rst_cnt == RST_CNT_LIMIT) && locked) begin
		rst_in_n_tmp <= #`D 1;
	end else begin
		rst_in_n_tmp <= #`D 0;
	end	

always@(posedge clk)
	begin
		rst_in_n_d1 <= #`D rst_in_n_tmp;
		rst_n       <= #`D rst_in_n_d1;		
	end

//-------------------------------------------------------------------------------------------------------------

uart_pll pll(
			.inclk0(clk_in),
			.c0(clk),
			.locked(locked)
		  );
	
  
//-------------------------------------------------------------------------------------------------------------
                     /*  generate uart sampling Clock  */
  reg          uart_clk      ;
  reg  [7:0]   uart_clk_divider  ;
  
  always @ (posedge clk) 
   begin
        if(!rst_n)
		     uart_clk_divider <= 8'd0;
		  else begin
		        if(uart_clk_divider == UART_CLK_DIVIDER - 8'd1)
				     begin
			          uart_clk_divider <= 8'd0;
			        end
			     else begin
			            uart_clk_divider <= uart_clk_divider + 8'd1;
			          end
		       end  
   end

	always @(posedge clk)
	  begin
	       if(!rst_n)
			     uart_clk       <= 1'd0;
			 else begin
			       if(uart_clk_divider == UART_CLK_DIVIDER - 8'd1)
			         uart_clk <= 1'd1;
					 else 
					   uart_clk <= 1'd0;
					end						
	  end 
//-------------------------------------------------------------------------------------------------------------
	  
command_rw_main  cmd_main(
										.uart_chip_de(rs422_de_main),      //uart transceiver chip transmit enable
										.uart_chip_re_n(rs422_re_n_main),    //uart transceiver chip receive enable
										.uart_chip_di(rs422_di_main),      //uart transceiver chip transmit input
										.uart_chip_ro(rs422_ro_main),      //uart transceiver chip receive output
										
										.command_rx_ready(command_rx_flag_main),   //high level pulse signal a received command
										.command_rx(command_rx_main),
										.data_field_rx(data_field_rx_main), 

										.command_tx_over(command_tx_over_main),   //high pulse signals new command can be transmitted
	                           .command_tx_status(command_tx_status_main), //high level means command is trasmitting
								`ifdef SIM
										.command_tx_ready(1'b1),   //high level pulse signal a new command has arrived for transmiting
										.command_tx(8'd1),
										.data_field_tx(32'h02030405),										
								`else
										.command_tx_ready(command_tx_flag_main),   //high level pulse signal a new command has arrived for transmiting
										.command_tx(command_tx_main),
										.data_field_tx(data_field_tx_main),
								`endif					 
										.clk(clk),  
										.uart_clk(uart_clk),          //uart sampling clock	,baudrate is calcurated according this clock
										.rst_n(rst_n), 
											
										.version(version)
         
										);
//-------------------------------------------------------------------------------------------------------------



//---------------------------------------------------------------------------------------------------------------	
version_reg ver(
                    .clock(clk),
						  .reset(rst_n),
						  .data_out(version)
						  );
endmodule
