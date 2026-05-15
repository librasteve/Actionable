grammar Grammar {
    token TOP       { <letter>+ }
    token letter    { <vowel> || <consonant> }
    token vowel     { <[aeiou]> }
    token consonant { <[bcdfghjklmnpqrstvwxyz]> }
}

class Actions {
    method TOP($/) { make $<letter>>><vowel>.grep(*.so).join }
}


Grammar.parse('hello', :actions(Actions.new)).made.say;