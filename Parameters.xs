/*
Copyright 2012 Lukas Mai.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.
 */

#ifdef __GNUC__
 #if (__GNUC__ == 4 && __GNUC_MINOR__ >= 6) || __GNUC__ >= 5
  #define PRAGMA_GCC_(X) _Pragma(#X)
  #define PRAGMA_GCC(X) PRAGMA_GCC_(GCC X)
 #endif
#endif

#ifndef PRAGMA_GCC
 #define PRAGMA_GCC(X)
#endif

#ifdef DEVEL
 #define WARNINGS_RESET PRAGMA_GCC(diagnostic pop)
 #define WARNINGS_ENABLEW(X) PRAGMA_GCC(diagnostic warning #X)
 #define WARNINGS_ENABLE \
 	WARNINGS_ENABLEW(-Wall) \
 	WARNINGS_ENABLEW(-Wextra) \
 	WARNINGS_ENABLEW(-Wundef) \
 	/* WARNINGS_ENABLEW(-Wshadow) :-( */ \
 	WARNINGS_ENABLEW(-Wbad-function-cast) \
 	WARNINGS_ENABLEW(-Wcast-align) \
 	WARNINGS_ENABLEW(-Wwrite-strings) \
 	/* WARNINGS_ENABLEW(-Wnested-externs) wtf? */ \
 	WARNINGS_ENABLEW(-Wstrict-prototypes) \
 	WARNINGS_ENABLEW(-Wmissing-prototypes) \
 	WARNINGS_ENABLEW(-Winline) \
 	WARNINGS_ENABLEW(-Wdisabled-optimization)

#else
 #define WARNINGS_RESET
 #define WARNINGS_ENABLE
#endif


#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include <string.h>


WARNINGS_ENABLE


#define HAVE_PERL_VERSION(R, V, S) \
	(PERL_REVISION > (R) || (PERL_REVISION == (R) && (PERL_VERSION > (V) || (PERL_VERSION == (V) && (PERL_SUBVERSION >= (S))))))

#if HAVE_PERL_VERSION(5, 16, 0)
 #define IF_HAVE_PERL_5_16(YES, NO) YES
#else
 #define IF_HAVE_PERL_5_16(YES, NO) NO
#endif

#if 0
 #if HAVE_PERL_VERSION(5, 17, 6)
  #error "internal error: missing definition of KEY_my (your perl is too new)"
 #elif HAVE_PERL_VERSION(5, 15, 8)
  #define S_KEY_my 134
 #elif HAVE_PERL_VERSION(5, 15, 6)
  #define S_KEY_my 133
 #elif HAVE_PERL_VERSION(5, 15, 5)
  #define S_KEY_my 132
 #elif HAVE_PERL_VERSION(5, 13, 0)
  #define S_KEY_my 131
 #else
  #error "internal error: missing definition of KEY_my (your perl is too old)"
 #endif
#endif


#define MY_PKG "Function::Parameters"

#define HINTK_KEYWORDS MY_PKG "/keywords"
#define HINTK_FLAGS_   MY_PKG "/flags:"
#define HINTK_SHIFT_   MY_PKG "/shift:"
#define HINTK_ATTRS_   MY_PKG "/attrs:"

#define DEFSTRUCT(T) typedef struct T T; struct T

enum {
	FLAG_NAME_OK      = 0x01,
	FLAG_ANON_OK      = 0x02,
	FLAG_DEFAULT_ARGS = 0x04,
	FLAG_CHECK_NARGS  = 0x08,
	FLAG_INVOCANT     = 0x10,
	FLAG_NAMED_PARAMS = 0x20
};

DEFSTRUCT(KWSpec) {
	unsigned flags;
	SV *shift;
	SV *attrs;
};

static int (*next_keyword_plugin)(pTHX_ char *, STRLEN, OP **);

static int kw_flags(pTHX_ const char *kw_ptr, STRLEN kw_len, KWSpec *spec) {
	HV *hints;
	SV *sv, **psv;
	const char *p, *kw_active;
	STRLEN kw_active_len;

	spec->flags = 0;
	spec->shift = sv_2mortal(newSVpvs(""));
	spec->attrs = sv_2mortal(newSVpvs(""));

	if (!(hints = GvHV(PL_hintgv))) {
		return FALSE;
	}
	if (!(psv = hv_fetchs(hints, HINTK_KEYWORDS, 0))) {
		return FALSE;
	}
	sv = *psv;
	kw_active = SvPV(sv, kw_active_len);
	if (kw_active_len <= kw_len) {
		return FALSE;
	}
	for (
		p = kw_active;
		(p = strchr(p, *kw_ptr)) &&
		p < kw_active + kw_active_len - kw_len;
		p++
	) {
		if (
			(p == kw_active || p[-1] == ' ') &&
			p[kw_len] == ' ' &&
			memcmp(kw_ptr, p, kw_len) == 0
		) {

#define FETCH_HINTK_INTO(NAME, PTR, LEN, X) STMT_START { \
	const char *fk_ptr_; \
	STRLEN fk_len_; \
	SV *fk_sv_; \
	fk_sv_ = sv_2mortal(newSVpvs(HINTK_ ## NAME)); \
	sv_catpvn(fk_sv_, PTR, LEN); \
	fk_ptr_ = SvPV(fk_sv_, fk_len_); \
	if (!((X) = hv_fetch(hints, fk_ptr_, fk_len_, 0))) { \
		croak("%s: internal error: $^H{'%.*s'} not set", MY_PKG, (int)fk_len_, fk_ptr_); \
	} \
} STMT_END

			FETCH_HINTK_INTO(FLAGS_, kw_ptr, kw_len, psv);
			spec->flags = SvIV(*psv);

			FETCH_HINTK_INTO(SHIFT_, kw_ptr, kw_len, psv);
			SvSetSV(spec->shift, *psv);

			FETCH_HINTK_INTO(ATTRS_, kw_ptr, kw_len, psv);
			SvSetSV(spec->attrs, *psv);

#undef FETCH_HINTK_INTO
			return TRUE;
		}
	}
	return FALSE;
}


static void free_ptr_op(pTHX_ void *vp) {
	OP **pp = vp;
	op_free(*pp);
	Safefree(pp);
}

#define sv_eq_pvs(SV, S) my_sv_eq_pvn(aTHX_ SV, "" S "", sizeof (S) - 1)

static int my_sv_eq_pvn(pTHX_ SV *sv, const char *p, STRLEN n) {
	STRLEN sv_len;
	const char *sv_p = SvPV(sv, sv_len);
	return memcmp(sv_p, p, n) == 0;
}


#include "padop_on_crack.c.inc"


enum {
	MY_ATTR_LVALUE = 0x01,
	MY_ATTR_METHOD = 0x02,
	MY_ATTR_SPECIAL = 0x04
};

static void my_sv_cat_c(pTHX_ SV *sv, U32 c) {
	char ds[UTF8_MAXBYTES + 1], *d;
	d = uvchr_to_utf8(ds, c);
	if (d - ds > 1) {
		sv_utf8_upgrade(sv);
	}
	sv_catpvn(sv, ds, d - ds);
}

static bool my_is_uni_xidfirst(pTHX_ UV c) {
	U8 tmpbuf[UTF8_MAXBYTES + 1];
	uvchr_to_utf8(tmpbuf, c);
	return is_utf8_xidfirst(tmpbuf);
}

static bool my_is_uni_xidcont(pTHX_ UV c) {
	U8 tmpbuf[UTF8_MAXBYTES + 1];
	uvchr_to_utf8(tmpbuf, c);
	return is_utf8_xidcont(tmpbuf);
}

static SV *my_scan_word(pTHX_ bool allow_package) {
	bool at_start, at_substart;
	I32 c;
	SV *sv = sv_2mortal(newSVpvs(""));
	if (lex_bufutf8()) {
		SvUTF8_on(sv);
	}

	at_start = at_substart = TRUE;
	c = lex_peek_unichar(0);

	while (c != -1) {
		if (at_substart ? my_is_uni_xidfirst(aTHX_ c) : my_is_uni_xidcont(aTHX_ c)) {
			lex_read_unichar(0);
			my_sv_cat_c(aTHX_ sv, c);
			at_substart = FALSE;
			c = lex_peek_unichar(0);
		} else if (allow_package && !at_substart && c == '\'') {
			lex_read_unichar(0);
			c = lex_peek_unichar(0);
			if (!my_is_uni_xidfirst(aTHX_ c)) {
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
			if (!my_is_uni_xidfirst(aTHX_ c)) {
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

static SV *my_scan_parens_tail(pTHX_ bool keep_backslash) {
	I32 c, nesting;
	SV *sv;
	line_t start;

	start = CopLINE(PL_curcop);

	sv = sv_2mortal(newSVpvs(""));
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

static void my_check_prototype(pTHX_ const SV *declarator, SV *proto) {
	char *start, *r, *w, *end;
	STRLEN len;

	/* strip spaces */
	start = SvPV(proto, len);
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
		SV *dsv = newSVpvs_flags("", SVs_TEMP);
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
				if (r[1] && !strchr(";@%", *r)) {
					warner(
						packWARN(WARN_ILLEGALPROTO),
						"Illegal character after '_' in prototype for %"SVf" : %s",
						SVfARG(declarator), r
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


DEFSTRUCT(Param) {
	SV *name;
	PADOFFSET padoff;
};

DEFSTRUCT(ParamInit) {
	Param param;
	OP *init;
};

#define VEC(B) B ## _Vec

#define DEFVECTOR(B) DEFSTRUCT(VEC(B)) { \
	B (*data); \
	size_t used, size; \
}

DEFVECTOR(Param);
DEFVECTOR(ParamInit);

#define DEFVECTOR_INIT(N, B) static void N(VEC(B) *p) { \
	p->used = 0; \
	p->size = 23; \
	Newx(p->data, p->size, B); \
} static void N(VEC(B) *)

DEFSTRUCT(ParamSpec) {
	Param invocant;
	VEC(Param) positional_required;
	VEC(ParamInit) positional_optional;
	VEC(Param) named_required;
	VEC(ParamInit) named_optional;
	Param slurpy;
};

DEFVECTOR_INIT(pv_init, Param);
DEFVECTOR_INIT(piv_init, ParamInit);

static void p_init(Param *p) {
	p->name = NULL;
	p->padoff = NOT_IN_PAD;
}

static void ps_init(ParamSpec *ps) {
	p_init(&ps->invocant);
	pv_init(&ps->positional_required);
	piv_init(&ps->positional_optional);
	pv_init(&ps->named_required);
	piv_init(&ps->named_optional);
	p_init(&ps->slurpy);
}

#define DEFVECTOR_EXTEND(N, B) static B (*N(VEC(B) *p)) { \
	assert(p->used <= p->size); \
	if (p->used == p->size) { \
		const size_t n = p->size / 2 * 3 + 1; \
		Renew(p->data, n, B); \
		p->size = n; \
	} \
	return &p->data[p->used]; \
} static B (*N(VEC(B) *))

DEFVECTOR_EXTEND(pv_extend, Param);
DEFVECTOR_EXTEND(piv_extend, ParamInit);

#define DEFVECTOR_CLEAR(N, B, F) static void N(pTHX_ VEC(B) *p) { \
	while (p->used) { \
		p->used--; \
		F(aTHX_ &p->data[p->used]); \
	} \
	Safefree(p->data); \
	p->data = NULL; \
	p->size = 0; \
} static void N(pTHX_ VEC(B) *)

static void p_clear(pTHX_ Param *p) {
	p->name = NULL;
	p->padoff = NOT_IN_PAD;
}

static void pi_clear(pTHX_ ParamInit *pi) {
	p_clear(aTHX_ &pi->param);
	if (pi->init) {
		op_free(pi->init);
		pi->init = NULL;
	}
}

DEFVECTOR_CLEAR(pv_clear, Param, p_clear);
DEFVECTOR_CLEAR(piv_clear, ParamInit, pi_clear);

static void ps_clear(pTHX_ ParamSpec *ps) {
	p_clear(aTHX_ &ps->invocant);

	pv_clear(aTHX_ &ps->positional_required);
	piv_clear(aTHX_ &ps->positional_optional);

	pv_clear(aTHX_ &ps->named_required);
	piv_clear(aTHX_ &ps->named_optional);

	p_clear(aTHX_ &ps->slurpy);
}

static int ps_contains(pTHX_ const ParamSpec *ps, SV *sv) {
	size_t i, lim;

	if (ps->invocant.name && sv_eq(sv, ps->invocant.name)) {
		return 1;
	}

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

static int args_min(pTHX_ const ParamSpec *ps, const KWSpec *ks) {
	int n = 0;
	if (!ps) {
		return SvTRUE(ks->shift) ? 1 : 0;
	}
	if (ps->invocant.name) {
		n++;
	}
	n += ps->positional_required.used;
	n += ps->named_required.used * 2;
	return n;
}

static int args_max(const ParamSpec *ps) {
	int n = 0;
	if (!ps) {
		return -1;
	}
	if (ps->invocant.name) {
		n++;
	}
	n += ps->positional_required.used;
	n += ps->positional_optional.used;
	if (ps->named_required.used || ps->named_optional.used || ps->slurpy.name) {
		n = -1;
	}
	return n;
}

static size_t count_positional_params(const ParamSpec *ps) {
	return ps->positional_required.used + ps->positional_optional.used;
}

static size_t count_named_params(const ParamSpec *ps) {
	return ps->named_required.used + ps->named_optional.used;
}

enum {
	PARAM_INVOCANT = 0x01,
	PARAM_NAMED    = 0x02
};

/* *pinit must be NULL on entry.
 * caller must free *pinit on error.
 */
static PADOFFSET parse_param(
	pTHX_
	const SV *declarator, const KWSpec *spec, ParamSpec *param_spec,
	int *pflags, SV **pname, OP **pinit
) {
	I32 c;
	char sigil;
	SV *name;

	assert(!*pinit);
	*pflags = 0;

	c = lex_peek_unichar(0);

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
	lex_read_space(0);

	if (!(name = my_scan_word(aTHX_ FALSE))) {
		croak("In %"SVf": missing identifier after '%c'", SVfARG(declarator), sigil);
	}
	sv_insert(name, 0, 0, &sigil, 1);
	*pname = name;

	lex_read_space(0);
	c = lex_peek_unichar(0);

	if (c == '=') {
		lex_read_unichar(0);
		lex_read_space(0);


		if (!param_spec->invocant.name && SvTRUE(spec->shift)) {
			param_spec->invocant.name = spec->shift;
			param_spec->invocant.padoff = pad_add_name_sv(param_spec->invocant.name, 0, NULL, NULL);
		}

		*pinit = parse_termexpr(0);

		lex_read_space(0);
		c = lex_peek_unichar(0);
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

	return pad_add_name_sv(*pname, IF_HAVE_PERL_5_16(padadd_NO_DUP_CHECK, 0), NULL, NULL);
}

static OP *my_var_g(pTHX_ I32 type, I32 flags, PADOFFSET padoff) {
	OP *var = newOP(type, flags);
	var->op_targ = padoff;
	return var;
}

static OP *my_var(pTHX_ I32 flags, PADOFFSET padoff) {
	return my_var_g(aTHX_ OP_PADSV, flags, padoff);
}

static SV *mkbits1(pTHX_ size_t n) {
	size_t bytes = n / 8, bits = n % 8;
	SV *sv = newSV(bytes + !!bits);
	char *p = SvPVX(sv), *q = p;
	while (bytes--) {
		*p++ = '\xff';
	}
	if (bits) {
		*p++ = (1u << bits) - 1;
	}
	*p = '\0';
	SvCUR_set(sv, p - q);
	SvPOK_on(sv);
	return sv;
}

static OP *mkvecbits(pTHX_ PADOFFSET padoff, size_t i) {
	OP *first, *mid, *last, *vec;

	last = newSVOP(OP_CONST, 0, newSViv(1));
	first = last;

	mid = newSVOP(OP_CONST, 0, newSViv(i));
	mid->op_sibling = first;
	first = mid;

	mid = my_var(aTHX_ 0, padoff);
	mid->op_sibling = first;

	first = newOP(OP_PUSHMARK, 0);

	vec = newLISTOP(OP_VEC, 0, first, mid);
	vec->op_targ = pad_alloc(OP_VEC, SVs_PADTMP);
	((LISTOP *)vec)->op_last = last;
	op_null(((LISTOP *)vec)->op_first);

	return vec;
}

static OP *mkargselem(pTHX_ OP *index) {
	OP *args = newAVREF(newGVOP(OP_GV, 0, PL_defgv));
	args->op_flags |= OPf_REF;

	return newBINOP(OP_AELEM, 0, args, index);
}

static OP *mkargselemv(pTHX_ PADOFFSET v) {
	return mkargselem(aTHX_ my_var(aTHX_ 0, v));
}

static int parse_fun(pTHX_ OP **pop, const char *keyword_ptr, STRLEN keyword_len, const KWSpec *spec) {
	ParamSpec *param_spec;
	SV *declarator;
	I32 floor_ix;
	int save_ix;
	SV *saw_name;
	OP **prelude_sentinel;
	SV *proto;
	OP **attrs_sentinel, *body;
	unsigned builtin_attrs;
	I32 c;

	declarator = sv_2mortal(newSVpvn(keyword_ptr, keyword_len));

	lex_read_space(0);

	builtin_attrs = 0;

	/* function name */
	saw_name = NULL;
	if ((spec->flags & FLAG_NAME_OK) && (saw_name = my_scan_word(aTHX_ TRUE))) {

		if (PL_parser->expect != XSTATE) {
			/* bail out early so we don't predeclare $saw_name */
			croak("In %"SVf": I was expecting a function body, not \"%"SVf"\"", SVfARG(declarator), SVfARG(saw_name));
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
	save_ix = S_block_start(aTHX_ TRUE);

	/* initialize synthetic optree */
	Newx(prelude_sentinel, 1, OP *);
	*prelude_sentinel = NULL;
	SAVEDESTRUCTOR_X(free_ptr_op, prelude_sentinel);

	/* parameters */
	param_spec = NULL;

	c = lex_peek_unichar(0);
	if (c == '(') {
		OP **init_sentinel;

		Newx(init_sentinel, 1, OP *);
		*init_sentinel = NULL;
		SAVEDESTRUCTOR_X(free_ptr_op, init_sentinel);

		Newx(param_spec, 1, ParamSpec);
		ps_init(param_spec);
		SAVEDESTRUCTOR_X(ps_free_void, param_spec);

		lex_read_unichar(0);
		lex_read_space(0);

		while ((c = lex_peek_unichar(0)) != ')') {
			int flags;
			SV *name;
			char sigil;
			PADOFFSET padoff;

			padoff = parse_param(aTHX_ declarator, spec, param_spec, &flags, &name, init_sentinel);

			S_intro_my(aTHX);

			sigil = SvPV_nolen(name)[0];

			/* internal consistency */
			if (flags & PARAM_NAMED) {
				if (flags & PARAM_INVOCANT) {
					croak("In %"SVf": invocant %"SVf" can't be a named parameter", SVfARG(declarator), SVfARG(name));
				}
				if (sigil != '$') {
					croak("In %"SVf": named parameter %"SVf" can't be a%s", SVfARG(declarator), SVfARG(name), sigil == '@' ? "n array" : " hash");
				}
			} else if (flags & PARAM_INVOCANT) {
				if (*init_sentinel) {
					croak("In %"SVf": invocant %"SVf" can't have a default value", SVfARG(declarator), SVfARG(name));
				}
				if (sigil != '$') {
					croak("In %"SVf": invocant %"SVf" can't be a%s", SVfARG(declarator), SVfARG(name), sigil == '@' ? "n array" : " hash");
				}
			} else if (sigil != '$' && *init_sentinel) {
				croak("In %"SVf": %s %"SVf" can't have a default value", SVfARG(declarator), sigil == '@' ? "array" : "hash", SVfARG(name));
			}

			/* external constraints */
			if (param_spec->slurpy.name) {
				croak("In %"SVf": I was expecting \")\" after \"%"SVf"\", not \"%"SVf"\"", SVfARG(declarator), SVfARG(param_spec->slurpy.name), SVfARG(name));
			}
			if (sigil != '$') {
				assert(!*init_sentinel);
				param_spec->slurpy.name = name;
				param_spec->slurpy.padoff = padoff;
				continue;
			}

			if (!(flags & PARAM_NAMED) && count_named_params(param_spec)) {
				croak("In %"SVf": positional parameter %"SVf" can't appear after named parameter %"SVf"", SVfARG(declarator), SVfARG(name), SVfARG((param_spec->named_required.used ? param_spec->named_required.data[0] : param_spec->named_optional.data[0].param).name));
			}

			if (flags & PARAM_INVOCANT) {
				if (param_spec->invocant.name) {
					croak("In %"SVf": invalid double invocants %"SVf", %"SVf"", SVfARG(declarator), SVfARG(param_spec->invocant.name), SVfARG(name));
				}
				if (count_positional_params(param_spec) || count_named_params(param_spec)) {
					croak("In %"SVf": invocant %"SVf" must be first in parameter list", SVfARG(declarator), SVfARG(name));
				}
				if (!(spec->flags & FLAG_INVOCANT)) {
					croak("In %"SVf": invocant %"SVf" not allowed here", SVfARG(declarator), SVfARG(name));
				}
				param_spec->invocant.name = name;
				param_spec->invocant.padoff = padoff;
				continue;
			}

			if (*init_sentinel && !(spec->flags & FLAG_DEFAULT_ARGS)) {
				croak("In %"SVf": default argument for %"SVf" not allowed here", SVfARG(declarator), SVfARG(name));
			}

			if (ps_contains(aTHX_ param_spec, name)) {
				croak("In %"SVf": %"SVf" can't appear twice in the same parameter list", SVfARG(declarator), SVfARG(name));
			}

			if (flags & PARAM_NAMED) {
				if (!(spec->flags & FLAG_NAMED_PARAMS)) {
					croak("In %"SVf": named parameter :%"SVf" not allowed here", SVfARG(declarator), SVfARG(name));
				}

				if (*init_sentinel) {
					ParamInit *pi = piv_extend(&param_spec->named_optional);
					pi->param.name = name;
					pi->param.padoff = padoff;
					pi->init = *init_sentinel;
					*init_sentinel = NULL;
					param_spec->named_optional.used++;
				} else {
					if (param_spec->positional_optional.used) {
						croak("In %"SVf": can't combine optional positional (%"SVf") and required named (%"SVf") parameters", SVfARG(declarator), SVfARG(param_spec->positional_optional.data[0].param.name), SVfARG(name));
					}

					Param *p = pv_extend(&param_spec->named_required);
					p->name = name;
					p->padoff = padoff;
					param_spec->named_required.used++;
				}
			} else {
				if (*init_sentinel || param_spec->positional_optional.used) {
					ParamInit *pi = piv_extend(&param_spec->positional_optional);
					pi->param.name = name;
					pi->param.padoff = padoff;
					pi->init = *init_sentinel;
					*init_sentinel = NULL;
					param_spec->positional_optional.used++;
				} else {
					Param *p = pv_extend(&param_spec->positional_required);
					p->name = name;
					p->padoff = padoff;
					param_spec->positional_required.used++;
				}
			}

		}
		lex_read_unichar(0);
		lex_read_space(0);
		*init_sentinel = NULL;

		if (!param_spec->invocant.name && SvTRUE(spec->shift)) {
			if (ps_contains(aTHX_ param_spec, spec->shift)) {
				croak("In %"SVf": %"SVf" can't appear twice in the same parameter list", SVfARG(declarator), SVfARG(spec->shift));
			}

			param_spec->invocant.name = spec->shift;
			param_spec->invocant.padoff = pad_add_name_sv(param_spec->invocant.name, 0, NULL, NULL);
		}
	}

	/* prototype */
	proto = NULL;
	c = lex_peek_unichar(0);
	if (c == ':') {
		lex_read_unichar(0);
		lex_read_space(0);

		c = lex_peek_unichar(0);
		if (c != '(') {
			lex_stuff_pvs(":", 0);
			c = ':';
		} else {
			lex_read_unichar(0);
			if (!(proto = my_scan_parens_tail(aTHX_ FALSE))) {
				croak("In %"SVf": prototype not terminated", SVfARG(declarator));
			}
			my_check_prototype(aTHX_ declarator, proto);
			lex_read_space(0);
			c = lex_peek_unichar(0);
		}
	}

	/* attributes */
	Newx(attrs_sentinel, 1, OP *);
	*attrs_sentinel = NULL;
	SAVEDESTRUCTOR_X(free_ptr_op, attrs_sentinel);

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

				if (!(attr = my_scan_word(aTHX_ FALSE))) {
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
					if (!(sv = my_scan_parens_tail(aTHX_ TRUE))) {
						croak("In %"SVf": unterminated attribute parameter in attribute list", SVfARG(declarator));
					}
					sv_catpvs(attr, "(");
					sv_catsv(attr, sv);
					sv_catpvs(attr, ")");

					lex_read_space(0);
					c = lex_peek_unichar(0);
				}

				if (attr) {
					*attrs_sentinel = op_append_elem(OP_LIST, *attrs_sentinel, newSVOP(OP_CONST, 0, SvREFCNT_inc_simple_NN(attr)));
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
	if (saw_name) {
		/* 'sub NAME (PROTO);' to make name/proto known to perl before it
		   starts parsing the body */
		const I32 sub_ix = start_subparse(FALSE, 0);
		SAVEFREESV(PL_compcv);

		SvREFCNT_inc_simple_void(PL_compcv);

		newATTRSUB(
			sub_ix,
			newSVOP(OP_CONST, 0, SvREFCNT_inc_simple_NN(saw_name)),
			proto ? newSVOP(OP_CONST, 0, SvREFCNT_inc_simple_NN(proto)) : NULL,
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
		size_t named;

		amin = args_min(aTHX_ param_spec, spec);
		if (amin > 0) {
			OP *chk, *cond, *err, *croak;

			err = newSVOP(OP_CONST, 0,
				          newSVpvf("Not enough arguments for %"SVf" (expected %d, got ", SVfARG(declarator), amin));
			err = newBINOP(OP_CONCAT, 0,
				           err,
				           newAVREF(newGVOP(OP_GV, 0, PL_defgv)));
			err = newBINOP(OP_CONCAT, 0,
				           err,
				           newSVOP(OP_CONST, 0, newSVpvs(")")));

			croak = newCVREF(OPf_WANT_SCALAR,
				             newGVOP(OP_GV, 0, gv_fetchpvs("Carp::croak", 0, SVt_PVCV)));
			err = newUNOP(OP_ENTERSUB, OPf_STACKED,
				          op_append_elem(OP_LIST, err, croak));

			cond = newBINOP(OP_LT, 0,
				            newAVREF(newGVOP(OP_GV, 0, PL_defgv)),
				            newSVOP(OP_CONST, 0, newSViv(amin)));
			chk = newLOGOP(OP_AND, 0, cond, err);

			*prelude_sentinel = op_append_list(OP_LINESEQ, *prelude_sentinel, newSTATEOP(0, NULL, chk));
		}

		amax = args_max(param_spec);
		if (amax >= 0) {
			OP *chk, *cond, *err, *croak;

			err = newSVOP(OP_CONST, 0,
				          newSVpvf("Too many arguments for %"SVf" (expected %d, got ", SVfARG(declarator), amax));
			err = newBINOP(OP_CONCAT, 0,
				           err,
				           newAVREF(newGVOP(OP_GV, 0, PL_defgv)));
			err = newBINOP(OP_CONCAT, 0,
				           err,
				           newSVOP(OP_CONST, 0, newSVpvs(")")));

			croak = newCVREF(OPf_WANT_SCALAR,
				             newGVOP(OP_GV, 0, gv_fetchpvs("Carp::croak", 0, SVt_PVCV)));
			err = newUNOP(OP_ENTERSUB, OPf_STACKED,
				          op_append_elem(OP_LIST, err, croak));

			cond = newBINOP(OP_GT, 0,
				            newAVREF(newGVOP(OP_GV, 0, PL_defgv)),
				            newSVOP(OP_CONST, 0, newSViv(amax)));
			chk = newLOGOP(OP_AND, 0, cond, err);

			*prelude_sentinel = op_append_list(OP_LINESEQ, *prelude_sentinel, newSTATEOP(0, NULL, chk));
		}

		if (param_spec && (count_named_params(param_spec) || (param_spec->slurpy.name && SvPV_nolen(param_spec->slurpy.name)[0] == '%'))) {
			OP *chk, *cond, *err, *croak;
			const UV fixed = count_positional_params(param_spec) + !!param_spec->invocant.name;

			err = newSVOP(OP_CONST, 0,
				          newSVpvf("Odd number of paired arguments for %"SVf"", SVfARG(declarator)));

			croak = newCVREF(OPf_WANT_SCALAR,
				             newGVOP(OP_GV, 0, gv_fetchpvs("Carp::croak", 0, SVt_PVCV)));
			err = newUNOP(OP_ENTERSUB, OPf_STACKED,
				          op_append_elem(OP_LIST, err, croak));

			cond = newBINOP(OP_GT, 0,
				            fixed
				            ? newBINOP(OP_SUBTRACT, 0,
				                       newAVREF(newGVOP(OP_GV, 0, PL_defgv)),
				                       newSVOP(OP_CONST, 0, newSVuv(fixed)))
				            : newAVREF(newGVOP(OP_GV, 0, PL_defgv)),
				            newSVOP(OP_CONST, 0, newSViv(0)));
			cond = newLOGOP(OP_AND, 0,
				            cond,
				            newBINOP(OP_MODULO, 0,
				                     fixed
				                     ? newBINOP(OP_SUBTRACT, 0,
				                                newAVREF(newGVOP(OP_GV, 0, PL_defgv)),
				                                newSVOP(OP_CONST, 0, newSVuv(fixed)))
				                     : newAVREF(newGVOP(OP_GV, 0, PL_defgv)),
				                     newSVOP(OP_CONST, 0, newSViv(2))));
			chk = newLOGOP(OP_AND, 0, cond, err);

			*prelude_sentinel = op_append_list(OP_LINESEQ, *prelude_sentinel, newSTATEOP(0, NULL, chk));
		}
	}

	if (!param_spec) {
		/* my $invocant = shift; */
		if (SvTRUE(spec->shift)) {
			OP *var;

			var = my_var(
				aTHX_
				OPf_MOD | (OPpLVAL_INTRO << 8),
				pad_add_name_sv(spec->shift, 0, NULL, NULL)
			);
			var = newASSIGNOP(OPf_STACKED, var, 0, newOP(OP_SHIFT, 0));

			*prelude_sentinel = op_append_list(OP_LINESEQ, *prelude_sentinel, newSTATEOP(0, NULL, var));
		}
	} else {
		/* my $invocant = shift; */
		if (param_spec->invocant.name) {
			OP *var;

			var = my_var(
				aTHX_
				OPf_MOD | (OPpLVAL_INTRO << 8),
				param_spec->invocant.padoff
			);
			var = newASSIGNOP(OPf_STACKED, var, 0, newOP(OP_SHIFT, 0));

			*prelude_sentinel = op_append_list(OP_LINESEQ, *prelude_sentinel, newSTATEOP(0, NULL, var));
		}

		/* my (...) = @_; */
		{
			OP *lhs;
			size_t i, lim;

			lhs = NULL;

			for (i = 0, lim = param_spec->positional_required.used; i < lim; i++) {
				OP *const var = my_var(
					aTHX_
					OPf_WANT_LIST | (OPpLVAL_INTRO << 8),
					param_spec->positional_required.data[i].padoff
				);
				lhs = op_append_elem(OP_LIST, lhs, var);
			}

			for (i = 0, lim = param_spec->positional_optional.used; i < lim; i++) {
				OP *const var = my_var(
					aTHX_
					OPf_WANT_LIST | (OPpLVAL_INTRO << 8),
					param_spec->positional_optional.data[i].param.padoff
				);
				lhs = op_append_elem(OP_LIST, lhs, var);
			}

			if (param_spec->slurpy.name) {
				if (count_named_params(param_spec)) {
					OP *const var = my_var_g(
						aTHX_
						SvPV_nolen(param_spec->slurpy.name)[0] == '@' ? OP_PADAV : OP_PADHV,
						OPf_MOD | (OPpLVAL_INTRO << 8),
						param_spec->slurpy.padoff
					);
					*prelude_sentinel = op_append_list(OP_LINESEQ, *prelude_sentinel, newSTATEOP(0, NULL, var));
				} else {
					OP *const var = my_var_g(
						aTHX_
						SvPV_nolen(param_spec->slurpy.name)[0] == '@' ? OP_PADAV : OP_PADHV,
						OPf_WANT_LIST | (OPpLVAL_INTRO << 8),
						param_spec->slurpy.padoff
					);
					lhs = op_append_elem(OP_LIST, lhs, var);
				}
			}

			if (lhs) {
				OP *rhs;
				lhs->op_flags |= OPf_PARENS;
				rhs = newAVREF(newGVOP(OP_GV, 0, PL_defgv));

				*prelude_sentinel = op_append_list(
					OP_LINESEQ, *prelude_sentinel,
					newSTATEOP(
						0, NULL,
						newASSIGNOP(OPf_STACKED, lhs, 0, rhs)
					)
				);
			}
		}

		/* default arguments */
		{
			size_t i, lim, req;
			OP *nest;

			nest = NULL;

			req = param_spec->positional_required.used;
			for (i = 0, lim = param_spec->positional_optional.used; i < lim; i++) {
				ParamInit *cur = &param_spec->positional_optional.data[i];
				OP *var, *cond;

				cond = newBINOP(
					OP_LT, 0,
					newAVREF(newGVOP(OP_GV, 0, PL_defgv)),
					newSVOP(OP_CONST, 0, newSViv(req + i + 1))
				);

				var = my_var(aTHX_ 0, cur->param.padoff);

				nest = op_append_list(
					OP_LINESEQ, nest,
					newASSIGNOP(OPf_STACKED, var, 0, cur->init)
				);
				cur->init = NULL;
				nest = newCONDOP(
					0,
					cond,
					nest,
					NULL
				);
			}

			*prelude_sentinel = op_append_list(
				OP_LINESEQ, *prelude_sentinel,
				nest
			);
		}

		/* named parameters */
		if (count_named_params(param_spec)) {
			int nameblock_ix;
			OP *nameblock;
			PADOFFSET vb, vc, vi, vk;
			const size_t pos = count_positional_params(param_spec);

			nameblock = NULL;
			nameblock_ix = S_block_start(aTHX_ TRUE);

			{
				OP *decl, *var;

				decl = NULL;

				if (!param_spec->named_required.used || !(spec->flags & FLAG_CHECK_NARGS)) {
					vb = 0;
				} else {
					var = newOP(OP_PADSV, OPf_MOD | (OPpLVAL_INTRO << 8));
					var->op_targ = vb = pad_add_name_pvs("$__B", 0, NULL, NULL);
					var = newASSIGNOP(OPf_STACKED, var, 0, newSVOP(OP_CONST, 0, newSVpvs("")));
					decl = op_append_list(OP_LINESEQ, decl, newSTATEOP(0, NULL, var));
				}

				if (!param_spec->named_optional.used) {
					vc = 0;
				} else {
					var = newOP(OP_PADSV, OPf_MOD | (OPpLVAL_INTRO << 8));
					var->op_targ = vc = pad_add_name_pvs("$__C", 0, NULL, NULL);
					var = newASSIGNOP(OPf_STACKED, var, 0, newSVOP(OP_CONST, 0, newSVpvs("")));
					decl = op_append_list(OP_LINESEQ, decl, newSTATEOP(0, NULL, var));
				}

				var = newOP(OP_PADSV, OPf_MOD | (OPpLVAL_INTRO << 8));
				var->op_targ = vk = pad_add_name_pvs("$__K", 0, NULL, NULL);
				decl = op_append_list(OP_LINESEQ, decl, newSTATEOP(0, NULL, var));

				var = newOP(OP_PADSV, OPf_MOD | (OPpLVAL_INTRO << 8));
				var->op_targ = vi = pad_add_name_pvs("$__I", 0, NULL, NULL);
				var = newASSIGNOP(OPf_STACKED, var, 0, newSVOP(OP_CONST, 0, newSViv(pos)));
				decl = op_append_list(OP_LINESEQ, decl, newSTATEOP(0, NULL, var));

				//S_intro_my(aTHX);
				nameblock = op_append_list(OP_LINESEQ, nameblock, decl);
			}

			{
				OP *loop;

				loop = NULL;

				loop = op_append_list(
					OP_LINESEQ,
					loop,
					newSTATEOP(
						0, NULL,
						newASSIGNOP(
							OPf_STACKED,
							my_var(aTHX_ 0, vk),
							0,
							mkargselemv(aTHX_ vi)
						)
					)
				);

				{
					OP *nest;
					size_t i;

					if (param_spec->slurpy.name) {
						if (SvPV_nolen(param_spec->slurpy.name)[0] == '@') {
							OP *first, *mid, *last;

							last = mkargselem(
								aTHX_
								newBINOP(
									OP_ADD, 0,
									my_var(aTHX_ 0, vi),
									newSVOP(OP_CONST, 0, newSViv(1))
								)
							);
							mid = last;

							first = my_var(aTHX_ 0, vk);
							first->op_sibling = mid;
							mid = first;

							first = my_var_g(aTHX_ OP_PADAV, 0, param_spec->slurpy.padoff);
							first->op_sibling = mid;
							mid = first;

							first = newOP(OP_PUSHMARK, 0);
							nest = newLISTOP(OP_PUSH, 0, first, mid);
							nest->op_targ = pad_alloc(OP_PUSH, SVs_PADTMP);
							((LISTOP *)nest)->op_last = last;
						} else {
							nest = newASSIGNOP(
								OPf_STACKED,
								newBINOP(
									OP_HELEM, 0,
									my_var_g(aTHX_ OP_PADHV, 0, param_spec->slurpy.padoff),
									my_var(aTHX_ 0, vk)
								),
								0,
								mkargselem(
									aTHX_
									newBINOP(
										OP_ADD, 0,
										my_var(aTHX_ 0, vi),
										newSVOP(OP_CONST, 0, newSViv(1))
									)
								)
							);
						}
					} else if (spec->flags & FLAG_CHECK_NARGS) {
						OP *err, *croak;

						err = newSVOP(OP_CONST, 0,
						              newSVpvf("In %"SVf": No such named parameter: ", SVfARG(declarator)));
						err = newBINOP(
							OP_CONCAT, 0,
							err,
							my_var(aTHX_ 0, vk)
						);

						croak = newCVREF(OPf_WANT_SCALAR,
						                 newGVOP(OP_GV, 0, gv_fetchpvs("Carp::croak", 0, SVt_PVCV)));
						nest = newUNOP(OP_ENTERSUB, OPf_STACKED,
						               op_append_elem(OP_LIST, err, croak));
					} else {
						nest = NULL;
					}

					for (i = param_spec->named_optional.used; i--; ) {
						Param *cur = &param_spec->named_optional.data[i].param;
						size_t dn;
						char *dp = SvPV(cur->name, dn);
						OP *vec;

						if (!(spec->flags & FLAG_CHECK_NARGS)) {
							vec = NULL;
						} else {
							vec = newASSIGNOP(
								OPf_STACKED,
								mkvecbits(aTHX_ vc, i),
								0,
								newSVOP(OP_CONST, 0, newSViv(1))
							);
						}

						nest = newCONDOP(
							0,
							newBINOP(
								OP_SEQ, 0,
								my_var(aTHX_ 0, vk),
								newSVOP(OP_CONST, 0, newSVpvn_utf8(dp + 1, dn - 1, SvUTF8(cur->name)))
							),
							op_append_list(
								OP_LINESEQ,
								newASSIGNOP(
									OPf_STACKED,
									my_var(aTHX_ 0, cur->padoff),
									0,
									mkargselem(
										aTHX_
										newBINOP(
											OP_ADD, 0,
											my_var(aTHX_ 0, vi),
											newSVOP(OP_CONST, 0, newSViv(1))
										)
									)
								),
								vec
							),
							nest
						);
					}

					for (i = param_spec->named_required.used; i--; ) {
						Param *cur = &param_spec->named_required.data[i];
						size_t dn;
						char *dp = SvPV(cur->name, dn);
						OP *vec;

						if (!(spec->flags & FLAG_CHECK_NARGS)) {
							vec = NULL;
						} else {
							vec = newASSIGNOP(
								OPf_STACKED,
								mkvecbits(aTHX_ vb, i),
								0,
								newSVOP(OP_CONST, 0, newSViv(1))
							);
						}

						nest = newCONDOP(
							0,
							newBINOP(
								OP_SEQ, 0,
								my_var(aTHX_ 0, vk),
								newSVOP(OP_CONST, 0, newSVpvn_utf8(dp + 1, dn - 1, SvUTF8(cur->name)))
							),
							op_append_list(
								OP_LINESEQ,
								newASSIGNOP(
									OPf_STACKED,
									my_var(aTHX_ 0, cur->padoff),
									0,
									mkargselem(
										aTHX_
										newBINOP(
											OP_ADD, 0,
											my_var(aTHX_ 0, vi),
											newSVOP(OP_CONST, 0, newSViv(1))
										)
									)
								),
								vec
							),
							nest
						);
					}

					loop = op_append_elem(OP_LINESEQ, loop, newSTATEOP(0, NULL, nest));
				}

				loop = newWHILEOP(
					0, 1,
					NULL,
					newBINOP(
						OP_LT, 0,
						my_var(aTHX_ 0, vi),
						newAVREF(newGVOP(OP_GV, 0, PL_defgv))
					),
					loop,
					newASSIGNOP(
						OPf_STACKED,
						my_var(aTHX_ 0, vi),
						OP_ADD,
						newSVOP(OP_CONST, 0, newSViv(2))
					),
					0
				);

				nameblock = op_append_list(OP_LINESEQ, nameblock, newSTATEOP(0, NULL, loop));
			}

			if (param_spec->named_required.used && (spec->flags & FLAG_CHECK_NARGS)) {
				OP *cond, *err, *croak, *join;

				{
					size_t i, lim;
					OP *first, *mid, *last;

					last = newNULLLIST();
					mid = last;

					for (i = param_spec->named_required.used; i--; ) {
						OP *cur;
						SV *sv = param_spec->named_required.data[i].name;
						size_t n;
						char *p = SvPV(sv, n);
						cur = newCONDOP(
							0,
							mkvecbits(aTHX_ vb, i),
							newNULLLIST(),
							newSVOP(OP_CONST, 0, newSVpvn_utf8(p + 1, n - 1, SvUTF8(sv)))
						);
						cur->op_sibling = mid;
						mid = cur;
					}

					first = newSVOP(OP_CONST, 0, newSVpvs(", "));
					first->op_sibling = mid;
					mid = first;

					first = newOP(OP_PUSHMARK, 0);

					join = newLISTOP(OP_JOIN, 0, first, mid);
					join->op_targ = pad_alloc(OP_JOIN, SVs_PADTMP);
					((LISTOP *)join)->op_last = last;
				}

				err = newSVOP(
					OP_CONST, 0,
					newSVpvf("In %"SVf": Missing named parameter(s): ", SVfARG(declarator))
				);
				err = newBINOP(OP_CONCAT, 0, err, join);
				croak = newCVREF(
					OPf_WANT_SCALAR,
					newGVOP(OP_GV, 0, gv_fetchpvs("Carp::croak", 0, SVt_PVCV))
				);
				err = newUNOP(
					OP_ENTERSUB,
					OPf_STACKED,
					op_append_elem(OP_LIST, err, croak)
				);
				cond = newBINOP(
					OP_SNE, 0,
					my_var(aTHX_ 0, vb),
					newSVOP(OP_CONST, 0, mkbits1(aTHX_ param_spec->named_required.used))
				);
				err = newCONDOP(
					0,
					cond,
					err,
					NULL
				);

				nameblock = op_append_list(OP_LINESEQ, nameblock, err);
			}

			if (param_spec->named_optional.used) {
				size_t i, lim;

				for (i = 0, lim = param_spec->named_optional.used; i < lim; i++) {
					ParamInit *const cur = &param_spec->named_optional.data[i];
					OP *init, *cond;

					init = newASSIGNOP(
						OPf_STACKED,
						my_var(aTHX_ 0, cur->param.padoff),
						0,
						cur->init
					);
					cur->init = NULL;

					cond = newUNOP(OP_NOT, OPf_SPECIAL, mkvecbits(aTHX_ vc, i));

					init = newCONDOP(0, cond, init, NULL);

					nameblock = op_append_list(OP_LINESEQ, nameblock, newSTATEOP(0, NULL, init));
				}
			}

			nameblock = S_block_end(aTHX_ nameblock_ix, nameblock);
			nameblock = op_scope(nameblock);

			*prelude_sentinel = op_append_list(OP_LINESEQ, *prelude_sentinel, nameblock);
		}
	}

	/* finally let perl parse the actual subroutine body */
	body = parse_block(0);

	/* add '();' to make function return nothing by default */
	/* (otherwise the invisible parameter initialization can "leak" into
	   the return value: fun ($x) {}->("asdf", 0) == 2) */
	if (*prelude_sentinel) {
		body = newSTATEOP(0, NULL, body);
	}

	body = op_append_list(OP_LINESEQ, *prelude_sentinel, body);
	*prelude_sentinel = NULL;

	/* it's go time. */
	{
		OP *const attrs = *attrs_sentinel;
		*attrs_sentinel = NULL;
		SvREFCNT_inc_simple_void(PL_compcv);

		/* close outer block: '}' */
		S_block_end(aTHX_ save_ix, body);

		if (!saw_name) {
			*pop = newANONATTRSUB(
				floor_ix,
				proto ? newSVOP(OP_CONST, 0, SvREFCNT_inc_simple_NN(proto)) : NULL,
				attrs,
				body
			);
			return KEYWORD_PLUGIN_EXPR;
		}

		newATTRSUB(
			floor_ix,
			newSVOP(OP_CONST, 0, SvREFCNT_inc_simple_NN(saw_name)),
			proto ? newSVOP(OP_CONST, 0, SvREFCNT_inc_simple_NN(proto)) : NULL,
			attrs,
			body
		);
		*pop = newOP(OP_NULL, 0);
		return KEYWORD_PLUGIN_STMT;
	}
}

static int my_keyword_plugin(pTHX_ char *keyword_ptr, STRLEN keyword_len, OP **op_ptr) {
	KWSpec spec;
	int ret;

	SAVETMPS;

	if (kw_flags(aTHX_ keyword_ptr, keyword_len, &spec)) {
		ret = parse_fun(aTHX_ op_ptr, keyword_ptr, keyword_len, &spec);
	} else {
		ret = next_keyword_plugin(aTHX_ keyword_ptr, keyword_len, op_ptr);
	}

	FREETMPS;

	return ret;
}

WARNINGS_RESET

MODULE = Function::Parameters   PACKAGE = Function::Parameters
PROTOTYPES: ENABLE

BOOT:
WARNINGS_ENABLE {
	HV *const stash = gv_stashpvs(MY_PKG, GV_ADD);
	/**/
	newCONSTSUB(stash, "FLAG_NAME_OK",      newSViv(FLAG_NAME_OK));
	newCONSTSUB(stash, "FLAG_ANON_OK",      newSViv(FLAG_ANON_OK));
	newCONSTSUB(stash, "FLAG_DEFAULT_ARGS", newSViv(FLAG_DEFAULT_ARGS));
	newCONSTSUB(stash, "FLAG_CHECK_NARGS",  newSViv(FLAG_CHECK_NARGS));
	newCONSTSUB(stash, "FLAG_INVOCANT",     newSViv(FLAG_INVOCANT));
	newCONSTSUB(stash, "FLAG_NAMED_PARAMS", newSViv(FLAG_NAMED_PARAMS));
	newCONSTSUB(stash, "HINTK_KEYWORDS", newSVpvs(HINTK_KEYWORDS));
	newCONSTSUB(stash, "HINTK_FLAGS_",   newSVpvs(HINTK_FLAGS_));
	newCONSTSUB(stash, "HINTK_SHIFT_",   newSVpvs(HINTK_SHIFT_));
	newCONSTSUB(stash, "HINTK_ATTRS_",   newSVpvs(HINTK_ATTRS_));
	/**/
	next_keyword_plugin = PL_keyword_plugin;
	PL_keyword_plugin = my_keyword_plugin;
} WARNINGS_RESET
