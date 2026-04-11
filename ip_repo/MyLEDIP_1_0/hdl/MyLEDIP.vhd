library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity MyLEDIP is
	generic (
		-- Users to add parameters here

		-- User parameters ends
		-- Do not modify the parameters beyond this line


		-- Parameters of Axi Slave Bus Interface S00_AXI
		C_S00_AXI_DATA_WIDTH	: integer	:= 32;
		C_S00_AXI_ADDR_WIDTH	: integer	:= 4
	);
	port (
		-- Users to add ports here
       --LED Output
        pl_led : out std_logic;
		-- User ports ends
		
		-- Do not modify the ports beyond this line


		-- Ports of Axi Slave Bus Interface S00_AXI
		s00_axi_aclk	: in std_logic;
		s00_axi_aresetn	: in std_logic;
		s00_axi_awaddr	: in std_logic_vector(C_S00_AXI_ADDR_WIDTH-1 downto 0);
		s00_axi_awprot	: in std_logic_vector(2 downto 0);
		s00_axi_awvalid	: in std_logic;
		s00_axi_awready	: out std_logic;
		s00_axi_wdata	: in std_logic_vector(C_S00_AXI_DATA_WIDTH-1 downto 0);
		s00_axi_wstrb	: in std_logic_vector((C_S00_AXI_DATA_WIDTH/8)-1 downto 0);
		s00_axi_wvalid	: in std_logic;
		s00_axi_wready	: out std_logic;
		s00_axi_bresp	: out std_logic_vector(1 downto 0);
		s00_axi_bvalid	: out std_logic;
		s00_axi_bready	: in std_logic;
		s00_axi_araddr	: in std_logic_vector(C_S00_AXI_ADDR_WIDTH-1 downto 0);
		s00_axi_arprot	: in std_logic_vector(2 downto 0);
		s00_axi_arvalid	: in std_logic;
		s00_axi_arready	: out std_logic;
		s00_axi_rdata	: out std_logic_vector(C_S00_AXI_DATA_WIDTH-1 downto 0);
		s00_axi_rresp	: out std_logic_vector(1 downto 0);
		s00_axi_rvalid	: out std_logic;
		s00_axi_rready	: in std_logic
		

		
	);
end MyLEDIP;

architecture rtl of MyLEDIP is

--	-- component declaration
--	component MyLEDIP_slave_lite_v1_0_S00_AXI is
--		generic (
--		C_S_AXI_DATA_WIDTH	: integer	:= 32;
--		C_S_AXI_ADDR_WIDTH	: integer	:= 4
--		);
--		port (
--		S_AXI_ACLK	: in std_logic;
--		S_AXI_ARESETN	: in std_logic;
--		S_AXI_AWADDR	: in std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
--		S_AXI_AWPROT	: in std_logic_vector(2 downto 0);
--		S_AXI_AWVALID	: in std_logic;
--		S_AXI_AWREADY	: out std_logic;
--		S_AXI_WDATA	: in std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
--		S_AXI_WSTRB	: in std_logic_vector((C_S_AXI_DATA_WIDTH/8)-1 downto 0);
--		S_AXI_WVALID	: in std_logic;
--		S_AXI_WREADY	: out std_logic;
--		S_AXI_BRESP	: out std_logic_vector(1 downto 0);
--		S_AXI_BVALID	: out std_logic;
--		S_AXI_BREADY	: in std_logic;
--		S_AXI_ARADDR	: in std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
--		S_AXI_ARPROT	: in std_logic_vector(2 downto 0);
--		S_AXI_ARVALID	: in std_logic;
--		S_AXI_ARREADY	: out std_logic;
--		S_AXI_RDATA	: out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
--		S_AXI_RRESP	: out std_logic_vector(1 downto 0);
--		S_AXI_RVALID	: out std_logic;
--		S_AXI_RREADY	: in std_logic;
		
--		--LED Output
--        pl_led : out std_logic
        
--		);
--	end component MyLEDIP_slave_lite_v1_0_S00_AXI;

    -- Register map
    -- 0x00: LED control (bit 0 = LED on/off)
    -- 0x04: LED status (bit 0 = current state, read-only)
    
    signal led_ctrl_reg : std_logic_vector(31 downto 0) := (others => '0');
    signal led_state    : std_logic := '0';
    
    --AXI handshake signals
    signal awready_r : std_logic := '0';
    signal wready_r  : std_logic := '0';
    signal bvalid_r  : std_logic := '0';
    signal arready_r : std_logic := '0';
    signal rvalid_r  : std_logic := '0';
    signal rdata_r   : std_logic_vector(31 downto 0)  := (others => '0');
    signal aw_addr   : std_logic_vector(C_S00_AXI_ADDR_WIDTH-1 downto 0);
    
    
    
begin

-- Instantiation of Axi Bus Interface S00_AXI
--MyLEDIP_slave_lite_v1_0_S00_AXI_inst : MyLEDIP_slave_lite_v1_0_S00_AXI
--	generic map (
--		C_S_AXI_DATA_WIDTH	=> C_S00_AXI_DATA_WIDTH,
--		C_S_AXI_ADDR_WIDTH	=> C_S00_AXI_ADDR_WIDTH
--	)
--	port map (
--		S_AXI_ACLK	=> s00_axi_aclk,
--		S_AXI_ARESETN	=> s00_axi_aresetn,
--		S_AXI_AWADDR	=> s00_axi_awaddr,
--		S_AXI_AWPROT	=> s00_axi_awprot,
--		S_AXI_AWVALID	=> s00_axi_awvalid,
--		S_AXI_AWREADY	=> s00_axi_awready,
--		S_AXI_WDATA	=> s00_axi_wdata,
--		S_AXI_WSTRB	=> s00_axi_wstrb,
--		S_AXI_WVALID	=> s00_axi_wvalid,
--		S_AXI_WREADY	=> s00_axi_wready,
--		S_AXI_BRESP	=> s00_axi_bresp,
--		S_AXI_BVALID	=> s00_axi_bvalid,
--		S_AXI_BREADY	=> s00_axi_bready,
--		S_AXI_ARADDR	=> s00_axi_araddr,
--		S_AXI_ARPROT	=> s00_axi_arprot,
--		S_AXI_ARVALID	=> s00_axi_arvalid,
--		S_AXI_ARREADY	=> s00_axi_arready,
--		S_AXI_RDATA	=> s00_axi_rdata,
--		S_AXI_RRESP	=> s00_axi_rresp,
--		S_AXI_RVALID	=> s00_axi_rvalid,
--		S_AXI_RREADY	=> s00_axi_rready,
--				--LED Output
--        pl_led => pl_led0
--	);

	-- Add user logic here
    -- Outputs
    pl_led <= led_state;
    
    s00_axi_awready <= awready_r;
    s00_axi_wready  <= wready_r;
    s00_axi_bvalid  <= bvalid_r;
    s00_axi_bresp <= "00"; -- OKAY
    s00_axi_arready <= arready_r;
    s00_axi_rvalid <= rvalid_r;
    s00_axi_rdata <= rdata_r;
    s00_axi_rresp <= "00"; --OKAY
    
    --Write address handshake
    process(s00_axi_aclk)
    begin
        if rising_edge(s00_axi_aclk) then
          if s00_axi_aresetn = '0' then
             awready_r <= '0';
           else
             if awready_r = '0' and s00_axi_awvalid = '1' and s00_axi_wvalid = '1' then
              awready_r <= '1';
              aw_addr <= s00_axi_awaddr;
             else
              awready_r <= '0';
             end if;
         end if;
       end if;    
    end process;
    
    -- write data handshare + register write
    process(s00_axi_aclk)
    begin
     if rising_edge(s00_axi_aclk) then
       if s00_axi_aresetn <= '0' then
         wready_r <= '0';
         led_ctrl_reg <= (others => '0');
         led_state <= '0';
       else
         if wready_r = '0' and s00_axi_wvalid = '1' and s00_axi_awvalid = '1' then
            wready_r <= '1';
            -- write to register
            case aw_addr(3 downto 2) is 
              when "00" => -- offeset 0x00: LED control
                led_ctrl_reg <= s00_axi_wdata;
                led_state <= s00_axi_wdata(0);
              when others => null;
            end case;
         else
           wready_r <= '0';
         end if;
       end if;
     end if;
    end process;
   
   -- write response
   process(s00_axi_aclk)
   begin
    if rising_edge(s00_axi_aclk) then
      if s00_axi_aresetn = '0' then
         bvalid_r <= '0';
      else
        if awready_r = '1' and s00_axi_awvalid = '1' and 
           wready_r = '1' and s00_axi_wvalid = '1' and
           bvalid_r = '0' then
             bvalid_r <= '1';
        elsif s00_axi_bready = '1' and bvalid_r = '1' then
          bvalid_r <= '0';
        end if;
      end if;
    end if;
   end process;
    
   -- Read address handshake
   process(s00_axi_aclk)
   begin
     if rising_edge(s00_axi_aclk) then
        if s00_axi_aresetn = '0' then
            arready_r <= '0';
         else
              if arready_r = '0' and s00_axi_arvalid = '1' then
                  arready_r <= '1';
              else
                  arready_r <= '0';
              end if;
         end if;
     end if;
   
   end process; 
            
  -- Read data
  process(s00_axi_aclk)
  begin
    if rising_edge(s00_axi_aclk) then
       if s00_axi_aresetn = '0' then
           rvalid_r <= '0';
           rdata_r <= (others => '0');
       else
         if arready_r = '1' and s00_axi_arvalid = '1' and rvalid_r = '0' then
            rvalid_r <= '1';
            case s00_axi_araddr(3 downto 2) is
                 when "00" => -- offset 0x00: LED control readback
                    rdata_r <= led_ctrl_reg;
                 when "01" => -- offset 0x04: LED status
                    rdata_r <= (0 => led_state, others => '0');
                 when others =>
                    rdata_r <= (others => '0');
            end case;
          elsif rvalid_r = '1' and s00_axi_rready = '1' then
             rvalid_r <= '0';
         end if;
       end if;
    end if;
  
  end process;       
    
	-- User logic ends

end rtl;
