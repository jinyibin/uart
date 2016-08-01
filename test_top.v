`timescale 1ns/1ps

module test_top;

  reg clk;
  reg rst_n;
  wire       rs422_de_main;  
  wire       rs422_re_n_main;
  wire       rs422_di_main; 
  reg        rs422_ro_main;
  
  
	wire       led;    //ledtest
	
	
	wire[3:0] cd4514_d;        //4-16 decoder input
	 wire      cd4514_strobe;   //high level enable the 4-16 decoder to latch the input 
	wire      cd4514_en_n;     //low level enable 4-16 decoder
	wire[3:0] cd4514_d_1;      //4-16 decoder back up control
   wire      cd4514_strobe_1;
	wire      cd4514_en_n_1;
	
	wire[1:0] cd4555_d;        //2-4 decoder input
	wire      cd4555_en_n;     //2-4 decoder enable,low level active
	
	wire[1:0] cd4555_d_1;      //2-4 decoder back up control
	wire      cd4555_en_n_1;
	
	 wire      pre_pwr_on;
	 wire      pre_pwr_on_1;
	reg      pre_pwr_on_ack;  //low level signifies pre power open
	
	wire [4:0] camera_rst;
	wire [4:0] camera_pwr_en;
	wire       sensor_pwr_en;
	wire       motor_pwr_en;
	
	 wire      txd_to_stm32;
     wire      rxd_from_stm32;	
  
//-------------------------------------------------------------------------------
   parameter  CLK_HALF_PERIOD = 10;
   parameter  UART_CLK_PERIOD = 8681;//115200
parameter 	FRAME_HEAD1 = 8'hAA,
            FRAME_HEAD2 = 8'h55,
				FRAME_HEAD3 = 8'hEB,
            FRAME_HEAD4 = 8'h90,
				FRAME_HEAD5 = 8'h1D,
            FRAME_HEAD6 = 8'h1B;
	  
//----------------------------------------------------------------------- 
  initial
    begin
     clk=0;
     rst_n=0;
     
     #10000 rst_n= 1;
     rs422_ro_main=1'b1;
	 
	 
     #10000;
	 
   
	   uart_tx(8'h1);
       uart_tx(8'h2);

       uart_tx(FRAME_HEAD1);
       uart_tx(FRAME_HEAD2);
       uart_tx(FRAME_HEAD3);
       uart_tx(FRAME_HEAD4);
       uart_tx(FRAME_HEAD5);
       uart_tx(FRAME_HEAD6);      
       uart_tx(8'h0); 
       uart_tx(8'h01);
       uart_tx(8'h0);
       uart_tx(8'h0);
       uart_tx(8'h10);
       uart_tx(8'h0);
       uart_tx(8'h0);
       uart_tx(8'h0);
       uart_tx(8'h0B);
       uart_tx(8'h54);
       uart_tx(8'h8);
       
       uart_tx(FRAME_HEAD1);
       uart_tx(FRAME_HEAD2);
       uart_tx(FRAME_HEAD3);
       uart_tx(FRAME_HEAD4);
       uart_tx(FRAME_HEAD5);
       uart_tx(FRAME_HEAD6);  
       uart_tx(8'h0); 
       uart_tx(8'h01);
       uart_tx(8'h0);
       uart_tx(8'h0);
       uart_tx(8'h00);
       uart_tx(8'h00);
       uart_tx(8'h0);
       uart_tx(8'h0);
       uart_tx(8'hcb);
       uart_tx(8'h50);
       
              uart_tx(8'h8);
       uart_tx(FRAME_HEAD1);
       uart_tx(FRAME_HEAD2);
       uart_tx(FRAME_HEAD3);
       uart_tx(FRAME_HEAD4);
       uart_tx(FRAME_HEAD5);
       uart_tx(FRAME_HEAD6); 
       uart_tx(8'h0); 
       uart_tx(8'h01);
       uart_tx(8'h2);
       uart_tx(8'h0);
       uart_tx(8'h10);
       uart_tx(8'h00);
       uart_tx(8'h0);
       uart_tx(8'h0);
       uart_tx(8'he9);
       uart_tx(8'h55);
       
              uart_tx(8'h8);
              
       uart_tx(FRAME_HEAD1);
       uart_tx(FRAME_HEAD2);
       uart_tx(FRAME_HEAD3);
       uart_tx(FRAME_HEAD4);
       uart_tx(FRAME_HEAD5);
       uart_tx(FRAME_HEAD6); 
       uart_tx(8'h0); 
       uart_tx(8'h01);
       uart_tx(8'h00);
       uart_tx(8'h00);
       uart_tx(8'h10);
       uart_tx(8'h1f);
       uart_tx(8'h0);
       uart_tx(8'h0);
       uart_tx(8'hcd);
       uart_tx(8'h65);
       #10000;
       uart_tx(FRAME_HEAD1);
       uart_tx(FRAME_HEAD2);
       uart_tx(FRAME_HEAD3);
       uart_tx(FRAME_HEAD4);
       uart_tx(FRAME_HEAD5);
       uart_tx(FRAME_HEAD6); 
       uart_tx(8'h0); 
       uart_tx(8'h01);
       uart_tx(8'h00);
       uart_tx(8'h00);
       uart_tx(8'h00);
       uart_tx(8'h0);
       uart_tx(8'h0);
       uart_tx(8'h00);
       uart_tx(8'hcb);
       uart_tx(8'h50);
       
       uart_tx(FRAME_HEAD1);
       uart_tx(FRAME_HEAD2);
       uart_tx(FRAME_HEAD3);
       uart_tx(FRAME_HEAD4);
       uart_tx(FRAME_HEAD5);
       uart_tx(FRAME_HEAD6); 
       uart_tx(8'h0); 
       uart_tx(8'h01);
       uart_tx(8'h00);
       uart_tx(8'h00);
       uart_tx(8'h10);
       uart_tx(8'h0);
       uart_tx(8'h0);
       uart_tx(8'h00);
       uart_tx(8'h0b);
       uart_tx(8'h54);
       
       uart_tx(FRAME_HEAD1);
       uart_tx(FRAME_HEAD2);
       uart_tx(FRAME_HEAD3);
       uart_tx(FRAME_HEAD4);
       uart_tx(FRAME_HEAD5);
       uart_tx(FRAME_HEAD6); 
       uart_tx(8'h0); 
       uart_tx(8'h01);
       uart_tx(8'hff);
       uart_tx(8'hff);
       uart_tx(8'h1f);
       uart_tx(8'h0);
       uart_tx(8'h0);
       uart_tx(8'h0);
       uart_tx(8'h4);
       uart_tx(8'h57);
       #100000;

	    
     #1500000 $stop;

end    
  always #CLK_HALF_PERIOD clk=~clk;

always #CLK_HALF_PERIOD pre_pwr_on_ack = !pre_pwr_on;
//------------------------------------------------------------------------------- 
 
//------------------------------------------------------------------------------- 
task uart_tx;
	input [7:0] data;
	integer i;
	
	begin
	  #1000
	  rs422_ro_main = 1;
		i = 7;

		#UART_CLK_PERIOD ;
		rs422_ro_main = 0; 
		#UART_CLK_PERIOD ; 
		rs422_ro_main = data[0];
		#UART_CLK_PERIOD ; 
		rs422_ro_main = data[1]; 
		#UART_CLK_PERIOD ; 
		rs422_ro_main = data[2]; 
		#UART_CLK_PERIOD ; 
		rs422_ro_main = data[3]; 
		#UART_CLK_PERIOD ; 
		rs422_ro_main = data[4]; 
		#UART_CLK_PERIOD ; 
		rs422_ro_main = data[5]; 
		#UART_CLK_PERIOD ; 
		rs422_ro_main = data[6]; 
		#UART_CLK_PERIOD ; 
		rs422_ro_main = data[7]; 
		#UART_CLK_PERIOD ;
	  rs422_ro_main = 1; 
	  #UART_CLK_PERIOD ;        

		
	end	 
endtask
 

//------------------------------------------------------------------------------- 

//-------------------------------------------------------------------------


EP4CE10 top(  
            

	.led(led),    //ledtest
	

	
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
	.pre_pwr_on_ack(pre_pwr_on_ack),  //low level signifies pre power open
	
	.camera_rst(camera_rst),
	.camera_pwr_en(camera_pwr_en),
	.sensor_pwr_en(sensor_pwr_en),
	.motor_pwr_en(motor_pwr_en),
	
	.txd_to_stm32(txd_to_stm32),
    .rxd_from_stm32(rxd_from_stm32)	,                                
   .rs422_de_main(rs422_de_main),                    
   .rs422_re_n_main(rs422_re_n_main),                  
   .rs422_di_main(rs422_di_main),          
   .rs422_ro_main(rs422_ro_main), 
                                 
   .clkin(clk)              
                        
	);
	
	endmodule