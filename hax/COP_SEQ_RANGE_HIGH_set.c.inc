/* vi: set ft=c inde=: */

#ifndef COP_SEQ_RANGE_HIGH_set

#define COP_SEQ_RANGE_HIGH_set(SV, VAL) \
    STMT_START { ((XPVNV*)SvANY(SV))->xnv_u.xpad_cop_seq.xhigh = (VAL); } STMT_END

#endif
