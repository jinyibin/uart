`timescale 1ns/100ps
`include "define.v"
//`define SIM

module EP4CE10(
	input  wire      clkin,  //50Mhz
	output wire       led,    //ledtest
	
	output wire      rs422_de_main,   //transceiver tx enable,high level active             
   output wire      rs422_re_n_main, //transceiver rx enable,low level active             
   output wire      rs422_di_main,   //transceiver tx data   
   input  wire      rs422_ro_main,   //transceiver rx data
	
	output wire[3:0] cd4514_d,        //4-16 decoder input
	output wire      cd4514_strobe,   //high level enable the 4-16 decoder to latch the input 
	output wire      cd4514_en_n,     //low level enable 4-16 decoder
	output wire[3:0] cd4514_d_1,      //4-16 decoder back up control
   output wire      cd4514_strobe_1,
	output wire      cd4514_en_n_1,
	
	output wire[1:0] cd4555_d,        //2-4 decoder input
	output wire      cd4555_en_n,     //2-4 decoder enable,low level active
	
	output wire[1:0] cd4555_d_1,      //2-4 decoder back up control
	output wire      cd4555_en_n_1,
	
	output wire      pre_pwr_on,
	output wire      pre_pwr_on_1,
	input  wire      pre_pwr_on_ack,  //low level signifies pre power open
	
	output reg [4:0] camera_rst,
	output reg [4:0] camera_pwr_en,
	output reg       sensor_pwr_en,
	output reg       motor_pwr_en,
	
	output wire      txd_to_stm32,
   input  wire      rxd_from_stm32	
);

//-------------------------------------------------------------------------------------------------------------
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
wire [15:0]   command_rx_main;
wire [47:0]  data_field_rx_main;
wire         command_tx_over_main;
wire         command_tx_status_main;
wire         command_tx_flag_main;   //high level pulse signal a new command has arrived for transmiting
wire [15:0]   command_tx_main;
wire [47:0]  data_field_tx_main;

wire [31:0]  version;

wire [7:0]   explosion_err;
wire [47:0]  explosion_status;


//-------------------------------------------------------------------------------------------------------------
`ifdef SIM
parameter     RST_CNT_LIMIT = 100;
`else
parameter     RST_CNT_LIMIT = 2<<27;
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

pll pll(
			.inclk0(clkin),
			.c0(clk),
			.c1(led),
			.locked(locked)
		  );
//-------------------------------------------------------------------------------------------------------------
	                  /* light led 1HZ */
reg [31:0] led_cnt;
/*
always @ (posedge clk) 
   begin
        if(!rst_n)begin
		     led_cnt <= 32'd0;
			  led     <= 1'd0;
		  end  else begin
		        if(led_cnt == 32'd5000000 - 32'd1)
				     begin
			          led_cnt <= 32'd0;
						 led     <= ~led;
			        end
			     else begin
			            led_cnt <= led_cnt + 32'd1;
			          end
		       end  
   end							
  */
//-------------------------------------------------------------------------------------------------------------
                     /*  generate uart sampling Clock  */
  reg          uart_clk      ;
  reg  [7:0]   uart_clk_divider  ;
  assign txd_to_stm32 = uart_clk;
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
parameter SENSOR_PWR_MASK_BIT = 21,
          MOTOR_PWR_MASK_BIT =  22,
			 CAMERA_RST1_MASK_BIT =24,
			 CAMERA_RST2_MASK_BIT =25,
			 CAMERA_RST3_MASK_BIT =26,
			 CAMERA_RST4_MASK_BIT =27,
			 CAMERA_RST5_MASK_BIT =28;

//**********************************************************************			 
always @(posedge clk)
    if(!rst_n)begin
			sensor_pwr_en <= 1'd0;
			motor_pwr_en  <= 1'd0;
	 end else if(command_rx_flag_main)begin
         sensor_pwr_en <= data_field_rx_main[SENSOR_PWR_MASK_BIT];
			motor_pwr_en  <= data_field_rx_main[MOTOR_PWR_MASK_BIT];
    end
//**********************************************************************	
               /*camera control */
`ifdef SIM			 
parameter CAMERA_PWR_PULSE_TIME =5000;
`else
parameter CAMERA_PWR_PULSE_TIME =50000000;
`endif
parameter IDLE = 1, WAIT_FOR_PWR = 2,OPEN = 3;
					
reg [31:0]  camera_pwr_on_pulse_cnt0;
reg  [1:0]  camera_state0;
always @(posedge clk)
    if(!rst_n)begin  
			camera_rst[0]            <= 1'd0;
			camera_pwr_on_pulse_cnt0 <= 32'd0;
			camera_state0            <= OPEN;
			camera_pwr_en[0]         <= 1'd1;
	 end else begin
	      case(camera_state0)
			           IDLE:begin
										camera_rst[0]            <= 1'd0;
										camera_pwr_on_pulse_cnt0 <= 32'd0;
										if(camera_pwr_en[0])begin//camera already open
										    if(command_rx_flag_main&(~data_field_rx_main[CAMERA_RST1_MASK_BIT]))begin//receive close camera command
											    camera_state0 <= IDLE;
											    camera_pwr_en[0]   <= 1'd0;	
											 end 
										end else begin // camera closed
										    if(command_rx_flag_main&data_field_rx_main[CAMERA_RST1_MASK_BIT])//receive open camera command
											    camera_state0 <= WAIT_FOR_PWR;										
										end												 
								 end
				WAIT_FOR_PWR:begin
								      camera_pwr_en[0]         <= 1'd1;
										if(camera_pwr_on_pulse_cnt0==(CAMERA_PWR_PULSE_TIME<<2))begin
											camera_state0 <= OPEN;	
											camera_pwr_on_pulse_cnt0 <= 32'd0;											
										end else
											camera_pwr_on_pulse_cnt0 <= camera_pwr_on_pulse_cnt0 + 32'd1;									 
								 end
				        OPEN:begin
										camera_rst[0]            <= 1'd1;
										if(camera_pwr_on_pulse_cnt0==CAMERA_PWR_PULSE_TIME)
											camera_state0 <= IDLE;	
										else
											camera_pwr_on_pulse_cnt0 <= camera_pwr_on_pulse_cnt0 + 32'd1;				
				             end
			        default:  camera_state0 <= IDLE;			
			endcase
    end	
	
reg [31:0]  camera_pwr_on_pulse_cnt1;
reg  [1:0]  camera_state1;
always @(posedge clk)
    if(!rst_n)begin  
			camera_rst[1]            <= 1'd0;
			camera_pwr_on_pulse_cnt1 <= 32'd0;
			camera_state1            <= OPEN;
			camera_pwr_en[1]         <= 1'd1;
	 end else begin
	      case(camera_state1)
			           IDLE:begin
										camera_rst[1]            <= 1'd0;
										camera_pwr_on_pulse_cnt1 <= 32'd0;
										if(camera_pwr_en[1])begin//camera already open
										    if(command_rx_flag_main&(~data_field_rx_main[CAMERA_RST2_MASK_BIT]))begin//receive close camera command
											    camera_state1 <= IDLE;	
												 camera_pwr_en[1]   <= 1'd0; 
											 end
										end else begin // camera closed
										    if(command_rx_flag_main&data_field_rx_main[CAMERA_RST2_MASK_BIT])//receive open camera command
											    camera_state1 <= WAIT_FOR_PWR;										
										end												 
								 end
				WAIT_FOR_PWR:begin
								      camera_pwr_en[1]         <= 1'd1;
										if(camera_pwr_on_pulse_cnt1==(CAMERA_PWR_PULSE_TIME<<2))begin
											camera_state1 <= OPEN;	
											camera_pwr_on_pulse_cnt1 <= 32'd0;											
										end else
											camera_pwr_on_pulse_cnt1 <= camera_pwr_on_pulse_cnt1 + 32'd1;									 
								 end
				        OPEN:begin
										camera_rst[1]            <= 1'd1;
										if(camera_pwr_on_pulse_cnt1==CAMERA_PWR_PULSE_TIME)
											camera_state1 <= IDLE;		
										else
											camera_pwr_on_pulse_cnt1 <= camera_pwr_on_pulse_cnt1 + 32'd1;				
				             end
			        default:  camera_state1 <= IDLE;				
			endcase
    end
	 
reg [31:0]  camera_pwr_on_pulse_cnt2;
reg  [1:0]  camera_state2;
always @(posedge clk)
    if(!rst_n)begin  
			camera_rst[2]            <= 1'd0;
			camera_pwr_on_pulse_cnt2 <= 32'd0;
			camera_state2            <= OPEN;
			camera_pwr_en[2]         <= 1'd1;
	 end else begin
	      case(camera_state2)
			           IDLE:begin
										camera_rst[2]            <= 1'd0;
										camera_pwr_on_pulse_cnt2 <= 32'd0;
										if(camera_pwr_en[2])begin//camera already open
										    if(command_rx_flag_main&(~data_field_rx_main[CAMERA_RST3_MASK_BIT]))begin//receive close camera command
											    camera_pwr_en[2]   <= 1'd0;
											    camera_state2      <= IDLE;	
												end 
										end else begin // camera closed
										    if(command_rx_flag_main&data_field_rx_main[CAMERA_RST3_MASK_BIT])//receive open camera command
											    camera_state2 <= WAIT_FOR_PWR;										
										end												 
								 end
				WAIT_FOR_PWR:begin
								      camera_pwr_en[2]         <= 1'd1;
										if(camera_pwr_on_pulse_cnt2==(CAMERA_PWR_PULSE_TIME<<2))begin
											camera_state2 <= OPEN;	
											camera_pwr_on_pulse_cnt2 <= 32'd0;											
										end else
											camera_pwr_on_pulse_cnt2 <= camera_pwr_on_pulse_cnt2 + 32'd1;									 
								 end
				        OPEN:begin
										camera_rst[2]            <= 1'd1;
										if(camera_pwr_on_pulse_cnt2==CAMERA_PWR_PULSE_TIME)
											camera_state2 <= IDLE;		
										else
											camera_pwr_on_pulse_cnt2 <= camera_pwr_on_pulse_cnt2 + 32'd1;				
				             end
			        default:  camera_state2 <= IDLE;				
			endcase
    end
reg [31:0]  camera_pwr_on_pulse_cnt3;
reg  [1:0]  camera_state3;
always @(posedge clk)
    if(!rst_n)begin  
			camera_rst[3]            <= 1'd0;
			camera_pwr_on_pulse_cnt3 <= 32'd0;
			camera_state3            <= OPEN;
			camera_pwr_en[3]         <= 1'd1;
	 end else begin
	      case(camera_state3)
			           IDLE:begin
										camera_rst[3]            <= 1'd0;
										camera_pwr_on_pulse_cnt3 <= 32'd0;
										if(camera_pwr_en[3])begin//camera already open
										    if(command_rx_flag_main&(~data_field_rx_main[CAMERA_RST4_MASK_BIT]))begin//receive close camera command
											    camera_state3 <= IDLE;	
												camera_pwr_en[3]   <= 1'd0; 
											 end
										end else begin // camera closed
										    if(command_rx_flag_main&data_field_rx_main[CAMERA_RST4_MASK_BIT])//receive open camera command
											    camera_state3 <= WAIT_FOR_PWR;										
										end												 
								 end
				WAIT_FOR_PWR:begin
								      camera_pwr_en[3]         <= 1'd1;
										if(camera_pwr_on_pulse_cnt3==(CAMERA_PWR_PULSE_TIME<<2))begin
											camera_state3 <= OPEN;	
											camera_pwr_on_pulse_cnt3 <= 32'd0;											
										end else
											camera_pwr_on_pulse_cnt3 <= camera_pwr_on_pulse_cnt3 + 32'd1;									 
								 end
				        OPEN:begin
										camera_rst[3]            <= 1'd1;
										if(camera_pwr_on_pulse_cnt3==CAMERA_PWR_PULSE_TIME)
											camera_state3 <= IDLE;		
										else
											camera_pwr_on_pulse_cnt3 <= camera_pwr_on_pulse_cnt3 + 32'd1;				
				             end
			        default:  camera_state3 <= IDLE;			
			endcase
    end
reg [31:0]  camera_pwr_on_pulse_cnt4;
reg  [1:0]  camera_state4;
always @(posedge clk)
    if(!rst_n)begin  
			camera_rst[4]            <= 1'd0;
			camera_pwr_on_pulse_cnt4 <= 32'd0;
			camera_state4            <= OPEN;
			camera_pwr_en[4]         <= 1'd1;
	 end else begin
	      case(camera_state4)
			           IDLE:begin
										camera_rst[4]            <= 1'd0;
										camera_pwr_on_pulse_cnt4 <= 32'd0;
										if(camera_pwr_en[4])begin//camera already open
										    if(command_rx_flag_main&(~data_field_rx_main[CAMERA_RST5_MASK_BIT]))begin//receive close camera command
											    camera_state4 <= IDLE;	
												camera_pwr_en[4]   <= 1'd0; 
											 end
										end else begin // camera closed
										    if(command_rx_flag_main&data_field_rx_main[CAMERA_RST5_MASK_BIT])//receive open camera command
											    camera_state4 <= WAIT_FOR_PWR;										
										end												 
								 end
				WAIT_FOR_PWR:begin
								      camera_pwr_en[4]         <= 1'd1;
										if(camera_pwr_on_pulse_cnt4==CAMERA_PWR_PULSE_TIME)begin
											camera_state4 <= OPEN;	
											camera_pwr_on_pulse_cnt4 <= 32'd0;											
										end else
											camera_pwr_on_pulse_cnt4 <= camera_pwr_on_pulse_cnt4 + 32'd1;									 
								 end
				        OPEN:begin
										camera_rst[4]            <= 1'd1;
										if(camera_pwr_on_pulse_cnt4==(CAMERA_PWR_PULSE_TIME<<2))
											camera_state4 <= IDLE;		
										else
											camera_pwr_on_pulse_cnt4 <= camera_pwr_on_pulse_cnt4 + 32'd1;				
				             end
			        default:  camera_state4 <= IDLE;			
			endcase
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
										.command_tx_ready(command_rx_flag_main),   //high level pulse signal a new command has arrived for transmiting
										.command_tx(command_rx_main),
										.data_field_tx(explosion_status),										
								`else
										.command_tx_ready(command_rx_flag_main),   //high level pulse signal a new command has arrived for transmiting
										.command_tx(command_tx_main),
										.data_field_tx({4'd0,motor_pwr_en,sensor_pwr_en,explosion_status[41:0]}),
								`endif					 
										.clk(clk),  
										.uart_clk(uart_clk),          //uart sampling clock	,baudrate is calcurated according this clock
										.rst_n(rst_n), 
											
										.version(version)
         
										);
//-------------------------------------------------------------------------------------------------------------
explosive_ctrl  fire(

							.cd4514_d(cd4514_d),        //4-16 decoder input
							.cd4514_strobe(cd4514_strobe),   //high level enable the 4-16 decoder to latch the input 
							.cd4514_en_n(cd4514_en_n),     //low level enable 4-16 decoder
							.cd4514_d_1(cd4514_d_1),      //4-16 decoder back up control
							.cd4514_strobe_1(cd4514_strobe_1),
							.cd4514_en_n_1(cd4514_en_n_1),
								
							.cd4555_d(cd4555_d),        //2-4 decoder input
							.cd4555_en_n(cd4555_en_n),     //2-4 decoder enable,low level active
								
							.cd4555_d_1(cd4555_d_1),      //2-4 decoder back up control
							.cd4555_en_n_1(cd4555_en_n_1),
								
							.pre_pwr_on(pre_pwr_on),
							.pre_pwr_on_1(pre_pwr_on_1),
							.pre_pwr_on_ack(pre_pwr_on_ack),    //low level means pre power open
								
							.command_ready(command_rx_flag_main),     //high pulse signifies a new command
							.command_type(command_rx_main),
							.command_parameter(data_field_rx_main),
							.explosive_status(explosion_status),  //explosive status feedback,high level in bit n means channel n has been exploded
							.err_reg(explosion_err),               //error code
									
							.clk(clk),
							.rst_n(rst_n)
);


//---------------------------------------------------------------------------------------------------------------	
version_reg ver(
                    .clock(clk),
						  .reset(rst_n),
						  .data_out(version)
						  );
endmodule