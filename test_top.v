`timescale 1ns/1ps

module test_top;

  reg clk;
  reg rst_n;
  wire       rs422_de_main;  
  wire       rs422_re_n_main;
  wire       rs422_di_main; 
  reg        rs422_ro_main;
  
//-------------------------------------------------------------------------------
   parameter  CLK_HALF_PERIOD = 31.25;
   parameter  UART_CLK_PERIOD = 1000;//1Mhz

	  
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
       uart_tx(8'hAA);
       uart_tx(8'h55);
       uart_tx(8'h1);
       uart_tx(8'h2);
       uart_tx(8'h3);
       uart_tx(8'h4);
       uart_tx(8'h5);
       uart_tx(8'h2);
       uart_tx(8'hEF);
       uart_tx(8'h8);
              uart_tx(8'hAA);
       uart_tx(8'h55);
       uart_tx(8'h1);
       uart_tx(8'h2);
       uart_tx(8'h3);
       uart_tx(8'h4);
       uart_tx(8'h5);
       uart_tx(8'h1);
       uart_tx(8'hEF);
              uart_tx(8'h8);
              uart_tx(8'hAA);
       uart_tx(8'h55);
       uart_tx(8'h1);
       uart_tx(8'h2);
       uart_tx(8'h3);
       uart_tx(8'h4);
       uart_tx(8'h5);
       uart_tx(8'h1);
       uart_tx(8'hF);
              uart_tx(8'h8);
              uart_tx(8'hAA);
       uart_tx(8'h55);
       uart_tx(8'h1);
       uart_tx(8'h2);
       uart_tx(8'h3);
       #100000;
              uart_tx(8'hAA);
       uart_tx(8'h55);
       uart_tx(8'h1);
       uart_tx(8'h2);
       uart_tx(8'h3);
       uart_tx(8'h4);
       uart_tx(8'h5);
       uart_tx(8'h1);
       uart_tx(8'hEF);

	    
     #300000 $stop;

end    
  always #CLK_HALF_PERIOD clk=~clk;


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
		rs422_ro_main = data[7];
		#UART_CLK_PERIOD ; 
		rs422_ro_main = data[6]; 
		#UART_CLK_PERIOD ; 
		rs422_ro_main = data[5]; 
		#UART_CLK_PERIOD ; 
		rs422_ro_main = data[4]; 
		#UART_CLK_PERIOD ; 
		rs422_ro_main = data[3]; 
		#UART_CLK_PERIOD ; 
		rs422_ro_main = data[2]; 
		#UART_CLK_PERIOD ; 
		rs422_ro_main = data[1]; 
		#UART_CLK_PERIOD ; 
		rs422_ro_main = data[0]; 
		#UART_CLK_PERIOD ;
	  rs422_ro_main = 1; 
	  #UART_CLK_PERIOD ;        

		
	end	 
endtask
 

//------------------------------------------------------------------------------- 

//-------------------------------------------------------------------------


top top(  
            
                                 
   .rs422_de_main(rs422_de_main),                    
   .rs422_re_n_main(rs422_re_n_main),                  
   .rs422_di_main(rs422_di_main),          
   .rs422_ro_main(rs422_ro_main), 
                                 
   .clk_in(clk),              
   .rst_in_n(rst_n)                     
	);
	
	endmodule