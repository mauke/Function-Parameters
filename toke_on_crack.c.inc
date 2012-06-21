/*
 * This code was copied from perl/toke.c and subsequently butchered
 * by Lukas Mai (2012).
 */
/* vi: set ft=c: */

/* vvvvvvvvvvvvvvvvvvvvv I HAVE NO IDEA WHAT I'M DOING vvvvvvvvvvvvvvvvvvvv */
#define PL_linestr              (PL_parser->linestr)
#define PL_copline              (PL_parser->copline)
#define PL_bufptr               (PL_parser->bufptr)
#define PL_bufend               (PL_parser->bufend)
#define PL_multi_start          (PL_parser->multi_start)
#define PL_multi_open           (PL_parser->multi_open)
#define PL_multi_close          (PL_parser->multi_close)
#define PL_multi_end            (PL_parser->multi_end)
#define PL_rsfp                 (PL_parser->rsfp)

#define CLINE (PL_copline = (CopLINE(PL_curcop) < PL_copline ? CopLINE(PL_curcop) : PL_copline))

#ifdef USE_UTF8_SCRIPTS
#   define PARSING_UTF (!IN_BYTES)
#else
#   define PARSING_UTF ((PL_linestr && DO_UTF8(PL_linestr)) || (PL_hints & HINT_UTF8))
#endif

static STRLEN S_scan_word(pTHX_ const char *start, int allow_package) {
	const char *s = start;
	for (;;) {
		if (isALNUM(*s) || (!PARSING_UTF && isALNUMC_L1(*s))) {  /* UTF handled below */
			s++;
		} else if (allow_package && s > start && *s == '\'' && isIDFIRST_lazy_if(s+1, PARSING_UTF)) {
			s++;
		} else if (allow_package && s[0] == ':' && s[1] == ':' && isIDFIRST_lazy_if(s+2, PARSING_UTF)) {
			s += 2;
		} else if (PARSING_UTF && UTF8_IS_START(*s) && isALNUM_utf8((U8*)s)) {
			do {
				s += UTF8SKIP(s);
			} while (UTF8_IS_CONTINUED(*s) && is_utf8_mark((U8*)s));
		} else {
			return s - start;
		}
	}
}

static char *S_scan_str(pTHX_ SV *sv, int keep_quoted, int keep_delims) {
	dVAR;
	char *start = PL_bufptr;
	const char *tmps;                   /* temp string, used for delimiter matching */
	char *s = start;                    /* current position in the buffer */
	char term;                          /* terminating character */
	char *to;                           /* current position in the sv's data */
	I32 brackets = 1;                   /* bracket nesting level */
	bool has_utf8 = FALSE;              /* is there any utf8 content? */
	I32 termcode;                       /* terminating char. code */
	U8 termstr[UTF8_MAXBYTES];          /* terminating string */
	STRLEN termlen;                     /* length of terminating string */
	int last_off = 0;                   /* last position for nesting bracket */

	/* XXX ATTENTION: we don't skip whitespace! */

	/* mark where we are, in case we need to report errors */
	CLINE;

	/* after skipping whitespace, the next character is the terminator */
	term = *s;
	if (!PARSING_UTF) {
		termcode = termstr[0] = term;
		termlen = 1;
	}
	else {
		termcode = IF_HAVE_PERL_5_16(
			utf8_to_uvchr_buf((U8*)s, (U8*)PL_bufend, &termlen),
			utf8_to_uvchr((U8*)s, &termlen)
		);
		Copy(s, termstr, termlen, U8);
		if (!UTF8_IS_INVARIANT(term))
			has_utf8 = TRUE;
	}

	/* mark where we are */
	PL_multi_start = CopLINE(PL_curcop);
	PL_multi_open = term;

	/* find corresponding closing delimiter */
	if (term && (tmps = strchr("([{< )]}> )]}>",term)))
		termcode = termstr[0] = term = tmps[5];

	PL_multi_close = term;

	{
		STRLEN dummy;
		SvPV_force(sv, dummy);
		sv_setpvs(sv, "");
		SvGROW(sv, 80);
	}

	/* move past delimiter and try to read a complete string */
	if (keep_delims)
		sv_catpvn(sv, s, termlen);
	s += termlen;
	for (;;) {
		if (PL_encoding && !PARSING_UTF) {
			bool cont = TRUE;

			while (cont) {
				int offset = s - SvPVX_const(PL_linestr);
				const bool found = sv_cat_decode(sv, PL_encoding, PL_linestr,
				                                 &offset, (char*)termstr, termlen);
				const char * const ns = SvPVX_const(PL_linestr) + offset;
				char * const svlast = SvEND(sv) - 1;

				for (; s < ns; s++) {
					if (*s == '\n' && !PL_rsfp &&
						IF_HAVE_PERL_5_16(
							!PL_parser->filtered,
							TRUE
						)
					)
						CopLINE_inc(PL_curcop);
				}
				if (!found)
					goto read_more_line;
				else {
					/* handle quoted delimiters */
					if (SvCUR(sv) > 1 && *(svlast-1) == '\\') {
						const char *t;
						for (t = svlast-2; t >= SvPVX_const(sv) && *t == '\\';)
							t--;
						if ((svlast-1 - t) % 2) {
							if (!keep_quoted) {
								*(svlast-1) = term;
								*svlast = '\0';
								SvCUR_set(sv, SvCUR(sv) - 1);
							}
							continue;
						}
					}
					if (PL_multi_open == PL_multi_close) {
						cont = FALSE;
					}
					else {
						const char *t;
						char *w;
						for (t = w = SvPVX(sv)+last_off; t < svlast; w++, t++) {
							/* At here, all closes are "was quoted" one,
							   so we don't check PL_multi_close. */
							if (*t == '\\') {
								if (!keep_quoted && *(t+1) == PL_multi_open)
									t++;
								else
									*w++ = *t++;
							}
							else if (*t == PL_multi_open)
								brackets++;

							*w = *t;
						}
						if (w < t) {
							*w++ = term;
							*w = '\0';
							SvCUR_set(sv, w - SvPVX_const(sv));
						}
						last_off = w - SvPVX(sv);
						if (--brackets <= 0)
							cont = FALSE;
					}
				}
			}
			if (!keep_delims) {
				SvCUR_set(sv, SvCUR(sv) - 1);
				*SvEND(sv) = '\0';
			}
			break;
		}

		/* extend sv if need be */
		SvGROW(sv, SvCUR(sv) + (PL_bufend - s) + 1);
		/* set 'to' to the next character in the sv's string */
		to = SvPVX(sv)+SvCUR(sv);

		/* if open delimiter is the close delimiter read unbridle */
		if (PL_multi_open == PL_multi_close) {
			for (; s < PL_bufend; s++,to++) {
				/* embedded newlines increment the current line number */
				if (*s == '\n' && !PL_rsfp &&
					IF_HAVE_PERL_5_16(
						!PL_parser->filtered,
						1
					)
				)
					CopLINE_inc(PL_curcop);
				/* handle quoted delimiters */
				if (*s == '\\' && s+1 < PL_bufend && term != '\\') {
					if (!keep_quoted && s[1] == term)
						s++;
				/* any other quotes are simply copied straight through */
					else
						*to++ = *s++;
				}
				/* terminate when run out of buffer (the for() condition), or
				   have found the terminator */
				else if (*s == term) {
					if (termlen == 1)
						break;
					if (s+termlen <= PL_bufend && memEQ(s, (char*)termstr, termlen))
						break;
				}
				else if (!has_utf8 && !UTF8_IS_INVARIANT((U8)*s) && PARSING_UTF)
					has_utf8 = TRUE;
				*to = *s;
			}
		}

		/* if the terminator isn't the same as the start character (e.g.,
		   matched brackets), we have to allow more in the quoting, and
		   be prepared for nested brackets.
		*/
		else {
			/* read until we run out of string, or we find the terminator */
			for (; s < PL_bufend; s++,to++) {
				/* embedded newlines increment the line count */
				if (*s == '\n' && !PL_rsfp &&
					IF_HAVE_PERL_5_16(
						!PL_parser->filtered,
						1
					)
				)
					CopLINE_inc(PL_curcop);
				/* backslashes can escape the open or closing characters */
				if (*s == '\\' && s+1 < PL_bufend) {
					if (!keep_quoted &&
						((s[1] == PL_multi_open) || (s[1] == PL_multi_close)))
						s++;
					else
						*to++ = *s++;
				}
				/* allow nested opens and closes */
				else if (*s == PL_multi_close && --brackets <= 0)
					break;
				else if (*s == PL_multi_open)
					brackets++;
				else if (!has_utf8 && !UTF8_IS_INVARIANT((U8)*s) && PARSING_UTF)
					has_utf8 = TRUE;
				*to = *s;
			}
		}
		/* terminate the copied string and update the sv's end-of-string */
		*to = '\0';
		SvCUR_set(sv, to - SvPVX_const(sv));

		/*
		 * this next chunk reads more into the buffer if we're not done yet
		 */

		if (s < PL_bufend)
			break;              /* handle case where we are done yet :-) */

#ifndef PERL_STRICT_CR
		if (to - SvPVX_const(sv) >= 2) {
			if ((to[-2] == '\r' && to[-1] == '\n') ||
			    (to[-2] == '\n' && to[-1] == '\r'))
			{
				to[-2] = '\n';
				to--;
				SvCUR_set(sv, to - SvPVX_const(sv));
			}
			else if (to[-1] == '\r')
				to[-1] = '\n';
		}
		else if (to - SvPVX_const(sv) == 1 && to[-1] == '\r')
			to[-1] = '\n';
#endif

	 read_more_line:
		/* if we're out of file, or a read fails, bail and reset the current
		   line marker so we can report where the unterminated string began
		*/
		CopLINE_inc(PL_curcop);
		PL_bufptr = PL_bufend;
		if (!lex_next_chunk(0)) {
			CopLINE_set(PL_curcop, (line_t)PL_multi_start);
			return NULL;
		}
		s = PL_bufptr;
	}

	/* at this point, we have successfully read the delimited string */

	if (!PL_encoding || PARSING_UTF) {
		if (keep_delims)
			sv_catpvn(sv, s, termlen);
		s += termlen;
	}
	if (has_utf8 || PL_encoding)
		SvUTF8_on(sv);

	PL_multi_end = CopLINE(PL_curcop);

	/* if we allocated too much space, give some back */
	if (SvCUR(sv) + 5 < SvLEN(sv)) {
		SvLEN_set(sv, SvCUR(sv) + 1);
		SvPV_renew(sv, SvLEN(sv));
	}

	PL_bufptr = s;
	return s;
}

static void S_check_prototype(const SV *declarator, SV *proto) {
	bool bad_proto = FALSE;
	bool in_brackets = FALSE;
	char greedy_proto = ' ';
	bool proto_after_greedy_proto = FALSE;
	bool must_be_last = FALSE;
	bool underscore = FALSE;
	bool seen_underscore = FALSE;
	const bool warnillegalproto = ckWARN(WARN_ILLEGALPROTO);
	char *d, *p;
	STRLEN tmp, tmplen;

	/* strip spaces and check for bad characters */
	d = SvPV(proto, tmplen);
	tmp = 0;
	for (p = d; tmplen; tmplen--, ++p) {
		if (!isSPACE(*p)) {
			d[tmp++] = *p;

			if (warnillegalproto) {
				if (must_be_last) {
					proto_after_greedy_proto = TRUE;
				}
				if (!strchr("$@%*;[]&\\_+", *p) || *p == '\0') {
					bad_proto = TRUE;
				} else {
					if (underscore) {
						if (!strchr(";@%", *p)) {
							bad_proto = TRUE;
						}
						underscore = FALSE;
					}
					if (*p == '[') {
						in_brackets = TRUE;
					} else if (*p == ']') {
						in_brackets = FALSE;
					} else if (
						(*p == '@' || *p == '%') &&
						(tmp < 2 || d[tmp - 2] != '\\') &&
						!in_brackets
					) {
						must_be_last = TRUE;
						greedy_proto = *p;
					} else if (*p == '_') {
						underscore = seen_underscore = TRUE;
					}
				}
			}
		}
	}
	d[tmp] = '\0';
	SvCUR_set(proto, tmp);
	if (proto_after_greedy_proto) {
		Perl_warner(aTHX_ packWARN(WARN_ILLEGALPROTO),
			"In %"SVf": prototype after '%c': %s",
			 SVfARG(declarator), greedy_proto, d
		);
	}
	if (bad_proto) {
		SV *dsv = newSVpvs_flags("", SVs_TEMP);
		Perl_warner(aTHX_ packWARN(WARN_ILLEGALPROTO),
			"In %"SVf": illegal character %sin prototype: %s",
			SVfARG(declarator),
			seen_underscore ? "after '_' " : "",
			SvUTF8(proto)
				? sv_uni_display(dsv,
					newSVpvn_flags(d, tmp, SVs_TEMP | SVf_UTF8),
					tmp,
					UNI_DISPLAY_ISPRINT
				)
				: pv_pretty(dsv, d, tmp, 60, NULL, NULL,
					PERL_PV_ESCAPE_NONASCII
				)
		);
	}
	SvCUR_set(proto, tmp);
}

#undef CLINE
/* ^^^^^^^^^^^^^^^^^^^^^ I HAVE NO IDEA WHAT I'M DOING ^^^^^^^^^^^^^^^^^^^^ */
