package Dist::Zilla::Plugin::ScriptX;

# AUTHORITY
# DATE
# DIST
# VERSION

use 5.010001;
use strict;
use warnings;

use Moose;
use namespace::autoclean;

use Dist::Zilla::File::InMemory;
use File::Slurper qw(read_binary);
use File::Spec::Functions qw(catfile);

with (
    'Dist::Zilla::Role::RequireFromBuild',
    'Dist::Zilla::Role::FileMunger',
    'Dist::Zilla::Role::FileFinderUser' => {
        default_finders => [':InstallModules'],
    },
);

sub _get_meta {
    my ($self, $pkg) = @_;

    $self->require_from_build($pkg);
    my $meta = {};
    eval { $meta = $pkg->meta };
    $meta;
}

# dzil also wants to get abstract for main module to put in dist's
# META.{yml,json}
sub before_build {
    my $self  = shift;
    my $name  = $self->zilla->name;
    my $class = $name; $class =~ s{ [\-] }{::}gmx;
    my $filename = $self->zilla->_main_module_override ||
        catfile( 'lib', split m{ [\-] }mx, "${name}.pm" );

    $filename or die 'No main module specified';
    -f $filename or die "Path ${filename} does not exist or not a file";
    #open my $fh, '<', $filename or die "File ${filename} cannot open: $!";

    my $meta = $self->_get_meta($class);
    my $abstract = $meta->{summary};
    return unless $abstract;

    $self->zilla->abstract($abstract);
    return;
}

sub munge_files {
    no strict 'refs';
    my $self = shift;

    local @INC = ("lib", @INC);

    # gather dist modules
    my %distmodules;
    for my $file (@{ $self->found_files }) {
        next unless $file->name =~ m!\Alib/(.+)\.pm\z!;
        my $mod = $1; $mod =~ s!/!::!g;
        $distmodules{$mod}++;
    }

    for my $file (@{ $self->found_files }) {
        next unless $file->name =~ m!\Alib/(ScriptX/.+)\.pm\z!;
        (my $pkg = $1) =~ s!/!::!g;
        my $meta = $self->_get_meta($pkg);

        # fill-in ABSTRACT from meta's summary
        {
            my $content = $file->content;
            my $abstract = $meta->{summary};
            last unless $abstract;
            $content =~ s{^#\s*ABSTRACT:.*}{# ABSTRACT: $abstract}m
                or die "Can't insert abstract for " . $file->name;
            $self->log(["inserting abstract for %s (%s)",
                        $file->name, $abstract]);

            $file->content($content);
        }
    } # foreach file
    return;
}

__PACKAGE__->meta->make_immutable;
1;
# ABSTRACT: Plugin to use when building ScriptX::* distribution

=for Pod::Coverage .+

=head1 SYNOPSIS

In F<dist.ini>:

 [ScriptX]


=head1 DESCRIPTION

This plugin is to be used when building C<ScriptX::*> distribution. It currently
does the following:

=over

=item * Fill the Abstract from meta's summary

=back


=head1 SEE ALSO

L<ScriptX>

L<Pod::Weaver::Plugin::ScriptX>
