# $Id$
#
# BioPerl module for Bio::PopGen::Population
#
# Cared for by Jason Stajich <jason@bioperl.org>
#
# Copyright Jason Stajich
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::PopGen::Population - A population of individuals

=head1 SYNOPSIS

Give standard usage here

=head1 DESCRIPTION

This is a collection of individuals.  We'll have ways of generating
Bio::PopGen::Marker objects out so we can calculate allele_frequencies
for implementing the various statistical tests.

=head1 FEEDBACK

=head2 Mailing Lists

User feedback is an integral part of the evolution of this and other
Bioperl modules. Send your comments and suggestions preferably to
the Bioperl mailing list.  Your participation is much appreciated.

  bioperl-l@bioperl.org              - General discussion
  http://bioperl.org/MailList.shtml  - About the mailing lists

=head2 Reporting Bugs

Report bugs to the Bioperl bug tracking system to help us keep track
of the bugs and their resolution. Bug reports can be submitted via
email or the web:

  http://bugzilla.bioperl.org/

=head1 AUTHOR - Jason Stajich

Email jason-at-bioperl.org

=head1 CONTRIBUTORS

Matthew Hahn, matthew.hahn-at-duke.edu

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::PopGen::Population;
use vars qw(@ISA);
use strict;

# Object preamble - inherits from Bio::Root::Root

use Bio::Root::Root;
use Bio::PopGen::PopulationI;
use Bio::PopGen::Marker;

@ISA = qw(Bio::Root::Root Bio::PopGen::PopulationI );

=head2 new

 Title   : new
 Usage   : my $obj = new Bio::PopGen::Population();
 Function: Builds a new Bio::PopGen::Population object 
 Returns : an instance of Bio::PopGen::Population
 Args    : -individuals => array ref of individuals (optional)
           -name        => population name (optional)
           -source      => a source tag (optional)
           -description => a short description string of the population (optional)

=cut

sub new {
  my($class,@args) = @_;

  my $self = $class->SUPER::new(@args);
  $self->{'_individuals'} = [];
  my ($name,$source,$description,
      $inds) = $self->_rearrange([qw(NAME 
				     SOURCE 
				     DESCRIPTION
				     INDIVIDUALS)], @args);
  if( defined $inds ) {
      if( ref($inds) !~ /ARRAY/i ) {
	  $self->warn("Need to provide a value array ref for the -individuals initialization flag");
      } else { 
	  $self->add_Individual(@$inds);
      }
  }

  defined $name   && $self->name($name);
  defined $source && $self->source($source);
  defined $description && $self->description($description);

  return $self;
}


=head2 name

 Title   : name
 Usage   : my $name = $pop->name
 Function: Get the population name
 Returns : string representing population name
 Args    : [optional] string representing population name


=cut

sub name{
   my $self = shift;
   return $self->{'_name'} = shift if @_;
   return $self->{'_name'};
}

=head2 description

 Title   : description
 Usage   : my $description = $pop->description
 Function: Get the population description
 Returns : string representing population description
 Args    : [optional] string representing population description


=cut

sub description{
   my $self = shift;
   return $self->{'_description'} = shift if @_;
   return $self->{'_description'};
}

=head2 source

 Title   : source
 Usage   : my $source = $pop->source
 Function: Get the population source
 Returns : string representing population source
 Args    : [optional] string representing population source


=cut

sub source{
   my $self = shift;
   return $self->{'_source'} = shift if @_;
   return $self->{'_source'};
}

=head2 set_Allele_Frequency

 Title   : set_Allele_Frequency
 Usage   : $population->set_Allele_Frequency(
 Function: Sets an allele frequency for a Marker for this Population
           This allows the Population to not have individual individual
           genotypes but rather a set of overall allele frequencies
 Returns : Count of the number of markers
 Args    : -name      => (string) marker name
           -allele    => (string) allele name
           -frequency => (double) allele frequency - must be between 0 and 1
           OR
	   -frequencies => { 'marker1' => { 'allele1' => 0.01,
					    'allele2' => 0.99},
			     'marker2' => ...
			    }

=cut

sub set_Allele_Frequency {
   my ($self,@args) = @_;
   my ($name,$allele, $frequency,
       $frequencies) = $self->_rearrange([qw(NAME
					     ALLELE
					     FREQUENCY
					     FREQUENCIES
					     )], @args);
   if( defined $frequencies ) { # this supercedes the res
       if( ref($frequencies) =~ /HASH/i ) {
	   my ($markername,$alleles);
	   while( ($markername,$alleles) = each %$frequencies ) {
	       $self->{'_allele_freqs'}->{$markername} = 
		   new Bio::PopGen::Marker(-name        => $markername,
					   -allele_freq => $alleles);
	   }
       } else { 
	   $self->throw("Must provide a valid hashref for the -frequencies option");
       }
   } else { 
       unless( defined $self->{'_allele_freqs'}->{$name} ) {
	   $self->{'_allele_freqs'}->{$name} = 
	       new Bio::PopGen::Marker(-name        => $name);
       }
       $self->{'_allele_freqs'}->{$name}->add_Allele_Frequency($allele,$frequency);
   }
   return scalar keys %{$self->{'_allele_freqs'}};
}


=head2 add_Individual

 Title   : add_Individual
 Usage   : $population->add_Individual(@individuals);
 Function: Add individuals to a population
 Returns : count of the current number in the object 
 Args    : Array of Individuals


=cut

sub add_Individual{
    my ($self,@inds) = @_;
    foreach my $i ( @inds ) {
	next if ! defined $i;
	unless(  $i->isa('Bio::PopGen::IndividualI') ) {
	    $self->warn("cannot add an individual ($i) which is not a Bio::PopGen::IndividualI");
	    next;
	}
	push @{$self->{'_individuals'}}, $i;
    }
    $self->{'_cached_markernames'} = undef;
    $self->{'_allele_freqs'} = {};
    return scalar @{$self->{'_individuals'}};
}


=head2 remove_Individuals

 Title   : remove_Individuals
 Usage   : $population->remove_Individuals(@ids);
 Function: Remove individual(s) to a population
 Returns : count of the current number in the object 
 Args    : Array of ids

=cut

sub remove_Individuals {
    my ($self,@names) = @_;
    my $i = 0;
    my %namehash; # O(1) lookup will be faster I think
    foreach my $n ( @names ) { $namehash{$n}++ }
    my @tosplice;
    foreach my $ind (  @{$self->{'_individuals'}} ) {
	unshift @tosplice, $i if( $namehash{$ind->person_id} );
	$i++;
    }
    foreach my $index ( @tosplice ) {
	splice(@{$self->{'_individuals'}}, $index,1);
    }
    $self->{'_cached_markernames'} = undef;
    $self->{'_allele_freqs'} = {};
    return scalar @{$self->{'_individuals'}};
}

=head2 get_Individuals

 Title   : get_Individuals
 Usage   : my @inds = $pop->get_Individuals();
 Function: Return the individuals, alternatively restrict by a criteria
 Returns : Array of Bio::PopGen::IndividualI objects
 Args    : none if want all the individuals OR,
           -unique_id => To get an individual with a specific id
           -marker    => To only get individuals which have a genotype specific
                        for a specific marker name


=cut

sub get_Individuals{
   my ($self,@args) = @_;
   my @inds = @{$self->{'_individuals'}};
   return unless @inds;
   if( @args ) { # save a little time here if @args is empty
       my ($id,$name,$marker) = $self->_rearrange([qw(UNIQUE_ID
						      MARKER)], @args);

       if( defined $id ) { 
	   @inds = grep { $_->unique_id eq $id } @inds;
       } elsif (defined $marker) { 
	   @inds = grep { $_->has_Marker($marker) } @inds;
       }
   }
   return @inds;
}

=head2 get_Genotypes

 Title   : get_Genotypes
 Usage   : my @genotypes = $pop->get_Genotypes(-marker => $name)
 Function: Get the genotypes for all the individuals for a specific
           marker name
 Returns : Array of Bio::PopGen::GenotypeI objects
 Args    : -marker => name of the marker


=cut

sub get_Genotypes{
   my ($self,@args) = @_;
   my ($name) = $self->_rearrange([qw(MARKER)],@args);
   if( defined $name ) {
       return grep { defined $_ } map { $_->get_Genotypes(-marker => $name) } 
       @{$self->{'_individuals'}}
   } 
   $self->warn("You needed to have provided a valid -marker value");
   return ();
}


=head2 get_marker_names

 Title   : get_marker_names
 Usage   : my @names = $pop->get_marker_names;
 Function: Get the names of the markers
 Returns : Array of strings
 Args    : [optional] boolean flag to ignore internal cache status


=cut

sub get_marker_names{
    my ($self,$force) = @_;
    return @{$self->{'_cached_markernames'}} 
      if( ! $force && defined $self->{'_cached_markernames'});
    my %unique;
    foreach my $n ( map { $_->get_marker_names } $self->get_Individuals() ) {
	$unique{$n}++;
    }
    $self->{'_cached_markernames'} = [ keys %unique ];
    return @{$self->{'_cached_markernames'} };
}


=head2 get_Marker

 Title   : get_Marker
 Usage   : my $marker = $population->get_Marker($name)
 Function: Get a Bio::PopGen::Marker object based on this population
 Returns : Bio::PopGen::MarkerI object
 Args    : name of the marker


=cut

sub get_Marker{
   my ($self,$markername) = @_;
   my $marker;
   # setup some caching too
   if( defined $self->{'_allele_freqs'} &&
       defined ($marker = $self->{'_allele_freqs'}->{$markername}) ) {
       # marker is now set to the stored value
   } else { 
       my @genotypes = $self->get_Genotypes(-marker => $markername);
       $marker = new Bio::PopGen::Marker(-name   => $markername);
       
       if( ! @genotypes ) {
	   $self->warn("No genotypes for Marker $markername in the population");
       } else { 
	   my %alleles;
	   my $count;
	   map { $count++; $alleles{$_}++ } map { $_->get_Alleles } @genotypes;
	   foreach my $allele ( keys %alleles ) {
	       $marker->add_Allele_Frequency($allele, $alleles{$allele}/$count);
	   }
       }
       $self->{'_allele_freqs'}->{$markername} = $marker;
   }
   return $marker;
}


=head2 get_number_individuals

 Title   : get_number_individuals
 Usage   : my $count = $pop->get_number_individuals;
 Function: Get the count of the number of individuals
 Returns : integer >= 0
 Args    : none


=cut

sub get_number_individuals{
   my ($self,$markername) = @_;
   unless( defined $markername ) {
       return scalar @{$self->{'_individuals'}};
   } else { 
       my $number =0;
       foreach my $individual ( @{$self->{'_individuals'}} ) {
	   $number++ if( $individual->has_Marker($markername));
       }
       return $number;
   }
}


=head2 get_Frequency_Homozygotes

 Title   : get_Frequency_Homozygotes
 Usage   : my $freq = $pop->get_Frequency_Homozygotes;
 Function: Calculate the frequency of homozygotes in the population
 Returns : fraction between 0 and 1
 Args    : $markername


=cut

sub get_Frequency_Homozygotes{
   my ($self,$marker,$allelename) = @_;
   my ($homozygote_count) = 0;
   return 0 if ! defined $marker || ! defined $allelename;
   $marker = $marker->name if( defined $marker && 
			       ref($marker) &&
			       $marker->isa('Bio::PopGen::MarkerI'));
   my $total = $self->get_number_individuals($marker);
   foreach my $genotype ( $self->get_Genotypes($marker) ) {
       my %alleles = map { $_ => 1} $genotype->get_Alleles();
       # what to do for non-diploid situations?
       if( $alleles{$allelename} ) {
	   $homozygote_count++ if( keys %alleles == 1);
       }
   }
   return $total ? $homozygote_count / $total : 0;
}

=head2 get_Frequency_Heterozygotes

 Title   : get_Frequency_Heterozygotes
 Usage   : my $freq = $pop->get_Frequency_Homozygotes;
 Function: Calculate the frequency of homozygotes in the population
 Returns : fraction between 0 and 1
 Args    : $markername


=cut

sub get_Frequency_Heterozygotes{
   my ($self,$marker,$allelename) = @_;
   my ($heterozygote_count) = 0;
   return 0 if ! defined $marker || ! defined $allelename;
   $marker = $marker->name if( defined $marker && ref($marker) &&
			       $marker->isa('Bio::PopGen::MarkerI'));
   if( ref($marker) ) {
       $self->warn("Passed in a ".ref($marker). " to has_Marker, expecting either a string or a Bio::PopGen::MarkerI");
       return 0;
   }
   my $total = $self->get_number_individuals($marker);

   foreach my $genotype ( $self->get_Genotypes($marker) ) {
       my %alleles = map { $_ => 1} $genotype->get_Alleles();
       # what to do for non-diploid situations?
       if( $alleles{$allelename} ) {
	   $heterozygote_count++ if( keys %alleles == 2);
       }
   }
   return $total ? $heterozygote_count / $total : 0;
}

1;
