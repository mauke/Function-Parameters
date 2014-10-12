/* vi: set ft=c inde=: */

#ifndef pad_findmy_pvs

#if HAVE_PERL_VERSION(5, 16, 0)
#error "This situation surprises me considerably."
#endif

#define pad_findmy_pvs(NAME, FLAGS) pad_findmy("" NAME "", sizeof NAME - 1, FLAGS)

#endif
