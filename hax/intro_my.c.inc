/* vi: set ft=c inde=: */

#ifndef intro_my

#include "COP_SEQ_RANGE_HIGH_set.c.inc"
#include "COP_SEQ_RANGE_LOW_set.c.inc"

#define intro_my() S_intro_my(aTHX)

static U32 S_intro_my(pTHX) {
    dVAR;
    SV **svp;
    I32 i;
    U32 seq;

    ASSERT_CURPAD_ACTIVE("intro_my");
    if (! PL_min_intro_pending)
        return PL_cop_seqmax;

    svp = AvARRAY(PL_comppad_name);
    for (i = PL_min_intro_pending; i <= PL_max_intro_pending; i++) {
        SV *const sv = svp[i];

        if (sv && IF_HAVE_PERL_5_19_3(PadnameLEN(sv), sv != &PL_sv_undef) && !SvFAKE(sv)
            && COP_SEQ_RANGE_LOW(sv) == PERL_PADSEQ_INTRO)
        {
            COP_SEQ_RANGE_HIGH_set(sv, PERL_PADSEQ_INTRO); /* Don't know scope end yet. */
            COP_SEQ_RANGE_LOW_set(sv, PL_cop_seqmax);
            DEBUG_Xv(PerlIO_printf(Perl_debug_log,
                                   "Pad intromy: %ld \"%s\", (%lu,%lu)\n",
                                   (long)i, SvPVX_const(sv),
                                   (unsigned long)COP_SEQ_RANGE_LOW(sv),
                                   (unsigned long)COP_SEQ_RANGE_HIGH(sv))
            );
        }
    }
    seq = PL_cop_seqmax;
    PL_cop_seqmax++;
    if (PL_cop_seqmax == PERL_PADSEQ_INTRO) /* not a legal value */
        PL_cop_seqmax++;
    PL_min_intro_pending = 0;
    PL_comppad_name_fill = PL_max_intro_pending; /* Needn't search higher */
    DEBUG_Xv(PerlIO_printf(Perl_debug_log,
                           "Pad intromy: seq -> %ld\n", (long)(PL_cop_seqmax)));

    return seq;
}

#endif
