use strict;
use warnings;
use utf8;
binmode STDOUT, ':encoding(UTF-8)';

for my $row (1 .. 9) {
    for my $column (1 .. $row) {
        printf "%d×%d=%2d\t", $column, $row, $column * $row;
    }
    print "\n";
}
