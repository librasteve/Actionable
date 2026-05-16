use Actionable;

grammar Grammar {
    token TOP {    <.slash><subject>
    <.slash><command>
    [ <.slash><data> ]?    }

    proto token command {*}
    token command:sym<create>   { <sym> }
    token command:sym<retrieve> { <sym> }
    token command:sym<update>   { <sym> }
    token command:sym<delete>   { <sym> }

    token subject { \w+ }
    token data    { .*  }
    token slash   { '/' }
}

class Command does Actionable {
    has ($.subject, $.command, $.data);

    method raku {
        my %h := $.action-hash;
        %h<subject-id> = $!data.split('/')[0];
        $.action-table(%h);
    }
}

class Actions {
    method TOP ($/) {
        make Command.action($/)
    }
}

Grammar.parse('/product/update/7/notify', :actions(Actions.new)).made.say;
