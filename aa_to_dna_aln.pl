#!/usr/bin/env perl

use strict;
use warnings;
use Getopt::Long;

use Bio::SeqIO;
use Bio::AlignIO;
use File::Basename;
use Bio::Align::Utilities qw(aa_to_dna_aln);
use Data::Dumper;

my $usage = "
SYNOPSIS
  1. Maps dna sequences onto aa alignments, for Ka/Ks, PAML etc.
  2. Fasta headers must correspond exactly between aa and dna sequences,
     otherwise the missing entry in the dna alignment will be shown as a bunch of gaps ('---').

OPTIONS [*required]
  -a|--aa    *[PATH] : path to dir of aa alignments (fasta format)
  -d|--dna   *[PATH] : path to dir of unaligned dna sequences (fasta format)
  -b|--aext   [STR]  : filename extension used to glob files from aa path ('\*.fasta')
  -e|--dext   [STR]  : filename extension used to glob files from dna path ('\*.fasta')
  -m|--max    [INT]  : maximum number of seqs in aa alignment, skips if > (100)
  -n|--min    [INT]  : minimum number of seqs in aa alignment (2)
  -o|--outdir [DIR]  : base dirname to write stuff ('aa_to_dna_aln_results/')
  -x|--overwrite     : overwrite outdir if it already exists
  -h|--help          : print this message
\n";

my ($aa_path, $dna_path, $overwrite, $help);
my $aa_extension = "fasta";
my $dna_extension = "fasta";
my $outdir = "aa_to_dna_aln_results";
my $max_seqs = 100;
my $min_seqs = 2;

GetOptions (
  'a|aa=s'      => \$aa_path,
  'b|aext:s'    => \$aa_extension,
  'd|dna=s'     => \$dna_path,
  'e|dext:s'    => \$dna_extension,
  'm|max:i'     => \$max_seqs,
  'n|min:i'     => \$min_seqs,
  'o|outdir:s'  => \$outdir,
  'x|overwrite' => \$overwrite,
  'h|help'      => \$help
);

die $usage if ( $help );
die $usage unless ( $aa_path && $dna_path );

$aa_path =~ s/\/$//;
$dna_path =~ s/\/$//;

if ( -d $outdir ) {
  if ( $overwrite ) {
    `rm -r $outdir`;
    `mkdir $outdir`;
  } else {
    die "[ERROR] Dir $outdir already exists and overwrite set to false\n";
  }
} else {
  `mkdir $outdir`;
}

## parse CDSs
my %cds_hash;
my @dna_files = glob ("$dna_path/*.$dna_extension");
print STDOUT "[INFO] Reading files from $dna_path/\*.$dna_extension...\n";
foreach my $dna_file (@dna_files) {
  my $in = Bio::SeqIO->new( -file => $dna_file, -format => 'fasta' );
  while (my $seq = $in->next_seq() ) {
    $cds_hash{$seq->display_id()} = $seq->seq();
  }
}
if ( scalar(keys %cds_hash) == 0 ) {
  die "[ERROR] No sequences found in $dna_path!\n";
} else {
  print STDOUT "[INFO] Fetched ".commify(scalar(keys %cds_hash))." CDS seqs from ".commify(scalar(@dna_files))." files in $dna_path/\n";
}

## cycle thru alignments
my @aln_files = glob ("$aa_path/*.$aa_extension");
print STDOUT "[INFO] Reading files from $aa_path/\*.$aa_extension... (".commify(scalar(@aln_files))." files)\n";
ALN: foreach my $aln_file (@aln_files) {
  print STDOUT "\r[INFO] Working on file: $aln_file"; $|=1;
  ## fetch alignment and backtranslate to nucleotides
  my $get_prot_aln = Bio::AlignIO -> new( -file => $aln_file, -format => 'fasta' );
  my $prot_aln = $get_prot_aln -> next_aln();

  ## skip if too many or too few seqs in alignment
  if ( ($prot_aln->num_sequences < $min_seqs) || ($prot_aln->num_sequences > $max_seqs) ) {
    next ALN;
  } else {
    my %cds_seqs;
    foreach my $seq ( $prot_aln->each_seq() ) {
      $cds_seqs{$seq->display_id()} = Bio::Seq->new( -display_id => $seq->display_id(), -seq => $cds_hash{$seq->display_id()} );
    }
    my $dna_aln = aa_to_dna_aln($prot_aln, \%cds_seqs);
    my $dna_aln_filename = (basename ($aln_file, ".fa")) . "_dna.fa";
    my $write_dna_aln = Bio::AlignIO -> new( -file => ">$outdir/$dna_aln_filename", -format => 'fasta', -verbose => -1 );
    $write_dna_aln -> write_aln($dna_aln);
  }
}

print STDOUT "\n[INFO] Finished! " . `date`;

######################## SUBS

sub commify {
  my $text = reverse $_[0];
  $text =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
  return scalar reverse $text;
}

__END__
