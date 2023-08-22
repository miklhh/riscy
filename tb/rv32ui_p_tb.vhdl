library ieee, work, vunit_lib;
context vunit_lib.vunit_context;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.riscy_conf.all;

entity rv32ui_p_tb is
    generic(
        -- VUnit runner configuration
        runner_cfg  : string;   -- VUnit-Python pipe
        tb_path     : string;   -- Absolute path to this testbench

        -- Path to hex dump of unit test memory data
        hex_dump_file : string;
        test_name     : string
    );
end entity rv32ui_p_tb;

architecture tb_rtl of rv32ui_p_tb is

    -- Clock, reset
    signal clk, rst         : std_logic;

    -- CPU core fault and environment 
    signal core_fault       : fault_type;
    signal ecall            : std_logic;
    signal ecall_regs       : regfile_vector_type;

    -- Stall injection
    signal stall            : std_logic_vector(0 to 4);

begin

    --
    -- VUnit test runner
    --
    vunit_test_runner : process
    begin
        test_runner_setup(runner, runner_cfg);
        wait until rst = '0';
        -- Test finish successfully iff gp=1 and a0=0 during an ECALL
        wait until ecall = '1' and unsigned(ecall_regs(3)) = 1 and unsigned(ecall_regs(10)) = 0;
        report "Test '" & test_name & "' completed successfully" severity note;
        test_runner_cleanup(runner);
    end process;

    --
    -- Time-out tester
    --
    time_out_tester : process
    begin
        wait for 100 us;
        report "Timeout: more than 10 000 clk cycles passed without success" severity failure;
    end process;

    --
    -- Core fault tester
    --
    core_fault_tester : process
    begin
        wait until rising_edge(clk);

        -- First test if 
        if core_fault /= NONE then
            case core_fault is
                when UNIMPLEMENTED_INSTRUCTION_ERROR =>
                    report "CPU core fault: UNIMPLEMENTED_INSTRUCTION_ERROR" severity failure;
                when others =>
                    report "CPU core fault: UNKNOWN" severity failure;
            end case;
        end if;
    end process;

    --
    -- Unit test failure test
    --
    unit_test_fail_tester : process
    begin
        wait until ecall = '1';
        wait until clk = '0';
        assert unsigned(ecall_regs(3)) = 1 and unsigned(ecall_regs(10)) = 0
            report "Unit test failure (" & test_name & "): #" & 
                integer'image(to_integer(unsigned(ecall_regs(3)))/2)
                severity failure;
    end process;

    --
    -- clk [100 MHz] and rst generation
    --
    rst <= '1', '0' after 100 ns;
    process begin
        clk <= '0'; loop wait for 5 ns; clk <= not(clk); end loop;
    end process;

    --
    -- Design under test (RISC-V CPU)
    --
    DUT : entity work.riscy_top
    generic map(
        hex_dump_file=>hex_dump_file
    )
    port map (
        clk=>clk,
        rst=>rst,

        -- CPU core fault and environment 
        o_core_fault=>core_fault,
        o_ecall=>ecall,
        o_ecall_regs=>ecall_regs,

        i_stall=>stall
    );

    stall <= (others => '0');
    --process
    --begin
    --    wait for 10 ns;
    --    stall <= "00100";
    --    wait for 10 ns;
    --    stall <= "00000";
    --end process;

end architecture tb_rtl;

