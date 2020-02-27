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

entity wr_reg_axl362 is
	generic (SCLK_T: INTEGER:= 10*(10**5)); -- Time (in periods of clock) of a period of SCLK
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
end wr_reg_axl362;

architecture Behavioral of wr_reg_axl362 is

	component my_genpulse_sclr
		generic (COUNT: INTEGER:= (10**2)/2); -- (10**2)/2 cycles of T = 10 ns --> 0.5us
		port (clock, resetn, E, sclr: in std_logic;
				Q: out std_logic_vector ( integer(ceil(log2(real(COUNT)))) - 1 downto 0);
				z: out std_logic);
	end component;
	
	component my_pashiftreg
		generic (N: INTEGER:= 4;
					DIR: STRING:= "LEFT");
		port ( clock, resetn: in std_logic;
				 din, E, s_l: in std_logic; -- din: shiftin input
				 D: in std_logic_vector (N-1 downto 0);
				 Q: out std_logic_vector (N-1 downto 0);
				 shiftout: out std_logic);
	end component;
		
	component fsm_sclk
		generic (COUNT_SCLKHP: INTEGER:= 5*(10**5));
		port (resetn, clock: in std_logic;
				start: in std_logic;
				sclk: out std_logic;
				zF, zR: out std_logic);
	end component;
	
	component dffe
    Port ( d : in  STD_LOGIC;
	        clrn: in std_logic:= '1';
			  prn: in std_logic:= '1';
           clk : in  STD_LOGIC;
			  ena: in std_logic;
           q : out  STD_LOGIC);
	end component;

    constant SCLKHP: INTEGER:= SCLK_T/2; -- SCLK high pulse width (in cycles of the 'clock' frequency)
	type state is (S1, S2, S3, S4, S5, S6, S7, S8);
	signal y: state;		
		
	signal Ea, Ed, Ei, Eo, L: std_logic;
	signal EQ, sclrQ, zQ, wr_rdq: std_logic;
	signal INST: std_logic_vector (7 downto 0);
	signal oa, od, oi: std_logic;
	signal sel: std_logic_vector (1 downto 0);	
	
	signal zR, zF: std_logic;
	constant tCSH: integer:= 2; -- in periods of 'clock'
	constant tCSD: integer:= 2; -- in periods of 'clock'
	signal qtCSH: integer range 0 to tCSH-1;
	signal qtCSD: integer range 0 to tCSD-1;
	
begin

gf: fsm_sclk generic map (COUNT_SCLKHP => SCLKHP)
    port map (resetn => resetn, clock => clock, start => start, sclk => sclk, zF => zF, zR => zR);	

-- Counter: modulo 8
gQ: my_genpulse_sclr generic map (COUNT => 8) 
	 port map (clock => clock, resetn => resetn, E => EQ, sclr => sclrQ, z => zQ);
	 
-- Shift Register: Address
sa: my_pashiftreg generic map (N => 8, DIR => "LEFT")
    port map (clock => clock, resetn => resetn, din => '0', E => Ea, s_l => L, D => address, shiftout => oa);

-- Shift Register: Data
sd: my_pashiftreg generic map (N => 8, DIR => "LEFT")
    port map (clock => clock, resetn => resetn, din => '0', E => Ed, s_l => L, D => data, shiftout => od);

di: dffe port map (d => wr_rd, clrn => resetn, prn => '1', clk => clock, ena => L, q => wr_rdq);

-- Shift Register: Instruction
si: my_pashiftreg generic map (N => 8, DIR => "LEFT")
    port map (clock => clock, resetn => resetn, din => '0', E => Ei, s_l => L, D => INST, shiftout => oi);

	 with wr_rd select
		  INST <= x"0A" when '1',
		          x"0B" when others;

	with sel select
			MOSI <= oa when "01",
			        od when "10",
					oi when "00",
					'0' when others;

-- Shift Register: Input data
so: my_pashiftreg generic map (N => 8, DIR => "LEFT")
    port map (clock => clock, resetn => resetn, din => MISO, E => Eo, s_l => '0', D => (others => '0'), Q => odata);
					  
-- Main FSM:
	Transitions: process (resetn, clock, zF, zR, zQ, wr_rdq, start)
	begin
		if resetn = '0' then -- asynchronous signal
			y <= S1; qtCSH <= 0; qtCSD <= 0;
		elsif (clock'event and clock = '1') then
			case y is
				when S1 =>
					if start = '1' then y <= S2; else y <= S1; end if;
				
				when S2 =>
					if zF = '1' then
						if zQ = '1' then y <= S3; else y <= S2; end if;
					else
						y <= S2;
					end if;

				when S3 =>
					if zF = '1' then
						if zQ = '1' then
							if wr_rdq = '1' then y <= S4; else y <= S5; end if;
						else
							y <= S3;
						end if;
					else
						y <= S3;
					end if;

				when S4 =>
					if zF = '1' then
						--if zQ = '1' then y <= S6; else y <= S4; end if;
						if zQ = '1' then y <= S7; else y <= S4; end if;
					else
						--y <= S7;
						y <= S4;
					end if;

				when S5 =>
					if zR = '1' then
						if zQ = '1' then y <= S6; else y <= S5; end if;
					else
						y <= S5;
					end if;

				when S6 =>
					if zF = '1' then y <= S7; else y <= S6; end if;
			    
			    when S7 =>
			         if qtCSH = tCSD-1 then
			             y <= S8; qtCSH <= 0;
			         else
			            y <= S7; qtCSH <= qtCSH + 1;
			         end if;
			    
			    when S8 =>
			         if qtCSD = tCSD-1 then
			             if start = '1' then
			                 y <= S8;
			             else
			                 y <= S1; qtCSD <= 0;
			             end if;
			         else
			             y <= S8; qtCSD <= qtCSD + 1;
			         end if;			    
			end case;			
		end if;		
	end process;
	
	Outputs: process (y, start, zF, zQ, zR, qtCSD)
	begin
		-- Default values for FSM outputs:
		L <= '0'; Ea <= '0'; Ed <= '0'; Ei <= '0'; EQ <= '0'; sclrQ <= '0'; sel <= "00"; Eo <= '0'; done <= '0'; nCS <= '0';
		
		case y is
			when S1 =>
					nCS <= '1';
					if start = '1' then
						L <= '1'; Ea <= '1'; Ed <= '1'; Ei <= '1';
					end if;
					
			when S2 =>
					sel <= "00";
					if zF = '1' then
						Ei <= '1';
						if zQ = '1' then
							EQ <= '1'; sclrQ <= '1';
						else
							EQ <= '1';
						end if;
					end if;

			when S3 =>
					sel <= "01";
					if zF = '1' then
						Ea <= '1';
						if zQ = '1' then
							EQ <= '1'; sclrQ <= '1';
						else
							EQ <= '1';
						end if;
					end if;					
				
			when S4 =>
					sel <= "10";
					if zF = '1' then
						Ed <= '1';
						if zQ = '1' then
							EQ <= '1'; sclrQ <= '1';
						else
							EQ <= '1';
						end if;
					end if;				
					
			when S5 =>
					if zR = '1' then
						Eo <= '1';
						if zQ = '1' then
							EQ <= '1'; sclrQ <= '1';
						else
							EQ <= '1';
						end if;
					end if;	
			
			when S6 =>
			
			when S7 =>
			    
			when S8 =>
			     nCS <= '1';
			     if qtCSD = tCSD-1 then
			         if start = '0' then
			             done <= '1';
			         end if;
			     end if;
				
		end case;
	end process;
 
end Behavioral;

