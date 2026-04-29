NAME
====

Actionable - auto-populate Raku classes from grammar match objects

SYNOPSIS
========

```raku
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
```

DESCRIPTION
===========

`Actionable` is a role providing a `action` class method. Mix it into any class to auto-populate scalar attributes from a Raku grammar match object.

Attributes not in `capture-map` are looked up by their own name. Numeric attributes (typed `Int`, `Num`, `Rat`, etc.) are coerced with `+`; all others with `~`. Array and hash attributes are skipped. Override `transform` for post-coercion adjustments.

AUTHOR
======

librasteve <librasteve@furnival.net>

COPYRIGHT AND LICENSE
=====================

Copyright 2026 librasteve

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

