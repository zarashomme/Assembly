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
        .equ    ADD_STACK_BYTECOUNT, 32
        
        // Local variable registers:
        // ULCARRY removed since it's handled by carry flag
        // LINDEX replaced by decrementer later in code
        ULSUM      .req x23   // Callee-saved
        LSUMLENGTH .req x22   // Calle-saved

        // Param registers OADDEND1/OADDEND2 replaced with scratch register
        // Parameter register: 
        OSUM       .req x19   // Callee-saved   

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
        str     x23, [sp, 8]
        str     x22, [sp, 16]
        str     x19, [sp, 24]
       
        // for optimization, use manipulable caller-saved regs. 
        // x9 = oAddend1->lLength (caller-saved x9)
        mov     x9, x0
        // x10 = oAddend2->lLength (caller-saved x10)
        mov     x10, x1 
        // x11 = oSum->lLength (caller-saved x11)
        mov     OSUM, x2

        // unsigned long ulSum
        // long lSumLength

        // When translating bigintadd.c to assembly language,
        // simply pretend that the calls of assert are not in the C code.

        // lSumLength = BigInt_larger(oAddend1->lLength, oAddend2->lLength)
        // -> converted to inline assembly (eliminated BigInt_larger) 
        mov     x0, x9
        ldr     x0, [x0]
        mov     x1, x10
        ldr     x1, [x1]
        cmp     x0, x1
        // sets LSUMLENGTH to x0 if greater(gt) than x1 else x1 
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

        // set pointers to top of aulDigits, saves loading time
        // these pointers will be adjusted during loop traversals
        // x9 = oAddend1->aulDigits 
        add     x9, x9, AULDIGITS
        // x10 = oAddend2->aulDigits 
        add     x10, x10, AULDIGITS
        // x11 = oSum->aulDigits (caller-saved x11)
        mov     x11, OSUM
        add     x11, x11, AULDIGITS

        // decrementer = LSUMLENGTH
        // starts at max, decrementing to 0 digits left
        mov     x8, LSUMLENGTH

        // verify that carry flag is cleared before loop 
        ands    xzr, xzr, xzr

        // loop processes two digits together while decrementer >= 2
loopSum_two:
        // if (decrementer == 0) i.e. branch if zero goto carryOutCheck
        cbz     x8, carryOutCheck
        // if (decrementer == 1) goto remaining_digit
        cmp     x8, 1 
        beq     remaining_digit

        // Load two digits from each addend 
        // post-increment by 16 for collection of next pair
        ldp     x0, x1, [x9], 16
        ldp     x2, x3, [x10], 16

        // adcs = add with carry-in and set flags 
        // Add first pair with carry, then second pair preserving carry
        adcs    x12, x0, x2
        adcs    x13, x1, x3

        // store both additions into digits array of ulSum
        // again post-increment by 16 for next pair 
        stp     x12, x13, [x11], 16

        // decrement decrementer by 2
        sub     x8, x8, 2
        b       loopSum_two

remaining_digit:
        cbz     x8, carryOutCheck
        // process last sum
        // only need ldr since processing pair
        ldr     x0, [x9], 8
        ldr     x1, [x10], 8
        adcs    x12, x0, x1
        str     x12, [x11], 8

carryOutCheck:
    // if (carry flag == 0) goto trueRet
    bcc     trueRet

    // if (lSumLength == MAX_DIGITS) goto returnFalse
    cmp     LSUMLENGTH, MAX_DIGITS
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
    ldr     x23, [sp, 8]
    ldr     x22, [sp, 16]
    ldr     x19, [sp, 24]
    add     sp, sp, ADD_STACK_BYTECOUNT
    ret

trueRet:
    // oSum->lLength = lSumLength
    mov     x0, OSUM
    str     LSUMLENGTH, [x0]

    // return TRUE
    mov     x0, TRUE
    ldr     x30, [sp]
    ldr     x23, [sp, 8]
    ldr     x22, [sp, 16]
    ldr     x19, [sp, 24]
    add     sp, sp, ADD_STACK_BYTECOUNT
    ret
    .size   BigInt_add, (. - BigInt_add)
