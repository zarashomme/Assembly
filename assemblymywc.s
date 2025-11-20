
/*--------------------------------------------------------------------*/

/* Write to stdout counts of how many lines, words, and characters
   are in stdin. A word is a sequence of non-whitespace characters.
   Whitespace is defined by the isspace() function. Return 0. */

//----------------------------------------------------------------------
// assemblymywc.s
// Author: Zara Hommez
//----------------------------------------------------------------------

        .equ    FALSE, 0
        .equ    TRUE,  1

//----------------------------------------------------------------------
        .section .rodata

outputInfo:
        .string "%7ld %7ld %7ld\n"

//----------------------------------------------------------------------
        .section .data

lLineCount:
        .quad   0

lWordCount:
        .quad   0

lCharCount:
        .quad   0

iInWord:
        .word   FALSE

//----------------------------------------------------------------------
        .section .bss

iChar:
        .skip   4

//----------------------------------------------------------------------
        .section .text

        //--------------------------------------------------------------
        // Write to stdout counts of how many lines, words, and characters
        // are in stdin. A word is a sequence of non-whitespace characters.
        // Whitespace is defined by the isspace() function. Return 0.
        //--------------------------------------------------------------

        // Must be a multiple of 16
        .equ    MAIN_STACK_BYTECOUNT, 16

        .global main

main:
        // Prolog
        sub     sp, sp, MAIN_STACK_BYTECOUNT
        str     x30, [sp]

readLoop:
        // if ((iChar = getchar()) == EOF) goto exitLoop
        bl      getchar
        adr     x1, iChar
        str     w0, [x1]
        ldr     w0, [x1]
        cmp     w0, -1
        beq     exitLoop

        // lCharCount++
        adr     x0, lCharCount
        ldr     x1, [x0]
        add     x1, x1, 1
        str     x1, [x0]

        // if (!isspace(iChar)) goto checkElse 
        adr     x0, iChar
        ldr     w0, [x0]
        bl      isspace
        cmp     w0, 0
        beq     checkElse

        // if (!iInWord) goto readLoopEnd
        adr     x0, iInWord
        ldr     w0, [x0]
        cmp     w0, 0
        beq     readLoopEnd

        // lWordCount++
        adr     x0, lWordCount
        ldr     x1, [x0]
        add     x1, x1, 1
        str     x1, [x0]

        // iInWord = FALSE 
        mov     w0, FALSE
        adr     x1, iInWord
        str     w0, [x1]
        // goto readLoopEnd
        b       readLoopEnd

checkElse:
        // if (iInWord) goto readLoopEnd
        adr     x0, iInWord
        ldr     w0, [x0]
        cmp     w0, 1
        beq     readLoopEnd

        // iInWord = TRUE
        mov     w0, TRUE
        adr     x1, iInWord
        str     w0, [x1]
        b       readLoopEnd

readLoopEnd:
        // if (iChar != '\n') goto readLoop
        adr     x0, iChar
        ldr     w0, [x0]
        cmp     w0, '\n'
        bne     readLoop

        // lLineCount++
        adr     x0, lLineCount
        ldr     x1, [x0]
        add     x1, x1, 1
        str     x1, [x0]

        // goto readLoop
        b       readLoop

exitLoop:
        // if (!iInWord) goto printInfo
        adr     x0, iInWord
        ldr     w0, [x0]
        cmp     w0, 0
        beq     printInfo

        // lWordCount++
        adr     x0, lWordCount
        ldr     x1, [x0]
        add     x1, x1, 1
        str     x1, [x0]
        // goto printInfo 
        b       printInfo

printInfo:
        // printf("%7ld %7ld %7ld\n", lLineCount, lWordCount, lCharCount)
        adr     x0, outputInfo
        adr     x1, lLineCount
        ldr     x1, [x1]
        adr     x2, lWordCount
        ldr     x2, [x2]
        adr     x3, lCharCount
        ldr     x3, [x3]
        bl      printf

        // Epilog and return 0
        mov     w0, 0
        ldr     x30, [sp]
        add     sp, sp, MAIN_STACK_BYTECOUNT
        ret

        .size   main, (. - main)
