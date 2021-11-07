% advtrains_speed_lessp(3advtrains) | Advtrains Developer's Manual

# NAME
`advtrains.speed.lessp`, `advtrains.speed.greaterp`, `advtrains.speed.not_lessp`, `advtrains.speed_not_greaterp`, `advtrains.speed.equalp`, `advtrains.speed.not_equalp`, `advtrains.speed.max`, `advtrains.speed.min` - speed restriction comparison functions

# SYNOPSIS
Each function takes two arguments and returns a boolean or (for `advtrains.speed.max` and `advtrains.speed.min`) a valid speed limit

# DESCRIPTION

The functions above correspond to the arithmetic `<`, `>`, `>=`, `<=`, `==`, `~=` operators and the `math.max` and `math.min` functions, respectively. The constants `nil` and `false` are treated as -1.

# NOTES

These functions are trivial to implement and the implementation can be easily embedded into existing code. They are simply provided for convenience.
