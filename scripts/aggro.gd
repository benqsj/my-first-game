class_name Aggro
extends RefCounted
## How far the creatures see a hero and how far they follow him, against what
## each kind's scene says (the user's word, 2026-10-06: they turned back too
## soon; they notice him from as far as before and chase three times as far). Applied once as each wakes
## ([Fighter], [Brute], [Wolf]).

## Seeing him: this many times its own sight (as it was).
const SIGHT := 1.0
## Following him: this many times its own ground (a camp's leash, a wolf's
## losing range).
const CHASE := 3.0
