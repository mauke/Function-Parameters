use warnings;
use strict;

use Test::More;

use Function::Parameters;

fun actual_location_of_line_with($marker) {
	seek DATA, 0, 0 or die "seek DATA: $!";
	my $loc = 0;
	while (my $line = readline DATA) {
		$loc++;
		index($line, $marker) >= 0
			and return $loc;
	}
	undef
}

fun test_loc($marker) {
	my $expected = actual_location_of_line_with $marker;
	defined $expected or die "$marker: something done fucked up";
	my $got = (caller)[2];
	is $got, $expected, "location of '$marker'";
}

sub {
	test_loc 'LT torture begin.';
	use integer;
	my $r = shift;

	my $a = shift;
	my $b = shift;

	test_loc 'LT torture A.';
	@_ = (
		sub {
			my $f = shift;
			test_loc 'LT torture B.';
			@_ = (
				sub {
					my $f = shift;
					test_loc 'LT torture C.';
					@_ = (
						sub {
							my $f = shift;
							test_loc 'LT torture D.';
							@_ = (
								sub {
									my $n = shift;
									test_loc 'LT torture end.';
									@_ = $n;
									goto &$r;
								},
								$b
							);
							goto &$f;
						},
						$a
					);
					goto &$f;
				},
				sub {
					my $r = shift;
					my $f = shift;
					@_ = sub {
						my $r = shift;
						my $x = shift;
						@_ = sub {
							my $r = shift;
							my $y = shift;
							test_loc 'LT torture body.';
							if ($x && $y) {
								@_ = (
									sub {
										my $f = shift;
										@_ = ($r, ($x & $y) << 1);
										goto &$f;
									},
									$x ^ $y
								);
								goto &$f;
							}
							@_ = $x ^ $y;
							goto &$r;
						};
						goto &$r;
					};
					goto &$r;
				}
			);
			goto &$f;
		},
		sub {
			my $r = shift;
			my $y = shift;
			@_ = sub {
				my $r = shift;
				my $f = shift;
				@_ = sub {
					my $r = shift;
					my $x = shift;
					@_ = (
						sub {
							my $f = shift;
							@_ = ($r, $x);
							goto &$f;
						},
						sub {
							my $r = shift;
							my $x = shift;
							@_ = (
								sub {
									my $g = shift;
									@_ = (
										sub {
											my $f = shift;
											@_ = ($r, $x);
											goto &$f;
										},
										$f
									);
									goto &$g;
								},
								$y
							);
							goto &$y;
						}
					);
					goto &$f;
				};
				goto &$r;
			};
			goto &$r;
		}
	);

	goto & {
		sub {
			my $r = shift;
			my $f = shift;
			test_loc 'LT torture boot.';
			@_ = ($r, $f);
			goto &$f;
		}
	};

}->(sub { my $n = shift; is $n, 2, '1 + 1 = 2' }, 1, 1);

{
	#local $TODO = 'line numbers all fucked up';

	fun ($r, $a, $b) {
		test_loc 'LX torture begin.';
		use integer;
		test_loc 'LX torture A.';
		@_ = ( do { test_loc 'LX torture A-post.'; () },
			do { test_loc 'LX torture B-pre.'; () }, fun ($f) { test_loc 'LX torture B-pre.';
				test_loc 'LX torture B.';
				@_ = (
					fun ($f) {
						test_loc 'LX torture C.';
						@_ = (
							fun ($f) {
								test_loc 'LX torture D.';
								@_ = (
									fun ($n) {
										test_loc 'LX torture end.';
										@_ = $n;
										goto &$r;
									},
									$b
								);
								goto &$f;
							},
							$a
						);
						goto &$f;
					},
					fun ($r, $f) {
						@_ = fun ($r, $x) {
							@_ = fun ($r, $y) {
								test_loc 'LX torture body.';
								if ($x && $y) {
									@_ = (
										fun ($f) {
											@_ = ($r, ($x & $y) << 1);
											goto &$f;
										},
										$x ^ $y
									);
									goto &$f;
								}
								@_ = $x ^ $y;
								goto &$r;
							};
							goto &$r;
						};
						goto &$r;
					}
				);
				goto &$f;
			},
			fun ($r, $y) {
				@_ = fun ($r, $f) {
					@_ = fun ($r, $x) {
						@_ = (
							fun ($f) {
								@_ = ($r, $x);
								goto &$f;
							},
							fun ($r, $x) {
								@_ = (
									fun ($g) {
										@_ = (
											fun ($f) {
												@_ = ($r, $x);
												goto &$f;
											},
											$f
										);
										goto &$g;
									},
									$y
								);
								goto &$y;
							}
						);
						goto &$f;
					};
					goto &$r;
				};
				goto &$r;
			}
		);

		goto & {
			fun ($r, $f) {
				test_loc 'LX torture boot.';
				@_ = ($r, $f);
				goto &$f;
			}
		};

	}->(fun ($n) { is $n, 2, '1 + 1 = 2' }, 1, 1);

}

done_testing;
__DATA__
