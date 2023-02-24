----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 02/04/2023 07:54:36 PM
-- Design Name: 
-- Module Name: Controller_Inputs - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity Controller_Inputs is
    Port ( CLK100MHZ : in STD_LOGIC;                                    -- Arty S7-50 Clock
           nes_latch : out STD_LOGIC;                                   -- Latch sent to controller (tells controller to capture buttons in shift register)
           nes_pulse : out STD_LOGIC;                                   -- Pulse sent to the controller (whenever pulse is high the data line is read)
           nes_data_in : in STD_LOGIC;                                  -- Incoming button data from controller
           reset : in STD_LOGIC;                                         -- reset switch
           led : out STD_LOGIC_VECTOR(3 downto 0);
           sel : in STD_LOGIC
           );                                       
end Controller_Inputs;

architecture Behavioral of Controller_Inputs is

           
signal latch, pulse : std_logic;                                        -- Internal signal which sets latch and pulse high and low 

signal latch_count : integer := 0;                                      -- Latch counter (used to count the 100MHZ clock and reset the latch)

signal pulse_count : integer := 0;                                      -- Pulse counter (used to count the 100MHZ clock and reset the pulse)

signal pulse_amount : integer := 0;                                     -- Pulse amount is a counter for the amount of pulses sent

type statetype is (idle, readinput, senddata, nextinput);               -- Declare the statetype of 4 (idle, readinput, senddata, nextinput)

signal current_state : statetype;                                       -- Declare the statetype to switch between states

signal button_count : integer := 0;                                     -- Button counter (used to count the button shifts)

signal button_data : std_logic_vector(7 downto 0);                      -- an array to store the 8 button presses

begin

    nes_latch <= latch;                                                 -- Assigns the latch signal to the nes_latch port
    Latch1 : process(CLK100MHZ, reset)                                  -- process Latch1 begins which includes ports Clk100MHZ & reset
    begin
        if reset = '1' then                                             -- When the reset switch is high
            latch <= '1';                                               -- Set the latch high
            latch_count <= 0;                                           -- Set the latch_count to 0
        elsif rising_edge(CLK100MHZ) then                               -- When the reset switch is low then on every rising_edge of the 100MHZ clock
            latch_count <= latch_count + 1;                             -- Add 1 to the signal latch_count and assign it to latch_count
            if latch_count = 1200 then                                  -- When latch_count hits 1200 or 12us then
                latch <= '0';                                           -- Set the latch low
            end if;                                                     -- ends "if latch_count = 1200 then" statement
            if latch_count = 1666667 then                               -- When latch_count is 1666667 or hits 60hz then (60hz is the refresh rate of the latch)
                latch <= '1';                                           -- Set the latch high
                latch_count <= 0;                                       -- Set the latch_count to 0
            end if;                                                     -- ends "if latch_count = 1666667 then" statement
        end if;                                                         -- ends "if reset = '1' then" statement
     end process Latch1;                                                -- process Latch1 ends
    
    nes_pulse <= pulse;                                                 -- Assigns the pulse signal to the nes_pulse port
    Pulse1 : process(CLK100MHZ, reset, latch, pulse)                    -- process Pulse1 begins which includes ports Clk100MHZ, reset, latch, pulse
        begin
            if latch = '1' then                                         -- When the latch is high then
                pulse <= '0';                                           -- Set the pulse low
                pulse_count <= 0;                                       -- Set the pulse_count to 0
                pulse_amount <= 0;                                      -- Set the pulse_amount to 0
            elsif rising_edge(CLK100MHZ) then                           -- When the latch is high then on every rising_edge of the 100MHZ clock
                if pulse_amount /= 16 then                              -- When the pulse_amount is not equal to 16 then (this gives you the 8 pulses for 8 buttons)
                    pulse_count <= pulse_count + 1;                     -- Add 1 to the signal pulse_count and assign it to pulse_count
                    if pulse_count = 600 then                           -- When pulse_count equals 600 or 6us then
                        pulse <= not pulse;                             -- Set the pulse low 
                        pulse_amount <= pulse_amount + 1;               -- Add 1 to the signal pulse_amount and assign it to pulse_amount
                        pulse_count <= 0;                               -- Set the pulse_count to 0
                    end if;                                             -- ends "if pulse_count = 600 then" statement
                end if;                                                 -- ends "if pulse_amount /= 14 then" statement
            end if;                                                     -- ends "if latch = '1' then" statement
        end process Pulse1;                                             -- process Pulse1 ends
        
    Statemachine : process(CLK100MHZ, reset, nes_data_in, latch, pulse, current_state, button_data)  ---- process Statemachine begins which includes ports CLK100MHZ, reset, nes_data_in, latch, pulse, current_state, button_data
    begin
        if reset = '1' then                                             -- When the reset switch is high
            current_state <= idle;                                      -- set the current state to idle
            button_count <= 0;                                          -- set the button count to 0
        elsif rising_edge(CLK100MHZ) then                               -- When the reset is low then on every rising_edge of the 100MHZ clock
            case current_state is                                       -- Start switch case
                when idle =>                                            -- Declare first case: idle
                    if latch = '1' then                                 -- when latch is high then
                        current_state <= readinput;                     -- set the current state to readinput
                        button_count <= 0;                              -- set the button count to 0
                    end if;                                             -- end "if latch = '1' then" statement
                when readinput =>                                       -- Declare second case : readinput
                    if latch = '0' then                                 -- when latch is low then
                        current_state <= senddata;                      -- set the current state to senddata
                        button_count <= button_count + 1;               -- Add 1 to the signal button_count and assign it to button_count
                        button_data(0) <= not nes_data_in;              -- Shift the first button (A button) into the array button_data
                    end if;                                             -- end "if latch = '0' then" statement
                when senddata =>                                        -- Declare third case: senddata
                    if button_count = 8 then                            -- when button_count is equal to 8 (nes controller has 8 btns)
                        current_state <= idle;                          -- set the current state to idle
                    elsif pulse = '1' then                              -- when pulse is high then
                        current_state <= nextinput;                     -- set the current state to the nextinput
                    end if;                                             -- end "if button_count = 8 then" statement
                when nextinput =>                                       -- Declare fourth case: nextinput
                    if pulse = '0' then                                 -- when pulse is low then
                        current_state <= senddata;                      -- set the current state to senddata
                        button_data(button_count) <= not nes_data_in;   -- Shift the next button into button_data based off the button_count
                        button_count <= button_count + 1;               -- Add 1 to the signal button_count and assign it to button_count
                    end if;                                             -- end "if pulse = '0' then" statement
            end case;                                                   -- end "case current_state is" statement
        end if;                                                         -- end "if reset = '1' then" statement
    end process Statemachine;                                           -- process Statemachine ends
                                                                           
    LED1 : process(CLK100MHZ, reset, button_data)                       -- button testing. pressing a button will turn on a led. sel will switch between a,b,start,select & up,down,left,right
        begin
            if reset = '1' then
                led(0) <= '0';
                led(1) <= '0';
                led(2) <= '0';
                led(3) <= '0';
            elsif rising_edge(CLK100MHZ) then
                if sel = '0' then
                    led(0) <= '0';
                    led(1) <= '0';
                    led(2) <= '0';
                    led(3) <= '0';
                    if button_data(0) = '1' then
                        led(0) <= '1';
                    elsif button_data(0) = '0' then
                        led(0) <= '0';
                    end if;
                    if button_data(1) = '1' then
                        led(1) <= '1';
                    elsif button_data(1) = '0' then
                        led(1) <= '0';
                    end if;
                    if button_data(2) = '1' then
                        led(2) <= '1';
                    elsif button_data(2) = '0' then
                        led(2) <= '0';
                    end if;
                    if button_data(3) = '1' then
                        led(3) <= '1';
                    elsif button_data(3) = '0' then
                        led(3) <= '0';
                    end if;                    
                end if;
                if sel = '1' then
                    led(0) <= '0';
                    led(1) <= '0';
                    led(2) <= '0';
                    led(3) <= '0';
                    if button_data(4) = '1' then
                        led(0) <= '1';
                    elsif button_data(4) = '0' then
                        led(0) <= '0';
                    end if;
                    if button_data(5) = '1' then
                        led(1) <= '1';
                    elsif button_data(5) = '0' then
                        led(1) <= '0';
                    end if;
                    if button_data(6) = '1' then
                        led(2) <= '1';
                    elsif button_data(6) = '0' then
                        led(2) <= '0';
                    end if;
                    if button_data(7) = '1' then
                        led(3) <= '1';
                    elsif button_data(7) = '0' then
                        led(3) <= '0';
                    end if;
                end if;
            end if;
    end process LED1;      

    
    
                                                   
                     
        
end Behavioral;
