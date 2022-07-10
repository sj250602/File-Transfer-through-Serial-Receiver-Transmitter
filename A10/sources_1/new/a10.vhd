----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 05/27/2022 06:39:53 PM
-- Design Name: 
-- Module Name: a10 - Behavioral
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
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity a10 is
 Port ( clk :in std_logic; --define a clock
        rx_in : in std_logic; --define a input data
        reset : in std_logic; -- define a reset button
        tx_start : in std_logic; -- define a transmitter start
        tx_out : out std_logic; -- define a transmitter out
        segment : out std_logic_vector(6 downto 0); -- define a vector for seven segment display
        anode : out std_logic_vector(3 downto 0); -- define a vector for anodes
        led_e : out std_logic; -- define a empty button
        led_f : out std_logic); -- define a full button
end a10;

architecture Behavioral of a10 is
    -- import a component of  BRAM
    component BRAM is
        port (
          BRAM_PORTA_addr : in STD_LOGIC_VECTOR ( 12 downto 0 );
          BRAM_PORTA_clk : in STD_LOGIC;
          BRAM_PORTA_din : in STD_LOGIC_VECTOR ( 7 downto 0 );
          BRAM_PORTA_dout : out STD_LOGIC_VECTOR ( 7 downto 0 );
          BRAM_PORTA_en : in STD_LOGIC;
          BRAM_PORTA_we : in STD_LOGIC_VECTOR ( 0 to 0 )
        );
        end component BRAM;
    
    signal addr :  STD_LOGIC_VECTOR ( 12 downto 0 ); -- define a signal of vector size 13 
    signal din :  STD_LOGIC_VECTOR ( 7 downto 0 ); -- define a signal of vector size 8
    signal dout : STD_LOGIC_VECTOR ( 7 downto 0 );  -- define a signal of vector size 8
    signal en :  STD_LOGIC; -- define a signal 
    signal we :  STD_LOGIC_VECTOR ( 0 to 0 ); -- define a vector of size 0

    -- define a FSM states for reciever and their intial condition before FSM start processing
    type rx_states is (rx_idle,rx_start,rx_data_shift,rx_stop);
    signal rx_state :rx_states:=rx_idle;    -- define a reciver current as idle
    signal rx_data : std_logic := '0'; -- define a data signal as 0
    signal rx_clk_counter : integer range 0 to 10416:=0; -- define a counter for clock
    signal rx_index : integer range 0 to 7 :=0; -- define an index for going to stop to idle
    signal rx_temp_data : std_logic_vector(7 downto 0):="00000000"; -- define a temp signal for storee the data for temporary purpose
    signal rx_perm_data : std_logic_vector(7 downto 0):="00000000"; -- define a perm signal for storee the data for permanent purpose(in mmry)
    signal rx_stop_bit : std_logic := '0'; -- define a stop bit as 0 for intial

 
    -- define a FSM states for transmitter and their intial condition before FSM start processing   
    type tx_states is (tx_idle,txstart,tx_data_shift,tx_stop,tx_read_conti);
    signal tx_state :tx_states:=tx_idle; -- define a transmitter current as idle
    signal tx_clk_counter : integer range 0 to 10416:=0; -- define a clock counter for transmitter
    signal tx_index : integer range 0 to 7 :=0; -- define a index for going from the stop to idle
    signal tx_temp_data : std_logic_vector(7 downto 0):="00000000"; -- define a temp signal for storee the data for temporary purpose
    signal tx_stop_bit : std_logic := '0';-- define a stop bit as 0 for intial
    signal tx_start_temp : std_logic := '0';  -- define a start transmitter state as zero
    signal tx_start_prev : std_logic := '0'; -- define a previous state for the transmitter
    signal reset_sig : std_logic := '0'; -- define a signal for the reset button
    signal reset_prev : std_logic := '0'; -- define a reset signal for checking the previous value of the reset button

    --define a FSM states for the read adn write the data
    type states is (idle, write_fifo, read_fifo,read_en);
    signal curr_state : states := idle; -- define current state as idle
    signal depth_counter : integer range 0 to 8192:=0; -- define a depth counter for read and write data
    signal full_sig : std_logic:='0'; -- define a signal for full the queue
    signal emp_sig : std_logic := '1'; -- define a signal for empty queue
    signal head_addr : std_logic_vector(12 downto 0):="0000000000000";-- define  a head address of size 13 
    signal tail_addr : std_logic_vector(12 downto 0):="0000000000000"; -- define  a tail address of size 13 
    signal read_data : std_logic := '0'; --define a read data as 0 intially
    signal write_data : std_logic := '0'; --define a write data as 0 intially
    signal ld_tx :std_logic := '0'; -- define a ld_tx to 0 intially
    signal debouncer_clk : std_logic := '0'; -- define a debounce clk as 0 
    signal debouncer_counter : std_logic_vector(20 downto 0):="000000000000000000000"; -- define a debounce lck counter of size 21 
    signal debouncer_wait : std_logic := '0'; -- define a bit for the debounce wait
    signal count : integer := 0; -- define a integer name count as 0
    signal output_val : std_logic_vector(7 downto 0):= "00000000"; -- define  a output val as 0 of size 8 that stores the output


    signal Bt:std_logic_vector(3 downto 0):="0000"; -- define a button 
    signal clk_input:std_logic_vector(1 downto 0):="00"; -- define a clock input
    signal refresh_clk :std_logic_vector(19 downto 0):=(others => '0'); -- define  a refresh clock



begin
    bram_fifo: component BRAM 
    port map(
        BRAM_PORTA_addr => addr,
        BRAM_PORTA_clk => clk,
        BRAM_PORTA_din => din,
        BRAM_PORTA_dout => dout,
        BRAM_PORTA_en => en,
        BRAM_PORTA_we => we
    );


    --process over the ridging edge for increase the debounce couounter
    process(clk)
    begin
    if rising_edge(clk) then
        debouncer_counter <= debouncer_counter + '1';  -- increase the debounce counter
    end if ;
    if debouncer_counter = "111101000010010000000" then
        debouncer_counter <= "000000000000000000001";   -- after a specifi value make 1 the debounce counter
        debouncer_clk <= not debouncer_clk; --taking negatio of the debounce counter
    end if ;
    end process;
    -- define a process over the debounce clk for checking thereset button and transmitter data send condition
    process(debouncer_clk)
    begin
        if rising_edge(debouncer_clk) then
            if tx_start = '1' then
                tx_start_temp <= '1'; -- when the tx_start bit i one means we  make the temp start as 1 such that we start the transmitting
            else
                tx_start_temp <= '0';-- if start state is not 1 then make it as 0 
            end if ;
            if reset = '1' then
                reset_sig <= '1'; -- when reset button is pressed then assign the reset signal as one such that we reset out data
            else
                reset_sig <= '0'; -- when the reset button is not pressed
            end if ;
        end if ;
    end process;
    -- define a process for display the output in the seven segment display
    process(Bt)
    begin
    segment(0) <= (not Bt(3) and not Bt(2) and not Bt(1) and Bt(0)) or(not Bt(3) and Bt(2) and not Bt(1) and not Bt(0)) or (Bt(3) and Bt(2) and not Bt(1) and Bt(0)) or (Bt(3) and not Bt(2) and Bt(1) and Bt(0));
    segment(1) <= (Bt(2) and Bt(1) and not Bt(0)) or (Bt(3) and Bt(1) and Bt(0)) or (not Bt(3) and Bt(2) and not Bt(1) and Bt(0)) or (Bt(3) and Bt(2) and not Bt(1) and not Bt(0));
    segment(2) <= ((NOT Bt(3)) AND (NOT Bt(2)) AND Bt(1) AND (NOT Bt(0))) OR (Bt(3) AND Bt(2) AND Bt(1)) OR (Bt(3) AND Bt(2) AND (NOT Bt(0)));
    segment(3) <= ((NOT Bt(3)) AND (NOT Bt(2)) AND (NOT Bt(1)) AND Bt(0)) OR ((NOT Bt(3)) AND Bt(2) AND (NOT Bt(1)) AND (NOT Bt(0))) OR (Bt(3) AND (NOT Bt(2)) AND Bt(1) AND (NOT Bt(0))) OR (Bt(2) AND Bt(1) AND Bt(0));
    segment(4) <= ((NOT Bt(2)) AND (NOT Bt(1)) AND Bt(0)) OR ((NOT Bt(3)) AND Bt(0)) OR ((NOT Bt(3)) AND Bt(2) AND (NOT Bt(1)));
    segment(5) <= ((NOT Bt(3)) AND (NOT Bt(2)) AND Bt(0)) OR ((NOT Bt(3)) AND (NOT Bt(2)) AND (Bt(1))) OR ((NOT Bt(3)) AND Bt(1) AND Bt(0)) OR (Bt(3) AND Bt(2) AND (NOT Bt(1)) AND Bt(0));
    segment(6) <= ((NOT Bt(3)) AND (NOT Bt(2)) AND (NOT Bt(1))) OR ((NOT Bt(3)) AND Bt(2) AND Bt(1) AND Bt(0)) OR (Bt(3) AND Bt(2) AND (NOT Bt(1)) AND (NOT Bt(0)));

    end process;

--define a process over the ridging edge for increase the refresh clk counter
    process(clk)
    begin 
    if rising_edge(clk) then
        refresh_clk <= refresh_clk + '1';
        end if ;
    end process;
    
    clk_input <= refresh_clk(19 downto 18);

-- define a process over the clock input for glowing the the 4 anodes according to their conditions

    process(clk_input)
    begin
    case( clk_input ) is

        when "00" =>
            anode <= "1110";
            Bt <= output_val(3 downto 0);

        when "01" =>
            anode <= "1101";
            Bt <= output_val(7 downto 4);
        when "10" =>
            anode <= "1011";
            Bt <= rx_perm_data(3 downto 0);

        when "11" =>
            anode <= "0111";
            Bt <= rx_perm_data(7 downto 4);
        when others => anode <= "1111";

    end case ;
    end process;
    -- define a process over the clk on ridging edge and put the value of rx_in into the rx_data
    process(clk)
    begin
        if rising_edge(clk) then
            rx_data <= rx_in;
        end if ;
    end process;

    -- define a process over rising edge of clk
    process(clk)
    begin
        if rising_edge(clk) then
            -- debouncer_counter <= debouncer_counter + 1;
            -- tx_start signal
            -- check when reset_sig is on then we reset each and everything 
            if reset_sig = '1' and reset_prev = '0' then
                rx_temp_data <= (others => '0');
                tx_out <= '1';
                head_addr <= "0000000000000";
                tail_addr <= "0000000000000";
                depth_counter <= 0;
                rx_state <= rx_idle; --reset receive state as idle
                tx_state <= tx_idle; --reset transmitter state as idle
                curr_state <= idle;
                tx_clk_counter <= 0;
                tx_index <= 0;
                rx_clk_counter <=0;
                rx_index <=0;
            end if;
            reset_prev <= reset_sig;
            case( rx_state ) is
            --when the state is in idle state then 
                when rx_idle =>
                    tx_out <= '1';
                    -- write_data <= '0';
                    rx_stop_bit <= '0';
                    rx_clk_counter <=0;
                    rx_index <=0;
                    --if rx_data =0 then go to the start state otherwise go to idle
                    if rx_data = '0' then
                        rx_state <= rx_start;
                    else
                        rx_state <= rx_idle;
                     end if ;
                --when the state in the start state 
                when rx_start =>
                    tx_out<='1';
                    -- if counter is 5208 and rx_data =0 then go to the data rx_data_shift otheriwse go to idle state if counter <5208 then stay on the start state
                    if rx_clk_counter = 5208 then
                        if rx_data = '0' then
                            rx_clk_counter <=0;
                            rx_state <= rx_data_shift;
                        else
                            rx_state <= rx_idle;
                        end if ;
                    elsif rx_clk_counter < 5208 then
                        rx_clk_counter <= rx_clk_counter+1;
                        rx_state <= rx_start;
                    else
                        rx_state <= rx_idle;
                    end if ;
                    --if state is data shift then 
                when rx_data_shift =>
                    tx_out <= '1';
                    -- if counter is 10416 if index is 7 then we go to the stop state  otherwise go to the rx_data_shift
                    if rx_clk_counter = 10416 then
                        rx_clk_counter <= 0;
                        rx_temp_data(rx_index) <= rx_data;
                        if rx_index = 7 then
                            rx_index <= 0;
                            rx_state <= rx_stop;
                        else
                            rx_index<=rx_index+1;
                            rx_state <= rx_data_shift;
                        end if ;
                    else
                        rx_clk_counter<=rx_clk_counter+1;
                        rx_state<=rx_data_shift;
                    end if ;
                    -- if state is stop state
                when rx_stop =>
                    tx_out <='1';
                    --if counter is 10416 and data is 1 then go to idle state until counter is not 10416 then stay in stop state
                    if rx_clk_counter = 10416 then
                        rx_clk_counter <= 0;
                        if rx_data = '1' then
                            rx_stop_bit<='1';
                            rx_perm_data <= rx_temp_data;
                            write_data <= '1';
                            ld_tx <= '1';
                            rx_clk_counter <= 0;
                            rx_state<=rx_idle;
                        else
                            rx_clk_counter <= 0;
                            rx_state<=rx_idle;
                        end if ;
                    else
                        rx_clk_counter <= rx_clk_counter + 1;
                        rx_state <= rx_stop;
                    end if ;

                when others =>
                    rx_state <= rx_idle;
            end case ;
            rx_perm_data <= rx_temp_data;
  
            case( tx_state ) is
            --when the state is in idle state then 
                when tx_idle =>
                    tx_out <= '1';
                    tx_clk_counter <= 0;
                    tx_index <= 0;
                    tx_stop_bit <= '0';
                    --if tx_data =1 then go to the start state otherwise go to idle
                    if tx_start_temp = '1'and tx_start_prev = '0' and  ld_tx = '1'  then  -- doubt
                        tx_temp_data <= rx_perm_data;
                        read_data <= '1';
                        tx_state <= txstart;
                    else
                        tx_state <= tx_idle;
                    end if ;
                    -- if state is start
                when txstart =>
                    tx_out <= '0';
                    read_data <= '0';
                    -- if counter is 10416 then go to tx_data_shift otheriwse go to start state
                    if tx_clk_counter = 10416 then
                        tx_clk_counter <= 0;
                        tx_state <= tx_data_shift;
                    else
                        tx_clk_counter <= tx_clk_counter + 1;
                        tx_state <= txstart;
                    end if ;
                    -- if state is data shift 
                when tx_data_shift =>
                    tx_out <= output_val(tx_index);
                    -- if counter is less than 10416 go to data state
                    if tx_clk_counter < 10416 then
                        tx_clk_counter <= tx_clk_counter + 1;
                        tx_state <= tx_data_shift;
                    else
                    -- if index less than 7 go to data shift otherwise go to stop state
                        tx_clk_counter <= 0;
                        if tx_index < 7 then
                            tx_index <= tx_index +1;
                            tx_state <= tx_data_shift;
                        else
                            tx_index <= 0;
                            tx_state <= tx_stop;
                        end if ;
                    end if;
                -- if state is stop state 
                when tx_stop =>
                    tx_out <= '1';
                    -- if counter is 10416 then go to idle state otherwise go to tx_read_conti state 
                    if tx_clk_counter = 10416 then
                        tx_stop_bit <= '1';
                        tx_clk_counter <= 0;
                        if depth_counter = 0 then
                            ld_tx <= '0';
                            tx_state <= tx_idle;
                        else
                            tx_state <= tx_read_conti;
                        end if ;
                        -- tx_state <= tx_idle;
                    else
                        tx_clk_counter <= tx_clk_counter + 1;
                        tx_state <= tx_stop;
                    end if ;
                when tx_read_conti =>
                    read_data <= '1';
                    tx_state <= txstart;
                when others =>
                    tx_state<=tx_idle;
            
            
            end case ;
            tx_start_prev <= tx_start_temp;
            case( curr_state ) is
                -- if state is idle 
                when idle =>
                  -- if depth_counter = 0 then
                  --   emp_sig <= '1';
                  --   full_sig <= '0';
                    
                  -- elsif depth_counter = 10 then
                  --   emp_sig <= '0';
                  --   full_sig <= '1';
                    
                  -- else
                  --   emp_sig <= '0';
                  --   full_sig <= '0';
                    
                  -- end if ;
                  en<='0';
                  we <= "0";
                  debouncer_wait <= '0';
                  --id read data is 1 then read the data 
                  if read_data = '1' then
                    en <= '1';
                    we <= "0";
                    debouncer_wait <= '1';
                    read_data <= '0';
                    curr_state<=read_fifo;
                  elsif write_data = '1' then 
                  --id write data is 1 then write the data 
                    write_data <= '0';
                    en <= '1';
                    we <= "1";
                    debouncer_wait <= '1';
                    curr_state<=write_fifo;
                  else
                    curr_state<=idle;
                  end if ;
                --if state is write fifo then write in the queue
                when write_fifo =>
                  if debouncer_wait <= '1' then 
                    if depth_counter < 8191 then
                      addr <= head_addr(12 downto 0);
                      depth_counter <= depth_counter + 1;
                      din <= rx_perm_data;
                      head_addr <= head_addr + 1;
                      debouncer_wait <= '0';
                      curr_state<= idle;
                    else
                      curr_state<=idle;
                    end if ;
          
                  else
                    debouncer_wait <= '1';
                    curr_state <= idle;
                  end if;
          -- if state is read fifo then read the data 
                when read_fifo =>
                  if debouncer_wait <= '1' then 
                    if depth_counter > 0 then
                      addr <= tail_addr(12 downto 0);
                      tail_addr <= tail_addr + 1;
                      depth_counter <= depth_counter - 1;
                    --   debouncer_wait <= '0';
                      count <= 1;
                      curr_state <= read_en;
                    else
                      curr_state <= idle;
                    end if ;
                    -- curr_state <= idle; for else
                  else
                    debouncer_wait <= '1';
                    curr_state <= idle;
                  end if;
                when read_en =>
                  if count < 3  then
                      count<= count +1;
                  elsif count = 3 then
                      output_val <= dout;
                      curr_state <= idle;
                      en <= '0';
                      we <= "0";
                  end if ;
                when others =>
                  curr_state<=idle;
              end case ;
              
            
        end if ;
    end process;
    -- if process is clk over the rising edge
    process(clk)
    begin
        if rising_edge(clk) then
        -- if counter is zero then set led empty as 0
            if depth_counter = 0 then
                led_e <='1';
            else
                led_e <= '0';
            end if ;
            
            if depth_counter = 8191 then
                led_f <= '1';
            else
                led_f <= '0';
            end if ;
        end if ;
    end process;
end Behavioral;
