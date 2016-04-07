library verilog;
use verilog.vl_types.all;
entity test_top is
    generic(
        CLK_HALF_PERIOD : integer := 10;
        UART_CLK_PERIOD : integer := 8681
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of CLK_HALF_PERIOD : constant is 1;
    attribute mti_svvh_generic_type of UART_CLK_PERIOD : constant is 1;
end test_top;
