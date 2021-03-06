package Bio::GenomicIslands;
require Exporter;
@ISA = qw(Exporter);
@EXPORT_OK = qw(parse_corefile find_islands);
use strict;
use warnings;

use Data::Dumper;


# Known Bugs
# 
# if an island crosses the origin of replication, we will not find it



sub new {
    my $class = shift;
    my $self = { 
        genes => {},                    # hash keyed on genome name; each value is an array of genes in the genome
        islands => {},                  # hash keyed on stringified arrays of islands; each value is a set of genomes
        possible_islands => {},         # hash keyed on genome, each value is an array of possible islands in the genome
        min_gap_between_genes => 0,     # allow a gap between genes in one genomic island
        max_gap_between_genes => 1000,  # ... it can be at most this long
        extreme_gap => 10000,           # a gap of this large can never be within a genome island
        allowed_gap_violations => 1,    # number of times we allow the gap length to exceed the max in a genomic island
        min_island_length =>  10000,    # if a string of genes is too short, it is not an island
        max_island_length => 250000,    # ... likewise if it is too long
        slack_missing_genomes => 1,     # allow the island to be missing in this many genomes
        debug => 0,
                                        # private
        current_island => [],           # temp island we're working on
        current_gap_violations => 0,    # temp number of gap violations
        current_genome => "",           # temp genome name we are processing
    };
    bless $self, $class;
    return $self; 
}

sub count_genomes {
    my ($self) = @_;
    return length(keys %{$self->{genes}});
}

sub add_gene {
    my ($self, $gene, $genome_name) = @_;
    push @{$self->{genes}->{$genome_name}}, $gene;
}

sub print_genomes {
    my ($self) = @_;
    print $self->count_genomes() . " GENOMES\n";
    print "-------\n";
    foreach my $genome_name ( keys %{$self->{genes}}) {
        my $gene_count = @{$self->{genes}->{$genome_name}};
        print "$gene_count genes in $genome_name\n";
        foreach my $gene (@{$self->{genes}->{$genome_name}}) {
            print "\t" . $gene->{profile} . " " . $gene->{start_pos} . " " . $gene->{end_pos} . "\n";
        }
    }
    print "-------\n";
}

sub print_possible_islands {
    my ($self, $genome) = @_;
    print "POSSIBLE ISLANDS\n";
    foreach my $genome_name (keys %{$self->{possible_islands}}) {
        if ($genome) {
            if ($genome_name eq $genome) {
                print "For $genome\n";
                foreach my $island (@{$self->{possible_islands}->{$genome}}) {
                    print "-" x 30 . "ISLAND" . "-" x 30 . "\n";
                    foreach my $gene (@$island) {
                        my $pad_length = 40;
                        my $print_profile = sprintf("%${pad_length}s", $gene->{profile});
                        print $print_profile . "\t" . $gene->{start_pos} . " to " . $gene->{end_pos} . "\n";
                    }
                }
            }
        }
        #print "$genome_name\n";
        #my $acc = 0;
        #foreach my $island ($self->{possible_islands}->{$genome_name}) {
        #    $acc++;
        #    print "ISLAND\n";
        #    foreach my $profile (@{$island}) {
        #        print "@{$profile}\n";
        #    }
        #}
    }
}

sub min {
    my ($one, $two) = @_;
    ($one < $two) ? return $one : return $two;
}

sub max {
    my ($one, $two) = @_;
    ($one > $two) ? return $one : return $two;
}

sub parse_corefile {
    my ($self, $corefile) = @_;
    print "parsing corefile: $corefile\n";
    open FH, $corefile or die "$!\n";
    while (<FH>) {
        chomp;
        my $line = $_;
        next if $line eq "#" or $line eq "";
        if ($line =~ /^>([A-Z0-9._]+) ID=".*CDS_([0-9]+)-([0-9]+)".*Description="(.*)" PID=".*/) {
            my $profile = $1;
            my $start_pos = min($2, $3);
            my $end_pos = max($2, $3);
            my $genome_name = $4;
            if ($profile ne "" and $start_pos ne "" and $end_pos ne "" and $genome_name ne "") {
                print "profile: $profile start: $start_pos end: $end_pos genome: $genome_name\n" if $self->{debug};
                my $gene = {
                    start_pos => $start_pos,
                    end_pos => $end_pos,
                    profile => $profile,
                };
                $self->add_gene($gene, $genome_name);
            }
            else {
                print STDERR "line did not match expected pattern:\n";
                print STDERR $line . "\n";
                return 0;
            }
        }
    }
    close FH;
    return 1;
}

sub _calculate_gap {
    # find the gap size between two genes
    my ($self, $end_prev_gene, $gene) = @_;
    my $gap;
    if (defined($end_prev_gene)) {
        $gap = $gene->{start_pos} - $end_prev_gene;
    }
    else {
        $gap = 0;  # if this is the first gene in the genome, then there is no gap
    }
    return $gap;
}

sub _gap_violations_exceeded {
    # will adding the gene following this gap mean we have exceeded any of the gap violation rules?
    my ($self, $gap) = @_;
    if ( $self->{min_gap_between_genes} <= $gap and $gap <= $self->{max_gap_between_genes} ) {
        return 0;
    }
    elsif ( $gap > $self->{extreme_gap} ) {
        print "hit extreme gap, ending island\n";
        return 1;
    }
    else {
        $self->{current_gap_violations}++;
        #print "incrementing current gap violations to " . $self->{current_gap_violations} . "\n";
        if ($self->{current_gap_violations} > $self->{allowed_gap_violations}) {
            return 1;
        }
        else {
            return 0;
        }
    }

}

sub _record_island {
    # copy this island into the set of possible islands for this genome
    my ($self) = @_;
    my $genome = $self->{current_genome};
    print "keeping this one for further examination @{$self->{current_island}}\n" if $self->{debug};
    push @{$self->{possible_islands}->{$genome}}, \@{$self->{current_island}}; 
}

sub _reset_island {
    # begin a new possible island
    my ($self) = @_;
    $self->{current_island} = [];
    $self->{current_gap_violations} = 0;
}

sub _island_big_enough {
    my ($self) = @_;
    my $size = @{$self->{current_island}};
    return $size >= $self->{min_island_length};
}

sub _island_too_big {
    my ($self) = @_;
    my $size = @{$self->{current_island}};
    return $size > $self->{max_island_length};
}

sub _add_current_island {
    # add this gene to the current possible island
    my ($self, $gene) = @_;
    push @{$self->{current_island}}, $gene;
}

sub _find_islands_in_genome {
    my ($self) = @_;

    my $end_prev_gene;
    my $gap_violations = 0;   #number of times the max_gap rule has been exceeded
    my $genome = $self->{current_genome};

    #sort genes on start position, then on end position since they do not come sorted
    foreach my $gene ( sort { ($a->{start_pos} <=> $b->{start_pos}) || ($a->{end_pos} <=> $b->{end_pos}) } @{$self->{genes}->{$genome}} ) {
        #print "\t protein: $gene->{profile} : $gene->{start_pos} - $gene->{end_pos}\n" if $self->{debug};

        my $gap = $self->_calculate_gap($end_prev_gene, $gene);
        if ($self->_gap_violations_exceeded($gap)) {
            #print "gap violations exceeded\n";
            $self->_record_island() if $self->_island_big_enough();
            $self->_reset_island();
        }

        $self->_add_current_island($gene);

        if ($self->_island_too_big()) {
            #print "island too big\n";
            $self->_reset_island();
        }
        #print "island is now: @{$self->{current_island}} \n";
        $end_prev_gene = $gene->{end_pos};
    }
    $self->_record_island() if $self->_island_big_enough();
    $self->_reset_island();
    if (defined $self->{possible_islands}->{$genome}) {
        return @{$self->{possible_islands}->{$genome}};
    }
    else {
        print "no possible islands found for $genome\n";
    }
}

sub _find_islands_in_genomes {
    my ($self) = @_;
    my $total_possible_island_count = 0;
    foreach my $genome (keys %{$self->{genes}}) {
        print "genome: $genome\n" if $self->{debug};
        $self->{current_genome} = $genome;
        $total_possible_island_count += $self->_find_islands_in_genome();
    }
    return $total_possible_island_count;
}


sub _print_possible_islands() {
    my ($self) = @_;
    foreach my $genome (keys %{$self->{possible_islands}}) {
        foreach my $island (@{$self->{possible_islands}->{$genome}}) {
            print "Island: \n";
            foreach my $profile (@{$island}) {
                print " $profile ";
            }
            print "\n";
        }
    }
}

sub islands_equal {
    my ($self, $island1, $island2) = @_;
    my @i1 = @$island1;
    my @i2 = @$island2;
    if ($#i1 != $#i2) {
        return 0;
    }
    foreach my $idx (0 .. $#i1) {
        my $e1 = $i1[$idx]->{profile};
        my $e2 = $i2[$idx]->{profile};
        # TODO this is where to add jitter
        unless ($e1 eq $e2) {
            #print "notsame\n";
            return 0;
        }
    }
    #print "same\n";
    return 1;
}

sub get_genome_count {
    my ($self) = @_;
    return scalar keys %{$self->{genes}};
}

sub _make_string {
    my ($array) = @_;
    my @ap;
    foreach my $a (@$array) {
        push @ap, $a->{'profile'};
    }
    return join "-", @ap;
}

sub _split_key {
    my ($key) = @_;
    return split /-/, $key;
}

sub _exclude {
    my ($exclude, @array) = @_;
    if ($exclude == 0) {
        my @slice = @array[$exclude+1 .. $#array];
        #print "EXCLUDE $exclude\n";
        #print Dumper(\@slice);
        return @slice;
    }
    elsif ($exclude == $#array) {
        my @slice =  @array[0 .. $exclude-1];
        #print "EXCLUDE $exclude\n";
        #print Dumper(\@slice);
        return @slice;
    }
    elsif ($exclude < 0 or $exclude > $#array) {
        print "index to exclude is out of bounds\n";
        return ();
    }
    else {
        my @slice = @array[0 .. $exclude-1];
        push @slice, @array[$exclude+1 .. $#array];
        #print "EXCLUDE $exclude\n";
        #print Dumper(\@slice);
        return @slice;
    }
}

sub _in_island {
    my ($self, $genome, $key) = @_;
    return exists $self->{islands}->{$key}->{$genome};
}

sub _add_to_island {
    my ($self, $genome, $key, $island) = @_;
    $self->{islands}->{$key}->{$genome} = $island;
}

sub _add_to_islands_list {
    my ($self, $island, $genome) = @_;
    my $key = _make_string($island);
    #unless ($self->_in_island($genome, $key)) {
        $self->_add_to_island($genome, $key, $island);
    #}
}


sub _find_islands_cross_genomes {
    my ($self) = @_;
    
    # this is slow and brute force
    print "now comparing possible islands across genomes\n";

    # we are going to take each genome as the reference
    foreach my $reference_genome (sort keys %{$self->{possible_islands}}) {
        print "reference genome is: $reference_genome\n";
        foreach my $island (@{$self->{possible_islands}->{$reference_genome}}) {
            $self->_add_to_islands_list($island, $reference_genome);

            # then, we'll look at every island in every other genome and see if minus a profile it it matches any of the reference islands
            foreach my $test_genome (sort keys %{$self->{possible_islands}}) {
                next if $test_genome eq $reference_genome;
                #print "\tchecking against $test_genome\n";
                foreach my $test_island (@{$self->{possible_islands}->{$test_genome}}) {
                    foreach my $ri (@{$self->{possible_islands}->{$reference_genome}}) {
                        if ($self->islands_equal($test_island, $ri)) {
                            $self->_add_to_islands_list($ri, $test_genome);
                            #print "\t\t Islands equal\n";
                        }
                        else {
                            #print "\t\t Islands different\n";
                            my @length = @$test_island;
                            foreach my $idx (0 .. $#length) {
                                #print "idx: $idx\n";
                                my @test_island_trimmed = _exclude($idx, @$test_island);
                                #print "trimmed test island: " . Dumper(\@test_island_trimmed);
                                #print "reference island: " . Dumper(\@reference_island);
                                if ($self->islands_equal(\@test_island_trimmed, $ri)) {
                                    #print "equal\n";
                                    $self->_add_to_islands_list(\@test_island_trimmed, $test_genome);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    print Dumper($self->{islands});
}







sub report_found_islands() {
    my ($self) = @_;

    # return the islands we've found if they occur in at least all the genomes - slack_missing_genomes
    print "found islands:\n";
    my $count = 0;
    foreach my $isle (keys %{$self->{islands}}) {
        print "checking $isle\n";
        if (scalar keys %{$self->{islands}->{$isle}} >= $self->get_genome_count() - $self->{slack_missing_genomes}) {
            print "this one is ok: $isle\n";
            $count++;
        }
    }
    print "final islands:\n";
    print Dumper($self->{islands});
    return $count;
}

sub find_islands {
    my ($self) = @_;

    # this must be called after parse_corefile
    unless ($self->count_genomes() > 0) {
        return 0;
    }

    # we are going to make a list of possible islands in each genome
    $self->_find_islands_in_genomes();
    #$self->_find_islands_cross_genomes();
    #return $self->report_found_islands();
}

sub get_islands {
    my ($self, $lack) = @_;
    # return islands that have all but $lack genomes
}


1;
