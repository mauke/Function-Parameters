/* vi: set ft=c inde=: */

#ifndef block_end

#include "scalarseq.c.inc"
#include "pad_leavemy.c.inc"

#define block_end(A, B) S_block_end(aTHX_ A, B)

static OP *S_block_end(pTHX_ I32 floor, OP *seq) {
    dVAR;
    const int needblockscope = PL_hints & HINT_BLOCK_SCOPE;
    OP *retval = scalarseq(seq);

    CALL_BLOCK_HOOKS(bhk_pre_end, &retval);

    LEAVE_SCOPE(floor);
    CopHINTS_set(&PL_compiling, PL_hints);
    if (needblockscope)
        PL_hints |= HINT_BLOCK_SCOPE; /* propagate out */
    pad_leavemy();

    CALL_BLOCK_HOOKS(bhk_post_end, &retval);

    return retval;
}

#endif
