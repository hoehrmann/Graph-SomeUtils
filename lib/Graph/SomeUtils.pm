package Graph::SomeUtils;

use 5.012000;
use strict;
use warnings;
use base qw(Exporter);
use Graph;
use Graph::Directed;

our $VERSION = '0.21';

our %EXPORT_TAGS = ( 'all' => [ qw(
	graph_delete_vertices_fast
  graph_delete_vertex_fast
  graph_all_successors_and_self
  graph_all_predecessors_and_self
  graph_vertices_between
  graph_edges_between
  graph_get_vertex_label
  graph_set_vertex_label
  graph_isolate_vertex
  graph_delete_vertices_except
  graph_truncate_to_vertices_between
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
);

sub graph_get_vertex_label {
  my ($g, $v) = @_;
  return $g->get_vertex_attribute($v, 'label');
}

sub graph_set_vertex_label {
  my ($g, $v, $label) = @_;
  $g->set_vertex_attribute($v, 'label', $label);
}

sub graph_delete_vertex_fast {
  my $g = shift;

  if (UNIVERSAL::isa($g, 'Graph::Feather')) {
    $g->delete_vertex($_[0]);
    return $g;
  }

  $g->expect_non_unionfind;
  my $V = $g->[ Graph::_V ];
  return $g unless $V->has_path( @_ );
  $g->delete_edge($_[0], $_) for $g->successors($_[0]);
  $g->delete_edge($_, $_[0]) for $g->predecessors($_[0]);
  $V->del_path( @_ );
  $g->[ Graph::_G ]++;
  return $g;
}

sub graph_delete_vertices_fast {
  my $g = shift;
  graph_delete_vertex_fast($g, $_) for @_;
}

sub graph_vertices_between {
  my ($g, $src, $dst) = @_;

  my %seen;
  
  for my $edge (graph_edges_between($g, $src, $dst)) {
    $seen{ $edge->[0] }++;
    $seen{ $edge->[1] }++;
  }

  warn unless $seen{$src};
  warn unless $seen{$dst};

  return keys %seen;
}

sub graph_vertices_between_old {
  my ($g, $src, $dst) = @_;
  my %from_src;
  
  $from_src{$_}++ for graph_all_successors_and_self($g, $src);
  
  return grep {
    $from_src{$_}
  } graph_all_predecessors_and_self($g, $dst);
}

sub graph_edges_between {
  my ($g, $src, $dst) = @_;

  my $subgraph = Graph::Directed->new(
    edges => [ grep {
      $_->[1] ne $src and $_->[0] ne $dst
    } $g->edges ],
  );

  my @vertices = graph_vertices_between_old($subgraph, $src, $dst);

  warn unless grep { $src eq $_ } @vertices;
  warn unless grep { $dst eq $_ } @vertices;

  my %in_subgraph = map { $_ => 1 } @vertices;

  my @subgraph_edges = grep {
    $in_subgraph{$_->[0]} and $in_subgraph{$_->[1]}
  } $g->edges;

  return @subgraph_edges;
}

sub graph_edges_between_old {
  my ($g, $src, $dst) = @_;

  my @subgraph = graph_vertices_between($g, $src, $dst);

  die unless grep { $src eq $_ } @subgraph;
  die unless grep { $dst eq $_ } @subgraph;

  my %in_subgraph = map { $_ => 1 } @subgraph;

  my @subgraph_edges = grep {
    $in_subgraph{$_->[0]} and $in_subgraph{$_->[1]}
  } $g->edges;

  return @subgraph_edges;
}

sub graph_all_successors_and_self {
  my ($g, $v) = @_;
  return ((grep { $_ ne $v } $g->all_successors($v)), $v);
}

sub graph_all_predecessors_and_self {
  my ($g, $v) = @_;
  return ((grep { $_ ne $v } $g->all_predecessors($v)), $v);
}

sub graph_isolate_vertex {
  my ($g, $vertex) = @_;
  $g->delete_edge($vertex, $_) for $g->successors($vertex);
  $g->delete_edge($_, $vertex) for $g->predecessors($vertex);
}

sub graph_delete_vertices_except {
  my ($g, @vertices) = @_;
  my %keep = map { $_ => 1 } @vertices;

  graph_delete_vertices_fast($g,
    grep { not $keep{$_} } $g->vertices);
}

sub graph_truncate_to_vertices_between {
  my ($g, $start, $final) = @_;
  graph_delete_vertices_except($g,
    graph_vertices_between($g, $start, $final));
}

1;

__END__

=head1 NAME

Graph::SomeUtils - Some utility functions for Graph objects

=head1 SYNOPSIS

  use Graph::SomeUtils ':all';

  graph_delete_vertex_fast($g, 'a');
  graph_delete_vertices_fast($g, 'a', 'b', 'c');

  my @pred = graph_all_predecessors_and_self($g, $v);
  my @succ = graph_all_successors_and_self($g, $v);

  my @between = graph_vertices_between($g, $source, $dest);
  
=head1 DESCRIPTION

Some helper functions for working with L<Graph> objects.

=head1 FUNCTIONS

=over

=item graph_delete_vertex_fast($g, $v)

The C<delete_vertex> method of the L<Graph> module C<v0.96> is very
slow. This function is an order-of-magnitude faster alternative. It
accesses internals of the Graph module and might break under newer
versions of the module.

=item graph_delete_vertices_fast($g, $v1, $v2, ...)

Same as C<graph_delete_vertex_fast> for multiple vertices.

=item graph_vertices_between($g, $source, $destination)

Returns the intersection of vertices that are reachable from C<$source>
and vertices from which C<$destination> is reachable, including the
C<$source> and C<$destination> vertices themself.

=item graph_edges_between($g, $source, $destination)

Returns the edges between vertices returned by C<graph_vertices_between>.

=item graph_all_successors_and_self($g, $v)

Returns the union of C<$g->all_successors($v)> and C<$v> in an arbitrary
order.

=item graph_all_predecessors_and_self($g, $v)

Returns the union of C<$g->all_predecessors($v)> and C<$v> in an arbitrary
order.

=item graph_get_vertex_label($g, $v)

Shorthand for getting the vertex attribute C<label>.

=item graph_set_vertex_label($g, $v, $label)

Shorthand for setting the vertex attribute C<label>.

=item graph_isolate_vertex($g, $v)

Removes edges coming in and going out of C<$v>.

=item graph_delete_vertices_except($g, @vertices)

Deletes vertices except C<@vertices>.

=item graph_truncate_to_vertices_between($g, $start, $final)

Removes all vertices that are neither C<$start> or C<$final>
nor on a path between them.

=back

=head1 EXPORTS

None by default, each of the functions by request. Use C<:all> to
import them all at once.

=head1 AUTHOR / COPYRIGHT / LICENSE

  Copyright (c) 2014 Bjoern Hoehrmann <bjoern@hoehrmann.de>.
  This module is licensed under the same terms as Perl itself.

=cut
