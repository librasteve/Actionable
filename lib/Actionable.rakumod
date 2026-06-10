=begin pod

=head1 NAME

Actionable - auto-populate Raku classes from grammar match objects

=head1 SYNOPSIS

=begin code :lang<raku>

use Actionable;

grammar Grammar {
    token TOP {
        <invoice-line>
        [ \n+ <ws> [ <field-line> | <item-line> ] ]*
        \n*
    }
    rule  invoice-line { invoice  <id>                  }
    rule  field-line   { | date   <date>
                         | client <client=quoted>
                         | tax    <tax-rate=number> '%' }
    rule  item-line    { item     <description=quoted>
                         hours    <hours=number>
                         rate     <rate=number>         }
    token id     { <[A..Za..z0..9_-]>+       }
    token date   { \d**4 '-' \d**2 '-' \d**2 }
    token quoted { '"' <( <-["]>+ )> '"'     }
    token number { \d+ [ '.' \d+ ]?          }
    token ws { \h* }  #horizontal whitespace only
}

class Item does Actionable {
    has ($.description, $.hours, $.rate);
    method subtotal { $.hours * $.rate }
}

class Invoice does Actionable {
    has ($.id, $.date, $.client, $.tax-rate = 0);
    has Item @.items;
    method transform(Str $attr, $raw) {
        $attr eq 'tax-rate' ?? $raw / 100 !! $raw
    }
    method subtotal { @.items.map(*.subtotal).sum }
    method tax      { $.subtotal * $.tax-rate }
    method total    { $.subtotal + $.tax }
}

class Actions {
    method TOP($/) {
        my $inv = Invoice.action($<invoice-line>);
         { $inv.action($_) } for $<field-line>;
         { $inv.items.push(Item.action($_)) } for $<item-line>;
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

=head2 Positional (quantified) captures

When a named capture is produced by a quantified token (C<*>, C<+>, C<?>) it
resolves to a C<Positional>. C<action> handles this transparently:

=item Zero matches — the attribute is skipped (left at its default).
=item One match — the single element is unwrapped and used normally.
=item Two or more matches — if the target attribute is C<Positional> (e.g. C<Array[Str]>), the matches are stored as C<Array[Str]>; otherwise C<action> dies with an unambiguous error.

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

=head2 Sub-match C<.made> values

If a sub-match has been processed by an C<Actions> method that called C<make>,
C<action> prefers the C<.made> value over raw string coercion. This enables
nested-class population without any explicit wiring:

=begin code :lang<raku>

class jCard does Actionable {
    has Address $.adr;   # populated automatically from $<adr>.made
    ...
}

class Actions {
    method adr($/)  { make Address.action($/) }   # sets .made on $<adr>
    method TOP($/)  { make jCard.action($/) }      # picks up .made automatically
}

=end code

=head2 Injecting values via named arguments

Pass named arguments to C<action> to supply or override attribute values
directly. Named arguments win over both C<.made> and raw captures, and are
used as-is (no coercion, no C<transform> call):

=begin code :lang<raku>

make jCard.action($/, adr => $pre-built-address);

=end code

=head2 Precedence

For each attribute, C<action> resolves its value in this order:

=item 1. Named argument (C<*%h>) — highest priority
=item 2. C<.made> of the resolved capture — if the sub-match was processed by an actions method
=item 3. Raw capture coerced and passed through C<transform> — fallback

=end pod


unit role Actionable;

use JSON::Fast;

sub apply-match($self, $match, %h, &act) {
    my %map = $self.capture-map;
    for $self.^attributes -> $attr {
        next if $attr.name.starts-with('@') || $attr.name.starts-with('%');
        my $name = $attr.name.substr(2);
        if %h{$name}:exists {
            act($attr, $name, %h{$name});
            next;
        }
        my $path = %map{$name} // $name;
        my $raw  = resolve-capture($match, $path) // next;
        my $val;
        if $raw ~~ Positional {
            if $attr.type ~~ Positional {
                $val = Array[Str].new($raw.map(*.Str));
            } else {
                die "Actionable: capture '$path' matched {$raw.elems} times; use an Array attr or capture-map"
                    if $raw.elems > 1;
                my $elem = $raw[0];
                $val = $elem.?made.defined
                    ?? $elem.made
                    !! $self.transform($name, $attr.type ~~ Numeric ?? +$elem !! ~$elem);
            }
        } else {
            $val = $raw.?made.defined
                ?? $raw.made
                !! $self.transform($name, $attr.type ~~ Numeric ?? +$raw !! ~$raw);
        }
        act($attr, $name, $val);
    }
}

sub resolve-capture($match, Str $path) {
    my $current = $match;
    for $path.split('.') -> $step {
        $current = $step ~~ /^ \d+ $/ ?? $current[$step.Int] !! $current{$step};
        return Nil without $current;
    }
    if $current ~~ Positional {
        return Nil unless $current.elems;
    }
    $current
}

method capture-map(--> Hash) { {} }

method transform(Str $attr, $raw) { $raw }

multi method action(Any:U: $match, *%h) {
    my %init;
    apply-match(self, $match, %h, -> $attr, $name, $val { %init{$name} = $val });
    self.new(|%init);
}

multi method action(Any:D: $match, *%h) {
    apply-match(self, $match, %h, -> $attr, $name, $val { $attr.set_value(self, $val) });
    self
}

#| get a hash of all the attrs with values populated via .action
method action-hash {
    self.^attributes
        .map({
        .name.substr(2) => .get_value(self)
    }).Hash
}

#| get json of all the attrs with values populated via .action
method action-to-json {
    self.action-hash.&to-json;
}

#| fallback method raku to preempt 'Object<9230298340589>'
method raku {
    self.action-hash.raku
}

#| basic table of action-hash values $k => $v
multi method action-table(%h = self.action-hash) {
    my $col1 = %h.keys.map(*.chars).max;
    my $col2 = %h.values.map(*.chars).max;

    gather {
        for %h.sort -> $p {
            my ($k, $v) = $p.kv;
            $v = "[{$v.join(", ")}]" if $v ~~ Iterable;
            take sprintf("%-{$col1}s %-1s %-{$col2}s", $k, '=>', $v);
        }
    }.join("\n");
}

=begin pod
=head1 AUTHOR

librasteve <librasteve@furnival.net>

=head1 COPYRIGHT AND LICENSE

Copyright 2026 librasteve

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod
