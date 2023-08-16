/*
Source: https://sourceware.org/binutils/docs/ld/Scripts.html
Source: https://docs.rs/riscv-rt/latest/riscv_rt/
Source: https://docs.rust-embedded.org/embedonomicon/memory-layout.html
*/

/* Define memory layout (RAM only architecture) */
MEMORY {
    RAM : ORIGIN = 0x80000000, LENGTH =  16K   /* 1K = 1 KiBi = 1024 bytes */
}

/* Define sections */
SECTIONS {
    . = ORIGIN(RAM);
    .init : { *(.init) } > RAM /* Set init as first section, this is the program's entry point if the PC starts at zero */
    .text : { *(.text .text.*) } > RAM
    .rodata : { *(.rodata) } > RAM
    .data : { *(.data) } > RAM
    . = ALIGN(4);
}

/* Set aliases (since this is a RAM only architecture, all regions are in RAM) */
REGION_ALIAS("REGION_INIT", RAM);
REGION_ALIAS("REGION_TEXT", RAM);
REGION_ALIAS("REGION_RODATA", RAM);
REGION_ALIAS("REGION_DATA", RAM);

