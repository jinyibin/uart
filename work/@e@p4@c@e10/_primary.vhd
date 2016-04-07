library verilog;
use verilog.vl_types.all;
entity EP4CE10 is
    generic(
        RST_CNT_LIMIT   : integer := 100;
        UART_CLK_DIVIDER: vl_logic_vector(0 to 7) := (Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi1, Hi0)
    );
    port(
        clkin           : in     vl_logic;
        led             : out    vl_logic;
        rs422_de_main   : out    vl_logic;
        rs422_re_n_main : out    vl_logic;
        rs422_di_main   : out    vl_logic;
        rs422_ro_main   : in     vl_logic;
        cd4514_d        : out    vl_logic_vector(3 downto 0);
        cd4514_strobe   : out    vl_logic;
        cd4514_en_n     : out    vl_logic;
        cd4514_d_1      : out    vl_logic_vector(3 downto 0);
        cd4514_strobe_1 : out    vl_logic;
        cd4514_en_n_1   : out    vl_logic;
        cd4555_d        : out    vl_logic_vector(1 downto 0);
        cd4555_en_n     : out    vl_logic;
        cd4555_d_1      : out    vl_logic_vector(1 downto 0);
        cd4555_en_n_1   : out    vl_logic;
        pre_pwr_on      : out    vl_logic;
        pre_pwr_on_1    : out    vl_logic;
        pre_pwr_on_ack  : in     vl_logic;
        camera_rst      : out    vl_logic_vector(4 downto 0);
        camera_pwr_en   : out    vl_logic_vector(4 downto 0);
        sensor_pwr_en   : out    vl_logic;
        motor_pwr_en    : out    vl_logic;
        txd_to_stm32    : out    vl_logic;
        rxd_from_stm32  : in     vl_logic
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of RST_CNT_LIMIT : constant is 1;
    attribute mti_svvh_generic_type of UART_CLK_DIVIDER : constant is 1;
end EP4CE10;
