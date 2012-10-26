
#define DEFSTRUCT(T) typedef struct T T; struct T

DEFSTRUCT(ParamInit) {
	SV *name;
	OP *init;
};

#define DEFVECTOR(T, B) DEFSTRUCT(T) { \
	B (*data); \
	size_t used, size; \
}

DEFVECTOR(ParamInitVec, ParamInit);
DEFVECTOR(ParamVec, SV *);

DEFSTRUCT(ParamSpec) {
	SV *invocant;
	ParamVec positional_required;
	ParamInitVec positional_optional;
	ParamVec named_required;
	ParamInitVec named_optional;
	SV *slurpy;
};

#define DEFVECTOR_CLEAR(T, N, F) static void N(T *p) { \
	while (p->used) { \
		p->used--; \
		F(p->data[p->used]); \
	} \
	Safefree(p->data); \
	p->data =NULL; \
	p->size = 0; \
} static void N(T *)

static void pi_clear(ParamInit pi) {
	if (pi.name) {
		SvREFCNT_dec(pi.name);
	}
	if (pi.init) {
		op_free(pi.init);
	}
}

DEFVECTOR_CLEAR(ParamVec, pv_clear, SvREFCNT_dec);
DEFVECTOR_CLEAR(ParamInitVec, piv_clear, pi_clear);

static void ps_free(ParamSpec *ps) {
	if (ps->invocant) {
		SvREFCNT_dec(ps->invocant);
		ps->invocant = NULL;
	}
	pv_clear(&ps->positional_required);
	piv_clear(&ps->positional_optional);
	pv_clear(&ps->named_required);
	piv_clear(&ps->named_optional);
	if (ps->slurpy) {
		SvREFCNT_dec(ps->slurpy);
		ps->slurpy = NULL;
	}
	Safefree(ps);
}

static int args_min(const ParamSpec *ps) {
	int n = 0;
	if (ps->invocant) {
		n++;
	}
	n += ps->positional_required.used;
	n += ps->named_required.used * 2;
	return n;
}

static int args_max(const ParamSpec *ps) {
	int n = 0;
	if (ps->invocant) {
		n++;
	}
	n += ps->positional_required.used;
	n += ps->positional_optional.used;
	if (ps->named_required.used || ps->named_optional.used || ps->slurpy) {
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

static void gen(ParamSpec *ps) {
	int amin = args_min(ps);
	if (amin > 0) {
		printf("croak 'not enough' if @_ < %d;\n", amin);
	}
	int amax = args_max(ps);
	if (amax >= 0) {
		printf("croak 'too many' if @_ > %d;\n", amax);
	}
	size_t named_params = count_named_params(ps);
	if (named_params || (ps->slurpy && SvPV_nolen(ps->slurpy)[0] == '%')) {
		size_t t = named_params + !!ps->invocant;
		printf("croak 'odd' if (@_ - %zu) > 0 && (@_ - %zu) % 2;\n", t, t);
	}
	if (ps->invocant) {
		printf("%s = shift @_;\n", SvPV_nolen(ps->invocant));
	}
	// XXX (...) = @_;
	size_t positional_params = count_positional_params(ps);
	for (size_t i = 0; i < ps->positional_optional.used; i++) {
		printf("%*sif (@_ < %zu) {\n", (int)i * 2, "", positional_params - i);
	}
	for (size_t i = 0; i < ps->positional_optional.used; i++) {
		ParamInit *pi = &ps->positional_optional.data[i];
		printf("%*s  %s = %p;\n", (int)(ps->positional_optional.used - i - 1) * 2, "", SvPV_nolen(pi->name), pi->init);
		printf("%*s}\n", (int)(ps->positional_optional.used - i - 1) * 2, "");
	}
	if (named_params) {
		printf("if (@_ > %zu) {\n", positional_params);
		printf("  my $_b = '';\n");
		printf("  my $_i = %zu;\n", positional_params);
		printf("  while ($_i < @_) {\n");
		printf("    my $_k = $_[$_i];\n");
		size_t req = ps->named_required.used;
		for (size_t i = 0; i < named_params; i++) {
			printf("    ");
			if (i) {
				printf("els");
			}
			SV *param = i >= req ? ps->named_optional.data[i - req] : ps->named_required.data[i];
			printf("if ($_k eq '%s') {\n", SvPV_nolen(param) + 1);
			printf("      %s = $_[$_i + 1];\n", SvPV_nolen(param));
			printf("      vec($_b, %zu, 1) = 1;\n", i);
			printf("    }\n");
		}
		printf("    else {\n");
		if (ps->slurpy) {
			const char *slurpy = SvPV_nolen(ps->slurpy);
			if (slurpy[0] == '%') {
				printf("      $%s{$_k} = $_[$_i + 1];\n", slurpy + 1);
			} else {
				printf("      push %s, $_k, $_[$_i + 1];\n", slurpy);
			}
		} else {
			printf("      croak 'no such param ' . $_k;\n");
		}
		printf("    }\n");
		printf("    $_i += 2;\n");
		printf("  }\n");
		if (ps->named_required.used) {
			printf("  if (($_b & pack('b*', '1' x %zu)) ne pack('b*', '1' x %zu)) {\n", ps->named_required.used, ps->named_required.used);
			printf("    croak 'missing required named args';\n"); // XXX
			printf("  }\n");
		}
		for (size_t i = 0; i < ps->named_optional.used; i++) {
			printf("  %s = %p unless vec $_k, %zu, 1;\n", SvPV_nolen(ps->named_optional[i].name), ps->named_optional[i].init, ps->named_required.used + i);
		}
		printf("}\n");
	}
}
