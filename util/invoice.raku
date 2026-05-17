use Actionable;
use FStrings;

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
    method label    { "Tax ({$.tax-rate * 100}%)" }
    method tax      { $.subtotal * $.tax-rate }
    method total    { $.subtotal + $.tax }

    method raku {
        { qq:to/INVOICE/.trim;

            Invoice: {.id}
            Date:    {.date}
            Client:  {.client}

            Description                     Hours     Rate   Subtotal
            ---------------------------------------------------------
            { .items.map({
            f(.description -f 30,.hours +f 6.1,.rate +f 8.2, .subtotal +f 10.2)
            }).join("\n") }
            ---------------------------------------------------------
                                                Subtotal   { .subtotal +f 10.2}
                                                {.label}   { .tax      +f 10.2}
                                                Total      { .total    +f 10.2}
            INVOICE

        } given self
    }
}

class Actions {
    method TOP($/) {
        my $inv = Invoice.action($<invoice-line>);
        { $inv.action($_) } for $<field-line>;
        { $inv.items.push(Item.action($_)) } for $<item-line>;
        make $inv;
    }
}

sub parse(Str $text --> Invoice) {
    Grammar.parse($text, :actions(Actions.new)).made;
}


my $EXAMPLE = q:to/END/;
invoice INV-001
  date 2026-04-29
  client "Acme Corp"

  item "Website redesign"  hours 10  rate 150
  item "Hosting setup"     hours 2   rate 100

  tax 8%
END

$EXAMPLE.&parse.say;
