/* memory_sections.ld
 *
 * Linker script for RWU-RV64I Harvard architecture (Variant B, cache).
 *
 * Address map (data bus / D-Cache view):
 *   0x0000_0000 – 0x0000_1FFF  Scratchpad SRAM  (8 kB, R/W, bypasses D-Cache)
 *   0x0000_2000+               NOR Flash region  (R only, cached in D-Cache)
 *
 * Instruction bus (I-Cache) fetches independently from Flash at PC addresses.
 * .text lives at address 0 in instruction space with no conflict with scratchpad.
 *
 * Section layout:
 *   .text   VMA=LMA=0x0000        Instructions in Flash, fetched via I-Cache
 *   .rodata VMA=LMA=0x2000        Constants in Flash, read via D-Cache ld
 *   .data   VMA=0x1000 LMA=0x3000 Init data: lives in scratchpad, init image in Flash
 *   .bss    VMA=follows .data     Uninit data in scratchpad, zeroed by startup (NOLOAD)
 *   stack                         Scratchpad top at 0x1FF8, grows downward
 *   heap                          Scratchpad above .bss (_heap_start = _bss_end)
 */

ENTRY(_start)

SECTIONS
{
    /* Instructions reside in Flash, fetched via I-Cache */
    .text 0x00000000 : AT(0x00000000)
    {
        *(.text*)
        . = ALIGN(4);
    }

    /* Read-only constants in Flash D-Cache region, loaded via ld instructions */
    .rodata 0x00002000 : AT(0x00002000)
    {
        *(.rodata*)
        . = ALIGN(8);
    }

    /* Initialised data: binary image at Flash LMA 0x3000, runs from scratchpad VMA 0x1000.
     * VMA 0x1000 is safely above .text (≤ ~0x200) and well below stack top (0x1FF8). */
    .data 0x00001000 : AT(0x00003000)
    {
        _data_start = .;
        *(.data*)
        . = ALIGN(8);
        _data_end = .;
    }
    _data_lma = LOADADDR(.data);   /* = 0x3000, used by startup copy loop */

    /* Uninitialised data in scratchpad, not present in binary — zeroed by startup */
    .bss (NOLOAD) :
    {
        _bss_start = .;
        *(.bss*)
        *(COMMON)
        . = ALIGN(8);
        _bss_end = .;
    }
}

_stack_top  = 0x00001FF8;   /* scratchpad top, SP grows downward */
_heap_start = _bss_end;     /* bump-allocator base, grows upward  */
