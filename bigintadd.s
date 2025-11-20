//----------------------------------------------------------------------
// bigintadd.s
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

        // Local variable stack offsets:
        .equ    LLARGER,     8

        // Parameter stack offsets:
        .equ    LLENGTH1,   16
        .equ    LLENGTH2,   24

BigInt_larger:
        // Prolog
        sub     sp, sp, LARGER_STACK_BYTECOUNT
        str     x30, [sp]
        str     x0, [sp, LLENGTH1]
        str     x1, [sp, LLENGTH2]

        // long lLarger
        // if (lLength1 <= lLength2) goto setLarger2
        ldr     x0, [sp, LLENGTH1]
        ldr     x1, [sp, LLENGTH2]
        cmp     x0, x1
        ble    setLarger2

        // lLarger = lLength1
        ldr     x0, [sp, LLENGTH1]
        str     x0, [sp, LLARGER]
        b       returnLarger

setLarger2:
        // lLarger = lLength2
        ldr     x0, [sp, LLENGTH2]
        str     x0, [sp, LLARGER]

returnLarger:
        // Epilog and return lLarger
        ldr     x0, [sp, LLARGER]
        ldr     x30, [sp]
        add     sp, sp, LARGER_STACK_BYTECOUNT
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

        // Local variable stack offsets:
        .equ    ULCARRY,     8
        .equ    ULSUM,       16
        .equ    LINDEX,      24
        .equ    LSUMLENGTH,  32

        // Parameter stack offsets:
        .equ    OADDEND1,   40
        .equ    OADDEND2,   48
        .equ    OSUM,       56

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
        str     x0, [sp, OADDEND1]
        str     x1, [sp, OADDEND2]
        str     x2, [sp, OSUM]

        // unsigned long ulCarry
        // unsigned long ulSum
        // long lIndex
        // long lSumLength

        // When translating bigintadd.c to assembly language,
        // simply pretend that the calls of assert are not in the C code.

        // lSumLength = BigInt_larger(oAddend1->lLength, oAddend2->lLength)
        ldr     x0, [sp, OADDEND1]
        ldr     x0, [x0]
        ldr     x1, [sp, OADDEND2]
        ldr     x1, [x1]
        bl      BigInt_larger
        str     x0, [sp, LSUMLENGTH]

        // if (oSum->lLength <= lSumLength) goto rstCarry
        ldr     x0, [sp, OSUM]
        ldr     x0, [x0]
        ldr     x1, [sp, LSUMLENGTH]
        cmp     x0, x1
        ble     rstCarry

        // memset(oSum->aulDigits, 0, MAX_DIGITS * sizeof(unsigned long))
        ldr     x0, [sp, OSUM]
        add     x0, x0, AULDIGITS
        mov     x1, 0
        mov     x2, MAX_DIGITS
        mov     x3, 8
        mul     x2, x2, x3
        bl      memset
        b       rstCarry

rstCarry:
    // ulCarry = 0
    mov     x0, 0
    str     x0, [sp, ULCARRY]

    // lIndex = 0
    mov     x0, 0
    str     x0, [sp, LINDEX]

loopSum:
    // if (lIndex >= lSumLength) goto carryOutCheck
    ldr     x0, [sp, LINDEX]
    ldr     x1, [sp, LSUMLENGTH]
    cmp     x0, x1
    bge     carryOutCheck

    // ulSum = ulCarry
    ldr     x0, [sp, ULCARRY]
    str     x0, [sp, ULSUM]

    // ulCarry = 0
    mov     x0, 0
    str     x0, [sp, ULCARRY]

    // ulSum += oAddend1->aulDigits[lIndex]
    ldr     x0, [sp, OADDEND1]
    add     x0, x0, AULDIGITS
    ldr     x1, [sp, LINDEX]
    ldr     x0, [x0, x1, lsl 3]
    ldr     x2, [sp, ULSUM]
    add     x2, x2, x0
    str     x2, [sp, ULSUM]

        // if (ulSum >= oAddend1->aulDigits[lIndex]) goto check2
        // Use unsigned comparison: branch if ulSum >= digit -> BHS (unsigned >=)
        ldr     x0, [sp, ULSUM]
        ldr     x1, [sp, OADDEND1]
        add     x1, x1, AULDIGITS
        ldr     x2, [sp, LINDEX]
        ldr     x1, [x1, x2, lsl 3]
        cmp     x0, x1
        bhs     check2
    // ulCarry = 1
    mov     x0, 1
    str     x0, [sp, ULCARRY]
    b check2

check2: 
    // ulSum += oAddend2->aulDigits[lIndex]
    ldr     x0, [sp, OADDEND2]
    add     x0, x0, AULDIGITS
    ldr     x1, [sp, LINDEX]
    ldr     x0, [x0, x1, lsl 3]
    ldr     x2, [sp, ULSUM]
    add     x2, x2, x0
    str     x2, [sp, ULSUM]

        // if (ulSum >= oAddend2->aulDigits[lIndex]) goto checked
        // Use unsigned comparison: branch if ulSum >= digit -> BHS (unsigned >=)
        ldr     x0, [sp, ULSUM]
        ldr     x1, [sp, OADDEND2]
        add     x1, x1, AULDIGITS
        ldr     x2, [sp, LINDEX]
        ldr     x1, [x1, x2, lsl 3]
        cmp     x0, x1
        bhs     checked
    // ulCarry = 1
    mov     x0, 1
    str     x0, [sp, ULCARRY]
    b checked
    
checked: 
    // oSum->aulDigits[lIndex] = ulSum
    ldr     x0, [sp, OSUM]
    add     x0, x0, AULDIGITS
    ldr     x1, [sp, LINDEX]
    ldr     x2, [sp, ULSUM]
    str     x2, [x0, x1, lsl 3]

    // lIndex++
    ldr     x0, [sp, LINDEX]
    add     x0, x0, 1
    str     x0, [sp, LINDEX]

    // goto loopSum
    b       loopSum

carryOutCheck:
    // if (ulCarry != 1) goto trueRet
    ldr     x0, [sp, ULCARRY]
    mov     x1, 1
    cmp     x0, x1
    bne     trueRet

    // if (lSumLength == MAX_DIGITS) goto returnFalse
    ldr     x0, [sp, LSUMLENGTH]
    mov     x1, MAX_DIGITS
    cmp     x0, x1
    beq     returnFalse

    // oSum->aulDigits[lSumLength] = 1
    ldr     x0, [sp, OSUM]
    add     x0, x0, AULDIGITS
    ldr     x1, [sp, LSUMLENGTH]
    mov     x2, 1
    str     x2, [x0, x1, lsl 3]

    // lSumLength++
    ldr     x0, [sp, LSUMLENGTH]
    add     x0, x0, 1
    str     x0, [sp, LSUMLENGTH]
    b       trueRet

returnFalse:
    // return FALSE
    mov     x0, FALSE
    ldr     x30, [sp]
    add     sp, sp, ADD_STACK_BYTECOUNT
    ret

trueRet:
    // oSum->lLength = lSumLength
    ldr     x0, [sp, OSUM]
    ldr     x1, [sp, LSUMLENGTH]
    str     x1, [x0]

    // return TRUE
    mov     x0, TRUE
    ldr     x30, [sp]
    add     sp, sp, ADD_STACK_BYTECOUNT
    ret

    .size   BigInt_add, (. - BigInt_add)
