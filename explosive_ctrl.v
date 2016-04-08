/***************************************************************************************************************
--Module Name:  explosive control
--Author     :  Jin
--Description:  control the explosives according the input command
                write explosive_en_reg to enable explosion of each channel,
					 write explosive time reg to set th time of explosion
					 check explosive_status to see if it is enabled
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
	output reg [7:0] err_reg,               //error code
		
	input  wire      clk,
	input  wire      rst_n
);
//-------------------------------------------------------------------------------------------------------------
parameter  PRE_GUARDING_TIME = 32'd5000;   //100us  time to check pre power ,return err if pre power do not open in this time
parameter  EXPLOSION_GUARDING_TIME = 32'd50000;   //1ms, time between consecutive explosion
parameter  COMMAND_TYPE_EXPLODE = 8'h05;
parameter  IDLE       = 1,EXPLOSION = 2;
parameter  EXPLOSIVE_TIME = 32'd100000000;//2 second explosion time base
//-------------------------------------------------------------------------------------------------------------			  
reg [1:0] state;

reg [31:0] explosion_guarding_time_cnt;
always@(posedge clk)
   if(!rst_n)begin
      explosion_guarding_time_cnt <= #`D 0;
   end else if(state != IDLE)	
	   explosion_guarding_time_cnt <= #`D 0;
	else if(state == IDLE)begin
	   if(explosion_guarding_time_cnt < EXPLOSION_GUARDING_TIME)
		   explosion_guarding_time_cnt <= explosion_guarding_time_cnt + 32'd1;
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
   end else begin
	    case(state)
		 IDLE:  begin
		           channel <= 8'hff;
		           if((command_ready==1)&&(command_type==COMMAND_TYPE_EXPLODE))begin
					     explosive_en_reg   <=  {8'd0,command_parameter[23:0]};
						  explosive_time_reg <= command_parameter[31:24];
                    explosive_status   <= {8'hFF,~command_parameter[23:0]} & explosive_status;						  
					  end else if(explosion_guarding_time_cnt == EXPLOSION_GUARDING_TIME)begin //make sure idle time is no less than EXPLOSION_GUARDING_TIME
					     if(explosive_en_reg != 0)begin
					       state <= #`D EXPLOSION;
					     end	
					  end  
		        end
		 EXPLOSION:begin
		              if(explosive_en_reg[0])begin
						      if(explosive_time_cnt == (EXPLOSIVE_TIME<<explosive_time_reg))begin//explosion over
								   explosive_status[0]  <= 1'b1;//set status bit
						         explosive_en_reg[0]  <= 1'b0;//clear en reggiter
									explosive_time_cnt   <= 33'd0;
									state                <= #`D IDLE;//return to idle,wait EXPLOSION_GUARDING_TIME for next explosion
								end else begin
								   channel            <= 0;
								   explosive_time_cnt <= explosive_time_cnt + 33'd1;
							   end
						  end else if(explosive_en_reg[1])begin
						      if(explosive_time_cnt == (EXPLOSIVE_TIME<<explosive_time_reg))begin//explosion over
								   explosive_status[1]  <= 1'b1;//set status bit
						         explosive_en_reg[1]  <= 1'b0;//clear en reggiter
									explosive_time_cnt   <= 33'd0;
									state                <= #`D IDLE;//return to idle,wait EXPLOSION_GUARDING_TIME for next explosion
								end else begin
								   channel            <= 1;
								   explosive_time_cnt <= explosive_time_cnt + 33'd1;
							   end
						  end else if(explosive_en_reg[2])begin
						      if(explosive_time_cnt == (EXPLOSIVE_TIME<<explosive_time_reg))begin//explosion over
								   explosive_status[2]  <= 1'b1;//set status bit
						         explosive_en_reg[2]  <= 1'b0;//clear en reggiter
									explosive_time_cnt   <= 33'd0;
									state                <= #`D IDLE;//return to idle,wait EXPLOSION_GUARDING_TIME for next explosion
								end else begin
								   channel            <= 2;
								   explosive_time_cnt <= explosive_time_cnt + 33'd1;
							   end						  
						  end else if(explosive_en_reg[3])begin
						      if(explosive_time_cnt == (EXPLOSIVE_TIME<<explosive_time_reg))begin//explosion over
								   explosive_status[3]  <= 1'b1;//set status bit
						         explosive_en_reg[3]  <= 1'b0;//clear en reggiter
									explosive_time_cnt   <= 33'd0;
									state                <= #`D IDLE;//return to idle,wait EXPLOSION_GUARDING_TIME for next explosion
								end else begin
								   channel            <= 3;
								   explosive_time_cnt <= explosive_time_cnt + 33'd1;
							   end						  
						  end else if(explosive_en_reg[4])begin
						      if(explosive_time_cnt == (EXPLOSIVE_TIME<<explosive_time_reg))begin//explosion over
								   explosive_status[4]  <= 1'b1;//set status bit
						         explosive_en_reg[4]  <= 1'b0;//clear en reggiter
									explosive_time_cnt   <= 33'd0;
									state                <= #`D IDLE;//return to idle,wait EXPLOSION_GUARDING_TIME for next explosion
								end else begin
								   channel            <= 4;
								   explosive_time_cnt <= explosive_time_cnt + 33'd1;
							   end						  
						  end else if(explosive_en_reg[5])begin
						      if(explosive_time_cnt == (EXPLOSIVE_TIME<<explosive_time_reg))begin//explosion over
								   explosive_status[5]  <= 1'b1;//set status bit
						         explosive_en_reg[5]  <= 1'b0;//clear en reggiter
									explosive_time_cnt   <= 33'd0;
									state                <= #`D IDLE;//return to idle,wait EXPLOSION_GUARDING_TIME for next explosion
								end else begin
								   channel            <= 5;
								   explosive_time_cnt <= explosive_time_cnt + 33'd1;
							   end						  
						  end else if(explosive_en_reg[6])begin
						      if(explosive_time_cnt == (EXPLOSIVE_TIME<<explosive_time_reg))begin//explosion over
								   explosive_status[6]  <= 1'b1;//set status bit
						         explosive_en_reg[6]  <= 1'b0;//clear en reggiter
									explosive_time_cnt   <= 33'd0;
									state                <= #`D IDLE;//return to idle,wait EXPLOSION_GUARDING_TIME for next explosion
								end else begin
								   channel            <= 6;
								   explosive_time_cnt <= explosive_time_cnt + 33'd1;
							   end						  
						  end else if(explosive_en_reg[7])begin
						      if(explosive_time_cnt == (EXPLOSIVE_TIME<<explosive_time_reg))begin//explosion over
								   explosive_status[7]  <= 1'b1;//set status bit
						         explosive_en_reg[7]  <= 1'b0;//clear en reggiter
									explosive_time_cnt   <= 33'd0;
									state                <= #`D IDLE;//return to idle,wait EXPLOSION_GUARDING_TIME for next explosion
								end else begin
								   channel            <= 7;
								   explosive_time_cnt <= explosive_time_cnt + 33'd1;
							   end						  
						  end else if(explosive_en_reg[8])begin
						      if(explosive_time_cnt == (EXPLOSIVE_TIME<<explosive_time_reg))begin//explosion over
								   explosive_status[8]  <= 1'b1;//set status bit
						         explosive_en_reg[8]  <= 1'b0;//clear en reggiter
									explosive_time_cnt   <= 33'd0;
									state                <= #`D IDLE;//return to idle,wait EXPLOSION_GUARDING_TIME for next explosion
								end else begin
								   channel            <= 8;
								   explosive_time_cnt <= explosive_time_cnt + 33'd1;
							   end						  
						  end else if(explosive_en_reg[9])begin
						      if(explosive_time_cnt == (EXPLOSIVE_TIME<<explosive_time_reg))begin//explosion over
								   explosive_status[9]  <= 1'b1;//set status bit
						         explosive_en_reg[9]  <= 1'b0;//clear en reggiter
									explosive_time_cnt   <= 33'd0;
									state                <= #`D IDLE;//return to idle,wait EXPLOSION_GUARDING_TIME for next explosion
								end else begin
								   channel            <= 9;
								   explosive_time_cnt <= explosive_time_cnt + 33'd1;
							   end						  
						  end else if(explosive_en_reg[10])begin
						      if(explosive_time_cnt == (EXPLOSIVE_TIME<<explosive_time_reg))begin//explosion over
								   explosive_status[10]  <= 1'b1;//set status bit
						         explosive_en_reg[10]  <= 1'b0;//clear en reggiter
									explosive_time_cnt   <= 33'd0;
									state                <= #`D IDLE;//return to idle,wait EXPLOSION_GUARDING_TIME for next explosion
								end else begin
								   channel            <= 10;
								   explosive_time_cnt <= explosive_time_cnt + 33'd1;
							   end						  
						  end else if(explosive_en_reg[11])begin
						      if(explosive_time_cnt == (EXPLOSIVE_TIME<<explosive_time_reg))begin//explosion over
								   explosive_status[11]  <= 1'b1;//set status bit
						         explosive_en_reg[11]  <= 1'b0;//clear en reggiter
									explosive_time_cnt   <= 33'd0;
									state                <= #`D IDLE;//return to idle,wait EXPLOSION_GUARDING_TIME for next explosion
								end else begin
								   channel            <= 11;
								   explosive_time_cnt <= explosive_time_cnt + 33'd1;
							   end						  
						  end else if(explosive_en_reg[12])begin
						      if(explosive_time_cnt == (EXPLOSIVE_TIME<<explosive_time_reg))begin//explosion over
								   explosive_status[12]  <= 1'b1;//set status bit
						         explosive_en_reg[12]  <= 1'b0;//clear en reggiter
									explosive_time_cnt   <= 33'd0;
									state                <= #`D IDLE;//return to idle,wait EXPLOSION_GUARDING_TIME for next explosion
								end else begin
								   channel            <= 12;
								   explosive_time_cnt <= explosive_time_cnt + 33'd1;
							   end						  
						  end else if(explosive_en_reg[13])begin
						      if(explosive_time_cnt == (EXPLOSIVE_TIME<<explosive_time_reg))begin//explosion over
								   explosive_status[13]  <= 1'b1;//set status bit
						         explosive_en_reg[13]  <= 1'b0;//clear en reggiter
									explosive_time_cnt   <= 33'd0;
									state                <= #`D IDLE;//return to idle,wait EXPLOSION_GUARDING_TIME for next explosion
								end else begin
								   channel            <= 13;
								   explosive_time_cnt <= explosive_time_cnt + 33'd1;
							   end						  
						  end else if(explosive_en_reg[14])begin
						      if(explosive_time_cnt == (EXPLOSIVE_TIME<<explosive_time_reg))begin//explosion over
								   explosive_status[14]  <= 1'b1;//set status bit
						         explosive_en_reg[14]  <= 1'b0;//clear en reggiter
									explosive_time_cnt   <= 33'd0;
									state                <= #`D IDLE;//return to idle,wait EXPLOSION_GUARDING_TIME for next explosion
								end else begin
								   channel            <= 14;
								   explosive_time_cnt <= explosive_time_cnt + 33'd1;
							   end						  
						  end else if(explosive_en_reg[15])begin
						      if(explosive_time_cnt == (EXPLOSIVE_TIME<<explosive_time_reg))begin//explosion over
								   explosive_status[15]  <= 1'b1;//set status bit
						         explosive_en_reg[15]  <= 1'b0;//clear en reggiter
									explosive_time_cnt   <= 33'd0;
									state                <= #`D IDLE;//return to idle,wait EXPLOSION_GUARDING_TIME for next explosion
								end else begin
								   channel            <= 15;
								   explosive_time_cnt <= explosive_time_cnt + 33'd1;
							   end						  
						  end else if(explosive_en_reg[16])begin
						      if(explosive_time_cnt == (EXPLOSIVE_TIME<<explosive_time_reg))begin//explosion over
								   explosive_status[16]  <= 1'b1;//set status bit
						         explosive_en_reg[16]  <= 1'b0;//clear en reggiter
									explosive_time_cnt   <= 33'd0;
									state                <= #`D IDLE;//return to idle,wait EXPLOSION_GUARDING_TIME for next explosion
								end else begin
								   channel            <= 16;
								   explosive_time_cnt <= explosive_time_cnt + 33'd1;
							   end						  
						  end else if(explosive_en_reg[17])begin
						      if(explosive_time_cnt == (EXPLOSIVE_TIME<<explosive_time_reg))begin//explosion over
								   explosive_status[17]  <= 1'b1;//set status bit
						         explosive_en_reg[17]  <= 1'b0;//clear en reggiter
									explosive_time_cnt   <= 33'd0;
									state                <= #`D IDLE;//return to idle,wait EXPLOSION_GUARDING_TIME for next explosion
								end else begin
								   channel            <= 17;
								   explosive_time_cnt <= explosive_time_cnt + 33'd1;
							   end						  
						  end else if(explosive_en_reg[18])begin
						      if(explosive_time_cnt == (EXPLOSIVE_TIME<<explosive_time_reg))begin//explosion over
								   explosive_status[18]  <= 1'b1;//set status bit
						         explosive_en_reg[18]  <= 1'b0;//clear en reggiter
									explosive_time_cnt   <= 33'd0;
									state                <= #`D IDLE;//return to idle,wait EXPLOSION_GUARDING_TIME for next explosion
								end else begin
								   channel            <= 18;
								   explosive_time_cnt <= explosive_time_cnt + 33'd1;
							   end						  
						  end else if(explosive_en_reg[19])begin
						      if(explosive_time_cnt == (EXPLOSIVE_TIME<<explosive_time_reg))begin//explosion over
								   explosive_status[19]  <= 1'b1;//set status bit
						         explosive_en_reg[19]  <= 1'b0;//clear en reggiter
									explosive_time_cnt   <= 33'd0;
									state                <= #`D IDLE;//return to idle,wait EXPLOSION_GUARDING_TIME for next explosion
								end else begin
								   channel            <= 19;
								   explosive_time_cnt <= explosive_time_cnt + 33'd1;
							   end						  
						  end 		 
		           end
		 default  :state <= #`D IDLE;
		 
       endcase
   end	
//-------------------------------------------------------------------------------------------------------------
reg [31:0]pre_time_out_cnt;
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
		 pre_pwr_on     <= #`D 0;  
		 pre_pwr_on_1   <= #`D 0;  
 
	    err_reg          <= #`D 0;  
       pre_time_out_cnt   <= #`D 0;		 
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
							 pre_pwr_on     <= #`D 0;  
							 pre_pwr_on_1   <= #`D 0;  
							 pre_time_out_cnt   <= #`D 0;
		 end else if((channel>=0)&&(channel<16))begin
		 				  cd4555_d       <= #`D 0;         
						  cd4555_en_n    <= #`D 1;  //disable decoder for channel 17-20    
						  cd4555_d_1     <= #`D 0; 
						  cd4555_en_n_1  <= #`D 1;
		              cd4514_d       <= channel[3:0]; 
						  cd4514_d_1     <= channel[3:0];
						  cd4514_en_n_1  <= #`D 0; //enable decoder for channel 1-16
						  cd4514_en_n    <= #`D 0; //enable decoder for channel 1-16
						  pre_pwr_on     <= #`D 1; //enable power 
		              pre_pwr_on_1   <= #`D 1; 
						  if(pre_pwr_on_ack==0)begin //power enable success
						     cd4514_strobe   <= #`D 1; //enable explosion
							  cd4514_strobe_1 <= #`D 1;
                    end else begin
						     if(pre_time_out_cnt == PRE_GUARDING_TIME)
							     err_reg <= 8'h01;
							  else
							    pre_time_out_cnt <=pre_time_out_cnt + 32'd1;
						  end                    						  
						  
		end else if((channel>=16)&&(channel<20))begin
		 				  cd4555_d       <= channel[1:0];          
						  cd4555_d_1     <= channel[1:0];        
		              cd4514_d       <= 4'd0; 
						  cd4514_d_1     <= 4'd0;
						  cd4514_en_n_1  <= #`D 1; //disable decoder for channel 1-16
						  cd4514_en_n    <= #`D 1; //disable decoder for channel 1-16
						  pre_pwr_on     <= #`D 1; //enable power 
		              pre_pwr_on_1   <= #`D 1; 
						  if(pre_pwr_on_ack==0)begin //power enable success
						     cd4555_en_n_1  <= #`D 0;	//enable explosion
							  cd4555_en_n    <= #`D 0; 					  
						  end else begin
						     if(pre_time_out_cnt == PRE_GUARDING_TIME)begin
							     err_reg <= err_reg + 8'd1;
								  pre_time_out_cnt <=32'd0;
							  end else
							    pre_time_out_cnt <=pre_time_out_cnt + 32'd1;
						  end                    						  		
		end
		
	end
//-------------------------------------------------------------------------------------------------------------




endmodule