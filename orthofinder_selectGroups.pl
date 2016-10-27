#!/usr/bin/env perl

## author: reubwn October 2016

use strict;
use warnings;

use Bio::Seq;
use Bio::SeqIO;
use Getopt::Long;
use Sort::Naturally;
use File::Path 'rmtree';

my $usage = "
SYNOPSIS:
Parses Orthofinder output file \"OrthologousGroups.txt\" for groups corresponding to input criteria.
Construct the 'select' string like so: \"ID1=X,ID2=Y,IDN=Z\", where ID1 is the unique species ID
corresponding to the entity on the lefthandside of the delimiter given by -d (default is '|'), and
X is the number of members from species 1 you want to select groups containing.

OUTPUTS:
A file \"selectGroups_output.groups.txt\" with only selected groups written, and a directory \"selectGroups_outputDir/\"
with fasta files containing sequence data of selected groups.

OPTIONS:
  -i|--in     [FILE] : OrthologousGroups.txt file [required]
  -f|--fasta  [FILE] : path to directory of fasta files used to construct OrthologousGroups.txt [required]
  -d|--delim  [STR]  : delimiter used in the protein naming structure [assumes an OrthoMCL-style schema of \"SPECIES_ID|PROTEIN_ID\"]
  -s|--select [STR]  : select string, eg. \"ID1=1,ID2=1,IDN=1\" would return 1:1 orthologous groups
  -n|--noseqs        : Don't print sequences; just count the groups
  -o|--out    [STR]  : output prefix [default: selectGroups_output]
  -h|--help          : prints this help message

EXAMPLES:
Select ONLY those groups where species ARIC and AVAG have 4 members each, and species RMAG and RMAC have 2 members each:
  >> ./orthofinder_selectGroups.pl -i OrthologousGroups.txt -f fastas/ -s \"ARIC=4,AVAG=4,RMAG=2,RMAC=2\"
\n";

my ($in,$fastas,$select,$noseqsplease,$out,$help);
my $prefix = "selectGroups_output";
my $delim = "|";

GetOptions (
  'in|i=s'     => \$in,
  'fastas|f=s' => \$fastas,
  'delim|d:s'  => \$delim,
  'select|s=s' => \$select,
  'noseqs|n'   => \$noseqsplease, ## :-)
  'out|o:s'    => \$prefix,
  'help|h'     => \$help,
);

die $usage if $help;
die $usage unless ($in && $fastas && $select);

## construct outfiles
open (my $GROUPS, ">".$prefix."Groups.txt") or die "$!\n";

## parse select string
my %select_hash;
my @a = split(",",$select);
foreach (@a){
  my @b = split("=",$_);
  $select_hash{$b[0]} = $b[1]; ## key= SPECIES_ID; value= PER_SPECIES_GROUP_SIZE
}

print "Select per-species group sizes:\n";
foreach (nsort keys %select_hash){
  print "  $_\t$select_hash{$_}\n";
}
print "\n";

## get sequences
my %seq_hash;
unless ($noseqsplease){ ## skip if just counting
  my @fastas = glob("$fastas*fasta");
  print "Reading sequences from:\n";
  foreach (@fastas){
    print "  $_\n";
    my $in = Bio::SeqIO->new ( -file => $_, -format => "fasta" );
    while ( my $seq_obj = $in->next_seq() ){
      $seq_hash{($seq_obj->display_id())} = ($seq_obj->seq());
    }
  }
  print "Read in ".commify(scalar(keys %seq_hash))." sequences from ".commify(scalar(@fastas))." files\n\n";
} else {
  print "Skipping fetching sequences, just counting\n";
}

## parse OrthologousGroups.txt
my %groups_hash;
open(my $IN, $in) or die "$!\n";
while (my $line = <$IN>){
  chomp $line;
  my @a = split(/\:\s+/,$line);
  my @b = split(/\s+/,$a[1]);
  my %g;
  foreach (@b){
    my @c = split(/\|/,$_);
    $g{$c[0]}++; ##count per-species membership for group
  }
  my $flags = 0;
  foreach (nsort keys %g){
    ## if the group contains the SPECIES_ID of interest and has the specified number of members
    if (($select_hash{$_}) && ($g{$_} == $select_hash{$_})) {
      $flags++;
    }
    ## only print if all SPECIES_ID criteria are met
    if ($flags == scalar(keys %select_hash)) {
      $groups_hash{$a[0]} = \@b;
      print $GROUPS "$line\n"; ## print selected groups to new groups file
    }
  }
}
close $GROUPS;
print "Found ".commify(scalar(keys %groups_hash))." groups satisfying select criteria\n";

unless ($noseqsplease) {
  ## mkdir for OG fastas
  my $dir = $prefix."Dir";
  if (-e $dir && -d $dir) {
    rmtree([ "$dir" ]);
    mkdir $dir;
    chdir $dir;
  } else {
    mkdir $dir;
    chdir $dir;
  }

  ## fetch sequence data for selected groups
  print "Printing sequence data per selected group in $dir/\n";
  foreach (nsort keys %groups_hash) {
    open (my $SEQS, ">$_.fasta") or die "$!\n";
    my @seqs = @{$groups_hash{$_}};
    foreach (@seqs) {
      print $SEQS "\>$_\n$seq_hash{$_}\n";
    }
    close $SEQS;
  }
}
print "\n";

######################## SUBS

sub commify {
  my $text = reverse $_[0];
  $text =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
  return scalar reverse $text;
}

__END__
