/* vi: set ft=c inde=: */

#ifndef block_end

#include "scalarseq.c.inc"
#include "pad_leavemy.c.inc"

#define block_end(A, B) S_block_end(aTHX_ A, B)

static OP *S_block_end(pTHX_ I32 floor, OP *seq) {
    dVAR;
    const int needblockscope = PL_hints & HINT_BLOCK_SCOPE;
    OP *retval = scalarseq(seq);
    OP *o;

    CALL_BLOCK_HOOKS(bhk_pre_end, &retval);

    LEAVE_SCOPE(floor);
#if !HAVE_PERL_VERSION(5, 19, 3)
    CopHINTS_set(&PL_compiling, PL_hints);
#endif
    if (needblockscope)
        PL_hints |= HINT_BLOCK_SCOPE; /* propagate out */

    o = pad_leavemy();
    if (o) {
#if HAVE_PERL_VERSION(5, 17, 4)
        OP *kid = o->op_flags & OPf_KIDS ? cLISTOPo->op_first : o;
        OP *const last = o->op_flags & OPf_KIDS ? cLISTOPo->op_last : o;
        for (;; kid = kid->op_sibling) {
            OP *newkid = newOP(OP_CLONECV, 0);
            newkid->op_targ = kid->op_targ;
            o = op_append_elem(OP_LINESEQ, o, newkid);
            if (kid == last) break;
        }
        retval = op_prepend_elem(OP_LINESEQ, o, retval);
#endif
    }

    CALL_BLOCK_HOOKS(bhk_post_end, &retval);

    return retval;
}

#endif
