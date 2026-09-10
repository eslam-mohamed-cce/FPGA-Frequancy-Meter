library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity freq_meter_5digit_dot is
    Port (
        clk_2hz  : in  STD_LOGIC;                    -- 2Hz input
        tgt_clk  : in  STD_LOGIC;                   
        lcd_rs   : out STD_LOGIC;                    
        lcd_en   : out STD_LOGIC;                   
        lcd_db   : out STD_LOGIC_VECTOR (7 downto 4) 
    );
end freq_meter_5digit_dot;

architecture Behavioral of freq_meter_5digit_dot is

    -- Gate & Timing Control
    signal gate_1hz          : std_logic := '0';
    signal prescale_cnt      : integer range 0 to 49 := 0;
    signal point1_khz_pulse  : std_logic := '0';

    -- Synchronizer Signals
    signal gate_sync0        : std_logic := '0';
    signal gate_sync1        : std_logic := '0';
    signal gate_prev         : std_logic := '0';

    -- BCD
    type bcd_array is array (0 to 4) of unsigned(3 downto 0);
    signal bcd_cnt           : bcd_array := (others => (others => '0'));
    signal bcd_latched       : bcd_array := (others => (others => '0'));

    -- LCD State Machine
    type state_type is (
        ST_RESET,
        ST_INIT1, ST_INIT2, ST_INIT3, ST_INIT4, 
        ST_FUNC_H, ST_FUNC_L,
        ST_DISP_H, ST_DISP_L,
        ST_CLR_H,  ST_CLR_L,
        ST_ENTRY_H, ST_ENTRY_L,
        ST_D4_H, ST_D4_L,
        ST_D3_H, ST_D3_L,
        ST_D2_H, ST_D2_L,
        ST_D1_H, ST_D1_L,
        ST_DOT_H, ST_DOT_L,
        ST_D0_H, ST_D0_L,
        ST_K_H, ST_K_L,
        ST_H_H, ST_H_L,
        ST_Z_H, ST_Z_L,
        ST_HOME_H, ST_HOME_L
    );
    signal state      : state_type := ST_RESET;
    signal en_active  : std_logic := '0';

begin

    lcd_en <= en_active and clk_2hz;

    ------------------------------------------------------------------
    -- 1. Gate Signal Generation
    ------------------------------------------------------------------
    process(clk_2hz)
    begin
        if rising_edge(clk_2hz) then
            gate_1hz <= not gate_1hz;
        end if;
    end process;

    ------------------------------------------------------------------
    -- 2. Prescaler + BCD Counter
    ------------------------------------------------------------------
    process(tgt_clk)
    begin
        if rising_edge(tgt_clk) then
           
            gate_sync0 <= gate_1hz;
            gate_sync1 <= gate_sync0;
            gate_prev  <= gate_sync1;

           
            if (gate_prev = '1' and gate_sync1 = '0') then
                bcd_latched      <= bcd_cnt;                      
                bcd_cnt          <= (others => (others => '0'));  
                prescale_cnt     <= 0;                           
                point1_khz_pulse <= '0';
            
           
            elsif gate_sync1 = '1' then
                if prescale_cnt = 49 then
                    prescale_cnt     <= 0;
                    point1_khz_pulse <= '1';
                else
                    prescale_cnt     <= prescale_cnt + 1;
                    point1_khz_pulse <= '0';
                end if;
                
                if point1_khz_pulse = '1' then
                    if bcd_cnt(0) = 9 then
                        bcd_cnt(0) <= (others => '0');
                        if bcd_cnt(1) = 9 then
                            bcd_cnt(1) <= (others => '0');
                            if bcd_cnt(2) = 9 then
                                bcd_cnt(2) <= (others => '0');
                                if bcd_cnt(3) = 9 then
                                    bcd_cnt(3) <= (others => '0');
                                    if bcd_cnt(4) < 9 then
                                        bcd_cnt(4) <= bcd_cnt(4) + 1;
                                    end if;
                                else
                                    bcd_cnt(3) <= bcd_cnt(3) + 1;
                                end if;
                            else
                                bcd_cnt(2) <= bcd_cnt(2) + 1;
                            end if;
                        else
                            bcd_cnt(1) <= bcd_cnt(1) + 1;
                        end if;
                    else
                        bcd_cnt(0) <= bcd_cnt(0) + 1;
                    end if;
                end if;
            else
                prescale_cnt <= 0;
            end if;
        end if;
    end process;

    ------------------------------------------------------------------
    -- 3. LCD State Machine (4-bit Mode Protocol)
    ------------------------------------------------------------------
    process(clk_2hz)
    begin
        if rising_edge(clk_2hz) then
            case state is

                when ST_RESET =>
                    en_active <= '0'; lcd_rs <= '0'; lcd_db <= "0000";
                    state <= ST_INIT1;

               
                when ST_INIT1 => lcd_rs <= '0'; lcd_db <= "0011"; en_active <= '1'; state <= ST_INIT2;
                when ST_INIT2 => lcd_rs <= '0'; lcd_db <= "0011"; en_active <= '1'; state <= ST_INIT3;
                when ST_INIT3 => lcd_rs <= '0'; lcd_db <= "0011"; en_active <= '1'; state <= ST_INIT4;
                when ST_INIT4 => lcd_rs <= '0'; lcd_db <= "0010"; en_active <= '1'; state <= ST_FUNC_H;

                
                when ST_FUNC_H => lcd_rs <= '0'; lcd_db <= "0010"; en_active <= '1'; state <= ST_FUNC_L;
                when ST_FUNC_L => lcd_rs <= '0'; lcd_db <= "1000"; en_active <= '1'; state <= ST_DISP_H;

                when ST_DISP_H => lcd_rs <= '0'; lcd_db <= "0000"; en_active <= '1'; state <= ST_DISP_L;
                when ST_DISP_L => lcd_rs <= '0'; lcd_db <= "1100"; en_active <= '1'; state <= ST_CLR_H;

                when ST_CLR_H  => lcd_rs <= '0'; lcd_db <= "0000"; en_active <= '1'; state <= ST_CLR_L;
                when ST_CLR_L  => lcd_rs <= '0'; lcd_db <= "0001"; en_active <= '1'; state <= ST_ENTRY_H;

                when ST_ENTRY_H=> lcd_rs <= '0'; lcd_db <= "0000"; en_active <= '1'; state <= ST_ENTRY_L;
                when ST_ENTRY_L=> lcd_rs <= '0'; lcd_db <= "0110"; en_active <= '1'; state <= ST_D4_H;

               
                when ST_D4_H   => lcd_rs <= '1'; lcd_db <= "0011"; en_active <= '1'; state <= ST_D4_L;
                when ST_D4_L   => lcd_rs <= '1'; lcd_db <= std_logic_vector(bcd_latched(4)); en_active <= '1'; state <= ST_D3_H;

                when ST_D3_H   => lcd_rs <= '1'; lcd_db <= "0011"; en_active <= '1'; state <= ST_D3_L;
                when ST_D3_L   => lcd_rs <= '1'; lcd_db <= std_logic_vector(bcd_latched(3)); en_active <= '1'; state <= ST_D2_H;

                when ST_D2_H   => lcd_rs <= '1'; lcd_db <= "0011"; en_active <= '1'; state <= ST_D2_L;
                when ST_D2_L   => lcd_rs <= '1'; lcd_db <= std_logic_vector(bcd_latched(2)); en_active <= '1'; state <= ST_D1_H;

                when ST_D1_H   => lcd_rs <= '1'; lcd_db <= "0011"; en_active <= '1'; state <= ST_D1_L;
                when ST_D1_L   => lcd_rs <= '1'; lcd_db <= std_logic_vector(bcd_latched(1)); en_active <= '1'; state <= ST_DOT_H;

                when ST_DOT_H  => lcd_rs <= '1'; lcd_db <= "0010"; en_active <= '1'; state <= ST_DOT_L;
                when ST_DOT_L  => lcd_rs <= '1'; lcd_db <= "1110"; en_active <= '1'; state <= ST_D0_H;

                when ST_D0_H   => lcd_rs <= '1'; lcd_db <= "0011"; en_active <= '1'; state <= ST_D0_L;
                when ST_D0_L   => lcd_rs <= '1'; lcd_db <= std_logic_vector(bcd_latched(0)); en_active <= '1'; state <= ST_K_H;

                when ST_K_H    => lcd_rs <= '1'; lcd_db <= "0110"; en_active <= '1'; state <= ST_K_L;
                when ST_K_L    => lcd_rs <= '1'; lcd_db <= "1011"; en_active <= '1'; state <= ST_H_H;

                when ST_H_H    => lcd_rs <= '1'; lcd_db <= "0100"; en_active <= '1'; state <= ST_H_L;
                when ST_H_L    => lcd_rs <= '1'; lcd_db <= "1000"; en_active <= '1'; state <= ST_Z_H;

                when ST_Z_H    => lcd_rs <= '1'; lcd_db <= "0111"; en_active <= '1'; state <= ST_Z_L;
                when ST_Z_L    => lcd_rs <= '1'; lcd_db <= "1010"; en_active <= '1'; state <= ST_HOME_H;

                when ST_HOME_H => lcd_rs <= '0'; lcd_db <= "1000"; en_active <= '1'; state <= ST_HOME_L;
                when ST_HOME_L => lcd_rs <= '0'; lcd_db <= "0000"; en_active <= '1'; state <= ST_D4_H;

                when others =>
                    state <= ST_RESET;
            end case;
        end if;
    end process;

end Behavioral;