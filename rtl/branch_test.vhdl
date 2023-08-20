--
-- Riscy RISC-V branch tester
-- Author: Mikael Henriksson (2023)
--

library ieee, work;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.riscy_conf.all;

entity riscy_branch_test is
    port(
        i_clk, i_rst        : in std_logic;

        -- Input 1 (RS1)
        i_opa               : in std_logic_vector(XLEN-1 downto 0);

        -- Input 2 (RS2)
        i_opb               : in std_logic_vector(XLEN-1 downto 0);

        -- Control signals
        i_opcode            : in std_logic_vector(6 downto 0);
        i_funct3            : in std_logic_vector(2 downto 0);
        i_funct7            : in std_logic_vector(6 downto 0);
        i_skip              : in std_logic;
        i_stall             : in std_logic;

        -- Output
        o_branch_take0      : out std_logic;   -- Take branch this clock cycle (lower priority)
        o_branch_take1      : out std_logic    -- Take branch next clock cycle (higher priority)
    );
end entity riscy_branch_test;

architecture riscy_branch_test_rtl of riscy_branch_test is
    signal opa_extended     : signed(XLEN+1 downto 0);
    signal opb_extended     : signed(XLEN+1 downto 0);
    signal difference       : signed(XLEN+1 downto 0); 
    signal difference_zero  : std_logic;
    signal sign_extend      : std_logic;
    signal branch_take0     : std_logic;  -- Take branch this clock cycle (lower priority)
    signal branch_take1     : std_logic;  -- Take branch next clock cycle (higher priority)
    signal branch_take1_reg : std_logic;
begin

    -- Subtract operand B from A
    opa_extended(XLEN-1 downto 0) <= signed(i_opa);
    opb_extended(XLEN-1 downto 0) <= signed(i_opb);
    opa_extended(XLEN) <= opa_extended(XLEN-1) when sign_extend = '1' else '0';
    opb_extended(XLEN) <= opb_extended(XLEN-1) when sign_extend = '1' else '0';
    opa_extended(XLEN+1) <= opa_extended(XLEN);
    opb_extended(XLEN+1) <= opb_extended(XLEN);
    difference <= opa_extended-opb_extended;
    difference_zero <= '1' when difference = 0 else '0';

    -- Sign extension during BEQ, BNE, BLT, BGE
    sign_extend <= '1' when to_opcode(i_opcode) = BRANCH and i_funct3(1) = '0' else '0';

    -- Branch take logic
    process(i_opcode, i_funct3, difference, difference_zero)
    begin
        case to_opcode(i_opcode) is
            when JAL =>
                branch_take0 <= '1';
                branch_take1 <= '0';
            when JALR =>
                branch_take0 <= '0';
                branch_take1 <= '1';
            when BRANCH =>
                case i_funct3 is
                    when "000" =>  -- BEQ
                        branch_take0 <= difference_zero;
                        branch_take1 <= '0';
                    when "001" =>  -- BNE
                        branch_take0 <= not(difference_zero);
                        branch_take1 <= '0';
                    when "100" =>  -- BLT
                        branch_take0 <= difference(XLEN+1);
                        branch_take1 <= '0';
                    when "101" =>  -- BGE
                        branch_take0 <= not(difference(XLEN+1));
                        branch_take1 <= '0';
                    when "110" =>  -- BLTU
                        branch_take0 <= difference(XLEN+1);
                        branch_take1 <= '0';
                    when "111" =>  -- BGEU
                        branch_take0 <= not(difference(XLEN+1));
                        branch_take1 <= '0';
                    when others => 
                        branch_take0 <= '0';
                        branch_take1 <= '0';
                end case;
            when others => 
                branch_take0 <= '0';
                branch_take1 <= '0';
        end case;
    end process;

    o_branch_take0 <= branch_take0 and not(i_skip);
    process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_stall = '1' then
                branch_take1_reg <= branch_take1_reg;
            else
                branch_take1_reg <= branch_take1 and not(i_skip);
            end if;
        end if;
    end process;
    o_branch_take1 <= branch_take1_reg;

    -- Sanity check
    assert not(branch_take0 = '1' and branch_take1 = '1')
        report "ALU: can not take branch this cycle and next cycle"
        severity failure;

end architecture riscy_branch_test_rtl;
