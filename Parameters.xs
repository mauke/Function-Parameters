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

#define MY_PKG "Function::Parameters"

#define HINTK_KEYWORDS MY_PKG "/keywords"
#define HINTK_NAME_    MY_PKG "/name:"
#define HINTK_SHIFT_   MY_PKG "/shift:"
#define HINTK_ATTRS_   MY_PKG "/attrs:"

#define HAVE_PERL_VERSION(R, V, S) \
	(PERL_REVISION > (R) || (PERL_REVISION == (R) && (PERL_VERSION > (V) || (PERL_VERSION == (V) && (PERL_SUBVERSION >= (S))))))

#if HAVE_PERL_VERSION(5, 16, 0)
 #define IF_HAVE_PERL_5_16(YES, NO) YES
#else
 #define IF_HAVE_PERL_5_16(YES, NO) NO
#endif

typedef struct {
	enum {
		FLAG_NAME_OPTIONAL = 1,
		FLAG_NAME_REQUIRED,
		FLAG_NAME_PROHIBITED
	} name;
	SV *shift;
	SV *attrs;
} Spec;

static int (*next_keyword_plugin)(pTHX_ char *, STRLEN, OP **);

static int kw_flags(pTHX_ const char *kw_ptr, STRLEN kw_len, Spec *spec) {
	HV *hints;
	SV *sv, **psv;
	const char *p, *kw_active;
	STRLEN kw_active_len;

	spec->name = 0;
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

			FETCH_HINTK_INTO(NAME_, kw_ptr, kw_len, psv);
			spec->name = SvIV(*psv);

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


#include "toke_on_crack.c.inc"


static void free_ptr_op(pTHX_ void *vp) {
	OP **pp = vp;
	op_free(*pp);
	Safefree(pp);
}

#define sv_eq_pvs(SV, S) sv_eq_pvn(aTHX_ SV, "" S "", sizeof (S) - 1)

static int sv_eq_pvn(pTHX_ SV *sv, const char *p, STRLEN n) {
	STRLEN sv_len;
	const char *sv_p = SvPV(sv, sv_len);
	return
		sv_len == n &&
		memcmp(sv_p, p, n) == 0
	;
}


#include "padop_on_crack.c.inc"


#if 0
static PADOFFSET pad_add_my_sv(SV *name) {
	PADOFFSET offset;
	SV *namesv, *myvar;
	char *p;
	STRLEN len;

	p = SvPV(name, len);
	myvar = *av_fetch(PL_comppad, AvFILLp(PL_comppad) + 1, 1);
	offset = AvFILLp(PL_comppad);
	SvPADMY_on(myvar);
	if (*p == '@') {
		SvUPGRADE(myvar, SVt_PVAV);
	} else if (*p == '%') {
		SvUPGRADE(myvar, SVt_PVHV);
	}
	PL_curpad = AvARRAY(PL_comppad);
	namesv = newSV_type(SVt_PVMG);
	sv_setpvn(namesv, p, len);
	COP_SEQ_RANGE_LOW_set(namesv, PL_cop_seqmax);
	COP_SEQ_RANGE_HIGH_set(namesv, PERL_PADSEQ_INTRO);
	PL_cop_seqmax++;
	av_store(PL_comppad_name, offset, namesv);
	return offset;
}
#endif

enum {
	MY_ATTR_LVALUE = 0x01,
	MY_ATTR_METHOD = 0x02,
	MY_ATTR_SPECIAL = 0x04
};

static int parse_fun(pTHX_ OP **pop, const char *keyword_ptr, STRLEN keyword_len, const Spec *spec) {
	SV *declarator;
	I32 floor_ix;
	SV *saw_name;
	AV *params;
	SV *proto;
	OP **attrs_sentinel, *body;
	unsigned builtin_attrs;
	int saw_colon;
	STRLEN len;
	char *s;
	I32 c;

	declarator = sv_2mortal(newSVpvn(keyword_ptr, keyword_len));

	lex_read_space(0);

	builtin_attrs = 0;

	/* function name */
	saw_name = NULL;
	s = PL_parser->bufptr;
	if (spec->name != FLAG_NAME_PROHIBITED && (len = S_scan_word(aTHX_ s, TRUE))) {
		saw_name = sv_2mortal(newSVpvn_flags(s, len, PARSING_UTF ? SVf_UTF8 : 0));

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

		lex_read_to(s + len);
		lex_read_space(0);
	} else if (spec->name == FLAG_NAME_REQUIRED) {
		croak("I was expecting a function name, not \"%.*s\"", (int)(PL_parser->bufend - s), s);
	} else {
		sv_catpvs(declarator, " (anon)");
	}

	floor_ix = start_subparse(FALSE, saw_name ? 0 : CVf_ANON);
	SAVEFREESV(PL_compcv);

	/* parameters */
	params = NULL;
	c = lex_peek_unichar(0);
	if (c == '(') {
		SV *saw_slurpy = NULL;

		lex_read_unichar(0);
		lex_read_space(0);

		params = newAV();
		sv_2mortal((SV *)params);

		for (;;) {
			c = lex_peek_unichar(0);
			if (c == '$' || c == '@' || c == '%') {
				SV *param;

				lex_read_unichar(0);
				lex_read_space(0);

				s = PL_parser->bufptr;
				if (!(len = S_scan_word(aTHX_ s, FALSE))) {
					croak("In %"SVf": missing identifier", SVfARG(declarator));
				}
				param = sv_2mortal(newSVpvf("%c%.*s", (int)c, (int)len, s));
				if (saw_slurpy) {
					croak("In %"SVf": I was expecting \")\" after \"%"SVf"\", not \"%"SVf"\"", SVfARG(declarator), SVfARG(saw_slurpy), SVfARG(param));
				}
				if (c != '$') {
					saw_slurpy = param;
				}
				av_push(params, SvREFCNT_inc_simple_NN(param));
				lex_read_to(s + len);
				lex_read_space(0);

				c = lex_peek_unichar(0);
				if (c == ',') {
					lex_read_unichar(0);
					lex_read_space(0);
					continue;
				}
			}

			if (c == ')') {
				lex_read_unichar(0);
				lex_read_space(0);
				break;
			}

			if (c == -1) {
				croak("In %"SVf": unexpected EOF in parameter list", SVfARG(declarator));
			}
			croak("In %"SVf": unexpected '%c' in parameter list", SVfARG(declarator), (int)c);
		}
	}

	/* prototype */
	proto = NULL;
	saw_colon = 0;
	c = lex_peek_unichar(0);
	if (c == ':') {
		lex_read_unichar(0);
		lex_read_space(0);

		c = lex_peek_unichar(0);
		if (c != '(') {
			lex_stuff_pvs(":", 0);
			c = ':';
		} else {
			proto = sv_2mortal(newSVpvs(""));
			if (!S_scan_str(aTHX_ proto, FALSE, FALSE)) {
				croak("In %"SVf": prototype not terminated", SVfARG(declarator));
			}
			S_check_prototype(aTHX_ declarator, proto);
			lex_read_space(0);
			c = lex_peek_unichar(0);
		}
	}

	/* surprise predeclaration! */
	if (saw_name) {
		/* 'sub NAME (PROTO);' to make name/proto known to perl before it
		   starts parsing the body */
		SvREFCNT_inc_simple_void(PL_compcv);

		newATTRSUB(
			floor_ix,
			newSVOP(OP_CONST, 0, SvREFCNT_inc_simple_NN(saw_name)),
			proto ? newSVOP(OP_CONST, 0, SvREFCNT_inc_simple_NN(proto)) : NULL,
			NULL,
			NULL
		);

		floor_ix = start_subparse(FALSE, 0);
		SAVEFREESV(PL_compcv);
	}


	/* attributes */
	Newx(attrs_sentinel, 1, OP *);
	*attrs_sentinel = NULL;
	SAVEDESTRUCTOR_X(free_ptr_op, attrs_sentinel);

	if (c == ':' || c == '{') {

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

				s = PL_parser->bufptr;
				if (!(len = S_scan_word(aTHX_ s, FALSE))) {
					break;
				}

				attr = sv_2mortal(newSVpvn_flags(s, len, PARSING_UTF ? SVf_UTF8 : 0));

				lex_read_to(s + len);
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
					SV *sv = sv_2mortal(newSVpvs(""));
					if (!S_scan_str(aTHX_ sv, TRUE, TRUE)) {
						croak("In %"SVf": unterminated attribute parameter in attribute list", SVfARG(declarator));
					}
					sv_catsv(attr, sv);

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
	if (c != '{') {
		croak("In %"SVf": I was expecting a function body, not \"%c\"", SVfARG(declarator), (int)c);
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

	/* munge */
	{
		/* create outer block: '{' */
		const int save_ix = S_block_start(aTHX_ TRUE);
		OP *init = NULL;

		/* my $self = shift; */
		if (SvTRUE(spec->shift)) {
			OP *const var = newOP(OP_PADSV, OPf_WANT_SCALAR | (OPpLVAL_INTRO << 8));
			var->op_targ = pad_add_name_sv(spec->shift, 0, NULL, NULL);

			init = newASSIGNOP(OPf_STACKED, var, 0, newOP(OP_SHIFT, 0));
			init = newSTATEOP(0, NULL, init);
		}

		/* my (PARAMS) = @_; */
		if (params && av_len(params) > -1) {
			SV *param;
			OP *init_param, *left, *right;

			left = NULL;
			while ((param = av_shift(params)) != &PL_sv_undef) {
				OP *const var = newOP(OP_PADSV, OPf_WANT_LIST | (OPpLVAL_INTRO << 8));
				var->op_targ = pad_add_name_sv(param, 0, NULL, NULL);
				SvREFCNT_dec(param);
				left = op_append_elem(OP_LIST, left, var);
			}

			left->op_flags |= OPf_PARENS;
			right = newAVREF(newGVOP(OP_GV, 0, PL_defgv));
			init_param = newASSIGNOP(OPf_STACKED, left, 0, right);
			init_param = newSTATEOP(0, NULL, init_param);

			init = op_append_list(OP_LINESEQ, init, init_param);
		}

		/* add '();' to make function return nothing by default */
		/* (otherwise the invisible parameter initialization can "leak" into
		   the return value: fun ($x) {}->("asdf", 0) == 2) */
		if (init) {
			init = op_append_list(OP_LINESEQ, init, newSTATEOP(0, NULL, newOP(OP_STUB, OPf_PARENS)));
		}

		/* finally let perl parse the actual subroutine body */
		body = parse_block(0);

		body = op_append_list(OP_LINESEQ, init, body);

		/* close outer block: '}' */
		S_block_end(aTHX_ save_ix, body);
	}

	/* it's go time. */
	{
		OP *const attrs = *attrs_sentinel;
		*attrs_sentinel = NULL;
		SvREFCNT_inc_simple_void(PL_compcv);

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
		*pop = NULL;
		return KEYWORD_PLUGIN_STMT;
	}
}

static int my_keyword_plugin(pTHX_ char *keyword_ptr, STRLEN keyword_len, OP **op_ptr) {
	Spec spec;
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
	newCONSTSUB(stash, "FLAG_NAME_OPTIONAL", newSViv(FLAG_NAME_OPTIONAL));
	newCONSTSUB(stash, "FLAG_NAME_REQUIRED", newSViv(FLAG_NAME_REQUIRED));
	newCONSTSUB(stash, "FLAG_NAME_PROHIBITED", newSViv(FLAG_NAME_PROHIBITED));
	newCONSTSUB(stash, "HINTK_KEYWORDS", newSVpvs(HINTK_KEYWORDS));
	newCONSTSUB(stash, "HINTK_NAME_", newSVpvs(HINTK_NAME_));
	newCONSTSUB(stash, "HINTK_SHIFT_", newSVpvs(HINTK_SHIFT_));
	newCONSTSUB(stash, "HINTK_ATTRS_", newSVpvs(HINTK_ATTRS_));
	/**/
	next_keyword_plugin = PL_keyword_plugin;
	PL_keyword_plugin = my_keyword_plugin;
} WARNINGS_RESET
