/* vi: set ft=c inde=: */

#ifndef pad_leavemy

#define pad_leavemy() S_pad_leavemy(aTHX)

static OP *S_pad_leavemy(pTHX) {
    dVAR;
    I32 off;
    OP *o = NULL;
    SV * const * const svp = AvARRAY(PL_comppad_name);

    PL_pad_reset_pending = FALSE;

    ASSERT_CURPAD_ACTIVE("pad_leavemy");
    if (PL_min_intro_pending && PL_comppad_name_fill < PL_min_intro_pending) {
        for (off = PL_max_intro_pending; off >= PL_min_intro_pending; off--) {
            const SV * const sv = svp[off];
            if (sv && IF_HAVE_PERL_5_19_3(PadnameLEN(sv), sv != &PL_sv_undef) && !SvFAKE(sv))
                Perl_ck_warner_d(aTHX_ packWARN(WARN_INTERNAL),
                                 "%"SVf" never introduced",
                                 SVfARG(sv));
        }
    }
    /* "Deintroduce" my variables that are leaving with this scope. */
    for (off = AvFILLp(PL_comppad_name); off > PL_comppad_name_fill; off--) {
        SV * const sv = svp[off];
        if (sv && IF_HAVE_PERL_5_19_3(PadnameLEN(sv), sv != &PL_sv_undef) && !SvFAKE(sv)
            && COP_SEQ_RANGE_HIGH(sv) == PERL_PADSEQ_INTRO)
        {
            COP_SEQ_RANGE_HIGH_set(sv, PL_cop_seqmax);
            DEBUG_Xv(PerlIO_printf(Perl_debug_log,
                                   "Pad leavemy: %ld \"%s\", (%lu,%lu)\n",
                                   (long)off, SvPVX_const(sv),
                                   (unsigned long)COP_SEQ_RANGE_LOW(sv),
                                   (unsigned long)COP_SEQ_RANGE_HIGH(sv))
            );
#if HAVE_PERL_VERSION(5, 17, 4)
            if (!PadnameIsSTATE(sv) && !PadnameIsOUR(sv)
                 && *PadnamePV(sv) == '&' && PadnameLEN(sv) > 1) {
                OP *kid = newOP(OP_INTROCV, 0);
                kid->op_targ = off;
                o = op_prepend_elem(OP_LINESEQ, kid, o);
            }
#endif
        }
    }
    PL_cop_seqmax++;
    if (PL_cop_seqmax == PERL_PADSEQ_INTRO) /* not a legal value */
        PL_cop_seqmax++;
    DEBUG_Xv(PerlIO_printf(Perl_debug_log,
                           "Pad leavemy: seq = %ld\n", (long)PL_cop_seqmax));
    return o;
}

#endif
