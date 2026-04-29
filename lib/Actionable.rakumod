unit role Actionable;

method capture-map(--> Hash) { {} }

method transform(Str $attr, $raw) { $raw }

multi method action(Any:U: $match) {
    my %init;
    apply-match(self, $match, -> $attr, $name, $val { %init{$name} = $val });
    self.new(|%init);
}

multi method action(Any:D: $match) {
    apply-match(self, $match, -> $attr, $name, $val { $attr.set_value(self, $val) });
    self
}

sub apply-match($self, $match, &act) {
    my %map = $self.capture-map;
    for $self.^attributes -> $attr {
        next if $attr.name.starts-with('@') || $attr.name.starts-with('%');
        my $name = $attr.name.substr(2);
        my $path = %map{$name} // $name;
        my $raw  = resolve-capture($match, $path) // next;
        my $val  = $self.transform($name, $attr.type ~~ Numeric ?? +$raw !! ~$raw);
        act($attr, $name, $val);
    }
}

sub resolve-capture($match, Str $path) {
    my $cur = $match;
    for $path.split('.') -> $step {
        $cur = $step ~~ /^ \d+ $/ ?? $cur[$step.Int] !! $cur{$step};
        return Nil without $cur;
    }
    $cur
}

=begin pod

=head1 NAME

Actionable - auto-populate Raku classes from grammar match objects

=head1 SYNOPSIS

=begin code :lang<raku>

use Actionable;

class Item does Actionable {
    has Str  $.description;
    has Real $.hours;
    has Real $.rate;
    method subtotal { $.hours * $.rate }
}

class Invoice does Actionable {
    has Str  $.id       is rw = "";
    has Str  $.date     is rw = "";
    has Str  $.client   is rw = "";
    has Real $.tax-rate is rw = 0.0;
    has Item @.items;
    method transform(Str $attr, $raw) {
        $attr eq 'tax-rate' ?? $raw / 100 !! $raw
    }
}

class Actions {
    method TOP($/) {
        my $inv = Invoice.action($<invoice-line>);  # create from type object
        $inv.action($_) for $<field-line>;           # update existing instance
        $inv.items.push(Item.action($_)) for $<item-line>;
        make $inv;
    }
}

=end code

=head1 DESCRIPTION

C<Actionable> is a role that eliminates boilerplate in Raku grammar C<Actions>
classes. Mix it into any class to get an C<action> method that auto-populates
attributes from a grammar match object.

C<action> dispatches on whether the invocant is defined:

=item B<Type object> (C<MyClass.action($match)>) — creates and returns a new instance, populating scalar attributes from named captures in C<$match>.

=item B<Instance> (C<$obj.action($match)>) — updates the instance in place from C<$match> and returns C<self>.

=head2 Attribute mapping

By default each attribute is looked up by its own name as a named capture.
To override, provide a C<capture-map> method returning a C<Hash> of
C<attr-name =E<gt> dot-path>:

=begin code :lang<raku>

method capture-map {
    { qty   => 'number.0',   # $match<number>[0]
      price => 'number.1' }  # $match<number>[1]
}

=end code

Dot-path segments are hash keys or array indices (all-digit segments are
treated as indices).

Alternatively, use Raku's aliased capture syntax in the grammar to name
captures after the target attribute — avoiding C<capture-map> entirely:

=begin code :lang<raku>

rule item-line { item <description=quoted-string> hours <hours=number> rate <rate=number> }

=end code

=head2 Type coercion

Attributes typed as C<Numeric> (or any subtype: C<Int>, C<Real>, C<Rat>,
C<Num>) are coerced with C<+>; all others with C<~>. Array and hash
attributes are skipped automatically.

=head2 Post-coercion transforms

Override C<transform> to adjust a value after coercion:

=begin code :lang<raku>

method transform(Str $attr, $raw) {
    $attr eq 'tax-rate' ?? $raw / 100 !! $raw
}

=end code

=head1 AUTHOR

librasteve <librasteve@furnival.net>

=head1 COPYRIGHT AND LICENSE

Copyright 2026 librasteve

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod
