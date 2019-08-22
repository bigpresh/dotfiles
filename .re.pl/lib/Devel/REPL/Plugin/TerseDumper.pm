package Devel::REPL::Plugin::TerseDumper;

use strict;
use Devel::REPL::Plugin;
use namespace::autoclean;

# Quick hack to use our::way's terse_dumper for more useful responses from our
# stuff - because of our layers of Moose, DBIx::Class, DateTime and voodoo, 
# some objects dumped using Data::Dump etc are horrendously chatty.
#
# our::way::dumper::terse_dumper() uses Data::Dump::Filtered with a filter
# callback which knows how to serialise some of them into concise, useful
# information rather than filling your scrollback with unhelpful spam which 99%
# of the time does nothing but bury the actual useful information you needed. 

if (eval { require our::way::dumper; 1 }) {
    print "OK, our::way::dumper is loaded, use it\n";
    around format_result => sub {
        my ($orig, $self, @to_dump) = @_; 
        use Data::Dump;
        my $out = terse_dumper(@to_dump);
        $self->$orig($out);
    };
} else {
    warn "No our::way::dumper, don't try to use it";
}


1;

