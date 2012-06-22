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


#define MY_PKG "Function::Parameters"

#define HINTK_KEYWORDS MY_PKG "/keywords"
#define HINTK_FLAGS_   MY_PKG "/flags:"
#define HINTK_SHIFT_   MY_PKG "/shift:"
#define HINTK_ATTRS_   MY_PKG "/attrs:"

#define DEFSTRUCT(T) typedef struct T T; struct T

DEFSTRUCT(DefaultParamSpec) {
	DefaultParamSpec *next;
	int limit;
	SV *name;
	OP *init;
};

enum {
	FLAG_NAME_OK      = 0x01,
	FLAG_ANON_OK      = 0x02,
	FLAG_DEFAULT_ARGS = 0x04,
	FLAG_CHECK_NARGS  = 0x08
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


#include "toke_on_crack.c.inc"


static void free_defspec(pTHX_ void *vp) {
	DefaultParamSpec *dp = vp;
	op_free(dp->init);
	Safefree(dp);
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

static int parse_fun(pTHX_ OP **pop, const char *keyword_ptr, STRLEN keyword_len, const KWSpec *spec) {
	SV *declarator;
	I32 floor_ix;
	int save_ix;
	SV *saw_name;
	AV *params;
	DefaultParamSpec *defaults;
	int args_min, args_max;
	SV *proto;
	OP **attrs_sentinel, *body;
	unsigned builtin_attrs;
	STRLEN len;
	char *s;
	I32 c;

	declarator = sv_2mortal(newSVpvn(keyword_ptr, keyword_len));

	lex_read_space(0);

	builtin_attrs = 0;

	/* function name */
	saw_name = NULL;
	s = PL_parser->bufptr;
	if ((spec->flags & FLAG_NAME_OK) && (len = S_scan_word(aTHX_ s, TRUE))) {
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
	} else if (!(spec->flags & FLAG_ANON_OK)) {
		croak("I was expecting a function name, not \"%.*s\"", (int)(PL_parser->bufend - s), s);
	} else {
		sv_catpvs(declarator, " (anon)");
	}

	/* we're a subroutine declaration */
	floor_ix = start_subparse(FALSE, saw_name ? 0 : CVf_ANON);
	SAVEFREESV(PL_compcv);

	/* create outer block: '{' */
	save_ix = S_block_start(aTHX_ TRUE);

	/* parameters */
	params = NULL;
	defaults = NULL;
	args_min = 0;
	args_max = -1;

	c = lex_peek_unichar(0);
	if (c == '(') {
		DefaultParamSpec **pdefaults_tail = &defaults;
		SV *saw_slurpy = NULL;
		int param_count = 0;
		args_max = 0;

		lex_read_unichar(0);
		lex_read_space(0);

		params = newAV();
		sv_2mortal((SV *)params);

		for (;;) {
			c = lex_peek_unichar(0);
			if (c == '$' || c == '@' || c == '%') {
				const char sigil = c;
				SV *param;

				param_count++;

				lex_read_unichar(0);
				lex_read_space(0);

				s = PL_parser->bufptr;
				if (!(len = S_scan_word(aTHX_ s, FALSE))) {
					croak("In %"SVf": missing identifier", SVfARG(declarator));
				}
				param = sv_2mortal(newSVpvf("%c%.*s", sigil, (int)len, s));
				if (saw_slurpy) {
					croak("In %"SVf": I was expecting \")\" after \"%"SVf"\", not \"%"SVf"\"", SVfARG(declarator), SVfARG(saw_slurpy), SVfARG(param));
				}
				if (sigil == '$') {
					args_max++;
				} else {
					args_max = -1;
					saw_slurpy = param;
				}
				av_push(params, SvREFCNT_inc_simple_NN(param));
				lex_read_to(s + len);
				lex_read_space(0);

				c = lex_peek_unichar(0);

				if (!(c == '=' && (spec->flags & FLAG_DEFAULT_ARGS))) {
					if (sigil == '$' && !defaults) {
						args_min++;
					}
				} else if (sigil != '$') {
					croak("In %"SVf": %s %"SVf" can't have a default value", SVfARG(declarator), sigil == '@' ? "array" : "hash", SVfARG(saw_slurpy));
				} else {
					DefaultParamSpec *curdef;

					lex_read_unichar(0);
					lex_read_space(0);

					Newx(curdef, 1, DefaultParamSpec);
					curdef->next = NULL;
					curdef->limit = param_count;
					curdef->name = param;
					curdef->init = NULL;
					SAVEDESTRUCTOR_X(free_defspec, curdef);

					curdef->next = *pdefaults_tail;
					*pdefaults_tail = curdef;
					pdefaults_tail = &curdef->next;

					/* let perl parse the default parameter value */
					curdef->init = parse_termexpr(0);

					lex_read_space(0);
					c = lex_peek_unichar(0);
				}

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

	/* munge */
	{
		OP *prelude = NULL;

		/* min/max argument count checks */
		if (spec->flags & FLAG_CHECK_NARGS) {
			if (SvTRUE(spec->shift)) {
				args_min++;
				if (args_max != -1) {
					args_max++;
				}
			}

			if (args_min > 0) {
				OP *chk, *cond, *err, *croak;

				err = newSVOP(OP_CONST, 0,
				              newSVpvf("Not enough arguments for %"SVf, SVfARG(declarator)));

				croak = newCVREF(OPf_WANT_SCALAR,
				                 newGVOP(OP_GV, 0, gv_fetchpvs("Carp::croak", 0, SVt_PVCV)));
				err = newUNOP(OP_ENTERSUB, OPf_STACKED,
				              op_append_elem(OP_LIST, err, croak));

				cond = newBINOP(OP_LT, 0,
				                newAVREF(newGVOP(OP_GV, 0, PL_defgv)),
				                newSVOP(OP_CONST, 0, newSViv(args_min)));
				chk = newLOGOP(OP_AND, 0, cond, err);

				prelude = op_append_list(OP_LINESEQ, prelude, newSTATEOP(0, NULL, chk));
			}
			if (args_max != -1) {
				OP *chk, *cond, *err, *croak;

				err = newSVOP(OP_CONST, 0,
				              newSVpvf("Too many arguments for %"SVf, SVfARG(declarator)));

				croak = newCVREF(OPf_WANT_SCALAR,
				                 newGVOP(OP_GV, 0, gv_fetchpvs("Carp::croak", 0, SVt_PVCV)));
				err = newUNOP(OP_ENTERSUB, OPf_STACKED,
				              op_append_elem(OP_LIST, err, croak));

				cond = newBINOP(OP_GT, 0,
				                newAVREF(newGVOP(OP_GV, 0, PL_defgv)),
				                newSVOP(OP_CONST, 0, newSViv(args_max)));
				chk = newLOGOP(OP_AND, 0, cond, err);

				prelude = op_append_list(OP_LINESEQ, prelude, newSTATEOP(0, NULL, chk));
			}
		}

		/* my $self = shift; */
		if (SvTRUE(spec->shift)) {
			OP *var, *shift;

			var = newOP(OP_PADSV, OPf_WANT_SCALAR | (OPpLVAL_INTRO << 8));
			var->op_targ = pad_add_name_sv(spec->shift, 0, NULL, NULL);

			shift = newASSIGNOP(OPf_STACKED, var, 0, newOP(OP_SHIFT, 0));
			prelude = op_append_list(OP_LINESEQ, prelude, newSTATEOP(0, NULL, shift));
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

			prelude = op_append_list(OP_LINESEQ, prelude, init_param);
		}

		/* defaults */
		{
			OP *gen = NULL;
			DefaultParamSpec *dp;

			for (dp = defaults; dp; dp = dp->next) {
				OP *init = dp->init;
				OP *var, *args, *cond;

				/* var = `$,name */
				var = newOP(OP_PADSV, 0);
				var->op_targ = pad_findmy_sv(dp->name, 0);

				/* init = `,var = ,init */
				init = newASSIGNOP(OPf_STACKED, var, 0, init);

				/* args = `@_ */
				args = newAVREF(newGVOP(OP_GV, 0, PL_defgv));

				/* cond = `,args < ,index */
				cond = newBINOP(OP_LT, 0, args, newSVOP(OP_CONST, 0, newSViv(dp->limit)));

				/* init = `,init if ,cond */
				init = newLOGOP(OP_AND, 0, cond, init);

				/* gen = `,gen ; ,init */
				gen = op_append_list(OP_LINESEQ, gen, newSTATEOP(0, NULL, init));

				dp->init = NULL;
			}

			prelude = op_append_list(OP_LINESEQ, prelude, gen);
		}

		/* finally let perl parse the actual subroutine body */
		body = parse_block(0);

		/* add '();' to make function return nothing by default */
		/* (otherwise the invisible parameter initialization can "leak" into
		   the return value: fun ($x) {}->("asdf", 0) == 2) */
		if (prelude) {
			body = newSTATEOP(0, NULL, body);
		}

		body = op_append_list(OP_LINESEQ, prelude, body);
	}

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
		*pop = NULL;
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
	newCONSTSUB(stash, "FLAG_NAME_OK", newSViv(FLAG_NAME_OK));
	newCONSTSUB(stash, "FLAG_ANON_OK", newSViv(FLAG_ANON_OK));
	newCONSTSUB(stash, "FLAG_DEFAULT_ARGS", newSViv(FLAG_DEFAULT_ARGS));
	newCONSTSUB(stash, "FLAG_CHECK_NARGS", newSViv(FLAG_CHECK_NARGS));
	newCONSTSUB(stash, "HINTK_KEYWORDS", newSVpvs(HINTK_KEYWORDS));
	newCONSTSUB(stash, "HINTK_FLAGS_", newSVpvs(HINTK_FLAGS_));
	newCONSTSUB(stash, "HINTK_SHIFT_", newSVpvs(HINTK_SHIFT_));
	newCONSTSUB(stash, "HINTK_ATTRS_", newSVpvs(HINTK_ATTRS_));
	/**/
	next_keyword_plugin = PL_keyword_plugin;
	PL_keyword_plugin = my_keyword_plugin;
} WARNINGS_RESET
