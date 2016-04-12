/***************************************************************************************************************
--Module Name:  explosive control
--Author     :  Jin
--Description:  control the explosives according the input command
                write explosive_en_reg to enable explosion of each channel,
					 write explosive time reg to set the time of explosion
					 check explosive_status[30:0] to see if explosion is over
					 check explosive_status[31] to see if pre_power is over
					 check err_reg to see if there is err
					 minimum time of explosion is 2s
                
--History    :  2016-04-03  Created by Jin.                          

***************************************************************************************************************/
`timescale 1ns/100ps
`include "define.v"

module explosive_ctrl(

	output reg [3:0] cd4514_d,        //4-16 decoder input
	output reg       cd4514_strobe,   //high level enable the 4-16 decoder to latch the input 
	output reg       cd4514_en_n,     //low level enable 4-16 decoder
	output reg [3:0] cd4514_d_1,      //4-16 decoder back up control
   output reg       cd4514_strobe_1,
	output reg       cd4514_en_n_1,
	
	output reg [1:0] cd4555_d,        //2-4 decoder input
	output reg       cd4555_en_n,     //2-4 decoder enable,low level active
	
	output reg [1:0] cd4555_d_1,      //2-4 decoder back up control
	output reg       cd4555_en_n_1,
	
	output reg       pre_pwr_on,
	output reg       pre_pwr_on_1,
	input  wire      pre_pwr_on_ack,    //low level means pre power open
	
	input  wire      command_ready,     //high pulse signifies a new command
	input  wire[7:0] command_type,
	input  wire[31:0]command_parameter,
	output reg [31:0]explosive_status,  //explosive status feedback,high level in bit n means channel n has been exploded
	                                    //bit32 is pre power success status ,1 means pre power success
	output reg [7:0] err_reg,               //error code
		
	input  wire      clk,
	input  wire      rst_n
);
//-------------------------------------------------------------------------------------------------------------
`ifdef SIM
parameter  PRE_POWER_GUARDING_TIME = 32'd500;   //10us, pre power ack signal must be active for PRE_POWER_GUARDING_TIME time to signifies a success pre power
parameter  PRE_POWER_FAIL_TIME = PRE_POWER_GUARDING_TIME + 32'd50;   //20us  time to check pre power ,return err if pre power do not success in this time
parameter  EXPLOSION_GUARDING_TIME = 33'd50;   //1us, time between consecutive explosion

parameter  COMMAND_TYPE_EXPLODE   = 8'h05,
           COMMAND_TYPE_CANCEL    = 8'h06,
           COMMAND_TYPE_PRE_POWER = 8'h07;
parameter  IDLE       = 1,PRE_POWER = 2,EXPLOSION = 3;
parameter  EXPLOSIVE_TIME = 32'd1000;//200us explosion time base
`else
parameter  PRE_POWER_GUARDING_TIME = 32'd50000;   //1ms, pre power ack signal must be active for PRE_POWER_GUARDING_TIME time to signifies a success pre power
parameter  PRE_POWER_FAIL_TIME = PRE_POWER_GUARDING_TIME + 32'd5000;   //1.1ms  time to check pre power ,return err if pre power do not success in this time
parameter  EXPLOSION_GUARDING_TIME = 33'd50;   //1us, time between consecutive explosion,make sure MOSFET is closed after before fire

parameter  COMMAND_TYPE_EXPLODE   = 8'h05,
           COMMAND_TYPE_CANCEL    = 8'h06,
           COMMAND_TYPE_PRE_POWER = 8'h07;
parameter  IDLE       = 1,PRE_POWER = 2,EXPLOSION = 3;
parameter  EXPLOSIVE_TIME = 32'd50000000;//2 second explosion time base
`endif
//-------------------------------------------------------------------------------------------------------------			  
reg [1:0] state;

reg [31:0] explosion_guarding_time_cnt;
always@(posedge clk)
   if(!rst_n)begin
      explosion_guarding_time_cnt <= #`D 0;
   end else if(state != PRE_POWER)	
	   explosion_guarding_time_cnt <= #`D 0;
	else if(state == PRE_POWER)begin
	   if(explosion_guarding_time_cnt < EXPLOSION_GUARDING_TIME)
		   explosion_guarding_time_cnt <= explosion_guarding_time_cnt + 32'd1;
	end
//-------------------------------------------------------------------------------------------------------------
reg [1:0]  pre_power_on_ack_buf;
always@(posedge clk)   //buffer the ack signal
   if(!rst_n)
		pre_power_on_ack_buf            <= #`D 0;
   else 	
	   pre_power_on_ack_buf            <= {pre_power_on_ack_buf[0],pre_pwr_on_ack};

reg [31:0] pre_power_guarding_time_cnt;
reg [31:0] pre_power_fail_time_cnt;
always@(posedge clk)
   if(!rst_n)begin
      pre_power_guarding_time_cnt <= #`D 0;
		pre_power_fail_time_cnt     <= #`D 0;
   end else if(state == IDLE)begin	
	   pre_power_guarding_time_cnt  <= #`D 0;
		pre_power_fail_time_cnt      <= #`D 0;
	end else if(state == PRE_POWER)begin
		if(explosive_status[31]==1'b0)//pre power did not success
		   pre_power_fail_time_cnt <= pre_power_fail_time_cnt + 32'd1;
	   if(pre_power_on_ack_buf[1] == 1'b0)begin//
	     if(pre_power_guarding_time_cnt < PRE_POWER_GUARDING_TIME)
		     pre_power_guarding_time_cnt <= pre_power_guarding_time_cnt + 32'd1;
	   end
	end
//-------------------------------------------------------------------------------------------------------------

reg [7:0] channel;	 

reg [31:0]explosive_en_reg;  //set bit n 1 will enabel explotion of channel n,reset to disable
reg [7:0] explosive_time_reg;//set time of explosion ,UNIT second
reg [32:0]explosive_time_cnt;

always@(posedge clk)
   if(!rst_n)begin		  
	    state      <= #`D IDLE;
		 explosive_en_reg <= #`D 0;
		 explosive_time_reg <= #`D 0;
		 explosive_time_cnt <= #`D 0;
		 explosive_status   <= #`D 0;
		 pre_pwr_on         <= #`D 0;  
		 pre_pwr_on_1       <= #`D 0;
		 err_reg            <= #`D 0;  
   end else begin
	    case(state)
		 IDLE:  begin
		           channel <= 8'hff;
					  pre_pwr_on     <= #`D 0;  
		           pre_pwr_on_1   <= #`D 0;
		           if((command_ready==1)&&(command_type==COMMAND_TYPE_PRE_POWER))begin
					     state          <= #`D PRE_POWER;	
	                 pre_pwr_on     <= #`D 1;  
		              pre_pwr_on_1   <= #`D 1;					  
					  end 
		        end
		 PRE_POWER:begin
						  if((command_ready==1)&&(command_type==COMMAND_TYPE_EXPLODE))begin
							  explosive_en_reg       <=  {8'd0,command_parameter[23:0]};
							  explosive_time_reg     <= command_parameter[31:24];
							  explosive_status[30:0] <= {7'h7F,~command_parameter[23:0]} & explosive_status[30:0];	
							  state                  <= #`D EXPLOSION;
						  end else if((command_ready==1)&&(command_type==COMMAND_TYPE_CANCEL))begin //cancel pre power,back to idle
							  explosive_en_reg    <=  32'd0;
							  explosive_time_reg  <=  8'd0;
							  explosive_status[31]<= 1'b0;
							  state              <= #`D IDLE;
							  //explosive_status   <= {8'hFF,~command_parameter[23:0]} & explosive_status;					  
						  end else if(pre_power_guarding_time_cnt == PRE_POWER_GUARDING_TIME)begin //make sure time between consecutive channels is no less than EXPLOSION_GUARDING_TIME
							  explosive_status[31] <= 1'b1; //set the pre power success bit
						  end else if(pre_power_fail_time_cnt > PRE_POWER_FAIL_TIME)begin //pre power ack fail,return to idle
							  explosive_en_reg    <=  32'd0;
							  explosive_time_reg  <=  8'd0;
							  explosive_status[31]<= 1'b0;
							  err_reg             <= 8'd1;  
							  state               <= #`D IDLE;
						  end  
		 
		           end
		 EXPLOSION:begin
		              if(explosive_en_reg[0])begin
						      if((explosive_time_cnt > (EXPLOSIVE_TIME<<explosive_time_reg))&&(explosive_time_cnt < (EXPLOSIVE_TIME<<explosive_time_reg)+EXPLOSION_GUARDING_TIME))begin//explosion over,reset decoder
	                        channel	            <= 8'hff;
	                        explosive_time_cnt <= explosive_time_cnt + 33'd1;							
								end else if(explosive_time_cnt == (EXPLOSIVE_TIME<<explosive_time_reg)+EXPLOSION_GUARDING_TIME)begin//explosion over
								   explosive_status[0]  <= 1'b1;//set status bit
						         explosive_en_reg[0]  <= 1'b0;//clear en reggiter
									explosive_time_cnt   <= 33'd0;								
								end else begin
								   channel            <= 0;
								   explosive_time_cnt <= explosive_time_cnt + 33'd1;
							   end
						  end else if(explosive_en_reg[1])begin
						      if((explosive_time_cnt > (EXPLOSIVE_TIME<<explosive_time_reg))&&(explosive_time_cnt < (EXPLOSIVE_TIME<<explosive_time_reg)+EXPLOSION_GUARDING_TIME))begin//explosion over,reset decoder
	                        channel	            <= 8'hff;	
	                        explosive_time_cnt <= explosive_time_cnt + 33'd1;						
								end else if(explosive_time_cnt == (EXPLOSIVE_TIME<<explosive_time_reg)+EXPLOSION_GUARDING_TIME)begin//explosion over

								   explosive_status[1]  <= 1'b1;//set status bit
						         explosive_en_reg[1]  <= 1'b0;//clear en reggiter
									explosive_time_cnt   <= 33'd0;									
								end else begin
								   channel            <= 1;
								   explosive_time_cnt <= explosive_time_cnt + 33'd1;
							   end
						  end else if(explosive_en_reg[2])begin
						      if((explosive_time_cnt > (EXPLOSIVE_TIME<<explosive_time_reg))&&(explosive_time_cnt < (EXPLOSIVE_TIME<<explosive_time_reg)+EXPLOSION_GUARDING_TIME))begin//explosion over,reset decoder
	                        channel	            <= 8'hff;	
	                        explosive_time_cnt <= explosive_time_cnt + 33'd1;						
								end else if(explosive_time_cnt == (EXPLOSIVE_TIME<<explosive_time_reg)+EXPLOSION_GUARDING_TIME)begin//explosion over

								   explosive_status[2]  <= 1'b1;//set status bit
						         explosive_en_reg[2]  <= 1'b0;//clear en reggiter
									explosive_time_cnt   <= 33'd0;									
								end else begin
								   channel            <= 2;
								   explosive_time_cnt <= explosive_time_cnt + 33'd1;
							   end						  
						  end else if(explosive_en_reg[3])begin
						      if((explosive_time_cnt > (EXPLOSIVE_TIME<<explosive_time_reg))&&(explosive_time_cnt < (EXPLOSIVE_TIME<<explosive_time_reg)+EXPLOSION_GUARDING_TIME))begin//explosion over,reset decoder
	                        channel	            <= 8'hff;	
	                        explosive_time_cnt <= explosive_time_cnt + 33'd1;						
								end else if(explosive_time_cnt == (EXPLOSIVE_TIME<<explosive_time_reg)+EXPLOSION_GUARDING_TIME)begin//explosion over

								   explosive_status[3]  <= 1'b1;//set status bit
						         explosive_en_reg[3]  <= 1'b0;//clear en reggiter
									explosive_time_cnt   <= 33'd0;									
								end else begin
								   channel            <= 3;
								   explosive_time_cnt <= explosive_time_cnt + 33'd1;
							   end						  
						  end else if(explosive_en_reg[4])begin
						      if((explosive_time_cnt > (EXPLOSIVE_TIME<<explosive_time_reg))&&(explosive_time_cnt < (EXPLOSIVE_TIME<<explosive_time_reg)+EXPLOSION_GUARDING_TIME))begin
								   //explosion over,reset decoder
	                        channel	            <= 8'hff;		
	                        explosive_time_cnt <= explosive_time_cnt + 33'd1;					
								end else if(explosive_time_cnt == (EXPLOSIVE_TIME<<explosive_time_reg)+EXPLOSION_GUARDING_TIME)begin//explosion over

								   explosive_status[4]  <= 1'b1;//set status bit
						         explosive_en_reg[4]  <= 1'b0;//clear en reggiter
									explosive_time_cnt   <= 33'd0;									
								end else begin
								   channel            <= 4;
								   explosive_time_cnt <= explosive_time_cnt + 33'd1;
							   end						  
						  end else if(explosive_en_reg[5])begin
						      if((explosive_time_cnt > (EXPLOSIVE_TIME<<explosive_time_reg))&&(explosive_time_cnt < (EXPLOSIVE_TIME<<explosive_time_reg)+EXPLOSION_GUARDING_TIME))begin
								   //explosion over,reset decoder
	                        channel	            <= 8'hff;	
	                        explosive_time_cnt <= explosive_time_cnt + 33'd1;						
								end else if(explosive_time_cnt == (EXPLOSIVE_TIME<<explosive_time_reg)+EXPLOSION_GUARDING_TIME)begin//explosion over,reset status reg
								   explosive_status[5]  <= 1'b1;//set status bit
						         explosive_en_reg[5]  <= 1'b0;//clear en reggiter
									explosive_time_cnt   <= 33'd0;									
								end else begin
								   channel            <= 5;
								   explosive_time_cnt <= explosive_time_cnt + 33'd1;
							   end						  
						  end else if(explosive_en_reg[6])begin
						      if((explosive_time_cnt > (EXPLOSIVE_TIME<<explosive_time_reg))&&(explosive_time_cnt < (EXPLOSIVE_TIME<<explosive_time_reg)+EXPLOSION_GUARDING_TIME))begin
								   //explosion over,reset decoder
	                        channel	            <= 8'hff;	
	                        explosive_time_cnt <= explosive_time_cnt + 33'd1;						
								end else if(explosive_time_cnt == (EXPLOSIVE_TIME<<explosive_time_reg)+EXPLOSION_GUARDING_TIME)begin//explosion over,reset status reg
								   explosive_status[6]  <= 1'b1;//set status bit
						         explosive_en_reg[6]  <= 1'b0;//clear en reggiter
									explosive_time_cnt   <= 33'd0;									
								end else begin
								   channel            <= 6;
								   explosive_time_cnt <= explosive_time_cnt + 33'd1;
							   end						  
						  end else if(explosive_en_reg[7])begin
						      if((explosive_time_cnt > (EXPLOSIVE_TIME<<explosive_time_reg))&&(explosive_time_cnt < (EXPLOSIVE_TIME<<explosive_time_reg)+EXPLOSION_GUARDING_TIME))begin
								   //explosion over,reset decoder
	                        channel	            <= 8'hff;			
	                        explosive_time_cnt <= explosive_time_cnt + 33'd1;				
								end else if(explosive_time_cnt == (EXPLOSIVE_TIME<<explosive_time_reg)+EXPLOSION_GUARDING_TIME)begin//explosion over,reset status reg
								   explosive_status[7]  <= 1'b1;//set status bit
						         explosive_en_reg[7]  <= 1'b0;//clear en reggiter
									explosive_time_cnt   <= 33'd0;									
								end else begin
								   channel            <= 7;
								   explosive_time_cnt <= explosive_time_cnt + 33'd1;
							   end						  
						  end else if(explosive_en_reg[8])begin
						      if((explosive_time_cnt > (EXPLOSIVE_TIME<<explosive_time_reg))&&(explosive_time_cnt < (EXPLOSIVE_TIME<<explosive_time_reg)+EXPLOSION_GUARDING_TIME))begin
								   //explosion over,reset decoder
	                        channel	            <= 8'hff;		
	                        explosive_time_cnt <= explosive_time_cnt + 33'd1;					
								end else if(explosive_time_cnt == (EXPLOSIVE_TIME<<explosive_time_reg)+EXPLOSION_GUARDING_TIME)begin//explosion over,reset status reg
								   explosive_status[8]  <= 1'b1;//set status bit
						         explosive_en_reg[8]  <= 1'b0;//clear en reggiter
									explosive_time_cnt   <= 33'd0;									
								end else begin
								   channel            <= 8;
								   explosive_time_cnt <= explosive_time_cnt + 33'd1;
							   end						  
						  end else if(explosive_en_reg[9])begin
						      if((explosive_time_cnt > (EXPLOSIVE_TIME<<explosive_time_reg))&&(explosive_time_cnt < (EXPLOSIVE_TIME<<explosive_time_reg)+EXPLOSION_GUARDING_TIME))begin
								   //explosion over,reset decoder
	                        channel	            <= 8'hff;	
	                        explosive_time_cnt <= explosive_time_cnt + 33'd1;						
								end else if(explosive_time_cnt == (EXPLOSIVE_TIME<<explosive_time_reg)+EXPLOSION_GUARDING_TIME)begin//explosion over,reset status reg
								   explosive_status[9]  <= 1'b1;//set status bit
						         explosive_en_reg[9]  <= 1'b0;//clear en reggiter
									explosive_time_cnt   <= 33'd0;									
								end else begin
								   channel            <= 9;
								   explosive_time_cnt <= explosive_time_cnt + 33'd1;
							   end						  
						  end else if(explosive_en_reg[10])begin
						      if((explosive_time_cnt > (EXPLOSIVE_TIME<<explosive_time_reg))&&(explosive_time_cnt < (EXPLOSIVE_TIME<<explosive_time_reg)+EXPLOSION_GUARDING_TIME))begin
								   //explosion over,reset decoder
	                        channel	            <= 8'hff;	
	                        explosive_time_cnt <= explosive_time_cnt + 33'd1;						
								end else if(explosive_time_cnt == (EXPLOSIVE_TIME<<explosive_time_reg)+EXPLOSION_GUARDING_TIME)begin//explosion over,reset status reg
								   explosive_status[10]  <= 1'b1;//set status bit
						         explosive_en_reg[10]  <= 1'b0;//clear en reggiter
									explosive_time_cnt   <= 33'd0;									
								end else begin
								   channel            <= 10;
								   explosive_time_cnt <= explosive_time_cnt + 33'd1;
							   end						  
						  end else if(explosive_en_reg[11])begin
						      if((explosive_time_cnt > (EXPLOSIVE_TIME<<explosive_time_reg))&&(explosive_time_cnt < (EXPLOSIVE_TIME<<explosive_time_reg)+EXPLOSION_GUARDING_TIME))begin
								   //explosion over,reset decoder
	                        channel	            <= 8'hff;	
	                        explosive_time_cnt <= explosive_time_cnt + 33'd1;						
								end else if(explosive_time_cnt == (EXPLOSIVE_TIME<<explosive_time_reg)+EXPLOSION_GUARDING_TIME)begin//explosion over,reset status reg
								   explosive_status[11]  <= 1'b1;//set status bit
						         explosive_en_reg[11]  <= 1'b0;//clear en reggiter
									explosive_time_cnt   <= 33'd0;									
								end else begin
								   channel            <= 11;
								   explosive_time_cnt <= explosive_time_cnt + 33'd1;
							   end						  
						  end else if(explosive_en_reg[12])begin
						      if((explosive_time_cnt > (EXPLOSIVE_TIME<<explosive_time_reg))&&(explosive_time_cnt < (EXPLOSIVE_TIME<<explosive_time_reg)+EXPLOSION_GUARDING_TIME))begin
								   //explosion over,reset decoder
	                        channel	            <= 8'hff;	
	                        explosive_time_cnt <= explosive_time_cnt + 33'd1;						
								end else if(explosive_time_cnt == (EXPLOSIVE_TIME<<explosive_time_reg)+EXPLOSION_GUARDING_TIME)begin//explosion over,reset status reg
								   explosive_status[12]  <= 1'b1;//set status bit
						         explosive_en_reg[12]  <= 1'b0;//clear en reggiter
									explosive_time_cnt   <= 33'd0;									
								end else begin
								   channel            <= 12;
								   explosive_time_cnt <= explosive_time_cnt + 33'd1;
							   end						  
						  end else if(explosive_en_reg[13])begin
						      if((explosive_time_cnt > (EXPLOSIVE_TIME<<explosive_time_reg))&&(explosive_time_cnt < (EXPLOSIVE_TIME<<explosive_time_reg)+EXPLOSION_GUARDING_TIME))begin
								   //explosion over,reset decoder
	                        channel	            <= 8'hff;
	                        explosive_time_cnt <= explosive_time_cnt + 33'd1;							
								end else if(explosive_time_cnt == (EXPLOSIVE_TIME<<explosive_time_reg)+EXPLOSION_GUARDING_TIME)begin//explosion over,reset status reg
								   explosive_status[13]  <= 1'b1;//set status bit
						         explosive_en_reg[13]  <= 1'b0;//clear en reggiter
									explosive_time_cnt   <= 33'd0;									
								end else begin
								   channel            <= 13;
								   explosive_time_cnt <= explosive_time_cnt + 33'd1;
							   end						  
						  end else if(explosive_en_reg[14])begin
						      if((explosive_time_cnt > (EXPLOSIVE_TIME<<explosive_time_reg))&&(explosive_time_cnt < (EXPLOSIVE_TIME<<explosive_time_reg)+EXPLOSION_GUARDING_TIME))begin
								   //explosion over,reset decoder
	                        channel	            <= 8'hff;		
	                        explosive_time_cnt <= explosive_time_cnt + 33'd1;					
								end else if(explosive_time_cnt == (EXPLOSIVE_TIME<<explosive_time_reg)+EXPLOSION_GUARDING_TIME)begin//explosion over,reset status reg
								   explosive_status[14]  <= 1'b1;//set status bit
						         explosive_en_reg[14]  <= 1'b0;//clear en reggiter
									explosive_time_cnt   <= 33'd0;									
								end else begin
								   channel            <= 14;
								   explosive_time_cnt <= explosive_time_cnt + 33'd1;
							   end						  
						  end else if(explosive_en_reg[15])begin
						      if((explosive_time_cnt > (EXPLOSIVE_TIME<<explosive_time_reg))&&(explosive_time_cnt < (EXPLOSIVE_TIME<<explosive_time_reg)+EXPLOSION_GUARDING_TIME))begin
								   //explosion over,reset decoder
	                        channel	            <= 8'hff;		
	                        explosive_time_cnt <= explosive_time_cnt + 33'd1;					
								end else if(explosive_time_cnt == (EXPLOSIVE_TIME<<explosive_time_reg)+EXPLOSION_GUARDING_TIME)begin//explosion over,reset status reg
								   explosive_status[15]  <= 1'b1;//set status bit
						         explosive_en_reg[15]  <= 1'b0;//clear en reggiter
									explosive_time_cnt   <= 33'd0;									
								end else begin
								   channel            <= 15;
								   explosive_time_cnt <= explosive_time_cnt + 33'd1;
							   end						  
						  end else if(explosive_en_reg[16])begin
						      if((explosive_time_cnt > (EXPLOSIVE_TIME<<explosive_time_reg))&&(explosive_time_cnt < (EXPLOSIVE_TIME<<explosive_time_reg)+EXPLOSION_GUARDING_TIME))begin
								   //explosion over,reset decoder
	                        channel	            <= 8'hff;		
	                        explosive_time_cnt <= explosive_time_cnt + 33'd1;					
								end else if(explosive_time_cnt == (EXPLOSIVE_TIME<<explosive_time_reg)+EXPLOSION_GUARDING_TIME)begin//explosion over,reset status reg
								   explosive_status[16]  <= 1'b1;//set status bit
						         explosive_en_reg[16]  <= 1'b0;//clear en reggiter
									explosive_time_cnt   <= 33'd0;									
								end else begin
								   channel            <= 16;
								   explosive_time_cnt <= explosive_time_cnt + 33'd1;
							   end						  
						  end else if(explosive_en_reg[17])begin
						      if((explosive_time_cnt > (EXPLOSIVE_TIME<<explosive_time_reg))&&(explosive_time_cnt < (EXPLOSIVE_TIME<<explosive_time_reg)+EXPLOSION_GUARDING_TIME))begin
								   //explosion over,reset decoder
	                        channel	            <= 8'hff;		
	                        explosive_time_cnt <= explosive_time_cnt + 33'd1;					
								end else if(explosive_time_cnt == (EXPLOSIVE_TIME<<explosive_time_reg)+EXPLOSION_GUARDING_TIME)begin//explosion over,reset status reg
								   explosive_status[17]  <= 1'b1;//set status bit
						         explosive_en_reg[17]  <= 1'b0;//clear en reggiter
									explosive_time_cnt   <= 33'd0;									
								end else begin
								   channel            <= 17;
								   explosive_time_cnt <= explosive_time_cnt + 33'd1;
							   end						  
						  end else if(explosive_en_reg[18])begin
						      if((explosive_time_cnt > (EXPLOSIVE_TIME<<explosive_time_reg))&&(explosive_time_cnt < (EXPLOSIVE_TIME<<explosive_time_reg)+EXPLOSION_GUARDING_TIME))begin
								   //explosion over,reset decoder
	                        channel	            <= 8'hff;		
	                        explosive_time_cnt <= explosive_time_cnt + 33'd1;					
								end else if(explosive_time_cnt == (EXPLOSIVE_TIME<<explosive_time_reg)+EXPLOSION_GUARDING_TIME)begin//explosion over,reset status reg
								   explosive_status[18]  <= 1'b1;//set status bit
						         explosive_en_reg[18]  <= 1'b0;//clear en reggiter
									explosive_time_cnt   <= 33'd0;									
								end else begin
								   channel            <= 18;
								   explosive_time_cnt <= explosive_time_cnt + 33'd1;
							   end						  
						  end else if(explosive_en_reg[19])begin
						      if((explosive_time_cnt > (EXPLOSIVE_TIME<<explosive_time_reg))&&(explosive_time_cnt < (EXPLOSIVE_TIME<<explosive_time_reg)+EXPLOSION_GUARDING_TIME))begin
								   //explosion over,reset decoder
	                        channel	            <= 8'hff;	
	                        explosive_time_cnt <= explosive_time_cnt + 33'd1;						
								end else if(explosive_time_cnt == (EXPLOSIVE_TIME<<explosive_time_reg)+EXPLOSION_GUARDING_TIME)begin//explosion over,reset status reg
								   explosive_status[19]  <= 1'b1;//set status bit
						         explosive_en_reg[19]  <= 1'b0;//clear en reggiter
									explosive_time_cnt   <= 33'd0;									
								end else begin
								   channel            <= 19;
								   explosive_time_cnt <= explosive_time_cnt + 33'd1;
							   end						  
						  end  else	//all channel exlosion over
						         state <= #`D IDLE;
		           end
		 default  :state <= #`D IDLE;
		 
       endcase
   end	
//-------------------------------------------------------------------------------------------------------------
reg [31:0]pre_time_out_cnt;
reg [4:0] cd4514_strobe_buf;
reg [4:0] cd4514_strobe_1_buf;
reg [1:0] cd4514_en_n_buf;
reg [1:0] cd4514_en_n_1_buf;
reg [1:0] cd4555_en_n_buf;
reg [1:0] cd4555_en_n_1_buf;
always@(posedge clk)
   if(!rst_n)begin
		 cd4514_d       <= #`D 0;        
		 cd4514_strobe  <= #`D 0;     
		 cd4514_en_n    <= #`D 1;       
		 cd4514_d_1     <= #`D 0;        
		 cd4514_strobe_1<= #`D 0;  
		 cd4514_en_n_1  <= #`D 1;  
		 cd4555_d       <= #`D 0;  
		 cd4555_en_n    <= #`D 1;      
		 cd4555_d_1     <= #`D 0;        
		 cd4555_en_n_1  <= #`D 1;  
		 cd4514_strobe_buf   <= #`D 0;
		 cd4514_strobe_1_buf <= #`D 0;
		 cd4514_en_n_buf     <= 2'b11;
		 cd4514_en_n_1_buf   <= 2'b11;
		 cd4555_en_n_buf     <= 2'b11;
		 cd4555_en_n_1_buf   <= 2'b11;	 
	end else begin
	    if(channel==8'hff)begin
							 cd4514_d       <= #`D 0;        
							 cd4514_strobe  <= #`D 0;     
							 cd4514_en_n    <= #`D 1;       
							 cd4514_d_1     <= #`D 0;        
							 cd4514_strobe_1  <= #`D 0;  
							 cd4514_en_n_1  <= #`D 1;  
							 cd4555_d       <= #`D 0;     
                      cd4555_en_n    <= #`D 1;      
							 cd4555_d_1     <= #`D 0;
							 cd4555_en_n_1  <= #`D 1; 
							 cd4555_en_n_buf     <= 2'b11;
		                cd4555_en_n_1_buf   <= 2'b11;
							 cd4514_strobe_buf   <= #`D 0;
							 cd4514_strobe_1_buf <= #`D 0;
							 cd4514_en_n_buf     <= 2'b11;
							 cd4514_en_n_1_buf   <= 2'b11;

		 end else if((channel>=0)&&(channel<16))begin
		 				  cd4555_d       <= #`D 0;         
						  cd4555_en_n    <= #`D 1;  //disable decoder for channel 17-20    
						  cd4555_d_1     <= #`D 0; 
						  cd4555_en_n_1  <= #`D 1;
		              cd4514_d       <= channel[3:0]; 
						  cd4514_d_1     <= channel[3:0];
						  cd4514_strobe_buf   <= {cd4514_strobe_buf [3:0],1'b1};
						  cd4514_strobe_1_buf <= {cd4514_strobe_1_buf[3:0],1'b1};
						  cd4514_en_n_buf     <= {cd4514_en_n_buf[0],1'b0};
						  cd4514_en_n_1_buf   <= {cd4514_en_n_1_buf[0],1'b0};						  
						  cd4514_en_n_1  <= cd4514_en_n_1_buf[1]; //enable decoder for channel 1-16
						  cd4514_en_n    <= cd4514_en_n_buf[1]; //enable decoder for channel 1-16
						  cd4514_strobe   <= cd4514_strobe_buf[4]; //enable explosion
						  cd4514_strobe_1 <= cd4514_strobe_1_buf[4];                    						  
		end else if((channel>=16)&&(channel<20))begin
		 				  cd4555_d       <= channel[1:0];          
						  cd4555_d_1     <= channel[1:0]; 
						  cd4555_en_n_1_buf  <= {cd4555_en_n_1_buf[0],1'b0};
						  cd4555_en_n_buf    <= {cd4555_en_n_buf[0],1'b0};
		              cd4555_en_n_1  <= cd4555_en_n_1_buf[1];	//enable explosion
						  cd4555_en_n    <= cd4555_en_n_buf[1]; 				  
		              cd4514_d       <= 4'd0; 
						  cd4514_d_1     <= 4'd0;
						  cd4514_en_n_1  <= #`D 1; //disable decoder for channel 1-16
						  cd4514_en_n    <= #`D 1; //disable decoder for channel 1-16
		end
		
	end
//-------------------------------------------------------------------------------------------------------------




endmodule