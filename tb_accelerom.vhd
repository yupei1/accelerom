LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
 
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--USE ieee.numeric_std.ALL;

-- Better use it with: generic (SCLK_T: INTEGER:= 16);
ENTITY tb_accelerom IS
END tb_accelerom;
 
ARCHITECTURE behavior OF tb_accelerom IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
 
    COMPONENT accelerom
    PORT(
         resetn : IN  std_logic;
         clock : IN  std_logic;
			sel: in std_logic_vector (1 downto 0);
         odata_reg : OUT  std_logic_vector(7 downto 0);
         nCS : OUT  std_logic;
         MOSI : OUT  std_logic;
         MISO : IN  std_logic;
         SCLK : OUT  std_logic
        );
    END COMPONENT;
    
   --Inputs
   signal resetn : std_logic := '0';
   signal clock : std_logic := '0';
   signal MISO : std_logic := '0';
	signal sel: std_logic_vector (1 downto 0):= "00";
 	--Outputs
   signal odata_reg : std_logic_vector(7 downto 0);
   signal nCS : std_logic;
   signal MOSI : std_logic;
   signal SCLK : std_logic;

   -- Clock period definitions
   constant clock_period : time := 10 ns;
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: accelerom PORT MAP (
          resetn => resetn,
          clock => clock,
			 sel => sel,
          odata_reg => odata_reg,
          nCS => nCS,
          MOSI => MOSI,
          MISO => MISO,
          SCLK => SCLK
        );

   -- Clock process definitions
   clock_process :process
   begin
		clock <= '0';
		wait for clock_period/2;
		clock <= '1';
		wait for clock_period/2;
   end process;

   -- Stimulus process
   stim_proc: process
   begin		
      -- hold reset state for 100 ns.
      wait for 100 ns;	

      wait for clock_period*10; resetn <= '1';

      -- insert stimulus here 
		sel <="00"; -- Reading register X (8 MSBs)
		MISO <= '1';
      wait for clock_period*10;

      -- insert stimulus here 
	
      wait;
   end process;

END;
