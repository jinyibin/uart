library verilog;
use verilog.vl_types.all;
entity test_top is
    generic(
        CLK_HALF_PERIOD : integer := 10;
        UART_CLK_PERIOD : integer := 8681;
        FRAME_HEAD1     : vl_logic_vector(0 to 7) := (Hi1, Hi0, Hi1, Hi0, Hi1, Hi0, Hi1, Hi0);
        FRAME_HEAD2     : vl_logic_vector(0 to 7) := (Hi0, Hi1, Hi0, Hi1, Hi0, Hi1, Hi0, Hi1);
        FRAME_HEAD3     : vl_logic_vector(0 to 7) := (Hi1, Hi1, Hi1, Hi0, Hi1, Hi0, Hi1, Hi1);
        FRAME_HEAD4     : vl_logic_vector(0 to 7) := (Hi1, Hi0, Hi0, Hi1, Hi0, Hi0, Hi0, Hi0);
        FRAME_HEAD5     : vl_logic_vector(0 to 7) := (Hi0, Hi0, Hi0, Hi1, Hi1, Hi1, Hi0, Hi1);
        FRAME_HEAD6     : vl_logic_vector(0 to 7) := (Hi0, Hi0, Hi0, Hi1, Hi1, Hi0, Hi1, Hi1)
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of CLK_HALF_PERIOD : constant is 1;
    attribute mti_svvh_generic_type of UART_CLK_PERIOD : constant is 1;
    attribute mti_svvh_generic_type of FRAME_HEAD1 : constant is 1;
    attribute mti_svvh_generic_type of FRAME_HEAD2 : constant is 1;
    attribute mti_svvh_generic_type of FRAME_HEAD3 : constant is 1;
    attribute mti_svvh_generic_type of FRAME_HEAD4 : constant is 1;
    attribute mti_svvh_generic_type of FRAME_HEAD5 : constant is 1;
    attribute mti_svvh_generic_type of FRAME_HEAD6 : constant is 1;
end test_top;
