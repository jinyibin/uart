library verilog;
use verilog.vl_types.all;
entity command_rw_main is
    generic(
        FRAME_HEAD1     : vl_logic_vector(0 to 7) := (Hi1, Hi0, Hi1, Hi0, Hi1, Hi0, Hi1, Hi0);
        FRAME_HEAD2     : vl_logic_vector(0 to 7) := (Hi0, Hi1, Hi0, Hi1, Hi0, Hi1, Hi0, Hi1);
        FRAME_END       : vl_logic_vector(0 to 7) := (Hi1, Hi1, Hi1, Hi0, Hi1, Hi1, Hi1, Hi1);
        IDLE            : integer := 0;
        HEAD1           : integer := 1;
        HEAD2           : integer := 2;
        COMMAND         : integer := 3;
        BYTE1           : integer := 4;
        BYTE2           : integer := 5;
        BYTE3           : integer := 6;
        BYTE4           : integer := 7;
        PARITY          : integer := 8;
        \END\           : integer := 9;
        RX_TIME_OUT_PROTECTION: integer := 100000;
        TX_GUARDING_TIME: integer := 50000000
    );
    port(
        uart_chip_de    : out    vl_logic;
        uart_chip_re_n  : out    vl_logic;
        uart_chip_di    : out    vl_logic;
        uart_chip_ro    : in     vl_logic;
        command_rx_ready: out    vl_logic;
        command_rx      : out    vl_logic_vector(7 downto 0);
        data_field_rx   : out    vl_logic_vector(31 downto 0);
        command_tx_over : out    vl_logic;
        command_tx_status: out    vl_logic;
        command_tx_ready: in     vl_logic;
        command_tx      : in     vl_logic_vector(7 downto 0);
        data_field_tx   : in     vl_logic_vector(31 downto 0);
        uart_clk        : in     vl_logic;
        version         : in     vl_logic_vector(31 downto 0);
        clk             : in     vl_logic;
        rst_n           : in     vl_logic
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of FRAME_HEAD1 : constant is 1;
    attribute mti_svvh_generic_type of FRAME_HEAD2 : constant is 1;
    attribute mti_svvh_generic_type of FRAME_END : constant is 1;
    attribute mti_svvh_generic_type of IDLE : constant is 1;
    attribute mti_svvh_generic_type of HEAD1 : constant is 1;
    attribute mti_svvh_generic_type of HEAD2 : constant is 1;
    attribute mti_svvh_generic_type of COMMAND : constant is 1;
    attribute mti_svvh_generic_type of BYTE1 : constant is 1;
    attribute mti_svvh_generic_type of BYTE2 : constant is 1;
    attribute mti_svvh_generic_type of BYTE3 : constant is 1;
    attribute mti_svvh_generic_type of BYTE4 : constant is 1;
    attribute mti_svvh_generic_type of PARITY : constant is 1;
    attribute mti_svvh_generic_type of \END\ : constant is 1;
    attribute mti_svvh_generic_type of RX_TIME_OUT_PROTECTION : constant is 1;
    attribute mti_svvh_generic_type of TX_GUARDING_TIME : constant is 1;
end command_rw_main;
