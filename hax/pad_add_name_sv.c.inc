/* vi: set ft=c inde=: */

#ifndef pad_add_name_sv

#include "pad_alloc.c.inc"
#include "COP_SEQ_RANGE_LOW_set.c.inc"
#include "COP_SEQ_RANGE_HIGH_set.c.inc"

#define pad_add_name_sv(NAMESV, FLAGS, TYPESTASH, OURSTASH) S_pad_add_name_sv(aTHX_ NAMESV, FLAGS, TYPESTASH, OURSTASH)

static PADOFFSET S_pad_alloc_name(pTHX_ SV *namesv, U32 flags, HV *typestash, HV *ourstash) {
    dVAR;
    const PADOFFSET offset = pad_alloc(OP_PADSV, SVs_PADMY);

    (void)flags;
    assert(flags == 0);

    ASSERT_CURPAD_ACTIVE("pad_alloc_name");

    if (typestash) {
        assert(SvTYPE(namesv) == SVt_PVMG);
        SvPAD_TYPED_on(namesv);
        SvSTASH_set(namesv, MUTABLE_HV(SvREFCNT_inc_simple_NN(MUTABLE_SV(typestash))));
    }
    if (ourstash) {
        SvPAD_OUR_on(namesv);
        SvOURSTASH_set(namesv, ourstash);
        SvREFCNT_inc_simple_void_NN(ourstash);
    }

    av_store(PL_comppad_name, offset, namesv);
    return offset;
}

static PADOFFSET S_pad_add_name_pvn(pTHX_ const char *namepv, STRLEN namelen, U32 flags, HV *typestash, HV *ourstash) {
    dVAR;
    PADOFFSET offset;
    SV *namesv;

    assert(flags == 0);

    namesv = newSV_type((ourstash || typestash) ? SVt_PVMG : SVt_PVNV);

    sv_setpvn(namesv, namepv, namelen);

    offset = S_pad_alloc_name(aTHX_ namesv, flags, typestash, ourstash);

    /* not yet introduced */
    COP_SEQ_RANGE_LOW_set(namesv, PERL_PADSEQ_INTRO);
    COP_SEQ_RANGE_HIGH_set(namesv, 0);

    if (!PL_min_intro_pending)
        PL_min_intro_pending = offset;
    PL_max_intro_pending = offset;
    /* if it's not a simple scalar, replace with an AV or HV */
    assert(SvTYPE(PL_curpad[offset]) == SVt_NULL);
    assert(SvREFCNT(PL_curpad[offset]) == 1);
    if (namelen != 0 && *namepv == '@')
        sv_upgrade(PL_curpad[offset], SVt_PVAV);
    else if (namelen != 0 && *namepv == '%')
        sv_upgrade(PL_curpad[offset], SVt_PVHV);
    assert(SvPADMY(PL_curpad[offset]));
    DEBUG_Xv(PerlIO_printf(Perl_debug_log,
                           "Pad addname: %ld \"%s\" new lex=0x%"UVxf"\n",
                           (long)offset, SvPVX(namesv),
                           PTR2UV(PL_curpad[offset])));

    return offset;
}

static PADOFFSET S_pad_add_name_sv(pTHX_ SV *name, U32 flags, HV *typestash, HV *ourstash) {
    char *namepv;
    STRLEN namelen;
    assert(flags == 0);
    namepv = SvPV(name, namelen);
    return S_pad_add_name_pvn(aTHX_ namepv, namelen, flags, typestash, ourstash);
}

#endif
