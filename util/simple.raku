use Actionable;
use Data::Dump::Tree;
use FStrings;

#use Grammar::Tracer;

grammar Grammar {
    token TOP       { <letter>+ }
    token letter    { <vowel> || <consonant> }
    token vowel     { <[aeiou]> }
    token consonant { <[bcdfghjklmnpqrstvwxyz]> }
}

class Actions {
    #make all the vowels
    method TOP($/)    { make $<letter>>>.made.grep(*.defined).join }
    method letter($/) { make $<vowel>.made if $<vowel> }
    method vowel($/)  { make $/ }

}

my $text = 'hello';

my $match = Grammar.parse($text, :actions(Actions.new));
say $match.made;