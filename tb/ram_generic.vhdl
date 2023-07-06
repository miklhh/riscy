--
-- Synchronous generic RAM with asynchronous 'cheat' back port for initialization.
-- This RAM is NOT synthesizable and is only to be used in simulations.
--
-- Author: Mikael Henriksson (2022)
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.math_real.ceil;
use ieee.math_real.log2;
use ieee.std_logic_textio.all;
use std.textio.all;

package ram_generic_package is
    type memory_data_type is array(natural range <>) of std_logic_vector;
    component ram_generic is
        generic(
            -- Number of bits used in each word of the RAM
            word_length    : natural := 32;

            -- Total number of words in the RAM
            words          : natural := 16#8000#;

            -- Filename of file which content will be used to initialize the RAM. Each word in the
            -- RAM will be initialized with the content of one row from the file.
            init_file_name : string := "";

            -- Line number (zero indexed) from which to start reading the file from. Left unset (0)
            -- to read from the begining of the file.
            line_start     : natural := 0;

            -- Number of hexadecimal characters to read from each line into a RAM word. Left unset
            -- (0) to use the word_length parameter to decide how many hexadecimal characters are to
            -- be read. It only makes sense to set this parameter if you intend to also set the
            -- 'upper' and 'lower' parameter.
            line_len       : natural := 0;

            -- Range used when moving a read line into a RAM word.
            -- ```
            -- ram_generic(word) <= line(upper downto lower)
            -- ```
            -- The difference upper-lower must be small enough to fit into a single RAM word. Left
            -- unset (0) to use the word length to determine 'upper' and 'lower'.
            upper          : integer := 0;
            lower          : integer := 0
        );
        port(
            clk         : in std_logic;

            -- Synchronous port
            rw          : in std_logic;
            ce          : in std_logic;
            address     : in std_logic_vector(integer(ceil(log2(real(words)))) - 1 downto 0);
            data_in     : in std_logic_vector(word_length - 1 downto 0);
            data_out    : out std_logic_vector(word_length - 1 downto 0)
        );
    end component;

    --
    -- Impure function used for reading memory content from a file into a 'memory_data_type'. This
    -- function can be used to initialize the content of the ram memory from a file. If no file-name
    -- is proveded, this function returns an empty 'memory_data_type'.
    --
    impure function mem_read_from_file(
        file_name:   String;
        word_length: natural;
        words:       natural;
        line_start:  natural;
        line_len:    natural;
        upper:       integer;
        lower:       integer
    ) return memory_data_type;

end package ram_generic_package;

package body ram_generic_package is

    --
    -- Impure function used for reading memory content from a file into a 'memory_data_type'. This
    -- function can be used to initialize the content of the ram memory from a file. If no file-name
    -- is proveded, this function returns an empty 'memory_data_type'.
    --
    impure function mem_read_from_file(
        file_name:   String;
        word_length: natural;
        words:       natural;
        line_start:  natural;
        line_len:    natural;
        upper:       integer;
        lower:       integer
    ) return memory_data_type is
        variable memory : memory_data_type(0 to words-1)(word_length-1 downto 0);
        file     fd               : text;
        variable line_content     : line;
        variable word_data        : std_logic_vector(
                                        integer(ceil(real(word_length)/real(4)))*4 - 1 downto 0
                                    );
        variable word_data_custom : std_logic_vector(4*line_len-1 downto 0);
    begin
        if file_name /= "" then
            -- Open file for reading
            file_open(fd, file_name, read_mode);

            -- Discard lines until we reach the starting line
            for i in 0 to line_start-1 loop
                readline(fd, line_content);
            end loop;

            -- Read memory content from file, one word (line) at a time
            for word in 0 to words-1 loop

                -- Make sure file contains another line to read
                if endfile(fd) then
                    -- No more data in file, fill memory with unknowns
                    memory(word) := (others => 'U');
                    next;
                end if;

                readline(fd, line_content);
                if line_len /= 0 then

                    -- The line length (number of hexadecimal characters to be read from each line)
                    -- has been specified by the user. Read into the custom length buffer and store
                    -- into memory.
                    hread(line_content, word_data_custom);
                    if upper = 0 and lower = 0 then
                        memory(word) := word_data_custom(word_length-1 downto 0);
                    else
                        memory(word) := word_data_custom(upper downto lower);
                    end if;

                else

                    -- The line length (number of hexadecimal characters to be read from each line)
                    -- has not been set by the user. Use the word length of RAM words to determine
                    -- length.
                    hread(line_content, word_data);
                    if upper = 0 and lower = 0 then
                        memory(word) := word_data(word_length-1 downto 0);
                    else
                        memory(word) := word_data(upper downto lower);
                    end if;

                end if;
            end loop;


            file_close(fd);
        else
            -- No filename provided, fill memory with zeros
            for word in 0 to words-1 loop
                memory(word) := (others => '0');
            end loop;
        end if;
        return memory;
    end function;

end package body;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.ceil;
use ieee.math_real.log2;
use ieee.std_logic_textio.all;
use std.textio.all;
use work.ram_generic_package.all;

entity ram_generic is
    generic(
        -- Number of bits used in each word of the RAM
        word_length    : natural := 32;

        -- Total number of words in the RAM
        words          : natural := 16#8000#;

        -- Filename of file which content will be used to initialize the RAM. Each word in the RAM
        -- will be initialized with the content of one row from the file.
        init_file_name : string := "";

        -- Line number (zero indexed) from which to start reading the file from. Left unset (0) to
        -- read from the begining of the file.
        line_start     : natural := 0;

        -- Number of hexadecimal characters to read from each line into a RAM word. Left unset (0)
        -- to use the word_length parameter to decide how many hexadecimal characters are to be
        -- read. It only makes sense to set this parameter if you intend to also set the 'upper' and
        -- 'lower' parameter.
        line_len       : natural := 0;

        -- Range used when moving a read line into a RAM word.
        -- ```
        -- ram_generic(word) <= line(upper downto lower)
        -- ```
        -- The difference upper-lower must be small enough to fit into a single RAM word. Left
        -- unset (0) to use the word length to determine 'upper' and 'lower'.
        upper          : integer := 0;
        lower          : integer := 0
    );
    port(
        clk         : in std_logic;

        -- Synchronous port
        rw          : in std_logic;
        ce          : in std_logic;
        address     : in std_logic_vector(integer(ceil(log2(real(words)))) - 1 downto 0);
        data_in     : in std_logic_vector(word_length - 1 downto 0);
        data_out    : out std_logic_vector(word_length - 1 downto 0)
    );
end entity ram_generic;

architecture rtl of ram_generic is
    signal mem_space : memory_data_type(0 to words - 1)(word_length - 1 downto 0) := 
        mem_read_from_file(init_file_name, word_length, words, line_start, line_len, upper, lower);
begin

    --
    -- Read port
    --
    read_proc : process(clk)
    begin
        if rising_edge(clk) then
            if ce = '1' and rw = '1' then
                data_out <= mem_space(to_integer(unsigned(address)));
            else
                data_out <= (others => '-');
            end if;
        end if;
    end process read_proc;

    --
    -- Write port
    --
    write_proc : process(clk)
    begin
        -- Synchronous write
        if rising_edge(clk) then
            if ce = '1' and rw = '0' then
                mem_space(to_integer(unsigned(address))) <= data_in;
            end if;
        end if;
    end process write_proc;

end architecture rtl;
