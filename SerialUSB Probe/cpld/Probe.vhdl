library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Probe is
    port(
        PHI_0       : in  std_logic;
        nRESET      : in  std_logic;

        -- Headers
        TEST1       : out std_logic;
        --TEST2       : out std_logic;
        --TEST3       : out std_logic;
        --TEST4       : out std_logic;

        -- 65C02
        RnW         : in  std_logic;
        SYNC        : in  std_logic;
        RDY         : out std_logic;
        A           : in  std_logic_vector(15 downto 0);
        D           : in  std_logic_vector(7 downto 0);

        -- FT245
        USB_LED     : out std_logic := '0';
        nRXF        : in  std_logic;
        nTXE        : in  std_logic;
        SD          : inout std_logic_vector(7 downto 0);
        nUSB_RD     : buffer std_logic;
        USB_WR      : buffer std_logic
    );
end Probe;

architecture behavioral of Probe is

    component DebugConsole is
        port(   
            nRESET  : in  std_logic; -- global reset
            PHI0    : in  std_logic;
            
            -- Headers
            TEST1   : out std_logic;
            
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
    end component;

    signal counter     : unsigned(15 downto 0);

begin

    -- Serial Console
    U_DEBUG : DebugConsole port map (
        nRESET  => nRESET,
        PHI0    => PHI_0,

        TEST1   => TEST1,

        A       => A,
        D       => D,
        RnW     => RnW,
        SYNC    => SYNC,
        RDY     => RDY,

        USB_LED => USB_LED,
        nRXF    => nRXF,
        nTXE    => nTXE,
        SD      => SD,
        nUSB_RD => nUSB_RD,
        USB_WR  => USB_WR
    );

end behavioral;