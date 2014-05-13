library verilog;
use verilog.vl_types.all;
entity RAM_searcher is
    port(
        clk             : in     vl_logic;
        rst             : in     vl_logic;
        req             : in     vl_logic_vector(1 downto 0);
        reply           : out    vl_logic_vector(7 downto 0);
        id_in           : in     vl_logic_vector(7 downto 0);
        src_ip          : in     vl_logic_vector(31 downto 0);
        dst_ip          : in     vl_logic_vector(31 downto 0);
        src_mac         : in     vl_logic_vector(23 downto 0);
        dst_mac         : in     vl_logic_vector(23 downto 0);
        src_port        : in     vl_logic_vector(15 downto 0);
        dst_port        : in     vl_logic_vector(15 downto 0)
    );
end RAM_searcher;
