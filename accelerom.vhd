---------------------------------------------------------------------------
-- This VHDL file was developed by Daniel Llamocca (2015).  It may be
-- freely copied and/or distributed at no cost.  Any persons using this
-- file for any purpose do so at their own risk, and are responsible for
-- the results of such use.  Daniel Llamocca does not guarantee that
-- this file is complete, correct, or fit for any particular purpose.
-- NO WARRANTY OF ANY KIND IS EXPRESSED OR IMPLIED.  This notice must
-- accompany any copy of this file.
--------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- This code reads ADXL362 (MEMS Accelerometer) registers:
-- 0x08 (low precision X), 0x09 (low precision Y), 0x0A (low precision Z), 0x0B (Status)
-- Only one of these registers is read. This is selected by 'sel' input.
-- sel   Register read (data on odata_reg)
-- 00     0x08
-- 01     0x09
-- 10     0x0A
-- 11     0x0B

-- If you want to read and write on other registers, you need to modify the FSM

entity accelerom is
-- SCLK period (in cycles of the 'clock' frequency)
	--generic (SCLK_T: INTEGER:= 40); -- Min. TSCLK = 40 (fSCLK = 2.5 MHz). According to ADXL362, Min. TSCLK = 100 ns (TSCLK=10), but our
                                  -- design with free running SCLK and the fact that we have to comply with CSS, tCS, tCSH, etc., 
                                  -- makes it that Min. SCLK = 280 ns, we pick for safety 400 ns, i.e. SCLK_T=40 
    generic (SCLK_T: INTEGER:= 10**6); -- fSCLK = 1000 Hz. To be able to properly see the values, we pick a higher period: every 1*24 periods, we refresh: 24 ms is a good refresh rate
    --generic (SCLK_T: INTEGER:= 16); -- For simulation purposes only
	port (resetn, clock: in std_logic;
	      sel: in std_logic_vector (1 downto 0); 
		  odata_reg: out std_logic_vector (7 downto 0);
		  -- SPI signals
		  nCS: out std_logic;
		  MOSI: out std_logic;
		  MISO: in std_logic;
		  SCLK: out std_logic);
end accelerom;

architecture Behavioral of accelerom is

	component wr_reg_axl362
		generic (SCLK_T: INTEGER:= 5*(10**5));
		port (resetn, clock: in std_logic;
				start: in std_logic;
				address, data: in std_logic_vector (7 downto 0);
				wr_rd: in std_logic; -- wr_rd = '0' -> Request a read, wr_rd = '1' -> Request a write
				odata: out std_logic_vector (7 downto 0);
				done: out std_logic;
				-- SPI signals
				nCS: out std_logic;
				MOSI: out std_logic;
				MISO: in std_logic;
				SCLK: out std_logic);
	end component;
	
	component my_rege
		generic (N: INTEGER:= 4);
		port ( clock, resetn: in std_logic;
				 E, sclr: in std_logic; -- sclr: Synchronous clear
				 D: in std_logic_vector (N-1 downto 0);
				 Q: out std_logic_vector (N-1 downto 0));
	end component;


	type state is (S1, S2, S3, S4, S5, S6);
	signal y: state;		

	signal start, wr_rd, done: std_logic;
	signal address, data, odata: std_logic_vector (7 downto 0);
	signal E_odata: std_logic;
	
begin

ji: wr_reg_axl362 generic map (SCLK_T => SCLK_T)
	 port map (resetn, clock, start, address, data, wr_rd, odata, done,
              nCS, MOSI, MISO, SCLK);

ro: my_rege generic map (N => 8)
    port map (clock => clock, resetn => resetn, E => E_odata, sclr => '0', D => odata, Q => odata_reg);                 

-- Main FSM:
	Transitions: process (resetn, clock, done)
	begin
		if resetn = '0' then -- asynchronous signal
			y <= S1;
		elsif (clock'event and clock = '1') then
			case y is
				when S1 =>
					y <= S2;
				
				when S2 =>
					if done = '1' then y <= S3; else y <= S2; end if;

				when S3 =>
					y <= S4;
					
				when S4 =>
					if done = '1' then y <= S5; else y <= S4; end if;

				when S5 =>
					y <= S6;
					
				when S6 =>
					--if done = '1' then y <= S3; else y <= S6; end if;
					if done = '1' then y <= S5; else y <= S6; end if;

					
			end case;			
		end if;		
	end process;
	
	Outputs: process (y, done, sel)
	begin
		-- Default values for FSM outputs:
		start <= '0'; address <= x"00"; data <= x"00"; wr_rd <= '0';
		E_odata <= '0';
		
		case y is
			when S1 =>
					address <= x"1F"; data <= x"52"; wr_rd <= '1'; -- Reset chip
					start <= '1'; 
					
			when S2 =>

			-- Before reading form a regsiter, activate the measurement mode on POWER_CTRL register (0x2D)
			when S3 =>
					address <= x"2D"; data <= x"02"; wr_rd <= '1'; -- Writing on Register POWER_CTRL (0x2D) the data 0x02 (measurement mode)
					start <= '1'; 
					
			when S4 =>
					
			when S5 =>
					if sel = "00" then
						address <= x"08"; -- Reading from X (8 MSBs, for low accuracy apps).
					elsif sel = "01" then
						address <= x"09"; -- Reading from Y (8 MSBS, for low accuracy apps).
					elsif sel = "10" then
						address <= x"0A"; -- Reading from Y (8 MSBS, for low accuracy apps).						
					else
						address <= x"0B"; -- Reading from Status Register.												
					end if;
					wr_rd <= '0'; data <= x"FF"; 
					start <= '1';
				
			when S6 =>			
					if done = '1' then E_odata <= '1'; end if;
			
		end case;
	end process;
 
end Behavioral;

