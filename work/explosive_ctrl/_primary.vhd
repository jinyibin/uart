library verilog;
use verilog.vl_types.all;
entity explosive_ctrl is
    generic(
        PRE_GUARDING_TIME: integer := 50000;
        EXPLOSION_GUARDING_TIME: integer := 50000;
        COMMAND_TYPE_EXPLODE: vl_logic_vector(0 to 7) := (Hi0, Hi0, Hi0, Hi0, Hi0, Hi1, Hi0, Hi1);
        IDLE            : integer := 1;
        EXPLOSION       : integer := 2;
        EXPLOSIVE_TIME  : integer := 50000
    );
    port(
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
        command_ready   : in     vl_logic;
        command_type    : in     vl_logic_vector(7 downto 0);
        command_parameter: in     vl_logic_vector(31 downto 0);
        explosive_status: out    vl_logic_vector(31 downto 0);
        err_reg         : out    vl_logic_vector(7 downto 0);
        clk             : in     vl_logic;
        rst_n           : in     vl_logic
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of PRE_GUARDING_TIME : constant is 1;
    attribute mti_svvh_generic_type of EXPLOSION_GUARDING_TIME : constant is 1;
    attribute mti_svvh_generic_type of COMMAND_TYPE_EXPLODE : constant is 1;
    attribute mti_svvh_generic_type of IDLE : constant is 1;
    attribute mti_svvh_generic_type of EXPLOSION : constant is 1;
    attribute mti_svvh_generic_type of EXPLOSIVE_TIME : constant is 1;
end explosive_ctrl;
