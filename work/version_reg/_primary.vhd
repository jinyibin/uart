library verilog;
use verilog.vl_types.all;
entity version_reg is
    port(
        clock           : in     vl_logic;
        reset           : in     vl_logic;
        data_out        : out    vl_logic_vector(31 downto 0)
    );
end version_reg;
