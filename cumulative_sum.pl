#!/usr/bin/env perl

## author: reubwn Mar 2020

use strict;
use warnings;

use Bio::SeqIO;
use Getopt::Long;
use File::Basename;
use Sort::Naturally;
use List::Util qw/sum/;

my $usage = "
SYNOPSIS
  Generate data for cumulative scaffold summary plots.

OPTIONS
  -d|--directory [PATH] : path to input directory ['./']
  -s|--suffix  [STRING] : suffix used to glob fasta files ['*.fasta']
  -o|--output  [STRING] : name for results file [cumulative_summary.txt]
  -a|--append    [FILE] : append results to existing <FILE>, rather than open new one
  -h|--help             : prints this help message
\n";

my ($suffix, $append_filename, $help, $debug);
my $fasta_path = "./";
my $output_filename = "cumulative_summary.txt";

GetOptions (
  'd|directory:s' => \$fasta_path,
  's|suffix:s' => \$suffix,
  'o|output:s' => \$output_filename,
  'a|append:s' => \$append_filename,
  'h|help' => \$help,
  'debug' => \$debug
);

die $usage if $help;
die $usage unless ($fasta_path);

my %results_hash;
my @fasta_files;
if ($suffix) {
  @fasta_files = glob ("$fasta_path/$suffix");
} else {
  @fasta_files = glob ("$fasta_path/*fasta $fasta_path/*fna $fasta_path/*fa");
}
print STDERR "[INFO] There are ".commify(scalar(@fasta_files))." files in '$fasta_path'\n";

foreach my $file_path (@fasta_files) {
  my $basename = fileparse($file_path, qr/\.[^.]*/);
  print STDERR "[INFO] Working on '$basename'\n";
  my $in = Bio::SeqIO -> new ( -file => $file_path, -format => 'fasta' );
  while (my $seq_obj = $in->next_seq()) {
    push (@{$results_hash{$basename}}, $seq_obj->length());
  }
}

## outfile
my $OUT;
if ( $append_filename ) {
  print STDERR "[INFO] Appending to file '$append_filename'\n";
  open ($OUT, '>>', $append_filename) or die $!; ## add results to the bottom of existing file
} else {
  print STDERR "[INFO] Opening new file '$output_filename'\n";
  open ($OUT, '>', $output_filename) or die $!;
}

print STDERR "[INFO] Sorting and summing scaffold lengths...\n";
foreach my $basename (nsort keys %results_hash) {
  print $OUT "$basename";
  my @lengths = sort {$b<=>$a} @{$results_hash{$basename}}; ## sort longest first
  for my $i (0 .. $#lengths) {
    if ($i == 0) {
      print $OUT "\t$lengths[0]";
    } else {
      # my @cumulative = @lengths[0..$i]; ## up to current position
      print $OUT "\t".sum(@lengths[0..$i]);
    }
  }
  print $OUT "\n";
}
close $OUT;
print STDERR "[INFO] Finished " . `date`;

######################### sub-routines

sub commify {
  my $text = reverse $_[0];
  $text =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
  return scalar reverse $text;
}

sub percentage {
  my $numerator = $_[0];
  my $denominator = $_[1];
  my $places = "\%.2f"; ## default is two decimal places
  if (exists $_[2]){$places = "\%.".$_[2]."f";};
  my $float = (($numerator / $denominator)*100);
  my $rounded = sprintf("$places",$float);
  return "$rounded\%";
}

__END__
