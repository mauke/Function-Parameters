/* vi: set ft=c inde=: */

#ifndef COP_SEQ_RANGE_LOW_set

#define COP_SEQ_RANGE_LOW_set(SV, VAL) \
    STMT_START { ((XPVNV*)SvANY(SV))->xnv_u.xpad_cop_seq.xlow = (VAL); } STMT_END

#endif
