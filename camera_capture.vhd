library IEEE;

use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
--
-- This method works only if we are sure that clk of the fpga is faster then
--pclk , additionally since we will need to synchronize the pclk , we will
--pass it into double flopping and a third ff to detect edge , since we s
--sample only on rising edge , so we get a delay of 3 clk edge , but
-- the camera outputs new data on falling edge of pclk , so we have only
-- tpclk/2 time to sample the right data otherwise we get garbage data or
--the next byte so we miss the data , bcs the data are multibit bus
--so we cannot hold them by sampling because we risk of metastability

--So a strong condition 3 * tclk < tpclk/2 , to add some margin would be better  

entity camera_capture_oversample is

generic (
	RES_WIDTH : integer := 480;
	RES_HEIGHT : integer := 480;
	);
port (
  	clk , vsync , hsync , rst : in std_logic;
  	data : in std_logic_vector ( 7 downto 0 );	
  	pixel_data : out std_logic_vector ( 15 downto 0 );
  	valid_pixel , last_pixel , last_line : out std_logic
);

architecture rtl of camera_capture_oversample is
--==========Clock synchronizer
signal clk_reg1 , clk_reg2 , clk_reg3 : std_logic := '0';
signal clk_rising : std_logic := '0';
--======Output registers
signal valid_pixel_reg  , last_pixel_reg , last_line_reg : std_logic := '0';
signal data_reg : std_logic_vector ( 15 downto 0) := ( others => '0');
--======Byte order
signal byte_order : std_logic := '0'; -- just to keep track are we on the first or second byte since 8 bit data but one pixel 2 bytes

--====Counters to keep track , at which frame we are , which line , which pixel
signal cnt_pixel : unsigned (8 downto 0 ) := 0 ;
signal cnt_line : unsigned ( 9 downto 0 ) := 0;
signal cnt_frame : unsigned (4 downto 0 ) := 0 ;
--====Signal Start of the design
signal start : std_logic := '0' ;


begin
--im not adding rst logic , rst sync logic , check the camera_capture.vhd
clk_rising <= '1' if clk_reg2 ='1' and clk_reg3 ='0' else '0'; 
CLK_SYNC : process ( clk , rst)
begin
if rising_edge ( clk ) then
	clk_reg1 <= clk;
	clk_reg2 <= clk_reg1;
	clk_reg3 <= clk_reg2;
end if;
end process CLK_SYNC;


sampling : process ( clk , rst )
begin
if rising_edge ( clk) then
	if clk_rising = '1' then
		if href = '1' then
			byte_order <= not byte_order;
			if byte_order = '0' then
				pixed_data ( 7 downto 0) <= data;
			else
				pixed_data ( 7 downto 0) <= data;
				pixel_valid <= 1;
				cnt_pixel <= cnt_pixel + 1 ;	
			end if;
			if cnt_pixel = RES_WIDTH - 1 then
				last_pixel_reg <= '1';
				cnt_line <= cnt_line + 1;
			end if;
			if cnt_line = RES_HEIGHT - 1 then
				last_line_reg <= '1';
				cnt_frame <= cnt_frame + 1 ; --could do also differently , adding more signals just to notify the sides or use a simple fsm but just being lazy today
-- we increment on the end of the pixel when we get both the bytes, the same for the line we increment when we have received the full line and are getting ready to send the last pixel		
			end if;
		else
			if vsync = '1' then
				if start = '0' then -- just as a start logic , could do also more to differentiate between when we are on the backporch frontporch these kind of stuff
					start <= '1';
					cnt_frame <= 0 ;
				end if ;
	end if;



end process;

valid_pixel <= valid_pixel_reg ;  
last_pixel <= last_pixel_reg ; 
last_line <=	last_line_reg;
pixel_data <= pixel_data_reg ; 


end architecture rtl;
