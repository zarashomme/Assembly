//----------------------------------------------------------------------
// bigintaddopt.s
// Author: Zara Hommez
//----------------------------------------------------------------------
        .equ    FALSE, 0
        .equ    TRUE,  1

//----------------------------------------------------------------------
        .section .rodata
    
//----------------------------------------------------------------------
        .section .data
    
//----------------------------------------------------------------------
        .section .bss
    
//----------------------------------------------------------------------
        .section .text

        //--------------------------------------------------------------
        // Assign the sum of oAddend1 and oAddend2 to oSum.
        // oSum should be distinct from oAddend1 and oAddend2. Return 0
        // (FALSE) if an overflow occurred, and 1 (TRUE) otherwise.
        // BigInt_add(BigInt_T oAddend1, BigInt_T oAddend2, BigInt_T oSum)
        //--------------------------------------------------------------

        // Must be a multiple of 16
        .equ    ADD_STACK_BYTECOUNT, 64
        
        // Local variable registers:
        ULCARRY    .req x25   // Callee-saved
        ULSUM      .req x24   // Callee-saved
        LINDEX     .req x23   // Callee-saved
        LSUMLENGTH .req x22 

        // Parameter registers:
        OADDEND1   .req x21   // Callee-saved
        OADDEND2   .req x20   // Callee-saved
        OSUM       .req x19   // Calle-saved    

        // Magic number constant:
        .equ    MAX_DIGITS, 32768

        // Struct field offsets:
        // lLength is already 0, so it doesn't need an offset from the struct 
        .equ    AULDIGITS,  8

        .global BigInt_add

BigInt_add:
        // Prolog
        sub     sp, sp, ADD_STACK_BYTECOUNT
        str     x30, [sp]
        str     x25, [sp, 8]
        str     x24, [sp, 16]
        str     x23, [sp, 24]
        str     x22, [sp, 32]
        str     x21, [sp, 40]
        str     x20, [sp, 48]
        str     x19, [sp, 56]

        mov     OADDEND1, x0
        mov     OADDEND2, x1
        mov     OSUM, x2

        // unsigned long ulCarry
        // unsigned long ulSum
        // long lIndex
        // long lSumLength

        // When translating bigintadd.c to assembly language,
        // simply pretend that the calls of assert are not in the C code.

        // lSumLength = BigInt_larger(oAddend1->lLength, oAddend2->lLength)
        mov     x0, OADDEND1
        ldr     x0, [x0]
        mov     x1, OADDEND2
        ldr     x1, [x1]
        cmp     x0, x1
        csel    LSUMLENGTH, x0, x1, gt

        // if (oSum->lLength <= lSumLength) goto rstCarry
        mov     x0, OSUM
        ldr     x0, [x0]
        cmp     x0, LSUMLENGTH
        ble     rstCarry

        // memset(oSum->aulDigits, 0, MAX_DIGITS * sizeof(unsigned long))
        mov     x0, OSUM
        add     x0, x0, AULDIGITS
        mov     x1, 0
        mov     x2, MAX_DIGITS
        mov     x3, 8
        mul     x2, x2, x3
        bl      memset
        b       rstCarry

rstCarry:
        // Use pointer-based, 2x-unrolled ADCS loop.
        // Keep LSUMLENGTH (x22) intact. Use x9=xP1, x10=xP2, x11=xPS, x8=remaining counter.
        // ulCarry implicitly in carry flag; initialize it to 0.
        mov     ULCARRY, 0
        mov     LINDEX, 0

        // P1 = oAddend1->aulDigits (caller-saved x9)
        mov     x9, OADDEND1
        add     x9, x9, AULDIGITS
        // P2 = oAddend2->aulDigits (caller-saved x10)
        mov     x10, OADDEND2
        add     x10, x10, AULDIGITS
        // PS = oSum->aulDigits (caller-saved x11)
        mov     x11, OSUM
        add     x11, x11, AULDIGITS

        // remaining = LSUMLENGTH
        mov     x8, LSUMLENGTH

        // Clear carry flag
        ands    xzr, xzr, xzr

        // Loop: process pairs while remaining >= 2
loop_pair:
        // if remaining == 0 -> done (carryOutCheck)
        cbz     x8, carryOutCheck
        // if remaining == 1 -> handle tail
        mov     x14, x8
        sub     x14, x14, #1
        cbz     x14, tail_single

        // Load two words from each addend (post-increment by 16)
        ldp     x0, x1, [x9], #16
        ldp     x2, x3, [x10], #16

        // Add low words with carry, then high words preserving carry
        adcs    x12, x0, x2
        adcs    x13, x1, x3

        // Store pair of results
        stp     x12, x13, [x11], #16

        // decrement remaining by 2
        sub     x8, x8, #2
        b       loop_pair

tail_single:
        cbz     x8, carryOutCheck
        // handle last word
        ldr     x0, [x9], #8
        ldr     x2, [x10], #8
        adcs    x12, x0, x2
        str     x12, [x11], #8

carryOutCheck:
        // if carry flag == 0 goto trueRet
                bcc     trueRet

    // if (lSumLength == MAX_DIGITS) goto returnFalse
        // compare against MAX_DIGITS using a register-held immediate
        mov     x0, MAX_DIGITS
        cmp     LSUMLENGTH, x0
        beq     returnFalse

    // oSum->aulDigits[lSumLength] = 1
    mov     x0, OSUM
    add     x0, x0, AULDIGITS
    mov     x1, 1
    str     x1, [x0, LSUMLENGTH, lsl 3]

    // lSumLength++
    add LSUMLENGTH, LSUMLENGTH, 1
    b       trueRet

returnFalse:
    // return FALSE
        mov     x0, FALSE
        // restore saved registers and return
        ldr     x30, [sp]
        ldr     x25, [sp, 8]
        ldr     x24, [sp, 16]
        ldr     x23, [sp, 24]
        ldr     x22, [sp, 32]
        ldr     x21, [sp, 40]
        ldr     x20, [sp, 48]
        ldr     x19, [sp, 56]
        add     sp, sp, ADD_STACK_BYTECOUNT
        ret

trueRet:
    // oSum->lLength = lSumLength
    mov     x0, OSUM
    str     LSUMLENGTH, [x0]

    // return TRUE
    mov     x0, TRUE
    ldr     x30, [sp]
    ldr     x25, [sp, 8]
    ldr     x24, [sp, 16]
    ldr     x23, [sp, 24]
    ldr     x22, [sp, 32]
    ldr     x21, [sp, 40]
    ldr     x20, [sp, 48]
    ldr     x19, [sp, 56]
    add     sp, sp, ADD_STACK_BYTECOUNT
    ret
    .size   BigInt_add, (. - BigInt_add)
