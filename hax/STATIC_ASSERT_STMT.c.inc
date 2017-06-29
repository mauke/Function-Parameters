/* vi: set ft=c inde=: */

#ifndef STATIC_ASSERT_STMT

#if (defined(static_assert) || (defined(__cplusplus) && __cplusplus >= 201103L)) && (!defined(__IBMC__) || __IBMC__ >= 1210)
/* static_assert is a macro defined in <assert.h> in C11 or a compiler
   builtin in C++11.  But IBM XL C V11 does not support _Static_assert, no
   matter what <assert.h> says.
*/
#  define STATIC_ASSERT_DECL(COND) static_assert(COND, #COND)
#else
/* We use a bit-field instead of an array because gcc accepts
   'typedef char x[n]' where n is not a compile-time constant.
   We want to enforce constantness.
*/
#  define STATIC_ASSERT_2(COND, SUFFIX) \
    typedef struct { \
        unsigned int _static_assertion_failed_##SUFFIX : (COND) ? 1 : -1; \
    } _static_assertion_failed_##SUFFIX PERL_UNUSED_DECL
#  define STATIC_ASSERT_1(COND, SUFFIX) STATIC_ASSERT_2(COND, SUFFIX)
#  define STATIC_ASSERT_DECL(COND)    STATIC_ASSERT_1(COND, __LINE__)
#endif
/* We need this wrapper even in C11 because 'case X: static_assert(...);' is an
   error (static_assert is a declaration, and only statements can have labels).
*/
#define STATIC_ASSERT_STMT(COND)      do { STATIC_ASSERT_DECL(COND); } while (0)

#endif
