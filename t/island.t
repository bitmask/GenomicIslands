
use strict;
use warnings;
use Test::More tests => 14;

BEGIN { use_ok( 'Bio::GenomicIslands' ); }
require_ok( 'Bio::GenomicIslands' );

my $testpath = "t/";
my $corefile_minimal = "test-minimal.core";
my $corefile_island = "test-island.core";
my $corefile_cross = "test-crossgenome.core";

my $Limfjorden = new_ok('Bio::GenomicIslands');
$Limfjorden->{debug} = 1;
is($Limfjorden->parse_corefile($testpath . $corefile_minimal), 1, 'Parse minimal core file');
is($Limfjorden->count_genomes(), 1, 'Correct number of genomes were added');
ok(exists $Limfjorden->{genes}->{'Vibrio cholerae LMA3894-4 chromosome I, complete sequence.'}, 'Correct genome name was added');
is(@{$Limfjorden->{genes}->{'Vibrio cholerae LMA3894-4 chromosome I, complete sequence.'}}, 2, 'Correct number of genes were added');
$Limfjorden->print_genomes();

my $Haida_Gwaii = new_ok('Bio::GenomicIslands');
$Haida_Gwaii->{min_gap_between_genes} = 0;
$Haida_Gwaii->{max_gap_between_genes} = 2000;
$Haida_Gwaii->{extreme_gap} = 10000;
$Haida_Gwaii->{allowed_gap_violations} = 1;
$Haida_Gwaii->{min_island_length} = 3;
$Haida_Gwaii->{max_island_length} = 5;
$Haida_Gwaii->{debug} = 1;
is($Haida_Gwaii->parse_corefile($testpath . $corefile_island), 1, 'Parse more realistic core file');
is($Haida_Gwaii->_find_islands_in_genomes(), 8, 'Find correct number of islands in one genome');
$Haida_Gwaii->_print_possible_islands();

my $San_Juan = new_ok('Bio::GenomicIslands');
$San_Juan->{min_gap_between_genes} = 0;
$San_Juan->{max_gap_between_genes} = 2000;
$San_Juan->{extreme_gap} = 10000;
$San_Juan->{allowed_gap_violations} = 1;
$San_Juan->{min_island_length} = 3;
$San_Juan->{max_island_length} = 5;
$San_Juan->{slack_missing_genomes} = 1;
$San_Juan->{debug} = 1;
is($San_Juan->parse_corefile($testpath . $corefile_cross), 1, 'Parse core file for cross genome comparison');
is($San_Juan->_find_islands_in_genomes(), 5, 'Find correct number of islands in genomes');
is($San_Juan->_find_islands_cross_genomes(), 1, 'Find correct number of islands cross genomes');

# Faroe
# Sakhalin
# Aegean
# Aeolian
