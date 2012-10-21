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
	FLAG_CHECK_NARGS  = 0x08,
	FLAG_INVOCANT     = 0x10
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

static int parse_fun(pTHX_ OP **pop, const char *keyword_ptr, STRLEN keyword_len, const KWSpec *spec) {
	SV *declarator;
	I32 floor_ix;
	int save_ix;
	SV *saw_name;
	OP **prelude_sentinel;
	int did_invocant_decl;
	SV *invocant;
	AV *params;
	DefaultParamSpec *defaults;
	int args_min, args_max;
	SV *proto;
	OP **attrs_sentinel, *body;
	unsigned builtin_attrs;
	STRLEN len;
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
	did_invocant_decl = 0;
	invocant = NULL;
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

				if (!(param = my_scan_word(aTHX_ FALSE))) {
					croak("In %"SVf": missing identifier", SVfARG(declarator));
				}
				sv_insert(param, 0, 0, &sigil, 1);
				if (saw_slurpy) {
					croak("In %"SVf": I was expecting \")\" after \"%"SVf"\", not \"%"SVf"\"", SVfARG(declarator), SVfARG(saw_slurpy), SVfARG(param));
				}
				if (sigil == '$') {
					args_max++;
				} else {
					args_max = -1;
					saw_slurpy = param;
				}

				lex_read_space(0);
				c = lex_peek_unichar(0);

				assert(param_count >= 1);

				if (c == ':') {
					if (invocant) {
						croak("In %"SVf": invalid double invocants %"SVf", %"SVf"", SVfARG(declarator), SVfARG(invocant), SVfARG(param));
					}
					if (param_count != 1) {
						croak("In %"SVf": invocant %"SVf" must be first in parameter list", SVfARG(declarator), SVfARG(param));
					}
					if (!(spec->flags & FLAG_INVOCANT)) {
						croak("In %"SVf": invocant %"SVf" not allowed here", SVfARG(declarator), SVfARG(param));
					}
					if (sigil != '$') {
						croak("In %"SVf": invocant %"SVf" can't be a %s", SVfARG(declarator), SVfARG(param), sigil == '@' ? "array" : "hash");
					}

					lex_read_unichar(0);
					lex_read_space(0);

					args_max--;
					param_count--;
					invocant = param;
				} else {
					av_push(params, SvREFCNT_inc_simple_NN(param));

					if (c == '=' && (spec->flags & FLAG_DEFAULT_ARGS)) {
						DefaultParamSpec *curdef;

						if (sigil != '$') {
							croak("In %"SVf": %s %"SVf" can't have a default value", SVfARG(declarator), sigil == '@' ? "array" : "hash", SVfARG(saw_slurpy));
						}

						lex_read_unichar(0);
						lex_read_space(0);

						/* my $self;  # in scope for default argument */
						if (!invocant && !did_invocant_decl && SvTRUE(spec->shift)) {
							OP *var;

							var = newOP(OP_PADSV, OPf_MOD | (OPpLVAL_INTRO << 8));
							var->op_targ = pad_add_name_sv(spec->shift, 0, NULL, NULL);

							*prelude_sentinel = op_append_list(OP_LINESEQ, *prelude_sentinel, newSTATEOP(0, NULL, var));

							did_invocant_decl = 1;
						}

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
					} else {
						if (sigil == '$' && !defaults) {
							args_min++;
						}
					}
				}

				/* my $param; */
				{
					OP *var;

					var = newOP(OP_PADSV, OPf_MOD | (OPpLVAL_INTRO << 8));
					var->op_targ = pad_add_name_sv(param, 0, NULL, NULL);

					*prelude_sentinel = op_append_list(OP_LINESEQ, *prelude_sentinel, newSTATEOP(0, NULL, var));
				}

				if (param_count == 0) {
					continue;
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

	if (!invocant) {
		invocant = spec->shift;

		/* my $self;  # wasn't needed yet */
		if (SvTRUE(invocant) && !did_invocant_decl) {
			OP *var;

			var = newOP(OP_PADSV, OPf_MOD | (OPpLVAL_INTRO << 8));
			var->op_targ = pad_add_name_sv(invocant, 0, NULL, NULL);

			*prelude_sentinel = op_append_list(OP_LINESEQ, *prelude_sentinel, newSTATEOP(0, NULL, var));
		}
	}

	/* min/max argument count checks */
	if (spec->flags & FLAG_CHECK_NARGS) {
		if (SvTRUE(invocant)) {
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

			*prelude_sentinel = op_append_list(OP_LINESEQ, *prelude_sentinel, newSTATEOP(0, NULL, chk));
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

			*prelude_sentinel = op_append_list(OP_LINESEQ, *prelude_sentinel, newSTATEOP(0, NULL, chk));
		}
	}

	/* $self = shift; */
	if (SvTRUE(invocant)) {
		OP *var, *shift;

		var = newOP(OP_PADSV, OPf_WANT_SCALAR);
		var->op_targ = pad_findmy_sv(invocant, 0);

		shift = newASSIGNOP(OPf_STACKED, var, 0, newOP(OP_SHIFT, 0));
		*prelude_sentinel = op_append_list(OP_LINESEQ, *prelude_sentinel, newSTATEOP(0, NULL, shift));
	}

	/* (PARAMS) = @_; */
	if (params && av_len(params) > -1) {
		SV *param;
		OP *init_param, *left, *right;

		left = NULL;
		while ((param = av_shift(params)) != &PL_sv_undef) {
			OP *const var = newOP(OP_PADSV, OPf_WANT_LIST);
			var->op_targ = pad_findmy_sv(param, 0);
			SvREFCNT_dec(param);
			left = op_append_elem(OP_LIST, left, var);
		}

		left->op_flags |= OPf_PARENS;
		right = newAVREF(newGVOP(OP_GV, 0, PL_defgv));
		init_param = newASSIGNOP(OPf_STACKED, left, 0, right);
		init_param = newSTATEOP(0, NULL, init_param);

		*prelude_sentinel = op_append_list(OP_LINESEQ, *prelude_sentinel, init_param);
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

		*prelude_sentinel = op_append_list(OP_LINESEQ, *prelude_sentinel, gen);
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
	newCONSTSUB(stash, "HINTK_KEYWORDS", newSVpvs(HINTK_KEYWORDS));
	newCONSTSUB(stash, "HINTK_FLAGS_",   newSVpvs(HINTK_FLAGS_));
	newCONSTSUB(stash, "HINTK_SHIFT_",   newSVpvs(HINTK_SHIFT_));
	newCONSTSUB(stash, "HINTK_ATTRS_",   newSVpvs(HINTK_ATTRS_));
	/**/
	next_keyword_plugin = PL_keyword_plugin;
	PL_keyword_plugin = my_keyword_plugin;
} WARNINGS_RESET
