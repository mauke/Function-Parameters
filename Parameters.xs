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
 	WARNINGS_ENABLEW(-Wshadow) \
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

#define FETCH_HINTK_INTO(NAME, PTR, LEN, X) do { \
	const char *fk_ptr_; \
	STRLEN fk_len_; \
	SV *fk_sv_; \
	fk_sv_ = sv_2mortal(newSVpvs(HINTK_ ## NAME)); \
	sv_catpvn(fk_sv_, PTR, LEN); \
	fk_ptr_ = SvPV(fk_sv_, fk_len_); \
	if (!((X) = hv_fetch(hints, fk_ptr_, fk_len_, 0))) { \
		croak("%s: internal error: $^H{'%.*s'} not set", MY_PKG, (int)fk_len_, fk_ptr_); \
	} \
} while (0)

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


static int parse_fun(pTHX_ OP **pop, const char *keyword_ptr, STRLEN keyword_len, const Spec *spec) {
	SV *gen, *declarator, *params, *sv;
	line_t line_start;
	int saw_name, saw_colon;
	STRLEN len;
	char *s;
	I32 c;

	gen = sv_2mortal(newSVpvs("sub"));
	declarator = sv_2mortal(newSVpvn(keyword_ptr, keyword_len));
	params = sv_2mortal(newSVpvs(""));

	line_start = CopLINE(PL_curcop);
	lex_read_space(0);

	/* function name */
	saw_name = 0;
	s = PL_parser->bufptr;
	if (spec->name != FLAG_NAME_PROHIBITED && (len = S_scan_word(aTHX_ s, TRUE))) {
		sv_catpvs(gen, " ");
		sv_catpvn(gen, s, len);
		sv_catpvs(declarator, " ");
		sv_catpvn(declarator, s, len);
		lex_read_to(s + len);
		lex_read_space(0);
		saw_name = 1;
	} else if (spec->name == FLAG_NAME_REQUIRED) {
		croak("I was expecting a function name, not \"%.*s\"", (int)(PL_parser->bufend - s), s);
	} else {
		sv_catpvs(declarator, " (anon)");
	}

	/* parameters */
	c = lex_peek_unichar(0);
	if (c == '(') {
		SV *saw_slurpy = NULL;

		lex_read_unichar(0);
		lex_read_space(0);

		for (;;) {
			c = lex_peek_unichar(0);
			if (c == '$' || c == '@' || c == '%') {
				sv_catpvf(params, "%c", (int)c);
				lex_read_unichar(0);
				lex_read_space(0);

				s = PL_parser->bufptr;
				if (!(len = S_scan_word(aTHX_ s, FALSE))) {
					croak("In %"SVf": missing identifier", SVfARG(declarator));
				}
				if (saw_slurpy) {
					croak("In %"SVf": I was expecting \")\" after \"%"SVf"\", not \"%c%.*s\"", SVfARG(declarator), SVfARG(saw_slurpy), (int)c, (int)len, s);
				}
				if (c != '$') {
					saw_slurpy = sv_2mortal(newSVpvf("%c%.*s", (int)c, (int)len, s));
				}
				sv_catpvn(params, s, len);
				sv_catpvs(params, ",");
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
	saw_colon = 0;
	c = lex_peek_unichar(0);
	if (c == ':') {
		lex_read_unichar(0);
		lex_read_space(0);

		c = lex_peek_unichar(0);
		if (c != '(') {
			saw_colon = 1;
		} else {
			sv = sv_2mortal(newSVpvs(""));
			if (!S_scan_str(aTHX_ sv, TRUE, TRUE)) {
				croak("In %"SVf": malformed prototype", SVfARG(declarator));
			}
			sv_catsv(gen, sv);
			lex_read_space(0);
		}
	}

	if (saw_name) {
		len = SvCUR(gen);
		s = SvGROW(gen, (len + 1) * 2);
		sv_catpvs(gen, ";");
		sv_catpvn(gen, s, len);
	}

	/* attributes */
	if (SvTRUE(spec->attrs)) {
		sv_catsv(gen, spec->attrs);
	}

	if (!saw_colon) {
		c = lex_peek_unichar(0);
		if (c == ':') {
			saw_colon = 1;
			lex_read_unichar(0);
			lex_read_space(0);
		}
	}
	if (saw_colon) {
		for (;;) {
			s = PL_parser->bufptr;
			if (!(len = S_scan_word(aTHX_ s, FALSE))) {
				break;
			}
			sv_catpvs(gen, ":");
			sv_catpvn(gen, s, len);
			lex_read_to(s + len);
			lex_read_space(0);
			c = lex_peek_unichar(0);
			if (c == '(') {
				sv = sv_2mortal(newSVpvs(""));
				if (!S_scan_str(aTHX_ sv, TRUE, TRUE)) {
					croak("In %"SVf": malformed attribute argument list", SVfARG(declarator));
				}
				sv_catsv(gen, sv);
				lex_read_space(0);
				c = lex_peek_unichar(0);
			}
			if (c == ':') {
				lex_read_unichar(0);
				lex_read_space(0);
			}
		}
	}

	/* body */
	c = lex_peek_unichar(0);
	if (c != '{') {
		croak("In %"SVf": I was expecting a function body, not \"%c\"", SVfARG(declarator), (int)c);
	}
	lex_read_unichar(0);
	sv_catpvs(gen, "{");
	if (SvTRUE(spec->shift)) {
		sv_catpvs(gen, "my");
		sv_catsv(gen, spec->shift);
		sv_catpvs(gen, "=shift;");
	}
	if (SvCUR(params)) {
		sv_catpvs(gen, "my(");
		sv_catsv(gen, params);
		sv_catpvs(gen, ")=@_;");
	}

	/* named sub */
	if (saw_name) {
		/* fprintf(stderr, "! [%.*s]\n", (int)(PL_bufend - PL_bufptr), PL_bufptr); */
		lex_stuff_sv(gen, SvUTF8(gen));
		*pop = parse_barestmt(0);
		return KEYWORD_PLUGIN_STMT;
	}

	/* anon sub */
	sv_catpvs(gen, "BEGIN{" MY_PKG "::_fini}");
	/* fprintf(stderr, "!> [%.*s]\n", (int)(PL_bufend - PL_bufptr), PL_bufptr); */
	lex_stuff_sv(gen, SvUTF8(gen));
	*pop = parse_arithexpr(0);
	s = PL_parser->bufptr;
	if (*s != '}') {
		croak("%s: internal error: expected '}', found '%c'", MY_PKG, *s);
	}
	lex_unstuff(s + 1);
	/* fprintf(stderr, "!< [%.*s]\n", (int)(PL_bufend - PL_bufptr), PL_bufptr); */
	return KEYWORD_PLUGIN_EXPR;
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

static int magic_free(pTHX_ SV *sv, MAGIC *mg) {
	lex_stuff_pvn("}", 1, 0);
	/* fprintf(stderr, "!~ [%.*s]\n", (int)(PL_bufend - PL_bufptr), PL_bufptr); */
	return 0;
}

static int magic_nop(pTHX_ SV *sv, MAGIC *mg) {
	return 0;
}

static MGVTBL my_vtbl = {
	0,           /* get   */
	0,           /* set   */
	0,           /* len   */
	0,           /* clear */
	magic_free,  /* free  */
	0,           /* copy  */
	0,           /* dup   */
	magic_nop    /* local */
};

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

void
_fini()
	CODE:
	sv_magicext((SV *)GvHV(PL_hintgv), NULL, PERL_MAGIC_ext, &my_vtbl, NULL, 0);
