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
    method subtotal { [+] @.items.map(*.subtotal) }
    method tax      { $.subtotal * $.tax-rate }
    method total    { $.subtotal + $.tax }
}

grammar Grammar {
    token ws { \h* }

    token TOP {
        <head-line>
        [ \n+ <ws> [ <info-line> | <item-line> ] ]*
        \n*
    }
    rule  head-line { invoice  <id>                  }
    rule  info-line { | date   <date>
                      | client <client=quoted>
                      | tax    <tax-rate=number> '%' }
    rule  item-line { item     <description=quoted>
                      hours    <hours=number>
                      rate     <rate=number>         }
    token id        { <[A..Za..z0..9_\-]>+       }
    token date      { \d\d\d\d '-' \d\d '-' \d\d }
    token quoted    { '"' <( <-["]>+ )> '"'      }
    token number    { \d+ [ '.' \d+ ]?           }
}

class Actions {
    method TOP($/) {
        my $inv = Invoice.action($<head-line>);
         { $inv.action($_) } for $<info-line>;
         { $inv.items.push(Item.action($_)) } for $<item-line>;
        make $inv;
    }
}

sub parse(Str $text --> Invoice) {
    Grammar.parse($text, :actions(Actions.new)).made;
}

sub render(Invoice $inv --> Str) {
    my @lines = (
        "Invoice: {$inv.id}",
        "Date:    {$inv.date}",
        "Client:  {$inv.client}",
        "",
        sprintf("%-30s %6s %8s %10s", "Description", "Hours", "Rate", "Subtotal"),
        "-" x 58,
    );
    for $inv.items {
        @lines.push: sprintf("%-30s %6.1f %8.2f %10.2f",
            .description, .hours, .rate, .subtotal);
    }
    my $tax-label = "Tax ({$inv.tax-rate * 100}%)";
    given @lines {
        .push: "-" x 58;
        .push: sprintf("%46s %10.2f", "Subtotal",  $inv.subtotal);
        .push: sprintf("%46s %10.2f", $tax-label,  $inv.tax);
        .push: sprintf("%46s %10.2f", "Total",     $inv.total);
        .join("\n");
    }
}

my $EXAMPLE = q:to/END/;
invoice INV-001
  date 2026-04-29
  client "Acme Corp"

  item "Website redesign"  hours 10  rate 150
  item "Hosting setup"     hours 2   rate 100

  tax 8%
END

my $inv = parse($EXAMPLE);
say render($inv);
