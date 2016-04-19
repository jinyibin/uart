library verilog;
use verilog.vl_types.all;
entity crc_16 is
    generic(
        POLY            : vl_logic_vector(0 to 15) := (Hi1, Hi0, Hi1, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi1)
    );
    port(
        clk             : in     vl_logic;
        rst_n           : in     vl_logic;
        crc_en          : in     vl_logic;
        data_in         : in     vl_logic_vector(7 downto 0);
        crc_reg         : out    vl_logic_vector(15 downto 0);
        crc_ready       : out    vl_logic
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of POLY : constant is 1;
end crc_16;
