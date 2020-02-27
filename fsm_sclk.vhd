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
use ieee.math_real.log2;
use ieee.math_real.ceil;

entity fsm_sclk is
   generic (COUNT_SCLKHP: INTEGER:= 5*(10**5)); -- SCLK high pulse width (in cycles of the 'clock' frequency)
	port (resetn, clock: in std_logic;
			start: in std_logic;
			sclk: out std_logic;
			zF, zR: out std_logic);
end fsm_sclk;

architecture Behavioral of fsm_sclk is

	component my_genpulse_sclr
		generic (COUNT: INTEGER:= (10**2)/2); -- (10**2)/2 cycles of T = 10 ns --> 0.5us
		port (clock, resetn, E, sclr: in std_logic;
				Q: out std_logic_vector ( integer(ceil(log2(real(COUNT)))) - 1 downto 0);
				z: out std_logic);
	end component;
		
	type state is (S1, S2, S3);
	signal y: state;	
	
	signal ET, zT, sclrT: std_logic;
	
begin

-- Counter: 5 ms. 5*10^-3/(10*10^-9)
bT: my_genpulse_sclr generic map (COUNT => COUNT_SCLKHP) 
	 port map (clock => clock, resetn => resetn, E => ET, sclr => sclrT, z => zT);
	
	Trans: process (resetn, clock, start, zT)
	begin
		if resetn = '0' then -- asynchronous signal
			y <= S1;
		elsif (clock'event and clock = '1') then
			case y is
				when S1 =>
					if start = '1' then y <= S2; else y <= S1; end if;
					
				when S2 =>
					if zT = '1' then y <= S3; else y <= S2; end if;
					
				when S3 =>
					if zT = '1' then y <= S2; else y <= S3; end if;
					
			end case;			
		end if;		
	end process;
	
	Output: process (y, start, zT)
	begin
		-- Default values of FSM outputs:
		sclk <= '0'; zR <= '0'; zF <= '0'; ET <= '0'; sclrT <= '0';
		
		case y is
			when S1 =>
				
			when S2 =>
				if zT = '1' then
					ET <= '1'; sclrT <= '1';
					zR <= '1';
				else
					ET <= '1';
				end if;

			when S3 =>
				sclk <= '1';
				if zT = '1' then
					ET <= '1'; sclrT <= '1';
					zF <= '1';
				else
					ET <= '1';
				end if;
				
		end case;
	end process;
	
end Behavioral;

