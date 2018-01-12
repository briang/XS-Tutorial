package XS::Tutorial::One;
require XSLoader;

XSLoader::load();
1;

=head1 NAME

XS::Tutorial::One - how to pass to and return basic values from C functions

=head2 Introduction

eXtendable Subroutines (XS) are subroutines written in C that are callable from
Perl code. There are two common reasons you'd want to use XS: there is a C
library you'd like to use with Perl, or you want to make a subroutine faster
by processing it in C instead of Perl.

This tutorial will walk you through all the components needed to get up and
running with a basic XS example. There will be a lot of new terms and concepts:

  If you want to write XS, you have to learn it. Learning XS is very difficult
  Steven W. McDougall

Try not to get discouraged if things don't click right away: I promise you that
learning XS can be hugely rewarding: you'll develop the power to write lightning
fast code; get a better understanding of how Perl internals work, and be able to
integrate any C library you choose and use it from Perl.

=head2 Components

There are three basic components needed to write an xsub. The first is a Perl
module that will provide the namespace for any XS functions. This is all that's
needed:

  package XS::Tutorial::One;
  require XSLoader;

  XSLoader::load();
  1;

This file should be saved as F<lib/XS/Tutorial/One.pm>. C<XSLoader::load> by
default searches for XS code that matches the package name it is called from*.

Let's create a main distribution module too:

  package XS::Tutorial;
  BEGIN { our $VERSION = 0.01 }
  1;

  =encoding utf8

  =head1 NAME

  XS::Tutorial - documentation with examples for learning Perl XS

  =cut

That file should be saved as F<lib/XS/Tutorial.pm>.

The next thing we need is a .xs file which defines the xsubs to be loaded by
C<XS::Tutorial::One>:

  #define PERL_NO_GET_CONTEXT // we'll define thread context if necessary (faster)
  #include "EXTERN.h"         // globals/constant import locations
  #include "perl.h"           // Perl symbols, structures and constants definition
  #include "XSUB.h"           // xsubpp functions and macros
  #include <stdlib.h>         // rand()

  // additional c code goes here

  MODULE = XS::Tutorial::One  PACKAGE = XS::Tutorial::One
  PROTOTYPES: ENABLE

   # XS code goes here

   # XS comments begin with " #" to avoid them being interpreted as pre-processor
   # directives

  unsigned int
  rand()

  void
  srand(seed)
    unsigned int seed

This file should be saved as F<lib/XS/Tutorial/One.xs>. The top half of the file
is pure C code. The line beginning C<MODULE = XS::Tutorial::One> indicates the
start of the XS code. This section will be parsed and compiled into C code by
C<xsubpp>.

The C<MODULE> and C<PACKAGE> directives define the Perl module and package which
will load any xsubs we define. The line C<PROTOTYPES: ENABLE> tells C<xsubpp>
to define subroutine prototypes for any xsubs we create. This is usually what
you want: prototypes can help Perl catch compile time errors.

The last two lines of the file are an xsub:

  unsigned int
  rand()

The first line defines the return type. The second line does two things: it
indicates the name of the C function to be called I<and> it defines the
signature of the xsub.

In this case we're calling C<rand> and accepting no parameters. This isn't
Perl's built-in rand function, I<this> rand comes from stdlib.h.

The final thing we need is a F<Makefile.PL> script - as XS code is compiled, we
need a tool to build it before we can use it:

  use 5.008005;
  use ExtUtils::MakeMaker 7.12; # for XSMULTI option

  WriteMakefile(
    NAME           => 'XS::Tutorial',
    VERSION_FROM   => 'lib/XS/Tutorial.pm',
    PREREQ_PM      => { 'ExtUtils::MakeMaker' => '7.12' },
    ABSTRACT_FROM  => 'lib/XS/Tutorial.pm',
    AUTHOR         => 'David Farrell',
    CCFLAGS        => '-Wall -std=c99',
    OPTIMIZE       => '-O3',
    LICENSE        => 'freebsd',
    XSMULTI        => 1,
  );

The ExtUtils::MakeMaker L<docs|https://metacpan.org/pod/ExtUtils::MakeMaker> explain these options.

But let's talk about C<XSMULTI>. This is a relatively new feature which allows
you to have separate .xs files for modules. By default EUMM assumes the xs
file matches the distribution name. In this case that would mean having a single
Tutorial.xs file, with multiple xs C<MODULE> and C<PACKAGE> declarations in it.
By using C<XSMULTI>, we can have multiple XS files, one for each module in the
distribution instead.

*Actually it searches for compiled C code but the effect is the same.

=head2 Building

Now we should have four files:

  lib/XS/Tutorial.pm
  lib/XS/Tutorial/One.pm
  lib/XS/Tutorial/One.xs
  Makefile.PL

The following commands will build the distribution:

  $ perl Makefile.PL
  $ make

=head2 A minor essay to understand xsubpp generated C

C<make> creates a bunch of files, but take a look at F<lib/XS/Tutorial/One.c>.
This is the output of C<xsubpp>. If you look closely enough, you can find the
lines of C code from F<lib/XS/Tutorial/One.xs> in there. But checkout what
happened to our C<rand> xsub:

  XS_EUPXS(XS_XS__Tutorial__One_rand); /* prototype to pass -Wmissing-prototypes */
  XS_EUPXS(XS_XS__Tutorial__One_rand)
  {
      dVAR; dXSARGS;
      if (items != 0)
         croak_xs_usage(cv,  "");
      {
    unsigned int	RETVAL;
    dXSTARG;

    RETVAL = rand();
    XSprePUSH; PUSHu((UV)RETVAL);
      }
      XSRETURN(1);
  }

C<xsubpp> has replaced our XS code with some rather ugly C macros! These macros
are part of the Perl interpreter's C API. Many are documented in L<perlapi|http://perldoc.perl.org/perlapi.html>
and they are usually defined in C<XSUB.h> or C<perl.h> in the Perl source code.

So what are these macros doing? At a high level, C<dVAR> and C<dXSARGS> setup
the global pointer stack and some local variables. C<items> is a count of the
arguments supplied to the xsub. As C<rand> is a void function, if this isn't
zero, it croaks. C<croak_xs_usage> takes a coderef and an args string. In this
context C<cv> is the xsub, and there are no args so the string is empty.

Next the code declares C<RETVAL>, the return value of the xsub. C<dXTARG>
initializes the C<TARG> pointer. Next C<rand()> is called its return value
assigned to C<RETVAL>. C<XSprePUSH> moves the stack pointer back one,
and C<PUSHu> copies C<RETVAL> into C<TARG> and pushes it onto the global stack
pointer. C<XSRETURN> returns from the xsub, indicating how many arguments it
added to the stack, which in this case, is one.

Writing XS, you usually don't need to study the generated C code, but it's
helpful to have an awareness of the process.

=head2 Installing

Now the code is compiled, install it with:

  $ make install

If you're using system Perl, you may need to use C<sudo> to install. Now we can
test the module using a one liner:

  $ perl -MXS::Tutorial::One -E 'say XS::Tutorial::One::rand()'
  1804289383

It works! Did you try running it twice though?

  $ perl -MXS::Tutorial::One -E 'say XS::Tutorial::One::rand()'
  1804289383

We get the same pseudorandom sequence each time... We need to call C<srand> to
seed the sequence. That function is already provided by C<stdlib.h>, so all we
need to do is append the following text to F<lib/XS/Tutorial/One.xs>:

  void
  srand(seed)
    unsigned int seed

This xsub is different to the first one: its return type is C<void> which
means it returns nothing. It also includes a parameter called C<seed> in its
signature, and the last line defines it as an unsigned int.

Rebuild and install the distribution:

  $ make && make install

Now we can seed the pseudorandom sequence by calling C<srand> before C<rand>:

  $ perl -MXS::Tutorial::One -E 'XS::Tutorial::One::srand(777);\
  say XS::Tutorial::One::rand()'
  947371799

We used a lucky (777) seed number, and C<rand> emitted a different number, yay!

=head2 Did we beat Perl?

As you know by now, xsubs are often faster than pure Perl code. We've built two
xsubs for C<rand> and C<srand>, which are also available as built-in functions
in Perl. Do you think the xsubs are faster? Here's a benchmark from my machine:

                Rate xs_rand bi_rand
  xs_rand 15691577/s      --    -64%
  bi_rand 43095739/s    175%      --

Oh no! Despite our C<rand> xsub directly calling the C C<stdlib> function, it's
miles slower than Perl's built-in C<rand>. This isn't because xsubs are slow,
rather that Perl's built-in functions are really fast.

=head2 Tests

Instead of running one liners to check our code works, we can write unit tests.
Here's a basic script:

  #!/usr/bin/perl
  use Test::More;

  BEGIN { use_ok 'XS::Tutorial::One' }

  ok my $rand = XS::Tutorial::One::rand(), 'rand()';
  like $rand, qr/^\d+$/, 'rand() returns a number';

  ok !defined XS::Tutorial::One::srand(5), 'srand()';
  ok $rand ne XS::Tutorial::One::rand(), 'after srand, rand returns different number';
  done_testing;

Save this file as F<t/one.t>. Assuming you built and installed the distribution
already, you can just do:

  $ perl t/one.t
  ok 1 - use XS::Tutorial::One;
  ok 2 - rand()
  ok 3 - rand() returns a number
  ok 4 - srand()
  ok 5 - after srand, rand returns different number
  1..5

Now when building the distribution in the future, you should do:

  $ perl Makefile.PL && make && make test

This will rebuild and test the distribution. Because XS code is compiled,
writing tests and using that one liner, you can quickly cycle through coding
and testing.

Don't forget to add Test::More to the C<PREREQ_PM> entry in F<Makefile.PL>. When
you don't have a specific minimum version, you can just use 0:

  PREREQ_PM => { 'Test::More' => 0, 'ExtUtils::MakeMaker' => '7.12' },

=head2 Cleanup

Building distributions generates a lot of temporary files. ExtUtils::MakeMaker
provides a clean routine:

  $ make clean

This will delete all the build files and reset the working directory to normal.

=head2 References

=over 4

=item * XS Mechanics by Steven W. McDougall is my second favorite :) XS L<tutorial|http://world.std.com/~swmcd/steven/perl/pm/xs/intro/>

=item * L<perlxs|http://perldoc.perl.org/perlxs.html> defines the keywords recognized by L<xsubpp|https://metacpan.org/pod/distribution/ExtUtils-ParseXS/lib/ExtUtils/xsubpp>

=item * L<perlapi|http://perldoc.perl.org/perlapi.html> : C macros used to interact with Perl data structures (and the interpreter)

=item * The L<stdlib.h|http://pubs.opengroup.org/onlinepubs/9699919799/> man page defines the C standard library functions and types

=item * For writing Makefile.PL files: ExtUtils::MakeMaker L<docs|https://metacpan.org/pod/ExtUtils::MakeMaker> are invaluable

=item * Perl's built-in L<rand|http://perldoc.perl.org/functions/rand.html> and <srand|http://perldoc.perl.org/functions/srand.html> functions

=back

=cut
