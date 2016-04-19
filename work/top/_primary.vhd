library verilog;
use verilog.vl_types.all;
entity top is
    generic(
        RST_CNT_LIMIT   : integer := 100;
        UART_CLK_DIVIDER: vl_logic_vector(0 to 7) := (Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi1, Hi0)
    );
    port(
        rs422_de_main   : out    vl_logic;
        rs422_re_n_main : out    vl_logic;
        rs422_di_main   : out    vl_logic;
        rs422_ro_main   : in     vl_logic;
        clk_in          : in     vl_logic;
        rst_in_n        : in     vl_logic
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of RST_CNT_LIMIT : constant is 1;
    attribute mti_svvh_generic_type of UART_CLK_DIVIDER : constant is 1;
end top;
