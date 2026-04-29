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
    has Str $.description;
    has Num $.hours;
    has Num $.rate;
    method capture-map {
        { description => 'quoted-string',
          hours       => 'number.0',
          rate        => 'number.1' }
    }
}

# In your Actions class:
my $item = Item.action($match);

=end code

=head1 DESCRIPTION

C<Actionable> is a role providing a C<action> class method. Mix it into
any class to auto-populate scalar attributes from a Raku grammar match object.

Attributes not in C<capture-map> are looked up by their own name. Numeric
attributes (typed C<Int>, C<Num>, C<Rat>, etc.) are coerced with C<+>;
all others with C<~>. Array and hash attributes are skipped. Override
C<transform> for post-coercion adjustments.

=head1 AUTHOR

librasteve <librasteve@furnival.net>

=head1 COPYRIGHT AND LICENSE

Copyright 2026 librasteve

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod
