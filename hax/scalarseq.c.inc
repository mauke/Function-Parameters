/* vi: set ft=c inde=: */

#ifndef scalarseq

#define scalarseq(A) S_scalarseq(aTHX_ A)

static OP *S_scalarseq(pTHX_ OP *o) {
    dVAR;
    if (o) {
        const OPCODE type = o->op_type;

        if (type == OP_LINESEQ || type == OP_SCOPE ||
            type == OP_LEAVE || type == OP_LEAVETRY)
        {
            OP *kid;
            for (kid = cLISTOPo->op_first; kid; kid = kid->op_sibling) {
                if (kid->op_sibling) {
                    op_contextualize(kid, G_VOID);
                }
            }
            PL_curcop = &PL_compiling;
        }
        o->op_flags &= ~OPf_PARENS;
        if (PL_hints & HINT_BLOCK_SCOPE)
            o->op_flags |= OPf_PARENS;
    }
    else
        o = newOP(OP_STUB, 0);
    return o;
}

#endif
