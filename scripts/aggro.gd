class_name Aggro
extends RefCounted
## How far the creatures see a hero and how far they follow him, against what
## each kind's scene says (the user's word, 2026-10-06: they turned back too
## soon; they should see further and chase far). Applied once as each wakes
## ([Fighter], [Brute], [Wolf]).

## Seeing him: this many times its own sight.
const SIGHT := 1.35
## Following him: this many times its own ground (a camp's leash, a wolf's
## losing range).
const CHASE := 2.0
