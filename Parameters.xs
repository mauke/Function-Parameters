/*
Copyright 2012, 2014 Lukas Mai.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.
 */

#ifdef __GNUC__
 #if __GNUC__ >= 5
  #define IF_HAVE_GCC_5(X) X
 #endif

 #if (__GNUC__ == 4 && __GNUC_MINOR__ >= 6) || __GNUC__ >= 5
  #define PRAGMA_GCC_(X) _Pragma(#X)
  #define PRAGMA_GCC(X) PRAGMA_GCC_(GCC X)
 #endif
#endif

#ifndef IF_HAVE_GCC_5
 #define IF_HAVE_GCC_5(X)
#endif

#ifndef PRAGMA_GCC
 #define PRAGMA_GCC(X)
#endif

#ifdef DEVEL
 #define WARNINGS_RESET PRAGMA_GCC(diagnostic pop)
 #define WARNINGS_ENABLEW(X) PRAGMA_GCC(diagnostic error #X)
 #define WARNINGS_ENABLE \
    WARNINGS_ENABLEW(-Wall) \
    WARNINGS_ENABLEW(-Wextra) \
    WARNINGS_ENABLEW(-Wundef) \
    WARNINGS_ENABLEW(-Wshadow) \
    WARNINGS_ENABLEW(-Wbad-function-cast) \
    WARNINGS_ENABLEW(-Wcast-align) \
    WARNINGS_ENABLEW(-Wwrite-strings) \
    WARNINGS_ENABLEW(-Wstrict-prototypes) \
    WARNINGS_ENABLEW(-Wmissing-prototypes) \
    WARNINGS_ENABLEW(-Winline) \
    WARNINGS_ENABLEW(-Wdisabled-optimization) \
    IF_HAVE_GCC_5(WARNINGS_ENABLEW(-Wnested-externs))

#else
 #define WARNINGS_RESET
 #define WARNINGS_ENABLE
#endif


#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include <string.h>

#ifdef DEVEL
#undef NDEBUG
#include <assert.h>
#endif

#ifdef PERL_MAD
#error "MADness is not supported."
#endif

#define HAVE_PERL_VERSION(R, V, S) \
    (PERL_REVISION > (R) || (PERL_REVISION == (R) && (PERL_VERSION > (V) || (PERL_VERSION == (V) && (PERL_SUBVERSION >= (S))))))

#if HAVE_PERL_VERSION(5, 19, 3)
 #define IF_HAVE_PERL_5_19_3(YES, NO) YES
#else
 #define IF_HAVE_PERL_5_19_3(YES, NO) NO
#endif

#ifndef SvREFCNT_dec_NN
 #define SvREFCNT_dec_NN(SV) SvREFCNT_dec(SV)
#endif


#define MY_PKG "Function::Parameters"

/* 5.22+ shouldn't require any hax */
#if !HAVE_PERL_VERSION(5, 22, 0)

 #if !HAVE_PERL_VERSION(5, 16, 0)
  #include "hax/pad_alloc.c.inc"
  #include "hax/pad_add_name_sv.c.inc"
  #include "hax/pad_add_name_pvs.c.inc"

  #ifndef padadd_NO_DUP_CHECK
   #define padadd_NO_DUP_CHECK 0
  #endif
 #endif

 #include "hax/newDEFSVOP.c.inc"
 #include "hax/intro_my.c.inc"
 #include "hax/block_start.c.inc"
 #include "hax/block_end.c.inc"

 #include "hax/op_convert_list.c.inc"  /* < 5.22 */

#endif


WARNINGS_ENABLE

#define HAVE_BUG_129090 (HAVE_PERL_VERSION(5, 21, 7) && !HAVE_PERL_VERSION(5, 25, 5))

#define HINTK_KEYWORDS MY_PKG "/keywords"
#define HINTK_FLAGS_   MY_PKG "/flags:"
#define HINTK_SHIFT_   MY_PKG "/shift:"
#define HINTK_ATTRS_   MY_PKG "/attrs:"
#define HINTK_REIFY_   MY_PKG "/reify:"
#define HINTK_INSTALL_ MY_PKG "/install:"

#define DEFSTRUCT(T) typedef struct T T; struct T

#define VEC(B) B ## _Vec

#define DEFVECTOR(B) DEFSTRUCT(VEC(B)) { \
    B (*data); \
    size_t used, size; \
}

#define DEFVECTOR_INIT(N, B) static void N(VEC(B) *p) { \
    p->used = 0; \
    p->size = 23; \
    Newx(p->data, p->size, B); \
} static void N(VEC(B) *)

#define DEFVECTOR_EXTEND(N, B) static B (*N(VEC(B) *p)) { \
    assert(p->used <= p->size); \
    if (p->used == p->size) { \
        const size_t n = p->size / 2 * 3 + 1; \
        Renew(p->data, n, B); \
        p->size = n; \
    } \
    return &p->data[p->used]; \
} static B (*N(VEC(B) *))

#define DEFVECTOR_CLEAR(N, B, F) static void N(pTHX_ VEC(B) *p) { \
    while (p->used) { \
        p->used--; \
        F(aTHX_ &p->data[p->used]); \
    } \
    Safefree(p->data); \
    p->data = NULL; \
    p->size = 0; \
} static void N(pTHX_ VEC(B) *)

enum {
    FLAG_NAME_OK      = 0x001,
    FLAG_ANON_OK      = 0x002,
    FLAG_DEFAULT_ARGS = 0x004,
    FLAG_CHECK_NARGS  = 0x008,
    FLAG_INVOCANT     = 0x010,
    FLAG_NAMED_PARAMS = 0x020,
    FLAG_TYPES_OK     = 0x040,
    FLAG_CHECK_TARGS  = 0x080,
    FLAG_RUNTIME      = 0x100
};

DEFSTRUCT(SpecParam) {
    SV *name;
    SV *type;
};

DEFVECTOR(SpecParam);
DEFVECTOR_INIT(spv_init, SpecParam);

static void sp_clear(pTHX_ SpecParam *p) {
    p->name = NULL;
    p->type = NULL;
}

DEFVECTOR_CLEAR(spv_clear, SpecParam, sp_clear);

DEFVECTOR_EXTEND(spv_extend, SpecParam);

static void spv_push(VEC(SpecParam) *ps, SV *name, SV *type) {
    SpecParam *p = spv_extend(ps);
    p->name = name;
    p->type = type;
    ps->used++;
}

DEFSTRUCT(KWSpec) {
    unsigned flags;
    I32 reify_type;
    VEC(SpecParam) shift;
    SV *attrs;
    SV *install_sub;
};

static void kws_free_void(pTHX_ void *p) {
    KWSpec *const spec = p;
    spv_clear(aTHX_ &spec->shift);
    spec->attrs = NULL;
    spec->install_sub = NULL;
    Safefree(spec);
}

DEFSTRUCT(Resource) {
    Resource *next;
    void *data;
    void (*destroy)(pTHX_ void *);
};

typedef Resource *Sentinel[1];

static void sentinel_clear_void(pTHX_ void *pv) {
    Resource **pp = pv;
    Resource *p = *pp;
    Safefree(pp);
    while (p) {
        Resource *cur = p;
        if (cur->destroy) {
            cur->destroy(aTHX_ cur->data);
        }
        cur->data = (void *)"no";
        cur->destroy = NULL;
        p = cur->next;
        Safefree(cur);
    }
}

static Resource *sentinel_register(Sentinel sen, void *data, void (*destroy)(pTHX_ void *)) {
    Resource *cur;

    Newx(cur, 1, Resource);
    cur->data = data;
    cur->destroy = destroy;
    cur->next = *sen;
    *sen = cur;

    return cur;
}

static void sentinel_disarm(Resource *p) {
    p->destroy = NULL;
}

static void my_sv_refcnt_dec_void(pTHX_ void *p) {
    SV *sv = p;
    SvREFCNT_dec(sv);
}

static SV *sentinel_mortalize(Sentinel sen, SV *sv) {
    sentinel_register(sen, sv, my_sv_refcnt_dec_void);
    return sv;
}


#if HAVE_PERL_VERSION(5, 17, 2)
 #define MY_OP_SLABBED(O) ((O)->op_slabbed)
#else
 #define MY_OP_SLABBED(O) 0
#endif

DEFSTRUCT(OpGuard) {
    OP *op;
    bool needs_freed;
};

static void op_guard_init(OpGuard *p) {
    p->op = NULL;
    p->needs_freed = FALSE;
}

static OpGuard op_guard_transfer(OpGuard *p) {
    OpGuard r = *p;
    op_guard_init(p);
    return r;
}

static OP *op_guard_relinquish(OpGuard *p) {
    OP *o = p->op;
    op_guard_init(p);
    return o;
}

static void op_guard_update(OpGuard *p, OP *o) {
    p->op = o;
    p->needs_freed = o && !MY_OP_SLABBED(o);
}

static void op_guard_clear(pTHX_ OpGuard *p) {
    if (p->needs_freed) {
        op_free(p->op);
    }
}

static void free_op_guard_void(pTHX_ void *vp) {
    OpGuard *p = vp;
    op_guard_clear(aTHX_ p);
    Safefree(p);
}

static void free_op_void(pTHX_ void *vp) {
    OP *p = vp;
    op_free(p);
}

#define sv_eq_pvs(SV, S) my_sv_eq_pvn(aTHX_ SV, "" S "", sizeof S - 1)

static int my_sv_eq_pvn(pTHX_ SV *sv, const char *p, STRLEN n) {
    STRLEN sv_len;
    const char *sv_p = SvPV(sv, sv_len);
    return sv_len == n && memcmp(sv_p, p, n) == 0;
}


#ifndef newMETHOP
#define newMETHOP newUNOP
#endif

enum {
    MY_ATTR_LVALUE  = 0x01,
    MY_ATTR_METHOD  = 0x02,
    MY_ATTR_SPECIAL = 0x04
};

static void my_sv_cat_c(pTHX_ SV *sv, U32 c) {
    char ds[UTF8_MAXBYTES + 1], *d;
    d = (char *)uvchr_to_utf8((U8 *)ds, c);
    if (d - ds > 1) {
        sv_utf8_upgrade(sv);
    }
    sv_catpvn(sv, ds, d - ds);
}


#define MY_UNI_IDFIRST(C) isIDFIRST_uni(C)
#define MY_UNI_IDCONT(C)  isALNUM_uni(C)
#if HAVE_PERL_VERSION(5, 25, 9)
#define MY_UNI_IDFIRST_utf8(P, Z) isIDFIRST_utf8_safe((const unsigned char *)(P), (const unsigned char *)(Z))
#define MY_UNI_IDCONT_utf8(P, Z)  isWORDCHAR_utf8_safe((const unsigned char *)(P), (const unsigned char *)(Z))
#else
#define MY_UNI_IDFIRST_utf8(P, Z) isIDFIRST_utf8((const unsigned char *)(P))
#define MY_UNI_IDCONT_utf8(P, Z)  isALNUM_utf8((const unsigned char *)(P))
#endif

static SV *my_scan_word(pTHX_ Sentinel sen, bool allow_package) {
    bool at_start, at_substart;
    I32 c;
    SV *sv = sentinel_mortalize(sen, newSVpvs(""));
    if (lex_bufutf8()) {
        SvUTF8_on(sv);
    }

    at_start = at_substart = TRUE;
    c = lex_peek_unichar(0);

    while (c != -1) {
        if (at_substart ? MY_UNI_IDFIRST(c) : MY_UNI_IDCONT(c)) {
            lex_read_unichar(0);
            my_sv_cat_c(aTHX_ sv, c);
            at_substart = FALSE;
            c = lex_peek_unichar(0);
        } else if (allow_package && !at_substart && c == '\'') {
            lex_read_unichar(0);
            c = lex_peek_unichar(0);
            if (!MY_UNI_IDFIRST(c)) {
                lex_stuff_pvs("'", 0);
                break;
            }
            sv_catpvs(sv, "'");
            at_substart = TRUE;
        } else if (allow_package && (at_start || !at_substart) && c == ':') {
            lex_read_unichar(0);
            if (lex_peek_unichar(0) != ':') {
                lex_stuff_pvs(":", 0);
                break;
            }
            lex_read_unichar(0);
            c = lex_peek_unichar(0);
            if (!MY_UNI_IDFIRST(c)) {
                lex_stuff_pvs("::", 0);
                break;
            }
            sv_catpvs(sv, "::");
            at_substart = TRUE;
        } else {
            break;
        }
        at_start = FALSE;
    }

    return SvCUR(sv) ? sv : NULL;
}

static SV *my_scan_parens_tail(pTHX_ Sentinel sen, bool keep_backslash) {
    I32 c, nesting;
    SV *sv;
    line_t start;

    start = CopLINE(PL_curcop);

    sv = sentinel_mortalize(sen, newSVpvs(""));
    if (lex_bufutf8()) {
        SvUTF8_on(sv);
    }

    nesting = 0;
    for (;;) {
        c = lex_read_unichar(0);
        if (c == EOF) {
            CopLINE_set(PL_curcop, start);
            return NULL;
        }

        if (c == '\\') {
            c = lex_read_unichar(0);
            if (c == EOF) {
                CopLINE_set(PL_curcop, start);
                return NULL;
            }
            if (keep_backslash || (c != '(' && c != ')')) {
                sv_catpvs(sv, "\\");
            }
        } else if (c == '(') {
            nesting++;
        } else if (c == ')') {
            if (!nesting) {
                break;
            }
            nesting--;
        }

        my_sv_cat_c(aTHX_ sv, c);
    }

    return sv;
}

static void my_check_prototype(pTHX_ Sentinel sen, const SV *declarator, SV *proto) {
    char *start, *r, *w, *end;
    STRLEN len;

    /* strip spaces */
    start = SvPVbyte_force(proto, len);
    end = start + len;

    for (w = r = start; r < end; r++) {
        if (!isSPACE(*r)) {
            *w++ = *r;
        }
    }
    *w = '\0';
    SvCUR_set(proto, w - start);
    end = w;
    len = end - start;

    if (!ckWARN(WARN_ILLEGALPROTO)) {
        return;
    }

    /* check for bad characters */
    if (strspn(start, "$@%*;[]&\\_+") != len) {
        SV *dsv = sentinel_mortalize(sen, newSVpvs(""));
        warner(
            packWARN(WARN_ILLEGALPROTO),
            "Illegal character in prototype for %"SVf" : %s",
            SVfARG(declarator),
            SvUTF8(proto)
                ? sv_uni_display(
                    dsv,
                    proto,
                    len,
                    UNI_DISPLAY_ISPRINT
                )
                : pv_pretty(dsv, start, len, 60, NULL, NULL,
                    PERL_PV_ESCAPE_NONASCII
                )
        );
        return;
    }

    for (r = start; r < end; r++) {
        switch (*r) {
            default:
                warner(
                    packWARN(WARN_ILLEGALPROTO),
                    "Illegal character in prototype for %"SVf" : %s",
                    SVfARG(declarator), r
                );
                return;

            case '_':
                if (r[1] && !strchr(";@%", r[1])) {
                    warner(
                        packWARN(WARN_ILLEGALPROTO),
                        "Illegal character after '_' in prototype for %"SVf" : %s",
                        SVfARG(declarator), r + 1
                    );
                    return;
                }
                break;

            case '@':
            case '%':
                if (r[1]) {
                    warner(
                        packWARN(WARN_ILLEGALPROTO),
                        "prototype after '%c' for %"SVf": %s",
                        *r, SVfARG(declarator), r + 1
                    );
                    return;
                }
                break;

            case '\\':
                r++;
                if (strchr("$@%&*", *r)) {
                    break;
                }
                if (*r == '[') {
                    r++;
                    for (; r < end && *r != ']'; r++) {
                        if (!strchr("$@%&*", *r)) {
                            break;
                        }
                    }
                    if (*r == ']' && r[-1] != '[') {
                        break;
                    }
                }
                warner(
                    packWARN(WARN_ILLEGALPROTO),
                    "Illegal character after '\\' in prototype for %"SVf" : %s",
                    SVfARG(declarator), r
                );
                return;

            case '$':
            case '*':
            case '&':
            case ';':
            case '+':
                break;
        }
    }
}

static SV *parse_type(pTHX_ Sentinel, const SV *, char);

static SV *parse_type_paramd(pTHX_ Sentinel sen, const SV *declarator, char prev) {
    I32 c;
    SV *t;

    if (!(t = my_scan_word(aTHX_ sen, TRUE))) {
        croak("In %"SVf": missing type name after '%c'", SVfARG(declarator), prev);
    }
    lex_read_space(0);

    c = lex_peek_unichar(0);
    if (c == '[') {
        do {
            SV *u;

            lex_read_unichar(0);
            lex_read_space(0);
            my_sv_cat_c(aTHX_ t, c);

            u = parse_type(aTHX_ sen, declarator, c);
            sv_catsv(t, u);

            c = lex_peek_unichar(0);
        } while (c == ',');
        if (c != ']') {
            croak("In %"SVf": missing ']' after '%"SVf"'", SVfARG(declarator), SVfARG(t));
        }
        lex_read_unichar(0);
        lex_read_space(0);

        my_sv_cat_c(aTHX_ t, c);
    }

    return t;
}

static SV *parse_type(pTHX_ Sentinel sen, const SV *declarator, char prev) {
    I32 c;
    SV *t;

    t = parse_type_paramd(aTHX_ sen, declarator, prev);

    while ((c = lex_peek_unichar(0)) == '|') {
        SV *u;

        lex_read_unichar(0);
        lex_read_space(0);

        my_sv_cat_c(aTHX_ t, c);
        u = parse_type_paramd(aTHX_ sen, declarator, '|');
        sv_catsv(t, u);
    }

    return t;
}

static SV *call_from_curstash(pTHX_ Sentinel sen, SV *sv, SV **args, size_t nargs, I32 flags) {
    SV *r;
    COP curcop_with_stash;
    I32 want;
    dSP;

    if ((flags & G_WANT) == 0) {
        flags |= G_SCALAR;
    }
    want = flags & G_WANT;

    ENTER;
    SAVETMPS;

    PUSHMARK(SP);
    if (!args) {
        flags |= G_NOARGS;
    } else {
        size_t i;
        EXTEND(SP, (SSize_t)nargs);
        for (i = 0; i < nargs; i++) {
            PUSHs(args[i]);
        }
    }
    PUTBACK;

    assert(PL_curcop == &PL_compiling);
    curcop_with_stash = PL_compiling;
    CopSTASH_set(&curcop_with_stash, PL_curstash);
    PL_curcop = &curcop_with_stash;
    call_sv(sv, flags);
    PL_curcop = &PL_compiling;

    if (want == G_VOID) {
        r = NULL;
    } else {
        assert(want == G_SCALAR);
        SPAGAIN;
        r = sentinel_mortalize(sen, SvREFCNT_inc(POPs));
        PUTBACK;
    }

    FREETMPS;
    LEAVE;

    return r;
}

static SV *reify_type(pTHX_ Sentinel sen, const SV *declarator, const KWSpec *spec, SV *name) {
    AV *type_reifiers;
    SV *t, *sv, **psv;

    type_reifiers = get_av(MY_PKG "::type_reifiers", 0);
    assert(type_reifiers != NULL);

    if (spec->reify_type < 0 || spec->reify_type > av_len(type_reifiers)) {
        croak("In %"SVf": internal error: reify_type [%ld] out of range [%ld]", SVfARG(declarator), (long)spec->reify_type, (long)(av_len(type_reifiers) + 1));
    }

    psv = av_fetch(type_reifiers, spec->reify_type, 0);
    assert(psv != NULL);
    sv = *psv;

    t = call_from_curstash(aTHX_ sen, sv, &name, 1, 0);

    if (!sv_isobject(t)) {
        croak("In %"SVf": invalid type '%"SVf"' (%"SVf" is not a type object)", SVfARG(declarator), SVfARG(name), SVfARG(t));
    }

    return t;
}


DEFSTRUCT(Param) {
    SV *name;
    PADOFFSET padoff;
    SV *type;
};

DEFSTRUCT(ParamInit) {
    Param param;
    OpGuard init;
};

DEFVECTOR(Param);
DEFVECTOR(ParamInit);

DEFSTRUCT(ParamSpec) {
    size_t shift;
    VEC(Param) positional_required;
    VEC(ParamInit) positional_optional;
    VEC(Param) named_required;
    VEC(ParamInit) named_optional;
    Param slurpy;
    PADOFFSET rest_hash;
};

DEFVECTOR_INIT(pv_init, Param);
DEFVECTOR_INIT(piv_init, ParamInit);

static void p_init(Param *p) {
    p->name = NULL;
    p->padoff = NOT_IN_PAD;
    p->type = NULL;
}

static void ps_init(ParamSpec *ps) {
    ps->shift = 0;
    pv_init(&ps->positional_required);
    piv_init(&ps->positional_optional);
    pv_init(&ps->named_required);
    piv_init(&ps->named_optional);
    p_init(&ps->slurpy);
    ps->rest_hash = NOT_IN_PAD;
}

DEFVECTOR_EXTEND(pv_extend, Param);
DEFVECTOR_EXTEND(piv_extend, ParamInit);

static void pv_push(VEC(Param) *ps, SV *name, PADOFFSET padoff, SV *type) {
    Param *p = pv_extend(ps);
    p->name = name;
    p->padoff = padoff;
    p->type = type;
    ps->used++;
}

static Param *pv_unshift(VEC(Param) *ps, size_t n) {
    size_t i;
    assert(ps->used <= ps->size);
    if (ps->used + n > ps->size) {
        const size_t n2 = ps->used + n + 10;
        Renew(ps->data, n2, Param);
        ps->size = n2;
    }
    Move(ps->data, ps->data + n, ps->used, Param);
    for (i = 0; i < n; i++) {
        p_init(&ps->data[i]);
    }
    ps->used += n;
    return ps->data;
}

static void p_clear(pTHX_ Param *p) {
    p->name = NULL;
    p->padoff = NOT_IN_PAD;
    p->type = NULL;
}

static void pi_clear(pTHX_ ParamInit *pi) {
    p_clear(aTHX_ &pi->param);
    op_guard_clear(aTHX_ &pi->init);
}

DEFVECTOR_CLEAR(pv_clear, Param, p_clear);
DEFVECTOR_CLEAR(piv_clear, ParamInit, pi_clear);

static void ps_clear(pTHX_ ParamSpec *ps) {
    pv_clear(aTHX_ &ps->positional_required);
    piv_clear(aTHX_ &ps->positional_optional);

    pv_clear(aTHX_ &ps->named_required);
    piv_clear(aTHX_ &ps->named_optional);

    p_clear(aTHX_ &ps->slurpy);
}

static int ps_contains(pTHX_ const ParamSpec *ps, SV *sv) {
    size_t i, lim;

    for (i = 0, lim = ps->positional_required.used; i < lim; i++) {
        if (sv_eq(sv, ps->positional_required.data[i].name)) {
            return 1;
        }
    }

    for (i = 0, lim = ps->positional_optional.used; i < lim; i++) {
        if (sv_eq(sv, ps->positional_optional.data[i].param.name)) {
            return 1;
        }
    }

    for (i = 0, lim = ps->named_required.used; i < lim; i++) {
        if (sv_eq(sv, ps->named_required.data[i].name)) {
            return 1;
        }
    }

    for (i = 0, lim = ps->named_optional.used; i < lim; i++) {
        if (sv_eq(sv, ps->named_optional.data[i].param.name)) {
            return 1;
        }
    }

    return 0;
}

static void ps_free_void(pTHX_ void *p) {
    ps_clear(aTHX_ p);
    Safefree(p);
}

static int args_min(const ParamSpec *ps) {
    return ps->positional_required.used + ps->named_required.used * 2;
}

static int args_max(const ParamSpec *ps) {
    if (ps->named_required.used || ps->named_optional.used || ps->slurpy.name) {
        return -1;
    }
    return ps->positional_required.used + ps->positional_optional.used;
}

static size_t count_positional_params(const ParamSpec *ps) {
    return ps->positional_required.used + ps->positional_optional.used;
}

static size_t count_named_params(const ParamSpec *ps) {
    return ps->named_required.used + ps->named_optional.used;
}

static SV *my_eval(pTHX_ Sentinel sen, I32 floor_ix, OP *op) {
    CV *cv;
    cv = newATTRSUB(floor_ix, NULL, NULL, NULL, op);
    return call_from_curstash(aTHX_ sen, (SV *)cv, NULL, 0, 0);
}

static OP *my_var_g(pTHX_ I32 type, I32 flags, PADOFFSET padoff) {
    OP *var = newOP(type, flags);
    var->op_targ = padoff;
    return var;
}

static OP *my_var(pTHX_ I32 flags, PADOFFSET padoff) {
    return my_var_g(aTHX_ OP_PADSV, flags, padoff);
}

static OP *mkhvelem(pTHX_ PADOFFSET h, OP *k) {
    OP *hv = my_var_g(aTHX_ OP_PADHV, OPf_REF, h);
    return newBINOP(OP_HELEM, 0, hv, k);
}

static OP *mkconstsv(pTHX_ SV *sv) {
    return newSVOP(OP_CONST, 0, sv);
}

static OP *mkconstiv(pTHX_ IV i) {
    return mkconstsv(aTHX_ newSViv(i));
}

static OP *mkconstpv(pTHX_ const char *p, size_t n) {
    return mkconstsv(aTHX_ newSVpv(p, n));
}

#define mkconstpvs(S) mkconstpv(aTHX_ "" S "", sizeof S - 1)

static OP *mkcroak(pTHX_ OP *msg) {
    OP *xcroak;
    xcroak = newCVREF(
        OPf_WANT_SCALAR,
        mkconstsv(aTHX_ newSVpvs(MY_PKG "::_croak"))
    );
    xcroak = newUNOP(OP_ENTERSUB, OPf_STACKED, op_append_elem(OP_LIST, msg, xcroak));
    return xcroak;
}

static OP *mktypecheck(pTHX_ const SV *declarator, int nr, SV *name, PADOFFSET padoff, SV *type) {
    /* $type->check($value) or F:P::_croak "...: " . $type->get_message($value) */
    OP *chk, *err, *msg, *xcroak;

    err = mkconstsv(aTHX_ newSVpvf("In %"SVf": parameter %d (%"SVf"): ", SVfARG(declarator), nr, SVfARG(name)));
    {
        OP *args = NULL;

        args = op_append_elem(OP_LIST, args, mkconstsv(aTHX_ SvREFCNT_inc_simple_NN(type)));
        args = op_append_elem(
            OP_LIST, args,
            padoff == NOT_IN_PAD
                ? newDEFSVOP()
                : my_var(aTHX_ 0, padoff)
        );

        msg = op_convert_list(
            OP_ENTERSUB, OPf_STACKED,
            op_append_elem(OP_LIST, args, newMETHOP(OP_METHOD, 0, mkconstpvs("get_message")))
        );
    }

    msg = newBINOP(OP_CONCAT, 0, err, msg);

    xcroak = mkcroak(aTHX_ msg);

    {
        OP *args = NULL;

        args = op_append_elem(OP_LIST, args, mkconstsv(aTHX_ SvREFCNT_inc_simple_NN(type)));
        args = op_append_elem(
            OP_LIST, args,
            padoff == NOT_IN_PAD
                ? newDEFSVOP()
                : my_var(aTHX_ 0, padoff)
        );

        chk = op_convert_list(
            OP_ENTERSUB, OPf_STACKED,
            op_append_elem(OP_LIST, args, newMETHOP(OP_METHOD, 0, mkconstpvs("check")))
        );
    }

    chk = newLOGOP(OP_OR, 0, chk, xcroak);
    return chk;
}

static OP *mktypecheckp(pTHX_ const SV *declarator, int nr, const Param *param) {
    return mktypecheck(aTHX_ declarator, nr, param->name, param->padoff, param->type);
}

enum {
    PARAM_INVOCANT = 0x01,
    PARAM_NAMED    = 0x02
};

static PADOFFSET parse_param(
    pTHX_
    Sentinel sen,
    const SV *declarator, const KWSpec *spec, ParamSpec *param_spec,
    int *pflags, SV **pname, OpGuard *ginit, SV **ptype
) {
    I32 c;
    char sigil;
    SV *name;

    assert(!ginit->op);
    *pflags = 0;
    *ptype = NULL;

    c = lex_peek_unichar(0);

    if (spec->flags & FLAG_TYPES_OK) {
        if (c == '(') {
            I32 floor_ix;
            OP *expr;
            Resource *expr_sentinel;

            lex_read_unichar(0);

            floor_ix = start_subparse(FALSE, 0);
            SAVEFREESV(PL_compcv);
            CvSPECIAL_on(PL_compcv);

            if (!(expr = parse_fullexpr(PARSE_OPTIONAL))) {
                croak("In %"SVf": invalid type expression", SVfARG(declarator));
            }
            if (MY_OP_SLABBED(expr)) {
                expr_sentinel = NULL;
            } else {
                expr_sentinel = sentinel_register(sen, expr, free_op_void);
            }

            lex_read_space(0);
            c = lex_peek_unichar(0);
            if (c != ')') {
                croak("In %"SVf": missing ')' after type expression", SVfARG(declarator));
            }
            lex_read_unichar(0);
            lex_read_space(0);

            SvREFCNT_inc_simple_void(PL_compcv);
            if (expr_sentinel) {
                sentinel_disarm(expr_sentinel);
            }
            *ptype = my_eval(aTHX_ sen, floor_ix, expr);
            if (!SvROK(*ptype)) {
                *ptype = reify_type(aTHX_ sen, declarator, spec, *ptype);
            } else if (!sv_isobject(*ptype)) {
                croak("In %"SVf": invalid type (%"SVf" is not a type object)", SVfARG(declarator), SVfARG(*ptype));
            }

            c = lex_peek_unichar(0);
        } else if (MY_UNI_IDFIRST(c)) {
            *ptype = parse_type(aTHX_ sen, declarator, ',');
            *ptype = reify_type(aTHX_ sen, declarator, spec, *ptype);

            c = lex_peek_unichar(0);
        }
    }

    if (c == ':') {
        lex_read_unichar(0);
        lex_read_space(0);

        *pflags |= PARAM_NAMED;

        c = lex_peek_unichar(0);
    }

    if (c == -1) {
        croak("In %"SVf": unterminated parameter list", SVfARG(declarator));
    }

    if (!(c == '$' || c == '@' || c == '%')) {
        croak("In %"SVf": unexpected '%c' in parameter list (expecting a sigil)", SVfARG(declarator), (int)c);
    }

    sigil = c;

    lex_read_unichar(0);

    c = lex_peek_unichar(0);
    if (c == '#') {
        croak("In %"SVf": unexpected '%c#' in parameter list (expecting an identifier)", SVfARG(declarator), sigil);
    }

    lex_read_space(0);

    if (!(name = my_scan_word(aTHX_ sen, FALSE))) {
        name = sentinel_mortalize(sen, newSVpvs(""));
    } else if (sv_eq_pvs(name, "_")) {
        croak("In %"SVf": Can't use global %c_ as a parameter", SVfARG(declarator), sigil);
    }
    sv_insert(name, 0, 0, &sigil, 1);
    *pname = name;

    lex_read_space(0);
    c = lex_peek_unichar(0);

    if (c == '=') {
        lex_read_unichar(0);
        lex_read_space(0);

        c = lex_peek_unichar(0);
        if (c == ',' || c == ')') {
            op_guard_update(ginit, newOP(OP_UNDEF, 0));
        } else {
            if (param_spec->shift == 0 && spec->shift.used) {
                size_t i, lim = spec->shift.used;
                Param *p = pv_unshift(&param_spec->positional_required, lim);
                for (i = 0; i < lim; i++) {
                    p[i].name = spec->shift.data[i].name;
                    p[i].padoff = pad_add_name_sv(p[i].name, 0, NULL, NULL);
                    p[i].type = spec->shift.data[i].type;
                }
                param_spec->shift = lim;
                intro_my();
            }

            op_guard_update(ginit, parse_termexpr(0));

            lex_read_space(0);
            c = lex_peek_unichar(0);
        }
    }

    if (c == ':') {
        *pflags |= PARAM_INVOCANT;
        lex_read_unichar(0);
        lex_read_space(0);
    } else if (c == ',') {
        lex_read_unichar(0);
        lex_read_space(0);
    } else if (c != ')') {
        if (c == -1) {
            croak("In %"SVf": unterminated parameter list", SVfARG(declarator));
        }
        croak("In %"SVf": unexpected '%c' in parameter list (expecting ',')", SVfARG(declarator), (int)c);
    }

    return SvCUR(*pname) < 2
        ? NOT_IN_PAD
        : pad_add_name_sv(*pname, padadd_NO_DUP_CHECK, NULL, NULL)
    ;
}

static void register_info(pTHX_ UV key, SV *declarator, const ParamSpec *ps) {
    dSP;

    ENTER;
    SAVETMPS;

    PUSHMARK(SP);
    EXTEND(SP, 9);

    /* 0 */ {
        mPUSHu(key);
    }
    /* 1 */ {
        STRLEN n;
        char *p = SvPV(declarator, n);
        char *q = memchr(p, ' ', n);
        SV *tmp = newSVpvn_utf8(p, q ? (size_t)(q - p) : n, SvUTF8(declarator));
        mPUSHs(tmp);
    }
    /* 2 */ {
        mPUSHu(ps->shift);
    }
    /* 3 */ {
        size_t i, lim;
        AV *av;

        lim = ps->positional_required.used;

        av = newAV();
        if (lim) {
            av_extend(av, (lim - 1) * 2);
            for (i = 0; i < lim; i++) {
                Param *cur = &ps->positional_required.data[i];
                av_push(av, SvREFCNT_inc_simple_NN(cur->name));
                av_push(av, cur->type ? SvREFCNT_inc_simple_NN(cur->type) : &PL_sv_undef);
            }
        }

        mPUSHs(newRV_noinc((SV *)av));
    }
    /* 4 */ {
        size_t i, lim;
        AV *av;

        lim = ps->positional_optional.used;

        av = newAV();
        if (lim) {
            av_extend(av, (lim - 1) * 2);
            for (i = 0; i < lim; i++) {
                Param *cur = &ps->positional_optional.data[i].param;
                av_push(av, SvREFCNT_inc_simple_NN(cur->name));
                av_push(av, cur->type ? SvREFCNT_inc_simple_NN(cur->type) : &PL_sv_undef);
            }
        }

        mPUSHs(newRV_noinc((SV *)av));
    }
    /* 5 */ {
        size_t i, lim;
        AV *av;

        lim = ps->named_required.used;

        av = newAV();
        if (lim) {
            av_extend(av, (lim - 1) * 2);
            for (i = 0; i < lim; i++) {
                Param *cur = &ps->named_required.data[i];
                av_push(av, SvREFCNT_inc_simple_NN(cur->name));
                av_push(av, cur->type ? SvREFCNT_inc_simple_NN(cur->type) : &PL_sv_undef);
            }
        }

        mPUSHs(newRV_noinc((SV *)av));
    }
    /* 6 */ {
        size_t i, lim;
        AV *av;

        lim = ps->named_optional.used;

        av = newAV();
        if (lim) {
            av_extend(av, (lim - 1) * 2);
            for (i = 0; i < lim; i++) {
                Param *cur = &ps->named_optional.data[i].param;
                av_push(av, SvREFCNT_inc_simple_NN(cur->name));
                av_push(av, cur->type ? SvREFCNT_inc_simple_NN(cur->type) : &PL_sv_undef);
            }
        }

        mPUSHs(newRV_noinc((SV *)av));
    }
    /* 7, 8 */ {
        if (ps->slurpy.name) {
            PUSHs(ps->slurpy.name);
            if (ps->slurpy.type) {
                PUSHs(ps->slurpy.type);
            } else {
                PUSHmortal;
            }
        } else {
            PUSHmortal;
            PUSHmortal;
        }
    }
    PUTBACK;

    call_pv(MY_PKG "::_register_info", G_VOID);

    FREETMPS;
    LEAVE;
}

static int parse_fun(pTHX_ Sentinel sen, OP **pop, const char *keyword_ptr, STRLEN keyword_len, const KWSpec *spec) {
    ParamSpec *param_spec;
    SV *declarator;
    I32 floor_ix;
    int save_ix;
    SV *saw_name;
    OpGuard *prelude_sentinel;
    SV *proto;
    OpGuard *attrs_sentinel;
    OP *body;
    unsigned builtin_attrs;
    I32 c;

    declarator = sentinel_mortalize(sen, newSVpvn(keyword_ptr, keyword_len));
    if (lex_bufutf8()) {
        SvUTF8_on(declarator);
    }

    lex_read_space(0);

    builtin_attrs = 0;

    /* function name */
    saw_name = NULL;
    if ((spec->flags & FLAG_NAME_OK) && (saw_name = my_scan_word(aTHX_ sen, TRUE))) {

        if (PL_parser->expect != XSTATE) {
            /* bail out early so we don't predeclare $saw_name */
            croak("In %"SVf": I was expecting a parameter list, not \"%"SVf"\"", SVfARG(declarator), SVfARG(saw_name));
        }

        sv_catpvs(declarator, " ");
        sv_catsv(declarator, saw_name);

        if (
            sv_eq_pvs(saw_name, "BEGIN") ||
            sv_eq_pvs(saw_name, "END") ||
            sv_eq_pvs(saw_name, "INIT") ||
            sv_eq_pvs(saw_name, "CHECK") ||
            sv_eq_pvs(saw_name, "UNITCHECK")
        ) {
            builtin_attrs |= MY_ATTR_SPECIAL;
        }

        lex_read_space(0);
    } else if (!(spec->flags & FLAG_ANON_OK)) {
        croak("I was expecting a function name, not \"%.*s\"", (int)(PL_parser->bufend - PL_parser->bufptr), PL_parser->bufptr);
    } else {
        sv_catpvs(declarator, " (anon)");
    }

    /* we're a subroutine declaration */
    floor_ix = start_subparse(FALSE, saw_name ? 0 : CVf_ANON);
    SAVEFREESV(PL_compcv);

    /* create outer block: '{' */
    save_ix = block_start(TRUE);

    /* initialize synthetic optree */
    Newx(prelude_sentinel, 1, OpGuard);
    op_guard_init(prelude_sentinel);
    sentinel_register(sen, prelude_sentinel, free_op_guard_void);

    /* parameters */
    c = lex_peek_unichar(0);
    if (c != '(') {
        croak("In %"SVf": I was expecting a parameter list, not \"%c\"", SVfARG(declarator), (int)c);
    }

    lex_read_unichar(0);
    lex_read_space(0);

    Newx(param_spec, 1, ParamSpec);
    ps_init(param_spec);
    sentinel_register(sen, param_spec, ps_free_void);

    {
        OpGuard *init_sentinel;

        Newx(init_sentinel, 1, OpGuard);
        op_guard_init(init_sentinel);
        sentinel_register(sen, init_sentinel, free_op_guard_void);

        while ((c = lex_peek_unichar(0)) != ')') {
            int flags;
            SV *name, *type;
            char sigil;
            PADOFFSET padoff;

            padoff = parse_param(aTHX_ sen, declarator, spec, param_spec, &flags, &name, init_sentinel, &type);

            if (padoff != NOT_IN_PAD) {
                intro_my();
            }

            sigil = SvPV_nolen(name)[0];

            /* internal consistency */
            if (flags & PARAM_NAMED) {
                if (padoff == NOT_IN_PAD) {
                    croak("In %"SVf": named parameter %"SVf" can't be unnamed", SVfARG(declarator), SVfARG(name));
                }
                if (flags & PARAM_INVOCANT) {
                    croak("In %"SVf": invocant %"SVf" can't be a named parameter", SVfARG(declarator), SVfARG(name));
                }
                if (sigil != '$') {
                    croak("In %"SVf": named parameter %"SVf" can't be a%s", SVfARG(declarator), SVfARG(name), sigil == '@' ? "n array" : " hash");
                }
            } else if (flags & PARAM_INVOCANT) {
                if (init_sentinel->op) {
                    croak("In %"SVf": invocant %"SVf" can't have a default value", SVfARG(declarator), SVfARG(name));
                }
                if (sigil != '$') {
                    croak("In %"SVf": invocant %"SVf" can't be a%s", SVfARG(declarator), SVfARG(name), sigil == '@' ? "n array" : " hash");
                }
            } else if (sigil != '$' && init_sentinel->op) {
                croak("In %"SVf": %s %"SVf" can't have a default value", SVfARG(declarator), sigil == '@' ? "array" : "hash", SVfARG(name));
            }
            if (type && padoff == NOT_IN_PAD) {
                croak("In %"SVf": unnamed parameter %"SVf" can't have a type", SVfARG(declarator), SVfARG(name));
            }

            /* external constraints */
            if (param_spec->slurpy.name) {
                croak("In %"SVf": \"%"SVf"\" can't appear after slurpy parameter \"%"SVf"\"", SVfARG(declarator), SVfARG(name), SVfARG(param_spec->slurpy.name));
            }
            if (sigil != '$') {
                assert(!init_sentinel->op);
                param_spec->slurpy.name = name;
                param_spec->slurpy.padoff = padoff;
                param_spec->slurpy.type = type;
                continue;
            }

            if (!(flags & PARAM_NAMED) && count_named_params(param_spec)) {
                croak("In %"SVf": positional parameter %"SVf" can't appear after named parameter %"SVf"", SVfARG(declarator), SVfARG(name), SVfARG((param_spec->named_required.used ? param_spec->named_required.data[0] : param_spec->named_optional.data[0].param).name));
            }

            if (flags & PARAM_INVOCANT) {
                if (param_spec->shift) {
                    assert(param_spec->shift <= param_spec->positional_required.used);
                    croak("In %"SVf": invalid double invocants (... %"SVf": ... %"SVf":)", SVfARG(declarator), SVfARG(param_spec->positional_required.data[param_spec->shift - 1].name), SVfARG(name));
                }
                if (!(spec->flags & FLAG_INVOCANT)) {
                    croak("In %"SVf": invocant %"SVf" not allowed here", SVfARG(declarator), SVfARG(name));
                }
                if (spec->shift.used && spec->shift.used != param_spec->positional_required.used + 1) {
                    croak("In %"SVf": number of invocants in parameter list (%lu) differs from number of invocants in keyword definition (%lu)", SVfARG(declarator), (unsigned long)(param_spec->positional_required.used + 1), (unsigned long)spec->shift.used);
                }
            }

            if (!(flags & PARAM_NAMED) && !init_sentinel->op && param_spec->positional_optional.used) {
                croak("In %"SVf": required parameter %"SVf" can't appear after optional parameter %"SVf"", SVfARG(declarator), SVfARG(name), SVfARG(param_spec->positional_optional.data[0].param.name));
            }

            if (init_sentinel->op && !(spec->flags & FLAG_DEFAULT_ARGS)) {
                croak("In %"SVf": default argument for %"SVf" not allowed here", SVfARG(declarator), SVfARG(name));
            }

            if (padoff != NOT_IN_PAD && ps_contains(aTHX_ param_spec, name)) {
                croak("In %"SVf": %"SVf" can't appear twice in the same parameter list", SVfARG(declarator), SVfARG(name));
            }

            if (flags & PARAM_NAMED) {
                if (!(spec->flags & FLAG_NAMED_PARAMS)) {
                    croak("In %"SVf": named parameter :%"SVf" not allowed here", SVfARG(declarator), SVfARG(name));
                }

                if (init_sentinel->op) {
                    ParamInit *pi = piv_extend(&param_spec->named_optional);
                    pi->param.name = name;
                    pi->param.padoff = padoff;
                    pi->param.type = type;
                    pi->init = op_guard_transfer(init_sentinel);
                    param_spec->named_optional.used++;
                } else {
                    if (param_spec->positional_optional.used) {
                        croak("In %"SVf": can't combine optional positional (%"SVf") and required named (%"SVf") parameters", SVfARG(declarator), SVfARG(param_spec->positional_optional.data[0].param.name), SVfARG(name));
                    }

                    pv_push(&param_spec->named_required, name, padoff, type);
                }
            } else {
                if (init_sentinel->op) {
                    ParamInit *pi = piv_extend(&param_spec->positional_optional);
                    pi->param.name = name;
                    pi->param.padoff = padoff;
                    pi->param.type = type;
                    pi->init = op_guard_transfer(init_sentinel);
                    param_spec->positional_optional.used++;
                } else {
                    assert(param_spec->positional_optional.used == 0);
                    pv_push(&param_spec->positional_required, name, padoff, type);
                    if (flags & PARAM_INVOCANT) {
                        assert(param_spec->shift == 0);
                        param_spec->shift = param_spec->positional_required.used;
                    }
                }
            }

        }
        lex_read_unichar(0);
        lex_read_space(0);

        if (param_spec->shift == 0 && spec->shift.used) {
            size_t i, lim = spec->shift.used;
            Param *p;
            p = pv_unshift(&param_spec->positional_required, lim);
            for (i = 0; i < lim; i++) {
                const SpecParam *const cur = &spec->shift.data[i];
                if (ps_contains(aTHX_ param_spec, cur->name)) {
                    croak("In %"SVf": %"SVf" can't appear twice in the same parameter list", SVfARG(declarator), SVfARG(cur->name));
                }

                p[i].name = cur->name;
                p[i].padoff = pad_add_name_sv(p[i].name, 0, NULL, NULL);
                p[i].type = cur->type;
            }
            param_spec->shift = lim;
        }
    }

    /* attributes */
    Newx(attrs_sentinel, 1, OpGuard);
    op_guard_init(attrs_sentinel);
    sentinel_register(sen, attrs_sentinel, free_op_guard_void);
    proto = NULL;

    c = lex_peek_unichar(0);
    if (c == ':' || c == '{') /* '}' - hi, vim */ {

        /* kludge default attributes in */
        if (SvTRUE(spec->attrs) && SvPV_nolen(spec->attrs)[0] == ':') {
            lex_stuff_sv(spec->attrs, 0);
            c = ':';
        }

        if (c == ':') {
            lex_read_unichar(0);
            lex_read_space(0);
            c = lex_peek_unichar(0);

            for (;;) {
                SV *attr;

                if (!(attr = my_scan_word(aTHX_ sen, FALSE))) {
                    break;
                }

                lex_read_space(0);
                c = lex_peek_unichar(0);

                if (c != '(') {
                    if (sv_eq_pvs(attr, "lvalue")) {
                        builtin_attrs |= MY_ATTR_LVALUE;
                        attr = NULL;
                    } else if (sv_eq_pvs(attr, "method")) {
                        builtin_attrs |= MY_ATTR_METHOD;
                        attr = NULL;
                    }
                } else {
                    SV *sv;
                    lex_read_unichar(0);
                    if (!(sv = my_scan_parens_tail(aTHX_ sen, TRUE))) {
                        croak("In %"SVf": unterminated attribute parameter in attribute list", SVfARG(declarator));
                    }

                    if (sv_eq_pvs(attr, "prototype")) {
                        if (proto) {
                            croak("In %"SVf": Can't redefine prototype (%"SVf") using attribute prototype(%"SVf")", SVfARG(declarator), SVfARG(proto), SVfARG(sv));
                        }
                        proto = sv;
                        my_check_prototype(aTHX_ sen, declarator, proto);
                        attr = NULL;
                    } else {
                        sv_catpvs(attr, "(");
                        sv_catsv(attr, sv);
                        sv_catpvs(attr, ")");
                    }

                    lex_read_space(0);
                    c = lex_peek_unichar(0);
                }

                if (attr) {
                    op_guard_update(attrs_sentinel, op_append_elem(OP_LIST, attrs_sentinel->op, mkconstsv(aTHX_ SvREFCNT_inc_simple_NN(attr))));
                }

                if (c == ':') {
                    lex_read_unichar(0);
                    lex_read_space(0);
                    c = lex_peek_unichar(0);
                }
            }
        }
    }

    /* body */
    if (c != '{') /* '}' - hi, vim */ {
        croak("In %"SVf": I was expecting a function body, not \"%c\"", SVfARG(declarator), (int)c);
    }

    /* surprise predeclaration! */
    if (saw_name && !spec->install_sub && !(spec->flags & FLAG_RUNTIME)) {
        /* 'sub NAME (PROTO);' to make name/proto known to perl before it
           starts parsing the body */
        const I32 sub_ix = start_subparse(FALSE, 0);
        SAVEFREESV(PL_compcv);

        SvREFCNT_inc_simple_void(PL_compcv);

#if HAVE_BUG_129090
        {
            CV *const outside = CvOUTSIDE(PL_compcv);
            if (outside) {
                CvOUTSIDE(PL_compcv) = NULL;
                if (!CvWEAKOUTSIDE(PL_compcv)) {
                    SvREFCNT_dec_NN(outside);
                }
            }
        }
#endif
        newATTRSUB(
            sub_ix,
            mkconstsv(aTHX_ SvREFCNT_inc_simple_NN(saw_name)),
            proto ? mkconstsv(aTHX_ SvREFCNT_inc_simple_NN(proto)) : NULL,
            NULL,
            NULL
        );
    }

    if (builtin_attrs & MY_ATTR_LVALUE) {
        CvLVALUE_on(PL_compcv);
    }
    if (builtin_attrs & MY_ATTR_METHOD) {
        CvMETHOD_on(PL_compcv);
    }
    if (builtin_attrs & MY_ATTR_SPECIAL) {
        CvSPECIAL_on(PL_compcv);
    }

    /* check number of arguments */
    if (spec->flags & FLAG_CHECK_NARGS) {
        int amin, amax;

        amin = args_min(param_spec);
        if (amin > 0) {
            OP *chk, *cond, *err;

            err = mkconstsv(aTHX_ newSVpvf("Too few arguments for %"SVf" (expected %d, got ", SVfARG(declarator), amin));
            err = newBINOP(
                OP_CONCAT, 0,
                err,
                newAVREF(newGVOP(OP_GV, 0, PL_defgv))
            );
            err = newBINOP(
                OP_CONCAT, 0,
                err,
                mkconstpvs(")")
            );

            err = mkcroak(aTHX_ err);

            cond = newBINOP(OP_LT, 0,
                            newAVREF(newGVOP(OP_GV, 0, PL_defgv)),
                            mkconstiv(aTHX_ amin));
            chk = newLOGOP(OP_AND, 0, cond, err);

            op_guard_update(prelude_sentinel, op_append_list(OP_LINESEQ, prelude_sentinel->op, newSTATEOP(0, NULL, chk)));
        }

        amax = args_max(param_spec);
        if (amax >= 0) {
            OP *chk, *cond, *err;

            err = mkconstsv(aTHX_ newSVpvf("Too many arguments for %"SVf" (expected %d, got ", SVfARG(declarator), amax));
            err = newBINOP(
                OP_CONCAT, 0,
                err,
                newAVREF(newGVOP(OP_GV, 0, PL_defgv))
            );
            err = newBINOP(
                OP_CONCAT, 0,
                err,
                mkconstpvs(")")
            );

            err = mkcroak(aTHX_ err);

            cond = newBINOP(
                OP_GT, 0,
                newAVREF(newGVOP(OP_GV, 0, PL_defgv)),
                mkconstiv(aTHX_ amax)
            );
            chk = newLOGOP(OP_AND, 0, cond, err);

            op_guard_update(prelude_sentinel, op_append_list(OP_LINESEQ, prelude_sentinel->op, newSTATEOP(0, NULL, chk)));
        }

        if (count_named_params(param_spec) || (param_spec->slurpy.name && SvPV_nolen(param_spec->slurpy.name)[0] == '%')) {
            OP *chk, *cond, *err;
            const UV fixed = count_positional_params(param_spec);

            err = mkconstsv(aTHX_ newSVpvf("Odd number of paired arguments for %"SVf"", SVfARG(declarator)));

            err = mkcroak(aTHX_ err);

            cond = newBINOP(OP_GT, 0,
                            newAVREF(newGVOP(OP_GV, 0, PL_defgv)),
                            mkconstiv(aTHX_ fixed));
            cond = newLOGOP(OP_AND, 0,
                            cond,
                            newBINOP(OP_MODULO, 0,
                                     fixed
                                     ? newBINOP(OP_SUBTRACT, 0,
                                                newAVREF(newGVOP(OP_GV, 0, PL_defgv)),
                                                mkconstiv(aTHX_ fixed))
                                     : newAVREF(newGVOP(OP_GV, 0, PL_defgv)),
                                     mkconstiv(aTHX_ 2)));
            chk = newLOGOP(OP_AND, 0, cond, err);

            op_guard_update(prelude_sentinel, op_append_list(OP_LINESEQ, prelude_sentinel->op, newSTATEOP(0, NULL, chk)));
        }
    }

    assert(param_spec->shift <= param_spec->positional_required.used);
    if (param_spec->shift) {
        bool all_anon = TRUE;
        {
            size_t i;
            for (i = 0; i < param_spec->shift; i++) {
                if (param_spec->positional_required.data[i].padoff != NOT_IN_PAD) {
                    all_anon = FALSE;
                    break;
                }
            }
        }
        if (param_spec->shift == 1) {
            if (all_anon) {
                /* shift; */
                op_guard_update(prelude_sentinel, op_append_list(OP_LINESEQ, prelude_sentinel->op, newSTATEOP(0, NULL, newOP(OP_SHIFT, 0))));
            } else {
                /* my $invocant = shift; */
                OP *var;

                var = my_var(
                    aTHX_
                    OPf_MOD | (OPpLVAL_INTRO << 8),
                    param_spec->positional_required.data[0].padoff
                );
                var = newASSIGNOP(OPf_STACKED, var, 0, newOP(OP_SHIFT, 0));

                op_guard_update(prelude_sentinel, op_append_list(OP_LINESEQ, prelude_sentinel->op, newSTATEOP(0, NULL, var)));

                if (param_spec->positional_required.data[0].type && (spec->flags & FLAG_CHECK_TARGS)) {
                    op_guard_update(prelude_sentinel, op_append_list(OP_LINESEQ, prelude_sentinel->op, newSTATEOP(0, NULL, mktypecheckp(aTHX_ declarator, 0, &param_spec->positional_required.data[0]))));
                }
            }
        } else {
            OP *const rhs = op_convert_list(OP_SPLICE, 0,
                op_append_elem(
                    OP_LIST,
                    op_append_elem(
                        OP_LIST,
                        newAVREF(newGVOP(OP_GV, 0, PL_defgv)),
                        mkconstiv(aTHX_ 0)
                    ),
                    mkconstiv(aTHX_ param_spec->shift)));
            if (all_anon) {
                /* splice @_, 0, $n; */
                op_guard_update(
                    prelude_sentinel,
                    op_append_list(
                        OP_LINESEQ,
                        prelude_sentinel->op,
                        newSTATEOP(0, NULL, rhs)));
            } else {
                /* my (...) = splice @_, 0, $n; */
                OP *lhs;
                size_t i, lim;

                lhs = NULL;

                for (i = 0, lim = param_spec->shift; i < lim; i++) {
                    const PADOFFSET padoff = param_spec->positional_required.data[i].padoff;
                    lhs = op_append_elem(
                        OP_LIST,
                        lhs,
                        padoff == NOT_IN_PAD
                            ? newOP(OP_UNDEF, 0)
                            : my_var(
                                aTHX_
                                OPf_WANT_LIST | (OPpLVAL_INTRO << 8),
                                padoff
                            )
                    );
                }

                lhs->op_flags |= OPf_PARENS;

                op_guard_update(prelude_sentinel, op_append_list(
                    OP_LINESEQ, prelude_sentinel->op,
                    newSTATEOP(
                        0, NULL,
                        newASSIGNOP(OPf_STACKED, lhs, 0, rhs)
                    )
                ));
            }
        }
    }

    /* my (...) = @_; */
    {
        OP *lhs;
        size_t i, lim;

        lhs = NULL;

        for (i = param_spec->shift, lim = param_spec->positional_required.used; i < lim; i++) {
            const PADOFFSET padoff = param_spec->positional_required.data[i].padoff;
            lhs = op_append_elem(
                OP_LIST,
                lhs,
                padoff == NOT_IN_PAD
                    ? newOP(OP_UNDEF, 0)
                    : my_var(
                        aTHX_
                        OPf_WANT_LIST | (OPpLVAL_INTRO << 8),
                        padoff
                    )
            );
        }

        for (i = 0, lim = param_spec->positional_optional.used; i < lim; i++) {
            const PADOFFSET padoff = param_spec->positional_optional.data[i].param.padoff;
            lhs = op_append_elem(
                OP_LIST,
                lhs,
                padoff == NOT_IN_PAD
                    ? newOP(OP_UNDEF, 0)
                    : my_var(
                        aTHX_
                        OPf_WANT_LIST | (OPpLVAL_INTRO << 8),
                        padoff
                    )
            );
        }

        {
            PADOFFSET padoff;
            I32 type;
            bool slurpy_hash;

            /*
             * cases:
             *  1) no named params
             *   1.1) slurpy
             *       => put it in
             *   1.2) no slurpy
             *       => nop
             *  2) named params
             *   2.1) no slurpy
             *       => synthetic %{__rest}
             *   2.2) slurpy is a hash
             *       => put it in
             *   2.3) slurpy is an array
             *       => synthetic %{__rest}
             *          remember to declare array later
             */

            slurpy_hash = param_spec->slurpy.name && SvPV_nolen(param_spec->slurpy.name)[0] == '%';
            if (!count_named_params(param_spec)) {
                if (param_spec->slurpy.name && param_spec->slurpy.padoff != NOT_IN_PAD) {
                    padoff = param_spec->slurpy.padoff;
                    type = slurpy_hash ? OP_PADHV : OP_PADAV;
                } else {
                    padoff = NOT_IN_PAD;
                    type = OP_PADSV;
                }
            } else if (slurpy_hash && param_spec->slurpy.padoff != NOT_IN_PAD) {
                padoff = param_spec->slurpy.padoff;
                type = OP_PADHV;
            } else {
                padoff = pad_add_name_pvs("%{__rest}", 0, NULL, NULL);
                type = OP_PADHV;
            }

            if (padoff != NOT_IN_PAD) {
                OP *const var = my_var_g(
                    aTHX_
                    type,
                    OPf_WANT_LIST | (OPpLVAL_INTRO << 8),
                    padoff
                );

                lhs = op_append_elem(OP_LIST, lhs, var);

                if (type == OP_PADHV) {
                    param_spec->rest_hash = padoff;
                }
            }
        }

        if (lhs) {
            OP *const rhs = newAVREF(newGVOP(OP_GV, 0, PL_defgv));
            lhs->op_flags |= OPf_PARENS;

            op_guard_update(prelude_sentinel, op_append_list(
                OP_LINESEQ, prelude_sentinel->op,
                newSTATEOP(
                    0, NULL,
                    newASSIGNOP(OPf_STACKED, lhs, 0, rhs)
                )
            ));
        }
    }

    /* default positional arguments */
    {
        size_t i, lim, req;
        OP *nest;

        nest = NULL;

        req = param_spec->positional_required.used - param_spec->shift;
        for (i = 0, lim = param_spec->positional_optional.used; i < lim; i++) {
            ParamInit *cur = &param_spec->positional_optional.data[i];
            OP *cond, *init;

            {
                OP *const init_op = cur->init.op;
                if (init_op->op_type == OP_UNDEF && !(init_op->op_flags & OPf_KIDS)) {
                    continue;
                }
            }

            cond = newBINOP(
                OP_LT, 0,
                newAVREF(newGVOP(OP_GV, 0, PL_defgv)),
                mkconstiv(aTHX_ req + i + 1)
            );

            init = op_guard_relinquish(&cur->init);
            if (cur->param.padoff != NOT_IN_PAD) {
                OP *var = my_var(aTHX_ 0, cur->param.padoff);
                init = newASSIGNOP(OPf_STACKED, var, 0, init);
            }

            nest = op_append_list(OP_LINESEQ, nest, init);
            nest = newCONDOP(0, cond, nest, NULL);
        }

        op_guard_update(prelude_sentinel, op_append_list(
            OP_LINESEQ, prelude_sentinel->op,
            nest
        ));
    }

    /* named parameters */
    if (count_named_params(param_spec)) {
        size_t i, lim;

        assert(param_spec->rest_hash != NOT_IN_PAD);

        for (i = 0, lim = param_spec->named_required.used; i < lim; i++) {
            Param *cur = &param_spec->named_required.data[i];
            size_t n;
            char *p = SvPV(cur->name, n);
            OP *var, *cond;

            assert(cur->padoff != NOT_IN_PAD);

            cond = mkhvelem(aTHX_ param_spec->rest_hash, mkconstpv(aTHX_ p + 1, n - 1));

            if (spec->flags & FLAG_CHECK_NARGS) {
                OP *xcroak, *msg;

                var = mkhvelem(aTHX_ param_spec->rest_hash, mkconstpv(aTHX_ p + 1, n - 1));
                var = newUNOP(OP_DELETE, 0, var);

                msg = mkconstsv(aTHX_ newSVpvf("In %"SVf": missing named parameter: %.*s", SVfARG(declarator), (int)(n - 1), p + 1));
                xcroak = mkcroak(aTHX_ msg);

                cond = newUNOP(OP_EXISTS, 0, cond);

                cond = newCONDOP(0, cond, var, xcroak);
            }

            var = my_var(
                aTHX_
                OPf_MOD | (OPpLVAL_INTRO << 8),
                cur->padoff
            );
            var = newASSIGNOP(OPf_STACKED, var, 0, cond);

            op_guard_update(prelude_sentinel, op_append_list(OP_LINESEQ, prelude_sentinel->op, newSTATEOP(0, NULL, var)));
        }

        for (i = 0, lim = param_spec->named_optional.used; i < lim; i++) {
            ParamInit *cur = &param_spec->named_optional.data[i];
            size_t n;
            char *p = SvPV(cur->param.name, n);
            OP *var, *expr;

            expr = mkhvelem(aTHX_ param_spec->rest_hash, mkconstpv(aTHX_ p + 1, n - 1));
            expr = newUNOP(OP_DELETE, 0, expr);

            {
                OP *const init = cur->init.op;
                if (!(init->op_type == OP_UNDEF && !(init->op_flags & OPf_KIDS))) {
                    OP *cond;

                    cond = mkhvelem(aTHX_ param_spec->rest_hash, mkconstpv(aTHX_ p + 1, n - 1));
                    cond = newUNOP(OP_EXISTS, 0, cond);

                    expr = newCONDOP(0, cond, expr, op_guard_relinquish(&cur->init));
                }
            }

            var = my_var(
                aTHX_
                OPf_MOD | (OPpLVAL_INTRO << 8),
                cur->param.padoff
            );
            var = newASSIGNOP(OPf_STACKED, var, 0, expr);

            op_guard_update(prelude_sentinel, op_append_list(OP_LINESEQ, prelude_sentinel->op, newSTATEOP(0, NULL, var)));
        }

        if (!param_spec->slurpy.name) {
            if (spec->flags & FLAG_CHECK_NARGS) {
                /* croak if %{__rest} */
                OP *xcroak, *cond, *keys, *msg;

                keys = newUNOP(OP_KEYS, 0, my_var_g(aTHX_ OP_PADHV, 0, param_spec->rest_hash));
                keys = newLISTOP(OP_SORT, 0, newOP(OP_PUSHMARK, 0), keys);
                keys->op_flags = (keys->op_flags & ~OPf_WANT) | OPf_WANT_LIST;
                keys = op_convert_list(OP_JOIN, 0, op_prepend_elem(OP_LIST, mkconstpvs(", "), keys));
                keys->op_targ = pad_alloc(OP_JOIN, SVs_PADTMP);

                msg = mkconstsv(aTHX_ newSVpvf("In %"SVf": no such named parameter: ", SVfARG(declarator)));
                msg = newBINOP(OP_CONCAT, 0, msg, keys);

                xcroak = mkcroak(aTHX_ msg);

                cond = newUNOP(OP_KEYS, 0, my_var_g(aTHX_ OP_PADHV, 0, param_spec->rest_hash));
                xcroak = newCONDOP(0, cond, xcroak, NULL);

                op_guard_update(prelude_sentinel, op_append_list(OP_LINESEQ, prelude_sentinel->op, newSTATEOP(0, NULL, xcroak)));
            } else {
                OP *clear;

                clear = newASSIGNOP(
                    OPf_STACKED,
                    my_var_g(aTHX_ OP_PADHV, 0, param_spec->rest_hash),
                    0,
                    newNULLLIST()
                );

                op_guard_update(prelude_sentinel, op_append_list(OP_LINESEQ, prelude_sentinel->op, newSTATEOP(0, NULL, clear)));
            }
        } else if (param_spec->slurpy.padoff != param_spec->rest_hash) {
            OP *clear;

            assert(param_spec->rest_hash != NOT_IN_PAD);
            if (SvPV_nolen(param_spec->slurpy.name)[0] == '%') {
                assert(param_spec->slurpy.padoff == NOT_IN_PAD);
            } else {

                assert(SvPV_nolen(param_spec->slurpy.name)[0] == '@');

                if (param_spec->slurpy.padoff != NOT_IN_PAD) {
                    OP *var = my_var_g(
                        aTHX_
                        OP_PADAV,
                        OPf_MOD | (OPpLVAL_INTRO << 8),
                        param_spec->slurpy.padoff
                    );

                    var = newASSIGNOP(OPf_STACKED, var, 0, my_var_g(aTHX_ OP_PADHV, 0, param_spec->rest_hash));

                    op_guard_update(prelude_sentinel, op_append_list(OP_LINESEQ, prelude_sentinel->op, newSTATEOP(0, NULL, var)));
                }
            }

            clear = newASSIGNOP(
                OPf_STACKED,
                my_var_g(aTHX_ OP_PADHV, 0, param_spec->rest_hash),
                0,
                newNULLLIST()
            );

            op_guard_update(prelude_sentinel, op_append_list(OP_LINESEQ, prelude_sentinel->op, newSTATEOP(0, NULL, clear)));
        }
    }

    if (spec->flags & FLAG_CHECK_TARGS) {
        size_t i, lim, base;

        base = 1;
        for (i = 0, lim = param_spec->positional_required.used; i < lim; i++) {
            Param *cur = &param_spec->positional_required.data[i];

            if (cur->type) {
                assert(cur->padoff != NOT_IN_PAD);
                op_guard_update(prelude_sentinel, op_append_list(OP_LINESEQ, prelude_sentinel->op, newSTATEOP(0, NULL, mktypecheckp(aTHX_ declarator, base + i, cur))));
            }
        }
        base += i;

        for (i = 0, lim = param_spec->positional_optional.used; i < lim; i++) {
            Param *cur = &param_spec->positional_optional.data[i].param;

            if (cur->type) {
                assert(cur->padoff != NOT_IN_PAD);
                op_guard_update(prelude_sentinel, op_append_list(OP_LINESEQ, prelude_sentinel->op, newSTATEOP(0, NULL, mktypecheckp(aTHX_ declarator, base + i, cur))));
            }
        }
        base += i;

        for (i = 0, lim = param_spec->named_required.used; i < lim; i++) {
            Param *cur = &param_spec->named_required.data[i];

            if (cur->type) {
                assert(cur->padoff != NOT_IN_PAD);
                op_guard_update(prelude_sentinel, op_append_list(OP_LINESEQ, prelude_sentinel->op, newSTATEOP(0, NULL, mktypecheckp(aTHX_ declarator, base + i, cur))));
            }
        }
        base += i;

        for (i = 0, lim = param_spec->named_optional.used; i < lim; i++) {
            Param *cur = &param_spec->named_optional.data[i].param;

            if (cur->type) {
                assert(cur->padoff != NOT_IN_PAD);
                op_guard_update(prelude_sentinel, op_append_list(OP_LINESEQ, prelude_sentinel->op, newSTATEOP(0, NULL, mktypecheckp(aTHX_ declarator, base + i, cur))));
            }
        }
        base += i;

        if (param_spec->slurpy.type) {
            /* $type->valid($_) or croak $type->get_message($_) for @rest / values %rest */
            OP *check, *list, *loop;

            assert(param_spec->slurpy.padoff != NOT_IN_PAD);

            check = mktypecheck(aTHX_ declarator, base, param_spec->slurpy.name, NOT_IN_PAD, param_spec->slurpy.type);

            if (SvPV_nolen(param_spec->slurpy.name)[0] == '@') {
                list = my_var_g(aTHX_ OP_PADAV, 0, param_spec->slurpy.padoff);
            } else {
                list = my_var_g(aTHX_ OP_PADHV, 0, param_spec->slurpy.padoff);
                list = newUNOP(OP_VALUES, 0, list);
            }

            loop = newFOROP(0, NULL, list, check, NULL);

            op_guard_update(prelude_sentinel, op_append_list(OP_LINESEQ, prelude_sentinel->op, newSTATEOP(0, NULL, loop)));
        }
    }

    /* finally let perl parse the actual subroutine body */
    body = parse_block(0);

    /* add '();' to make function return nothing by default */
    /* (otherwise the invisible parameter initialization can "leak" into
       the return value: fun ($x) {}->("asdf", 0) == 2) */
    if (prelude_sentinel->op) {
        body = newSTATEOP(0, NULL, body);
    }

    body = op_append_list(OP_LINESEQ, op_guard_relinquish(prelude_sentinel), body);

    /* it's go time. */
    {
        const bool runtime = cBOOL(spec->flags & FLAG_RUNTIME);
        CV *cv;
        OP *const attrs = op_guard_relinquish(attrs_sentinel);

        SvREFCNT_inc_simple_void(PL_compcv);

        /* close outer block: '}' */
        body = block_end(save_ix, body);

        cv = newATTRSUB(
            floor_ix,
            saw_name && !runtime && !spec->install_sub
                ? newSVOP(OP_CONST, 0, SvREFCNT_inc_simple_NN(saw_name)) : NULL,
            proto
                ? newSVOP(OP_CONST, 0, SvREFCNT_inc_simple_NN(proto))    : NULL,
            attrs,
            body
        );

        if (cv) {
            assert(cv != CvOUTSIDE(cv));
            register_info(aTHX_ PTR2UV(CvROOT(cv)), declarator, param_spec);
        }

        if (saw_name) {
            if (!runtime) {
                if (spec->install_sub) {
                    SV *args[2];
                    args[0] = saw_name;
                    args[1] = sentinel_mortalize(sen, newRV_noinc((SV *)cv));
                    call_from_curstash(aTHX_ sen, spec->install_sub, args, 2, G_VOID);
                }
                *pop = newOP(OP_NULL, 0);
            } else {
                *pop = newUNOP(
                    OP_ENTERSUB, OPf_STACKED,
                    op_append_elem(
                        OP_LIST,
                        op_append_elem(
                            OP_LIST,
                            mkconstsv(aTHX_ SvREFCNT_inc_simple_NN(saw_name)),
                            newUNOP(
                                OP_REFGEN, 0,
                                newSVOP(OP_ANONCODE, 0, (SV *)cv)
                            )
                        ),
                        newCVREF(
                            OPf_WANT_SCALAR,
                            mkconstsv(aTHX_
                                spec->install_sub
                                    ? SvREFCNT_inc_simple_NN(spec->install_sub)
                                    : newSVpvs(MY_PKG "::_defun")
                            )
                        )
                    )
                );
            }
            return KEYWORD_PLUGIN_STMT;
        }

        *pop = newUNOP(
            OP_REFGEN, 0,
            newSVOP(
                OP_ANONCODE, 0,
                (SV *)cv
            )
        );
        return KEYWORD_PLUGIN_EXPR;
    }
}

static int kw_flags_enter(pTHX_ Sentinel **ppsen, const char *kw_ptr, STRLEN kw_len, KWSpec **ppspec) {
    HV *hints;
    SV **psv;
    const char *kwa_p, *kw_active;
    STRLEN kw_active_len;
    bool kw_is_utf8;

    /* don't bother doing anything fancy after a syntax error */
    if (PL_parser && PL_parser->error_count) {
        return FALSE;
    }

    if (!(hints = GvHV(PL_hintgv))) {
        return FALSE;
    }
    if (!(psv = hv_fetchs(hints, HINTK_KEYWORDS, 0))) {
        return FALSE;
    }
    kw_active = SvPV(*psv, kw_active_len);
    if (kw_active_len <= kw_len) {
        return FALSE;
    }

    kw_is_utf8 = lex_bufutf8();

    for (
        kwa_p = kw_active;
        (kwa_p = strchr(kwa_p, *kw_ptr)) &&
        kwa_p < kw_active + kw_active_len - kw_len;
        kwa_p++
    ) {
        if (
            (kwa_p == kw_active || kwa_p[-1] == ' ') &&
            kwa_p[kw_len] == ' ' &&
            memcmp(kw_ptr, kwa_p, kw_len) == 0
        ) {
            ENTER;
            SAVETMPS;

            Newx(*ppsen, 1, Sentinel);
            ***ppsen = NULL;
            SAVEDESTRUCTOR_X(sentinel_clear_void, *ppsen);

            Newx(*ppspec, 1, KWSpec);
            (*ppspec)->flags = 0;
            (*ppspec)->reify_type = 0;
            spv_init(&(*ppspec)->shift);
            (*ppspec)->attrs = sentinel_mortalize(**ppsen, newSVpvs(""));
            (*ppspec)->install_sub = NULL;
            sentinel_register(**ppsen, *ppspec, kws_free_void);

#define FETCH_HINTK_INTO(NAME, PTR, LEN, X) STMT_START { \
    const char *fk_ptr_; \
    STRLEN fk_len_; \
    I32 fk_xlen_; \
    SV *fk_sv_; \
    fk_sv_ = sentinel_mortalize(**ppsen, newSVpvs(HINTK_ ## NAME)); \
    sv_catpvn(fk_sv_, PTR, LEN); \
    fk_ptr_ = SvPV(fk_sv_, fk_len_); \
    fk_xlen_ = fk_len_; \
    if (kw_is_utf8) { \
        fk_xlen_ = -fk_xlen_; \
    } \
    if (!((X) = hv_fetch(hints, fk_ptr_, fk_xlen_, 0))) { \
        croak("%s: internal error: $^H{'%.*s'} not set", MY_PKG, (int)fk_len_, fk_ptr_); \
    } \
} STMT_END

            FETCH_HINTK_INTO(FLAGS_, kw_ptr, kw_len, psv);
            (*ppspec)->flags = SvIV(*psv);

            FETCH_HINTK_INTO(REIFY_, kw_ptr, kw_len, psv);
            (*ppspec)->reify_type = SvIV(*psv);

            FETCH_HINTK_INTO(SHIFT_, kw_ptr, kw_len, psv);
            {
                SV *const sv = *psv;
                STRLEN sv_len;
                const char *const sv_p = SvPVutf8(sv, sv_len);
                const char *const sv_p_end = sv_p + sv_len;
                const char *p = sv_p;
                AV *shifty_types = NULL;
                SV *type = NULL;

                while (p < sv_p_end) {
                    const char *const v_start = p, *v_end;
                    if (*p != '$') {
                        croak("%s: internal error: $^H{'%s%.*s'}: expected '$', found '%.*s'", MY_PKG, HINTK_SHIFT_, (int)kw_len, kw_ptr, (int)(sv_p_end - p), p);
                    }
                    p++;
                    if (p >= sv_p_end || !MY_UNI_IDFIRST_utf8(p, sv_p_end)) {
                        croak("%s: internal error: $^H{'%s%.*s'}: expected idfirst, found '%.*s'", MY_PKG, HINTK_SHIFT_, (int)kw_len, kw_ptr, (int)(sv_p_end - p), p);
                    }
                    p += UTF8SKIP(p);
                    while (p < sv_p_end && MY_UNI_IDCONT_utf8(p, sv_p_end)) {
                        p += UTF8SKIP(p);
                    }
                    v_end = p;
                    if (v_end == v_start + 2 && v_start[1] == '_') {
                        croak("%s: internal error: $^H{'%s%.*s'}: can't use global $_ as a parameter", MY_PKG, HINTK_SHIFT_, (int)kw_len, kw_ptr);
                    }
                    {
                        size_t i, lim = (*ppspec)->shift.used;
                        for (i = 0; i < lim; i++) {
                            if (my_sv_eq_pvn(aTHX_ (*ppspec)->shift.data[i].name, v_start, v_end - v_start)) {
                                croak("%s: internal error: $^H{'%s%.*s'}: %"SVf" can't appear twice", MY_PKG, HINTK_SHIFT_, (int)kw_len, kw_ptr, SVfARG((*ppspec)->shift.data[i].name));
                            }
                        }
                    }
                    if (p < sv_p_end && *p == '/') {
                        SSize_t tix = 0;
                        SV **ptype;
                        p++;
                        while (p < sv_p_end && isDIGIT(*p)) {
                            tix = tix * 10 + (*p - '0');
                            p++;
                        }

                        if (!shifty_types) {
                            shifty_types = get_av(MY_PKG "::shifty_types", 0);
                            assert(shifty_types != NULL);
                        }
                        if (tix < 0 || tix > av_len(shifty_types)) {
                            croak("%s: internal error: $^H{'%s%.*s'}: tix [%ld] out of range [%ld]", MY_PKG, HINTK_SHIFT_, (int)kw_len, kw_ptr, (long)tix, (long)(av_len(shifty_types) + 1));
                        }
                        ptype = av_fetch(shifty_types, tix, 0);
                        if (!ptype) {
                            croak("%s: internal error: $^H{'%s%.*s'}: tix [%ld] doesn't exist", MY_PKG, HINTK_SHIFT_, (int)kw_len, kw_ptr, (long)tix);
                        }
                        type = *ptype;
                        if (!sv_isobject(type)) {
                            croak("%s: internal error: $^H{'%s%.*s'}: tix [%ld] is not an object (%"SVf")", MY_PKG, HINTK_SHIFT_, (int)kw_len, kw_ptr, (long)tix, SVfARG(type));
                        }
                    }

                    spv_push(&(*ppspec)->shift, sentinel_mortalize(**ppsen, newSVpvn_utf8(v_start, v_end - v_start, TRUE)), type);
                    if (p < sv_p_end) {
                        if (*p != ' ') {
                            croak("%s: internal error: $^H{'%s%.*s'}: expected ' ', found '%.*s'", MY_PKG, HINTK_SHIFT_, (int)kw_len, kw_ptr, (int)(sv_p_end - p), p);
                        }
                        p++;
                    }
                }
            }

            FETCH_HINTK_INTO(ATTRS_, kw_ptr, kw_len, psv);
            SvSetSV((*ppspec)->attrs, *psv);

            FETCH_HINTK_INTO(INSTALL_, kw_ptr, kw_len, psv);
            {
                SV *sv = *psv;
                STRLEN sv_len;
                const char *const sv_p = SvPVutf8(sv, sv_len);
                if (sv_len) {
                    if (isDIGIT(*sv_p)) {
                        IV ix = SvIV(sv);
                        AV *sub_installers = get_av(MY_PKG "::sub_installers", 0);
                        assert(sub_installers != NULL);

                        if (ix < 0 || ix > av_len(sub_installers)) {
                            croak("%s: internal error: $^H{'%s%.*s'}: ix [%ld] out of range [%ld]", MY_PKG, HINTK_INSTALL_, (int)kw_len, kw_ptr, (long)ix, (long)(av_len(sub_installers) + 1));
                        }

                        psv = av_fetch(sub_installers, ix, 0);
                        if (!psv || !SvROK(*psv) || SvTYPE(SvRV(*psv)) != SVt_PVCV) {
                            croak("%s: internal error: $^H{'%s%.*s'}: ix [%ld] is not a sub", MY_PKG, HINTK_INSTALL_, (int)kw_len, kw_ptr, (long)ix);
                        }
                        sv = *psv;
                    }
                    (*ppspec)->install_sub = sv;
                }
            }

#undef FETCH_HINTK_INTO
            return TRUE;
        }
    }
    return FALSE;
}

static int (*next_keyword_plugin)(pTHX_ char *, STRLEN, OP **);

static int my_keyword_plugin(pTHX_ char *keyword_ptr, STRLEN keyword_len, OP **op_ptr) {
    Sentinel *psen;
    KWSpec *pspec;
    int ret;

    if (kw_flags_enter(aTHX_ &psen, keyword_ptr, keyword_len, &pspec)) {
        /* scope was entered, 'psen' and 'pspec' are initialized */
        ret = parse_fun(aTHX_ *psen, op_ptr, keyword_ptr, keyword_len, pspec);
        FREETMPS;
        LEAVE;
    } else {
        /* not one of our keywords, no allocation done */
        ret = next_keyword_plugin(aTHX_ keyword_ptr, keyword_len, op_ptr);
    }

    return ret;
}

static void my_boot(pTHX) {
    HV *const stash = gv_stashpvs(MY_PKG, GV_ADD);

    newCONSTSUB(stash, "FLAG_NAME_OK",      newSViv(FLAG_NAME_OK));
    newCONSTSUB(stash, "FLAG_ANON_OK",      newSViv(FLAG_ANON_OK));
    newCONSTSUB(stash, "FLAG_DEFAULT_ARGS", newSViv(FLAG_DEFAULT_ARGS));
    newCONSTSUB(stash, "FLAG_CHECK_NARGS",  newSViv(FLAG_CHECK_NARGS));
    newCONSTSUB(stash, "FLAG_INVOCANT",     newSViv(FLAG_INVOCANT));
    newCONSTSUB(stash, "FLAG_NAMED_PARAMS", newSViv(FLAG_NAMED_PARAMS));
    newCONSTSUB(stash, "FLAG_TYPES_OK",     newSViv(FLAG_TYPES_OK));
    newCONSTSUB(stash, "FLAG_CHECK_TARGS",  newSViv(FLAG_CHECK_TARGS));
    newCONSTSUB(stash, "FLAG_RUNTIME",      newSViv(FLAG_RUNTIME));
    newCONSTSUB(stash, "HINTK_KEYWORDS", newSVpvs(HINTK_KEYWORDS));
    newCONSTSUB(stash, "HINTK_FLAGS_",   newSVpvs(HINTK_FLAGS_));
    newCONSTSUB(stash, "HINTK_SHIFT_",   newSVpvs(HINTK_SHIFT_));
    newCONSTSUB(stash, "HINTK_ATTRS_",   newSVpvs(HINTK_ATTRS_));
    newCONSTSUB(stash, "HINTK_REIFY_",   newSVpvs(HINTK_REIFY_));
    newCONSTSUB(stash, "HINTK_INSTALL_", newSVpvs(HINTK_INSTALL_));

    next_keyword_plugin = PL_keyword_plugin;
    PL_keyword_plugin = my_keyword_plugin;
}

#ifndef assert_
#ifdef DEBUGGING
#define assert_(X) assert(X),
#else
#define assert_(X)
#endif
#endif

#ifndef gv_method_changed
#define gv_method_changed(GV) (              \
    assert_(isGV_with_GP(GV))                \
    GvREFCNT(GV) > 1                         \
        ? (void)PL_sub_generation++          \
        : mro_method_changed_in(GvSTASH(GV)) \
)
#endif

WARNINGS_RESET

MODULE = Function::Parameters   PACKAGE = Function::Parameters   PREFIX = fp_
PROTOTYPES: ENABLE

UV
fp__cv_root(sv)
    SV *sv
    PREINIT:
        CV *xcv;
        HV *hv;
        GV *gv;
    CODE:
        xcv = sv_2cv(sv, &hv, &gv, 0);
        RETVAL = PTR2UV(xcv ? CvROOT(xcv) : NULL);
    OUTPUT:
        RETVAL

void
fp__defun(name, body)
    SV *name
    CV *body
    PREINIT:
        GV *gv;
        CV *xcv;
    CODE:
        assert(SvTYPE(body) == SVt_PVCV);
        gv = gv_fetchsv(name, GV_ADDMULTI, SVt_PVCV);
        xcv = GvCV(gv);
        if (xcv) {
            if (!GvCVGEN(gv) && (CvROOT(xcv) || CvXSUB(xcv)) && ckWARN(WARN_REDEFINE)) {
                warner(packWARN(WARN_REDEFINE), "Subroutine %"SVf" redefined", SVfARG(name));
            }
            SvREFCNT_dec_NN(xcv);
        }
        GvCVGEN(gv) = 0;
        GvASSUMECV_on(gv);
        if (GvSTASH(gv)) {
            gv_method_changed(gv);
        }
        GvCV_set(gv, (CV *)SvREFCNT_inc_simple_NN(body));
        CvGV_set(body, gv);
        CvANON_off(body);

BOOT:
    my_boot(aTHX);
