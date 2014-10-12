/* vi: set ft=c inde=: */

#ifndef pad_alloc

#define pad_alloc(OPTYPE, TMPTYPE) S_pad_alloc(aTHX_ OPTYPE, TMPTYPE)

static PADOFFSET S_pad_alloc(pTHX_ I32 optype, U32 tmptype) {
    dVAR;
    SV *sv;
    I32 retval;

    PERL_UNUSED_ARG(optype);
    ASSERT_CURPAD_ACTIVE("pad_alloc");

    if (AvARRAY(PL_comppad) != PL_curpad)
        Perl_croak(aTHX_ "panic: pad_alloc");
    PL_pad_reset_pending = FALSE;
    if (tmptype & SVs_PADMY) {
        sv = *av_fetch(PL_comppad, AvFILLp(PL_comppad) + 1, TRUE);
        retval = AvFILLp(PL_comppad);
    }
    else {
        SV * const * const names = AvARRAY(PL_comppad_name);
        const SSize_t names_fill = AvFILLp(PL_comppad_name);
        for (;;) {
            /*
             * "foreach" index vars temporarily become aliases to non-"my"
             * values.  Thus we must skip, not just pad values that are
             * marked as current pad values, but also those with names.
             */
            /* HVDS why copy to sv here? we don't seem to use it */
            if (++PL_padix <= names_fill &&
                (sv = names[PL_padix]) && sv != &PL_sv_undef)
                continue;
            sv = *av_fetch(PL_comppad, PL_padix, TRUE);
            if (!(SvFLAGS(sv) & (SVs_PADTMP | SVs_PADMY)) &&
                !IS_PADGV(sv) && !IS_PADCONST(sv))
                break;
        }
        retval = PL_padix;
    }
    SvFLAGS(sv) |= tmptype;
    PL_curpad = AvARRAY(PL_comppad);

    DEBUG_X(PerlIO_printf(Perl_debug_log,
                          "Pad 0x%"UVxf"[0x%"UVxf"] alloc:   %ld for %s\n",
                          PTR2UV(PL_comppad), PTR2UV(PL_curpad), (long) retval,
                          PL_op_name[optype]));
#ifdef DEBUG_LEAKING_SCALARS
    sv->sv_debug_optype = optype;
    sv->sv_debug_inpad = 1;
#endif
    return (PADOFFSET)retval;
}

#endif
