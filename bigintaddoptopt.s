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
        // Return the larger of lLength1 and lLength2.
        // static long BigInt_larger(long lLength1, long lLength2)
        //--------------------------------------------------------------

        // Must be a multiple of 16
        .equ    LARGER_STACK_BYTECOUNT, 32

        // Local variable registers:
        LLARGER    .req x23   // Calle-saved

        // Parameter registers:
        LLENGTH1   .req x22   // Callee-saved
        LLENGTH2   .req x21   // Callee-saved


BigInt_larger:
        // Prolog
        sub     sp, sp, LARGER_STACK_BYTECOUNT
        str     x30, [sp]
        // Prolog
        sub     sp, sp, GCD_STACK_BYTECOUNT
        str     x30, [sp]
        str     x23, [sp, 8]
        str     x22, [sp, 16]
        str     x21, [sp, 24]

        // Store parameters in registers
        mov     LLENGTH1, x0 
        mov     LLENGTH2, x1

        // long lLarger
        // if (lLength1 <= lLength2) goto setLarger2
        cmp    LLENGTH1, LLENGTH2
        ble    setLarger2

        // lLarger = lLength1
        mov     LLARGER, LLENGTH1
        b       returnLarger

setLarger2:
        // lLarger = lLength2
        mov LLARGER, LLENGTH2

returnLarger:
        // Epilog and return lLarger
        mov     x0, LLARGER
        ldr     x30, [sp]
        ldr     x23, [sp, 8]
        ldr     x22, [sp, 16]
        ldr     x21, [sp, 24]
        add     sp, sp, GCD_STACK_BYTECOUNT
        ret

        .size   BigInt_larger, (. - BigInt_larger)

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
        str     x23, [sp, 8]
        str     x22, [sp, 16]
        str     x21, [sp, 24]
        str     x20, [sp, 32]
        str     x19, [sp, 40]
        str     x18, [sp, 48]
        str     x17, [sp, 56]

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
        bl      BigInt_larger
        mov     LSUMLENGTH, x0

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
    // ulCarry = 0
    mov UCLARRY, 0
    // lIndex = 0
    mov LINDEX, 0 

loopSum:
    // if (lIndex >= lSumLength) goto carryOutCheck
    cmp     LINDEX, LSUMLENGTH
    bge     carryOutCheck

    // ulSum = ulCarry
    mov ULSUM,ULCARRY

    // ulCarry = 0
    mov ULCARRY, 0 

    // ulSum += oAddend1->aulDigits[lIndex]
    mov     x0, OADDEND1
    add     x0, x0, AULDIGITS
    ldr     x0, [x0, LINDEX, lsl 3]
    add     ULSUM, ULSUM, x0

        // if (ulSum >= oAddend1->aulDigits[lIndex]) goto check2
        mov     x0, OADDEND1
        add     x0, x0, AULDIGITS
        ldr     x0, [x0, LINDEX, lsl 3] 
        cmp     ULSUM, x0
        bhs     check2

        // ulCarry = 1
        mov ULCARRY, 1 
        b check2

check2: 
    // ulSum += oAddend2->aulDigits[lIndex]
    mov     x0, OADDEND2
    add     x0, x0, AULDIGITS
    ldr     x0, [x0, LINDEX, lsl 3]
    add     ULSUM, ULSUM, x0

        // if (ulSum >= oAddend2->aulDigits[lIndex]) goto checked
        mov     x0, OADDEND2
        add     x0, x0, AULDIGITS
        ldr     x0, [x0, LINDEX, lsl 3] 
        cmp     ULSUM, x0
        bhs     checked

        // ulCarry = 1
        mov ULCARRY, 1
        b checked
    
checked: 
    // oSum->aulDigits[lIndex] = ulSum
    mov     x0, OSUM
    add     x0, x0, AULDIGITS
    str     ULSUM, [x0, LINDEX, lsl 3]

    // lIndex++
    add     LINDEX, LINDEX, 1

    // goto loopSum
    b       loopSum

carryOutCheck:
    // if (ulCarry != 1) goto trueRet
    cmp ULCARRY, 1
    bne     trueRet

    // if (lSumLength == MAX_DIGITS) goto returnFalse
    cmp LSUMLENGTH, MAX_DIGITS
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
    ldr     x30, [sp]
    add     sp, sp, ADD_STACK_BYTECOUNT
    ret

    // return FALSE
    mov     x0, FALSE
    ldr     x30, [sp]
    ldr     x23, [sp, 8]
    ldr     x22, [sp, 16]
    ldr     x21, [sp, 24]
    ldr     x20, [sp, 32]
    ldr     x19, [sp, 40]
    ldr     x18, [sp, 48]
    ldr     x17, [sp, 56]
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
    ldr     x21, [sp, 24]
    ldr     x20, [sp, 32]
    ldr     x19, [sp, 40]
    ldr     x18, [sp, 48]
    ldr     x17, [sp, 56]
    add     sp, sp, ADD_STACK_BYTECOUNT
    ret
    .size   BigInt_add, (. - BigInt_add)
