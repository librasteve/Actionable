[![Actions Status](https://github.com/librasteve/Actionable/actions/workflows/test.yml/badge.svg)](https://github.com/librasteve/Actionable/actions)

NAME
====

Actionable - auto-populate Raku classes from grammar match objects

SYNOPSIS
========

```raku
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

