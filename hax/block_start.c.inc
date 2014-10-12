/* vi: set ft=c inde=: */

#ifndef block_start

#include "pad_block_start.c.inc"

#define block_start(A) S_block_start(aTHX_ A)

static int S_block_start(pTHX_ int full) {
    dVAR;
    const int retval = PL_savestack_ix;

    pad_block_start(full);
    SAVEHINTS();
    PL_hints &= ~HINT_BLOCK_SCOPE;
    SAVECOMPILEWARNINGS();
    PL_compiling.cop_warnings = DUP_WARNINGS(PL_compiling.cop_warnings);

    CALL_BLOCK_HOOKS(bhk_start, full);

    return retval;
}


#endif
