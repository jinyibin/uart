library verilog;
use verilog.vl_types.all;
entity uart_transceiver is
    generic(
        UART_BAUDRATE   : integer := 216;
        UART_BAUDRATE_HALF: integer := 107;
        TX_UART_BAUDRATE: integer := 433;
        IDLE            : integer := 0;
        START           : integer := 1;
        DATA            : integer := 2;
        STOP            : integer := 3
    );
    port(
        uart_rx_data    : out    vl_logic_vector(7 downto 0);
        uart_rx_data_ready: out    vl_logic;
        uart_rx_err     : out    vl_logic;
        uart_tx_status  : out    vl_logic;
        uart_tx_over    : out    vl_logic;
        uart_tx_data    : in     vl_logic_vector(7 downto 0);
        uart_tx_data_ready: in     vl_logic;
        uart_chip_de    : out    vl_logic;
        uart_chip_re_n  : out    vl_logic;
        uart_chip_di    : out    vl_logic;
        uart_chip_ro    : in     vl_logic;
        clk             : in     vl_logic;
        uart_clk        : in     vl_logic;
        rst_n           : in     vl_logic
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of UART_BAUDRATE : constant is 1;
    attribute mti_svvh_generic_type of UART_BAUDRATE_HALF : constant is 1;
    attribute mti_svvh_generic_type of TX_UART_BAUDRATE : constant is 1;
    attribute mti_svvh_generic_type of IDLE : constant is 1;
    attribute mti_svvh_generic_type of START : constant is 1;
    attribute mti_svvh_generic_type of DATA : constant is 1;
    attribute mti_svvh_generic_type of STOP : constant is 1;
end uart_transceiver;
