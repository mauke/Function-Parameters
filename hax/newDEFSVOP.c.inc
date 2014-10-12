/* vi: set ft=c inde=: */

#ifndef newDEFSVOP

#include "pad_findmy_pvs.c.inc"

#define newDEFSVOP() S_newDEFSVOP(aTHX)

static OP *S_newDEFSVOP(pTHX) {
    dVAR;
    const PADOFFSET offset = pad_findmy_pvs("$_", 0);
    if (offset == NOT_IN_PAD || PAD_COMPNAME_FLAGS_isOUR(offset)) {
        return newSVREF(newGVOP(OP_GV, 0, PL_defgv));
    }
    else {
        OP * const o = newOP(OP_PADSV, 0);
        o->op_targ = offset;
        return o;
    }
}

#endif
