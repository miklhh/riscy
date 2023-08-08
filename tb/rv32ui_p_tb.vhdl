library ieee, work, vunit_lib;
context vunit_lib.vunit_context;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.riscy_conf.fault_type;
use work.riscy_conf.fault_to_string;

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
    signal clk, rst : std_logic;

    signal test_complete, test_failure : std_logic;
    signal core_fault : fault_type;
begin

    --
    -- VUnit test runner
    --
    vunit_test_runner : process
    begin
        test_runner_setup(runner, runner_cfg);
        wait until rst = '0';
        wait until test_complete = '1';
        test_runner_cleanup(runner);
    end process;

    --
    -- Time-out test
    --
    time_out_test : process
    begin
        wait for 100 us;
        report "Timeout: more than 100 000 clk cycles passed without success" severity failure;
    end process;

    --
    -- Fault test
    --
    core_fault_test : process
    begin
        wait until rising_edge(clk);
        assert core_fault = NONE
            report "CPU Core fault: " & fault_to_string(core_fault) severity failure;
    end process;

    --
    -- clk [1 GHz] and rst generation
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

        test_complete=>test_complete,
        test_failure=>test_failure,
        core_fault=>core_fault
    );

end architecture tb_rtl;

