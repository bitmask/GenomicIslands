use strict;
use warnings;

use Bio::GenomicIslands;
use Getopt::Long;
use Data::Dumper;

sub usage() {
    print STDERR "usage:  $0 -core=file\n";
    exit 1;
}

my $corefile = "";
GetOptions( "core=s" => \$corefile );
usage() if $corefile eq "";

my $Galapagos = Bio::GenomicIslands->new();
$Galapagos->{min_gap_between_genes} = 0;
$Galapagos->{max_gap_between_genes} = 2000;
$Galapagos->{extreme_gap} = 100000;
$Galapagos->{allowed_gap_violations} = 1;
$Galapagos->{min_island_length} = 10;
$Galapagos->{max_island_length} = 250;
$Galapagos->{debug} = 0;
$Galapagos->parse_corefile($corefile);
$Galapagos->_find_islands_in_genomes();
$Galapagos->print_possible_islands('Vibrio cholerae O395 chromosome II, complete sequence.');

