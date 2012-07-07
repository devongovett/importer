#import "alsfile"

blarg = []
foo = (x) ->
  blarg.push x
foo x for x in ["hi", "from", "derp", "coffee"] when x isnt "derp"
console.log blarg.join(" ")
