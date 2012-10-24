# For use with t/error_interruption.t

package BarfyDie;

use strict;
use warnings;

use Function::Parameters qw(:strict);


# This _should_ produce a simple error like the following:
# Global symbol "$foo" requires explicit package name at t/lib/BarfyDie.pm line 13.
$foo = 'hi!';


method foo ($bar)
{
}


1;
