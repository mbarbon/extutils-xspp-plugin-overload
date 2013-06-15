package ExtUtils::XSpp::Plugin::Overload;

use strict;
use warnings;

use File::ShareDir;

our $VERSION = '0.01';

=head1 NAME

ExtUtils::XSpp::Plugin::Overload - default overload handling for XS++

=cut

my @overload_numeric_types = (
    'int', 'unsigned', 'short', 'long',
    'unsigned int', 'unsigned short',
    'unsigned long', 'float', 'double',
    'size_t', 'ssize_t',
);

my @overload_string_types = ('char*');

sub new {
    my ($class) = @_;
    my $self = bless { classes => {}, kinds => {} }, $class;

    $self->{kinds}{number} = [map _make_type($_), @overload_numeric_types];
    $self->{kinds}{string} = [map _make_type($_), @overload_string_types];
    $self->{kinds}{any} = [];

    return $self;
}

sub register_plugin {
    my ($class, $parser) = @_;
    my $instance = $class->new;

    $parser->add_post_process_plugin(plugin => $instance);
    $parser->add_method_tag_plugin(plugin => $instance, tag => 'Overload');
    $parser->add_toplevel_tag_plugin(plugin => $instance,
                                     tag    => 'OverloadType',
                                     method => 'handle_overload_type');
    $parser->add_toplevel_tag_plugin(plugin => $class,
                                     tag    => 'InitializeOverload',
                                     method => 'handle_initialize_overload');
}

sub handle_overload_type {
    my ($self, $empty, $tag, %args) = @_;

    die "Invalid argument count for %OverloadType"
        unless @{$args{positional}} == 2;

    my ($kind, $type) = @{$args{positional}};

    die "Invalid type kind '$kind'" unless exists $self->{kinds}{$kind};

    push @{$self->{kinds}{$kind}}, _make_type($type);

    1;
}

sub handle_initialize_overload {
    my ($self, undef, $tag, %args) = @_;
    my @rows;

    push @rows, sprintf qq{#include "%s"},
      File::ShareDir::dist_file('ExtUtils-XSpp-Plugin-Overload',
                                'overload.h');
    if (($args{positional}[0] || '') eq 'implement') {
        push @rows, sprintf qq{#include "%s"},
          File::ShareDir::dist_file('ExtUtils-XSpp-Plugin-Overload',
                                    'overload.cpp');
    }

    return (1, ExtUtils::XSpp::Node::Raw->new(rows => \@rows));
}

sub _make_type {
    my ($type) = @_;

    return ExtUtils::XSpp::Parser->parse_type($type);
}

sub handle_method_tag {
    my ($self, $method, $tag, %args) = @_;

    push @{$self->{classes}{$method->class}{$method->cpp_name}}, $method;

    1;
}

sub post_process {
    my ($self, $nodes) = @_;

    foreach my $group ( values %{$self->{classes}} ) {
        while (my ($method_name, $methods) = each %{$group}) {
            _add_overload($self, $methods);
        }
    }
}

sub is_bool {
    my ($self, $type) = @_;

    return !$type->is_pointer && $type->base_type eq 'bool';
}

sub is_string {
    my ($self, $type) = @_;

    return scalar grep $_->equals($type), @{$self->{kinds}{string}};
}

sub is_number {
    my ($self, $type) = @_;

    return scalar grep $_->equals($type), @{$self->{kinds}{number}};
}

sub is_value {
    my ($self, $type, $class) = @_;

    return !$type->is_pointer && $type->base_type eq $class;
}

sub is_any {
    my ($self, $type) = @_;

    return scalar grep $_->equals($type), @{$self->{kinds}{any}};
}

sub map_type {
    my ($self, $type) = @_;

    return '"' . $type->base_type . '"';
}

sub _compare_function {
    my ($self, $a, $b) = @_;

    # arbitrary order for functions with the same name, assuming they
    # will be guarded with different #ifdefs
    return $a <=> $b if $a->perl_name eq $b->perl_name;

    my ($ca, $cb) = (0, 0);

    $ca += 1 foreach grep !$_->has_default, @{$a->arguments};
    $cb += 1 foreach grep !$_->has_default, @{$b->arguments};

    return $ca - $cb if $ca != $cb;

    for(my $i = 0; $i < 10000; ++$i) {
        return -1 if $#{$a->arguments} <  $i && $#{$b->arguments} >= $i;
        return  1 if $#{$a->arguments} >= $i && $#{$b->arguments}  < $i;
        return  0 if $#{$a->arguments} <  $i && $#{$b->arguments}  < $i;
        # since optional arguments might not be specified, we can't rely on them
        # to disambiguate two calls
        return  0 if $ca <  $i && $cb < $i;

        my $ta = $a->arguments->[$i]->type;
        my $tb = $b->arguments->[$i]->type;

        my ($as, $bs) = ($self->is_string($ta) || $self->is_any($ta),
                         $self->is_string($tb) || $self->is_any($tb));
        my ($ai, $bi) = ($self->is_number($ta), $self->is_number($tb) );
        my ($ab, $bb) = ($self->is_bool($ta), $self->is_bool($tb) );
        my $asimple = $as || $ai || $ab;
        my $bsimple = $bs || $bi || $bb;

        # first complex types, then integer, then boolean/string

        # TODO this does not handle overloading on a base and a derived type,
        #      and an undef value is ambiguous even as an object
        return -1 if !$asimple && !$bsimple;

        return -1 if !$asimple &&  $bsimple;
        return  1 if  $asimple && !$bsimple;

        next      if  $ai &&  $bi;
        return -1 if  $ai && !$bi;
        return  1 if !$ai &&  $bi;

        # string/bool are ambiguous
        next;
    }

    return 0;
}

sub _make_dispatch {
    my ($self, $methods, $method) = @_;

    if (@{$method->arguments} == 0) {
        my $init = <<EOT;
    static Xsp::Plugin::Overload::Prototype void_proto(NULL, 0);
EOT
        return [$init, 'void_proto',
                sprintf('        XSP_PLUGIN_OVERLOAD_MATCH_VOID(%s)',
                         $method->perl_name),
                $method->condition_expression];
    }
    my($min, $max, @indices) = (0, 0);
    foreach my $arg ( @{$method->arguments} ) {
        ++$max;
        ++$min unless defined $arg->default;

        if ($self->is_bool($arg->type)) {
            push @indices, 'XspPluginOverloadBool';
            next;
        }
        if ($self->is_string($arg->type) || $self->is_any($arg->type)) {
            push @indices, 'XspPluginOverloadString';
            next;
        }
        if ($self->is_number($arg->type)) {
            push @indices, 'XspPluginOverloadNumber';
            next;
        }

        my $mapped_type = $self->map_type($arg->type);
        die "Unable to dispatch ", $arg->type->print(undef)
            unless $mapped_type;

        push @indices, $mapped_type;
    }

    my $proto_name = sprintf '%s_proto', $method->perl_name;
    my $init = sprintf <<EOT,
    static const char *%s_types[] = { %s };
    static Xsp::Plugin::Overload::Prototype %s_proto(%s_types, sizeof(%s_types) / sizeof(%s_types[0]));
EOT
        $method->perl_name, join(', ', @indices),
        $method->perl_name, $method->perl_name, $method->perl_name, $method->perl_name;

    if ($min != $max) {
        return [$init, $proto_name,
                sprintf('        XSP_PLUGIN_OVERLOAD_MATCH_MORE(%s_proto, %s, %d)',
                        $method->perl_name, $method->perl_name, $min),
                $method->condition_expression];
    } else {
        return [$init, $proto_name,
                sprintf('        XSP_PLUGIN_OVERLOAD_MATCH_EXACT(%s_proto, %s, %d)',
                        $method->perl_name, $method->perl_name, $max),
                $method->condition_expression];
    }
}

sub _wrap {
    my ($code, $condition) = @_;
    my $res;

    chomp $code;
    $res .= "#if $condition\n" if $condition ne '1';
    $res .= "$code\n";
    $res .= "#endif // $condition\n" if $condition ne '1';

    return $res;
}

sub _add_overload {
    my ($self, $methods) = @_;
    my $class = $methods->[0]->class;

    my @methods = sort { $self->_compare_function($a, $b) } @$methods;

    for (my $i = 0; $i < $#methods; ++$i) {
        next if $self->_compare_function($methods[$i], $methods[$i + 1]) != 0;
        die "Ambiguous overload for ", $methods[$i]->perl_name,
                              " and ", $methods[$i + 1]->perl_name;
    }

    for (my $i = 0; $i < @methods; ++$i) {
        my $method = $methods[$i];

        if ($method->cpp_name eq $method->perl_name) {
            $method->set_perl_name($method->cpp_name . $i);
        }
    }

    my @dispatch = map _make_dispatch($self, $methods, $_), @methods;
    my $method_name = $methods[0]->isa('ExtUtils::XSpp::Node::Constructor') ?
                          'new' : $methods[0]->cpp_name;

    my $code = sprintf <<EOT,
void
%s::%s(...)
  PPCODE:
EOT
      $class->cpp_name, $method_name;

    my @prototypes;
    foreach my $dispatch ( @dispatch ) {
        next unless $dispatch->[0];
        $code .= _wrap($dispatch->[0], $dispatch->[3]);
        push @prototypes, _wrap("        &$dispatch->[1],", $dispatch->[3]);
    }

    $code .= sprintf <<EOT,
    static Xsp::Plugin::Overload::Prototype *all_prototypes[] = {
%s        NULL };
    XSP_PLUGIN_OVERLOAD_BEGIN()
EOT
      join('', @prototypes);

    foreach my $dispatch ( @dispatch ) {
        $code .= _wrap($dispatch->[2], $dispatch->[3]);
    }

    $code .= sprintf <<EOT,
    XSP_PLUGIN_OVERLOAD_MESSAGE(%s::%s, all_prototypes)
EOT
      $class->perl_name, $method_name;

    $class->add_methods(ExtUtils::XSpp::Node::Raw->new
                            ( rows           => [$code],
                              emit_condition => $class->condition_expression,
                              ));
}

1;
