[![Actions Status](https://github.com/librasteve/Actionable/actions/workflows/test.yml/badge.svg)](https://github.com/librasteve/Actionable/actions)

### method raku

```raku
method raku() returns Mu
```

fallback method raku to preempt 'Object<9230298340589>'

NAME
====

Actionable - auto-populate Raku classes from grammar match objects

SYNOPSIS
========

```raku
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
```

DESCRIPTION
===========

`Actionable` is a role that eliminates boilerplate in Raku grammar `Actions` classes. Mix it into any class to get an `action` method that auto-populates attributes from a grammar match object.

`action` dispatches on whether the invocant is defined:

  * **Type object** (`MyClass.action($match)`) — creates and returns a new instance, populating scalar attributes from named captures in `$match`.

  * **Instance** (`$obj.action($match)`) — updates the instance in place from `$match` and returns `self`.

Attribute mapping
-----------------

By default each attribute is looked up by its own name as a named capture. To override, provide a `capture-map` method returning a `Hash` of `attr-name =E<gt> dot-path`:

```raku
method capture-map {
    { qty   => 'number.0',   # $match<number>[0]
      price => 'number.1' }  # $match<number>[1]
}
```

Dot-path segments are hash keys or array indices (all-digit segments are treated as indices).

Alternatively, use Raku's aliased capture syntax in the grammar to name captures after the target attribute — avoiding `capture-map` entirely:

```raku
rule item-line { item <description=quoted-string> hours <hours=number> rate <rate=number> }
```

Type coercion
-------------

Attributes typed as `Numeric` (or any subtype: `Int`, `Real`, `Rat`, `Num`) are coerced with `+`; all others with `~`. Array and hash attributes are skipped automatically.

Post-coercion transforms
------------------------

Override `transform` to adjust a value after coercion:

```raku
method transform(Str $attr, $raw) {
    $attr eq 'tax-rate' ?? $raw / 100 !! $raw
}
```

AUTHOR
======

librasteve <librasteve@furnival.net>

COPYRIGHT AND LICENSE
=====================

Copyright 2026 librasteve

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

