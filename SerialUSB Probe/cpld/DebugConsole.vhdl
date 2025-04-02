library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity DebugConsole is
	port(   
        nRESET  : in  std_logic; -- global reset
        PHI0    : in  std_logic; -- CPU Clock

        -- Headers
        TEST1   : out std_logic;

        -- CPU
        A       : in  std_logic_vector(15 downto 0);
        D       : in  std_logic_vector(7 downto 0);
        RnW     : in  std_logic;
        SYNC    : in  std_logic;
        RDY     : out std_logic;

        -- FT245
        USB_LED : out std_logic;
        nRXF    : in  std_logic;
        nTXE    : in  std_logic;
        SD      : inout std_logic_vector(7 downto 0);
        nUSB_RD : out std_logic;
        USB_WR  : out std_logic
    );
end DebugConsole;

architecture behavioral of DebugConsole is

	ATTRIBUTE ENUM_ENCODING: STRING;

    TYPE xmitStates IS
	(
        wait_for_nRXF_low,
        set_nRD_low,
		keep_nRD_low,
		fetch_cpu,
		halt_cpu,
		read_cpu_bus,
        wait_for_nTXE_low,
        set_WR_high,
        send_next_byte,
        set_WR_low,
        wait_next_phi0,
        done
	);

	ATTRIBUTE ENUM_ENCODING OF xmitStates: TYPE IS 
        "0000 0001 0010 0011 0100 0101 0110 0111 1000 1001 1010 1011";
    SIGNAL xmitState: xmitStates;

    TYPE xmitDataStates IS
	(
		send_address_nibble3,
        send_address_nibble2,
        send_address_nibble1,
        send_address_nibble0,
        send_address_separator, -- < or > (function of R/W)
        send_data_nibble1,
        send_data_nibble0,
        send_cr,
        send_lf,
        done
	);

	ATTRIBUTE ENUM_ENCODING OF xmitDataStates: TYPE IS 
        "0000 0001 0010 0011 0100 0101 0110 0111 1000 1001";
    SIGNAL xmitDataState: xmitDataStates;

    function f_Hex2ASCII (
        r_Hex_IN : in std_logic_vector(3 downto 0))
        return std_logic_vector is variable v_TEMP : std_logic_vector(7 downto 0);
    begin
        if (r_Hex_IN = X"A") then
            v_TEMP := X"41";
        elsif (r_Hex_IN = X"B") then
            v_TEMP := X"42";
        elsif (r_Hex_IN = X"C") then
            v_TEMP := X"43";
        elsif (r_Hex_IN = X"D") then
            v_TEMP := X"44";
        elsif (r_Hex_IN = X"E") then
            v_TEMP := X"45";
        elsif (r_Hex_IN = X"F") then
            v_TEMP := X"46";
        else
            v_TEMP := "0011" & r_Hex_IN;  
        end if;
        return v_TEMP;
    end;

    signal addr0   : std_logic_vector(3 downto 0);
    signal addr1   : std_logic_vector(3 downto 0);
    signal addr2   : std_logic_vector(3 downto 0);
    signal addr3   : std_logic_vector(3 downto 0);
    signal data0   : std_logic_vector(3 downto 0);
    signal data1   : std_logic_vector(3 downto 0);

    signal counter : unsigned(3 downto 0);
    signal jumpCounter : unsigned(3 downto 0);
    signal jumpMode : std_logic;
    signal syncMode : std_logic;
    signal freerunMode  : std_logic;
    signal compositeClock : std_logic;
    signal cmdChar : std_logic;

    signal command : std_logic_vector(7 downto 0);
begin

    FT245_sm : process (PHI0, nRESET, SYNC, nTXE, nRXF, xmitState)
    begin
        if falling_edge(PHI0) then
            if (nRESET = '0') then
                xmitState     <= wait_for_nRXF_low;
                xmitDataState <= send_address_nibble3;
                nUSB_RD <= '1';
                USB_WR  <= '0';
                SD      <= (others=>'Z');
                RDY     <= '0';
                TEST1   <= '0';
                command      <= (others=>'0');
                freerunMode  <= '0';
                jumpMode     <= '0';
                jumpCounter  <= (others=>'1');
                syncMode     <= '0';
            else
                case xmitState is
                    when wait_for_nRXF_low =>         -- Wait for a new char
                        USB_LED <= '0';
                        USB_WR <= '0';
                        if nRXF = '0' then            -- A new char is available
                            command <= (others=>'0'); -- Clear previous char
                            nUSB_RD <= '0';           -- Ask for Read FT245
                            RDY <= '0';               -- halt CPU
                            xmitState <= set_nRD_low;
                        elsif freerunMode = '1' then        -- freerun mode is requested
                            RDY <= '1';                     -- Keep CPU active
                            xmitState <= wait_for_nRXF_low; -- Until a new char is detected
                            nUSB_RD <= '1';
                        else                                -- step mode
                            xmitState <= wait_for_nRXF_low; -- Just wait for a command
                            RDY <= '0';                     -- And keep CPU halted
                            nUSB_RD <= '1';
                        end if;
                    
                    when set_nRD_low =>  -- Read command
                        USB_LED <= '1';
                        command <= SD;
                        xmitState <= keep_nRD_low;
                    
                    when keep_nRD_low => -- Interpret command
                        if command = X"67" then -- g (Go)
                            freerunMode <= '1';    -- Set freerun mode
                            jumpMode <= '0';       -- Disable jump mode
                            syncMode <= '0';       -- Disable sync mode
                            cmdChar  <= '1';       -- Acknowledge (echo) command
                            xmitState <= read_cpu_bus;

                        elsif command = X"68" then -- h (Halt)
                            freerunMode <= '0';    -- Disable freerun mode
                            jumpMode <= '0';       -- Disable jump mode
                            cmdChar  <= '1';       -- Acknowledge (echo) command
                            xmitState <= read_cpu_bus;

                        elsif command = X"20" then -- <space> (Step)
                            command(0) <= '1';     -- Print '!' to acknowledge command
                            jumpMode <= '0';       -- Disable jump mode
                            xmitState <= fetch_cpu;

                        elsif command = X"62" then -- b (Bump 16 iterations)
                            jumpMode <= '1';       -- Set jump mode
                            cmdChar  <= '1';       -- Acknowledge (echo) command
                            xmitState <= read_cpu_bus;
                            jumpCounter <= (others=>'1');

                        elsif command = X"73" then -- s (Toggle ON/OFF SYNC on OpCode fetch)
                            if syncMode = '1' then -- Print 'q' (Quit Sync) to acknowledge command
                                command(1) <= not command(1); -- Toggle bit 1 to generate 'q'
                            end if;
                            cmdChar   <= '1';      -- Acknowledge (echo) command
                            syncMode  <= not syncMode; -- Toggle sync mode
                            xmitState <= read_cpu_bus;

                        else
                            xmitState <= done;     -- Not a command key
                        end if;

                    when fetch_cpu =>
                        RDY <= '1';      -- Enable CPU for one new cycle
                        xmitState <= halt_cpu;

                    when halt_cpu =>
                        RDY <= '0';      -- Halt CPU
                        USB_WR <= '0';

                        xmitState <= read_cpu_bus; -- Read 6502 busses

                    when read_cpu_bus =>
                        TEST1 <= '1';
                        addr0 <= A(3 downto 0);
                        addr1 <= A(7 downto 4);
                        addr2 <= A(11 downto 8);
                        addr3 <= A(15 downto 12);
                        data0 <= D(3 downto 0);
                        data1 <= D(7 downto 4);

                        if syncMode = '1' and SYNC = '0' then
                            xmitState <= wait_next_phi0;-- Wait for the next Phi0
                        else
                            xmitState <= wait_for_nTXE_low;

                            if jumpMode = '1' then
                                if jumpCounter = "0000" then
                                    jumpMode <= '0';
                                end if;
                                jumpCounter <= jumpCounter - 1; -- Decrement lines counter for printed lines only
                            end if;
                        end if;
                        
                        if cmdChar  = '1' then
                            xmitDataState <= send_data_nibble0; -- Echo only one char with crlf
                        else
                            xmitDataState <= send_address_nibble3; -- Print busses
                        end if;
                        nUSB_RD <= '1';

                    when wait_for_nTXE_low =>
                        TEST1 <= '0';
                        USB_WR <= '0';
                        if nTXE = '0' then
                            xmitState <= set_WR_high;
                        else
                            xmitState <= wait_for_nTXE_low;
                        end if;

                    when set_WR_high =>
                        -- Print 4 addresses nibbles
                        if xmitDataState = send_address_nibble3 then
                            SD <= f_Hex2ASCII(addr3);
                        elsif xmitDataState = send_address_nibble2 then
                            SD <= f_Hex2ASCII(addr2);
                        elsif xmitDataState = send_address_nibble1 then
                            SD <= f_Hex2ASCII(addr1);
                        elsif xmitDataState = send_address_nibble0 then
                            SD <= f_Hex2ASCII(addr0);
                        elsif xmitDataState = send_address_separator then
                            if (RnW = '0') then -- Separator between addresses and data
                                SD <= x"3e";    -- '>' for write cycle
                            else
                                SD <= x"3c";    -- '<' for read cycle
                            end if;
                        -- Print 2 data nibbles
                        elsif xmitDataState = send_data_nibble1 then
                            SD <= f_Hex2ASCII(data1);
                        elsif xmitDataState = send_data_nibble0 then
                            if cmdChar = '1' then
                                cmdChar <= '0';
                                SD <= command;            -- Print command ASCII char
                            else
                                SD <= f_Hex2ASCII(data0); -- Print a nibble
                            end if;
                        -- Go to next line
                        elsif xmitDataState = send_cr then
                            SD <= x"0d";                  -- Print CR
                        elsif xmitDataState = send_lf then
                            SD <= x"0a";                  -- Print NL
                        end if;

                        USB_WR  <= '1';
                        xmitState <= send_next_byte;

                    when send_next_byte =>
                        -- Manage the printing states machine
                        if xmitDataState = send_address_nibble3 then
                            xmitDataState <= send_address_nibble2;
                        elsif xmitDataState = send_address_nibble2 then
                            xmitDataState <= send_address_nibble1;
                        elsif xmitDataState = send_address_nibble1 then
                            xmitDataState <= send_address_nibble0;
                        elsif xmitDataState = send_address_nibble0 then
                            xmitDataState <= send_address_separator;
                        elsif xmitDataState = send_address_separator then
                            xmitDataState <= send_data_nibble1;
                        elsif xmitDataState = send_data_nibble1 then
                            xmitDataState <= send_data_nibble0;
                        elsif xmitDataState = send_data_nibble0 then
                            xmitDataState <= send_cr;
                        elsif xmitDataState = send_cr then
                            xmitDataState <= send_lf;
                        elsif xmitDataState = send_lf then
                            xmitDataState <= send_address_nibble3;
                        end if;

                        USB_WR <= '0';
                        xmitState <= set_WR_low;

                    when set_WR_low =>
                        if jumpMode = '1' then      -- Jump mode so go to print the
                            if xmitDataState = send_address_nibble3 then
                                xmitState <= fetch_cpu;    -- next buses status
                                
                            else
                                xmitState <= wait_for_nTXE_low;
                            end if;
                        elsif xmitDataState = send_address_nibble3 then
                            xmitState <= done;         -- Buses fully printed, ending loop
                        else
                            xmitState <= wait_for_nTXE_low;
                        end if;

                    when wait_next_phi0 =>
                        SD  <= (others=>'Z');
                        xmitState <= fetch_cpu;
                    
                    when others => 
                        nUSB_RD <= '1';
                        SD  <= (others=>'Z');
                        if jumpMode = '1' then
                            xmitState <= fetch_cpu;
                        else
                            xmitState <= wait_for_nRXF_low;
                        end if;
                        
                end case;
            end if;
        end if;
    end process;

end behavioral;