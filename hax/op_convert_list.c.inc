/* vi: set ft=c inde=: */

#ifndef op_convert_list

#define CHECKOP(type,o) \
    ((PL_op_mask && PL_op_mask[type])                           \
     ? ( op_free((OP*)o),                                       \
         Perl_croak(aTHX_ "'%s' trapped by operation mask", PL_op_desc[type]),  \
         (OP*)0 )                                               \
     : PL_check[type](aTHX_ (OP*)o))

static OP *S_op_std_init(pTHX_ OP *o) {
    I32 type = o->op_type;

    if (PL_opargs[type] & OA_RETSCALAR)
        op_contextualize(o, G_SCALAR);
    if (PL_opargs[type] & OA_TARGET && !o->op_targ)
        o->op_targ = pad_alloc(type, SVs_PADTMP);

    return o;
}

#define op_convert_list(A, B, C) S_op_convert_list(aTHX_ A, B, C)

static OP *S_op_convert_list(pTHX_ I32 type, I32 flags, OP *o)
{
    dVAR;
    assert(type >= 0);
    if (!o || o->op_type != OP_LIST)
        o = newLISTOP(OP_LIST, 0, o, NULL);
    else
        o->op_flags &= ~OPf_WANT;

    if (!(PL_opargs[type] & OA_MARK))
        op_null(cLISTOPo->op_first);
    else {
#if HAVE_PERL_VERSION(5, 15, 3)
        OP * const kid2 = cLISTOPo->op_first->op_sibling;
        if (kid2 && kid2->op_type == OP_COREARGS) {
            op_null(cLISTOPo->op_first);
            kid2->op_private |= OPpCOREARGS_PUSHMARK;
        }
#endif
    }

    o->op_type = (OPCODE)type;
    o->op_ppaddr = PL_ppaddr[type];
    o->op_flags |= flags;

    o = CHECKOP(type, o);
    if (o->op_type != type) {
        return o;
    }

    return S_op_std_init(aTHX_ o);
}

#endif
