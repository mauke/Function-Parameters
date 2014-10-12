/* vi: set ft=c inde=: */

#ifndef scalarseq

#define scalarseq(A) S_scalarseq(aTHX_ A)

/* Check for in place reverse and sort assignments like "@a = reverse @a"
   and modify the optree to make them work inplace */

static void S_inplace_aassign(pTHX_ OP *o) {
    OP *modop, *modop_pushmark;
    OP *oright;
    OP *oleft, *oleft_pushmark;

    /* PERL_ARGS_ASSERT_INPLACE_AASSIGN; */

    assert((o->op_flags & OPf_WANT) == OPf_WANT_VOID);

    assert(cUNOPo->op_first->op_type == OP_NULL);
    modop_pushmark = cUNOPx(cUNOPo->op_first)->op_first;
    assert(modop_pushmark->op_type == OP_PUSHMARK);
    modop = modop_pushmark->op_sibling;

    if (modop->op_type != OP_SORT && modop->op_type != OP_REVERSE)
        return;

    /* no other operation except sort/reverse */
    if (modop->op_sibling)
        return;

    assert(cUNOPx(modop)->op_first->op_type == OP_PUSHMARK);
    if (!(oright = cUNOPx(modop)->op_first->op_sibling)) return;

    if (modop->op_flags & OPf_STACKED) {
        /* skip sort subroutine/block */
        assert(oright->op_type == OP_NULL);
        oright = oright->op_sibling;
    }

    assert(cUNOPo->op_first->op_sibling->op_type == OP_NULL);
    oleft_pushmark = cUNOPx(cUNOPo->op_first->op_sibling)->op_first;
    assert(oleft_pushmark->op_type == OP_PUSHMARK);
    oleft = oleft_pushmark->op_sibling;

    /* Check the lhs is an array */
    if (!oleft ||
        (oleft->op_type != OP_RV2AV && oleft->op_type != OP_PADAV)
        || oleft->op_sibling
        || (oleft->op_private & OPpLVAL_INTRO)
    )
        return;

    /* Only one thing on the rhs */
    if (oright->op_sibling)
        return;

    /* check the array is the same on both sides */
    if (oleft->op_type == OP_RV2AV) {
        if (oright->op_type != OP_RV2AV
            || !cUNOPx(oright)->op_first
            || cUNOPx(oright)->op_first->op_type != OP_GV
            || cUNOPx(oleft )->op_first->op_type != OP_GV
            || cGVOPx_gv(cUNOPx(oleft)->op_first) !=
               cGVOPx_gv(cUNOPx(oright)->op_first)
        )
            return;
    }
    else if (oright->op_type != OP_PADAV
             || oright->op_targ != oleft->op_targ
    )
        return;

    /* This actually is an inplace assignment */

    modop->op_private |= OPpSORT_INPLACE;

    /* transfer MODishness etc from LHS arg to RHS arg */
    oright->op_flags = oleft->op_flags;

    /* remove the aassign op and the lhs */
    op_null(o);
    op_null(oleft_pushmark);
    if (oleft->op_type == OP_RV2AV && cUNOPx(oleft)->op_first)
        op_null(cUNOPx(oleft)->op_first);
    op_null(oleft);
}

static OP *S_scalarvoid(pTHX_ OP *);

static OP *S_scalar(pTHX_ OP *o) {
    dVAR;
    OP *kid;

    /* assumes no premature commitment */
    if (!o || (PL_parser && PL_parser->error_count)
        || (o->op_flags & OPf_WANT)
        || o->op_type == OP_RETURN)
    {
        return o;
    }

    o->op_flags = (o->op_flags & ~OPf_WANT) | OPf_WANT_SCALAR;

    switch (o->op_type) {
        case OP_REPEAT:
            S_scalar(aTHX_ cBINOPo->op_first);
            break;
        case OP_OR:
        case OP_AND:
        case OP_COND_EXPR:
            for (kid = cUNOPo->op_first->op_sibling; kid; kid = kid->op_sibling)
                S_scalar(aTHX_ kid);
            break;
            /* FALL THROUGH */
        case OP_SPLIT:
        case OP_MATCH:
        case OP_QR:
        case OP_SUBST:
        case OP_NULL:
        default:
            if (o->op_flags & OPf_KIDS) {
                for (kid = cUNOPo->op_first; kid; kid = kid->op_sibling)
                    S_scalar(aTHX_ kid);
            }
            break;
        case OP_LEAVE:
        case OP_LEAVETRY:
            kid = cLISTOPo->op_first;
            S_scalar(aTHX_ kid);
            kid = kid->op_sibling;
do_kids:
            while (kid) {
                OP *sib = kid->op_sibling;
                if (sib && kid->op_type != OP_LEAVEWHEN)
                    S_scalarvoid(aTHX_ kid);
                else
                    S_scalar(aTHX_ kid);
                kid = sib;
            }
            PL_curcop = &PL_compiling;
            break;
        case OP_SCOPE:
        case OP_LINESEQ:
        case OP_LIST:
            kid = cLISTOPo->op_first;
            goto do_kids;
        case OP_SORT:
            Perl_ck_warner(aTHX_ packWARN(WARN_VOID), "Useless use of sort in scalar context");
            break;
    }
    return o;
}

static OP *S_scalarkids(pTHX_ OP *o) {
    if (o && o->op_flags & OPf_KIDS) {
        OP *kid;
        for (kid = cLISTOPo->op_first; kid; kid = kid->op_sibling)
            S_scalar(aTHX_ kid);
    }
    return o;
}

static OP *S_scalarvoid(pTHX_ OP *o) {
    dVAR;
    OP *kid;
    SV *useless_sv = NULL;
    const char *useless = NULL;
    SV *sv;
    U8 want;

    PERL_ARGS_ASSERT_SCALARVOID;

    /* trailing mad null ops don't count as "there" for void processing */
    if (PL_madskills &&
        o->op_type != OP_NULL &&
        o->op_sibling &&
        o->op_sibling->op_type == OP_NULL)
    {
        OP *sib;
        for (sib = o->op_sibling;
                sib && sib->op_type == OP_NULL;
                sib = sib->op_sibling) ;

        if (!sib)
            return o;
    }

    if (
        o->op_type == OP_NEXTSTATE ||
        o->op_type == OP_DBSTATE || (
            o->op_type == OP_NULL && (
                o->op_targ == OP_NEXTSTATE ||
                o->op_targ == OP_DBSTATE
            )
        )
    ) {
        PL_curcop = (COP*)o;        /* for warning below */
    }

    /* assumes no premature commitment */
    want = o->op_flags & OPf_WANT;
    if (
        (want && want != OPf_WANT_SCALAR) ||
        (PL_parser && PL_parser->error_count) ||
        o->op_type == OP_RETURN ||
        o->op_type == OP_REQUIRE ||
        o->op_type == OP_LEAVEWHEN
    ) {
        return o;
    }

    if (
        (o->op_private & OPpTARGET_MY) &&
        (PL_opargs[o->op_type] & OA_TARGLEX)
        /* OPp share the meaning */
    ) {
        return S_scalar(aTHX_ o);           /* As if inside SASSIGN */
    }

    o->op_flags = (o->op_flags & ~OPf_WANT) | OPf_WANT_VOID;

    switch (o->op_type) {
        default:
            if (!(PL_opargs[o->op_type] & OA_FOLDCONST))
                break;
            /* FALL THROUGH */
        case OP_REPEAT:
            if (o->op_flags & OPf_STACKED)
                break;
            goto func_ops;
        case OP_SUBSTR:
            if (o->op_private == 4)
                break;
            /* FALL THROUGH */
        case OP_GVSV:
        case OP_WANTARRAY:
        case OP_GV:
        case OP_SMARTMATCH:
        case OP_PADSV:
        case OP_PADAV:
        case OP_PADHV:
        case OP_PADANY:
        case OP_AV2ARYLEN:
        case OP_REF:
        case OP_REFGEN:
        case OP_SREFGEN:
        case OP_DEFINED:
        case OP_HEX:
        case OP_OCT:
        case OP_LENGTH:
        case OP_VEC:
        case OP_INDEX:
        case OP_RINDEX:
        case OP_SPRINTF:
        case OP_AELEM:
        case OP_AELEMFAST:
        IF_HAVE_PERL_5_16(case OP_AELEMFAST_LEX:, )
        case OP_ASLICE:
        case OP_HELEM:
        case OP_HSLICE:
        case OP_UNPACK:
        case OP_PACK:
        case OP_JOIN:
        case OP_LSLICE:
        case OP_ANONLIST:
        case OP_ANONHASH:
        case OP_SORT:
        case OP_REVERSE:
        case OP_RANGE:
        case OP_FLIP:
        case OP_FLOP:
        case OP_CALLER:
        case OP_FILENO:
        case OP_EOF:
        case OP_TELL:
        case OP_GETSOCKNAME:
        case OP_GETPEERNAME:
        case OP_READLINK:
        case OP_TELLDIR:
        case OP_GETPPID:
        case OP_GETPGRP:
        case OP_GETPRIORITY:
        case OP_TIME:
        case OP_TMS:
        case OP_LOCALTIME:
        case OP_GMTIME:
        case OP_GHBYNAME:
        case OP_GHBYADDR:
        case OP_GHOSTENT:
        case OP_GNBYNAME:
        case OP_GNBYADDR:
        case OP_GNETENT:
        case OP_GPBYNAME:
        case OP_GPBYNUMBER:
        case OP_GPROTOENT:
        case OP_GSBYNAME:
        case OP_GSBYPORT:
        case OP_GSERVENT:
        case OP_GPWNAM:
        case OP_GPWUID:
        case OP_GGRNAM:
        case OP_GGRGID:
        case OP_GETLOGIN:
        case OP_PROTOTYPE:
        IF_HAVE_PERL_5_16(case OP_RUNCV:, )
func_ops:
            if (!(o->op_private & (OPpLVAL_INTRO|OPpOUR_INTRO)))
                /* Otherwise it's "Useless use of grep iterator" */
                useless = OP_DESC(o);
            break;

        case OP_SPLIT:
            kid = cLISTOPo->op_first;
            if (kid && kid->op_type == OP_PUSHRE
#ifdef USE_ITHREADS
                && !((PMOP*)kid)->op_pmreplrootu.op_pmtargetoff
#else
                && !((PMOP*)kid)->op_pmreplrootu.op_pmtargetgv
#endif
            )
                    useless = OP_DESC(o);
            break;

        case OP_NOT:
            kid = cUNOPo->op_first;
            if (kid->op_type != OP_MATCH && kid->op_type != OP_SUBST &&
                kid->op_type != OP_TRANS && kid->op_type != OP_TRANSR) {
                goto func_ops;
            }
            useless = "negative pattern binding (!~)";
            break;

        case OP_SUBST:
            if (cPMOPo->op_pmflags & PMf_NONDESTRUCT)
                useless = "non-destructive substitution (s///r)";
            break;

        case OP_TRANSR:
            useless = "non-destructive transliteration (tr///r)";
            break;

        case OP_RV2GV:
        case OP_RV2SV:
        case OP_RV2AV:
        case OP_RV2HV:
            if (!(o->op_private & (OPpLVAL_INTRO|OPpOUR_INTRO)) &&
                (!o->op_sibling || o->op_sibling->op_type != OP_READLINE))
                useless = "a variable";
            break;

        case OP_CONST:
            sv = cSVOPo_sv;
            if (cSVOPo->op_private & OPpCONST_STRICT) {
                /* no_bareword_allowed(o); */
                croak("%s: internal error: what even are birds", MY_PKG);
            } else {
                if (ckWARN(WARN_VOID)) {
                    /* don't warn on optimised away booleans, eg 
                     * use constant Foo, 5; Foo || print; */
                    if (cSVOPo->op_private & OPpCONST_SHORTCIRCUIT)
                        useless = NULL;
                    /* the constants 0 and 1 are permitted as they are
                       conventionally used as dummies in constructs like
                       1 while some_condition_with_side_effects;  */
                    else if (SvNIOK(sv) && (SvNV(sv) == 0.0 || SvNV(sv) == 1.0))
                        useless = NULL;
                    else if (SvPOK(sv)) {
                        /* perl4's way of mixing documentation and code
                           (before the invention of POD) was based on a
                           trick to mix nroff and perl code. The trick was
                           built upon these three nroff macros being used in
                           void context. The pink camel has the details in
                           the script wrapman near page 319. */
                        const char * const maybe_macro = SvPVX_const(sv);
                        if (strnEQ(maybe_macro, "di", 2) ||
                            strnEQ(maybe_macro, "ds", 2) ||
                            strnEQ(maybe_macro, "ig", 2))
                            useless = NULL;
                        else {
                            SV * const dsv = newSVpvs("");
                            useless_sv
                                = Perl_newSVpvf(aTHX_
                                                "a constant (%s)",
                                                pv_pretty(dsv, maybe_macro,
                                                          SvCUR(sv), 32, NULL, NULL,
                                                          PERL_PV_PRETTY_DUMP
                                                          | PERL_PV_ESCAPE_NOCLEAR
                                                          | PERL_PV_ESCAPE_UNI_DETECT ));
                            SvREFCNT_dec_NN(dsv);
                        }
                    }
                    else if (SvOK(sv)) {
                        useless_sv = Perl_newSVpvf(aTHX_ "a constant (%"SVf")", sv);
                    }
                    else
                        useless = "a constant (undef)";
                }
            }
            op_null(o);     /* don't execute or even remember it */
            break;

        case OP_POSTINC:
            o->op_type = OP_PREINC;     /* pre-increment is faster */
            o->op_ppaddr = PL_ppaddr[OP_PREINC];
            break;

        case OP_POSTDEC:
            o->op_type = OP_PREDEC;     /* pre-decrement is faster */
            o->op_ppaddr = PL_ppaddr[OP_PREDEC];
            break;

        case OP_I_POSTINC:
            o->op_type = OP_I_PREINC;   /* pre-increment is faster */
            o->op_ppaddr = PL_ppaddr[OP_I_PREINC];
            break;

        case OP_I_POSTDEC:
            o->op_type = OP_I_PREDEC;   /* pre-decrement is faster */
            o->op_ppaddr = PL_ppaddr[OP_I_PREDEC];
            break;

        case OP_SASSIGN: {
            OP *rv2gv;
            UNOP *refgen, *rv2cv;
            LISTOP *exlist;

            if ((o->op_private & ~OPpASSIGN_BACKWARDS) != 2)
                break;

            rv2gv = ((BINOP *)o)->op_last;
            if (!rv2gv || rv2gv->op_type != OP_RV2GV)
                break;

            refgen = (UNOP *)((BINOP *)o)->op_first;

            if (!refgen || refgen->op_type != OP_REFGEN)
                break;

            exlist = (LISTOP *)refgen->op_first;
            if (!exlist || exlist->op_type != OP_NULL
                || exlist->op_targ != OP_LIST)
                break;

            if (exlist->op_first->op_type != OP_PUSHMARK)
                break;

            rv2cv = (UNOP*)exlist->op_last;

            if (rv2cv->op_type != OP_RV2CV)
                break;

            assert ((rv2gv->op_private & OPpDONT_INIT_GV) == 0);
            assert ((o->op_private & OPpASSIGN_CV_TO_GV) == 0);
            assert ((rv2cv->op_private & OPpMAY_RETURN_CONSTANT) == 0);

            o->op_private |= OPpASSIGN_CV_TO_GV;
            rv2gv->op_private |= OPpDONT_INIT_GV;
            rv2cv->op_private |= OPpMAY_RETURN_CONSTANT;

            break;
        }

        case OP_AASSIGN: {
            S_inplace_aassign(aTHX_ o);
            break;
        }

        case OP_OR:
        case OP_AND:
            kid = cLOGOPo->op_first;
            if (kid->op_type == OP_NOT
                && (kid->op_flags & OPf_KIDS)
                && !PL_madskills) {
                if (o->op_type == OP_AND) {
                    o->op_type = OP_OR;
                    o->op_ppaddr = PL_ppaddr[OP_OR];
                } else {
                    o->op_type = OP_AND;
                    o->op_ppaddr = PL_ppaddr[OP_AND];
                }
                op_null(kid);
            }

        case OP_DOR:
        case OP_COND_EXPR:
        case OP_ENTERGIVEN:
        case OP_ENTERWHEN:
            for (kid = cUNOPo->op_first->op_sibling; kid; kid = kid->op_sibling)
                S_scalarvoid(aTHX_ kid);
            break;

        case OP_NULL:
            if (o->op_flags & OPf_STACKED)
                break;
            /* FALL THROUGH */
        case OP_NEXTSTATE:
        case OP_DBSTATE:
        case OP_ENTERTRY:
        case OP_ENTER:
            if (!(o->op_flags & OPf_KIDS))
                break;
            /* FALL THROUGH */
        case OP_SCOPE:
        case OP_LEAVE:
        case OP_LEAVETRY:
        case OP_LEAVELOOP:
        case OP_LINESEQ:
        case OP_LIST:
        case OP_LEAVEGIVEN:
        case OP_LEAVEWHEN:
            for (kid = cLISTOPo->op_first; kid; kid = kid->op_sibling)
                S_scalarvoid(aTHX_ kid);
            break;
        case OP_ENTEREVAL:
            S_scalarkids(aTHX_ o);
            break;
        case OP_SCALAR:
            return S_scalar(aTHX_ o);
    }

    if (useless_sv) {
        /* mortalise it, in case warnings are fatal.  */
        Perl_ck_warner(aTHX_ packWARN(WARN_VOID),
                       "Useless use of %"SVf" in void context",
                       sv_2mortal(useless_sv));
    }
    else if (useless) {
        Perl_ck_warner(aTHX_ packWARN(WARN_VOID),
                       "Useless use of %s in void context",
                       useless);
    }
    return o;
}

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
                    S_scalarvoid(aTHX_ kid);
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
