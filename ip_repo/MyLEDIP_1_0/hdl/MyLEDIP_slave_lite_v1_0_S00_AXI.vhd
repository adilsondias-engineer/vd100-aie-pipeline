library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity MyLEDIP is
    generic (
        C_S_AXI_DATA_WIDTH : integer := 32;
        C_S_AXI_ADDR_WIDTH : integer := 4
    );
    port (
        -- Keep exact same port names as original
        s00_axi_aclk    : in  std_logic;
        s00_axi_aresetn : in  std_logic;
        s00_axi_awaddr  : in  std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
        s00_axi_awprot  : in  std_logic_vector(2 downto 0);
        s00_axi_awvalid : in  std_logic;
        s00_axi_awready : out std_logic;
        s00_axi_wdata   : in  std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
        s00_axi_wstrb   : in  std_logic_vector((C_S_AXI_DATA_WIDTH/8)-1 downto 0);
        s00_axi_wvalid  : in  std_logic;
        s00_axi_wready  : out std_logic;
        s00_axi_bresp   : out std_logic_vector(1 downto 0);
        s00_axi_bvalid  : out std_logic;
        s00_axi_bready  : in  std_logic;
        s00_axi_araddr  : in  std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
        s00_axi_arprot  : in  std_logic_vector(2 downto 0);
        s00_axi_arvalid : in  std_logic;
        s00_axi_arready : out std_logic;
        s00_axi_rdata   : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
        s00_axi_rresp   : out std_logic_vector(1 downto 0);
        s00_axi_rvalid  : out std_logic;
        s00_axi_rready  : in  std_logic;
        pl_led          : out std_logic
    );
end MyLEDIP;

architecture arch_imp of MyLEDIP is

    signal axi_awaddr  : std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
    signal axi_awready : std_logic;
    signal axi_wready  : std_logic;
    signal axi_bresp   : std_logic_vector(1 downto 0);
    signal axi_bvalid  : std_logic;
    signal axi_araddr  : std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
    signal axi_arready : std_logic;
    signal axi_rresp   : std_logic_vector(1 downto 0);
    signal axi_rvalid  : std_logic;

    constant ADDR_LSB          : integer := (C_S_AXI_DATA_WIDTH/32) + 1;
    constant OPT_MEM_ADDR_BITS : integer := 1;

    signal slv_reg0 : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    signal slv_reg1 : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    signal slv_reg2 : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    signal slv_reg3 : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    signal byte_index : integer;
    signal mem_logic  : std_logic_vector(ADDR_LSB + OPT_MEM_ADDR_BITS downto ADDR_LSB);

    constant Idle  : std_logic_vector(1 downto 0) := "00";
    constant Raddr : std_logic_vector(1 downto 0) := "10";
    constant Rdata : std_logic_vector(1 downto 0) := "11";
    constant Waddr : std_logic_vector(1 downto 0) := "10";
    constant Wdata : std_logic_vector(1 downto 0) := "11";

    signal state_read  : std_logic_vector(1 downto 0);
    signal state_write : std_logic_vector(1 downto 0);

begin
    -- I/O assignments
    s00_axi_awready <= axi_awready;
    s00_axi_wready  <= axi_wready;
    s00_axi_bresp   <= axi_bresp;
    s00_axi_bvalid  <= axi_bvalid;
    s00_axi_arready <= axi_arready;
    s00_axi_rresp   <= axi_rresp;
    s00_axi_rvalid  <= axi_rvalid;

    mem_logic <= s00_axi_awaddr(ADDR_LSB + OPT_MEM_ADDR_BITS downto ADDR_LSB)
                 when (s00_axi_awvalid = '1')
                 else axi_awaddr(ADDR_LSB + OPT_MEM_ADDR_BITS downto ADDR_LSB);

    -- Write state machine (from Vivado template)
    process (s00_axi_aclk)
    begin
        if rising_edge(s00_axi_aclk) then
            if s00_axi_aresetn = '0' then
                axi_awready   <= '0';
                axi_wready    <= '0';
                axi_bvalid    <= '0';
                axi_bresp     <= (others => '0');
                state_write   <= Idle;
            else
                case (state_write) is
                    when Idle =>
                        if s00_axi_aresetn = '1' then
                            axi_awready <= '1';
                            axi_wready  <= '0';
                            state_write <= Waddr;
                        end if;
                    when Waddr =>
                        axi_wready <= '0';
                        if s00_axi_awvalid = '1' and axi_awready = '1' then
                            axi_awready <= '0';
                            axi_wready  <= '1';
                            axi_awaddr  <= s00_axi_awaddr;
                            state_write <= Wdata;
                        else
                            state_write <= state_write;
                            if s00_axi_bready = '1' and axi_bvalid = '1' then
                                axi_bvalid <= '0';
                            end if;
                        end if;
                    when Wdata =>
                        if s00_axi_wvalid = '1' then
                            state_write <= Waddr;
                            axi_bvalid  <= '1';
                            axi_awready <= '1';
                            axi_wready  <= '0'; 
                        else
                            state_write <= state_write;
                            if s00_axi_bready = '1' and axi_bvalid = '1' then
                                axi_bvalid <= '0';
                            end if;
                        end if;
                    when others =>
                        axi_awready <= '0';
                        axi_wready  <= '0';
                        axi_bvalid  <= '0';
                end case;
            end if;
        end if;
    end process;

    -- Write data registers
    process (s00_axi_aclk)
    begin
        if rising_edge(s00_axi_aclk) then
            if s00_axi_aresetn = '0' then
                slv_reg0 <= (others => '0');
                slv_reg1 <= (others => '0');
                slv_reg2 <= (others => '0');
                slv_reg3 <= (others => '0');
            else
                if s00_axi_wvalid = '1' then
                    case (mem_logic) is
                        when b"00" =>
                            for byte_index in 0 to (C_S_AXI_DATA_WIDTH/8-1) loop
                                if s00_axi_wstrb(byte_index) = '1' then
                                    slv_reg0(byte_index*8+7 downto byte_index*8) <=
                                        s00_axi_wdata(byte_index*8+7 downto byte_index*8);
                                end if;
                            end loop;
                        when b"01" =>
                            for byte_index in 0 to (C_S_AXI_DATA_WIDTH/8-1) loop
                                if s00_axi_wstrb(byte_index) = '1' then
                                    slv_reg1(byte_index*8+7 downto byte_index*8) <=
                                        s00_axi_wdata(byte_index*8+7 downto byte_index*8);
                                end if;
                            end loop;
                        when b"10" =>
                            for byte_index in 0 to (C_S_AXI_DATA_WIDTH/8-1) loop
                                if s00_axi_wstrb(byte_index) = '1' then
                                    slv_reg2(byte_index*8+7 downto byte_index*8) <=
                                        s00_axi_wdata(byte_index*8+7 downto byte_index*8);
                                end if;
                            end loop;
                        when b"11" =>
                            for byte_index in 0 to (C_S_AXI_DATA_WIDTH/8-1) loop
                                if s00_axi_wstrb(byte_index) = '1' then
                                    slv_reg3(byte_index*8+7 downto byte_index*8) <=
                                        s00_axi_wdata(byte_index*8+7 downto byte_index*8);
                                end if;
                            end loop;
                        when others =>
                            slv_reg0 <= slv_reg0;
                            slv_reg1 <= slv_reg1;
                            slv_reg2 <= slv_reg2;
                            slv_reg3 <= slv_reg3;
                    end case;
                end if;
                
                -- Mirror reg0 to reg1 every clock cycle
                slv_reg1 <= slv_reg0;
            end if;
        end if;
    end process;

    -- Read state machine (from Vivado template)
    process (s00_axi_aclk)
    begin
        if rising_edge(s00_axi_aclk) then
            if s00_axi_aresetn = '0' then
                axi_arready <= '0';
                axi_rvalid  <= '0';
                axi_rresp   <= (others => '0');
                state_read  <= Idle;
            else
                case (state_read) is
                    when Idle =>
                        if s00_axi_aresetn = '1' then
                            axi_arready <= '1';
                            state_read  <= Raddr;
                        end if;
                    when Raddr =>
                        if s00_axi_arvalid = '1' and axi_arready = '1' then
                            state_read  <= Rdata;
                            axi_rvalid  <= '1';
                            axi_arready <= '0';
                            axi_araddr  <= s00_axi_araddr;
                        else
                            state_read <= state_read;
                        end if;
                    when Rdata =>
                        if axi_rvalid = '1' and s00_axi_rready = '1' then
                            axi_rvalid  <= '0';
                            axi_arready <= '1';
                            state_read  <= Raddr;
                        else
                            state_read <= state_read;
                        end if;
                    when others =>
                        axi_arready <= '0';
                        axi_rvalid  <= '0';
                end case;
            end if;
        end if;
    end process;

    -- Read data mux
    s00_axi_rdata <=
        slv_reg0 when axi_araddr(ADDR_LSB+OPT_MEM_ADDR_BITS downto ADDR_LSB) = "00" else
        slv_reg1 when axi_araddr(ADDR_LSB+OPT_MEM_ADDR_BITS downto ADDR_LSB) = "01" else
        slv_reg2 when axi_araddr(ADDR_LSB+OPT_MEM_ADDR_BITS downto ADDR_LSB) = "10" else
        slv_reg3 when axi_araddr(ADDR_LSB+OPT_MEM_ADDR_BITS downto ADDR_LSB) = "11" else
        (others => '0');

    -- LED output - slv_reg0 bit 0 slv_reg1 bit 4 current state
    pl_led <= slv_reg0(0);

end arch_imp;