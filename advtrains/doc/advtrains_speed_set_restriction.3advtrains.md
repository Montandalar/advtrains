% advtrains_speed_set_restriction(3advtrains) | Advtrains Developer's Manual

# NAME
`advtrains.speed.set_restriction`, `advtrains.speed.merge_aspect` - modify speed restriction

# SYNOPSIS
* `advtrains.speed.set_restriction(train, rtype, rval)`
* `advtrains.speed.merge_aspect(train, asp)`

# DESCRIPTION

The `advtrains.speed.set_restriction` function sets the speed restriction of type `rtype` of `train` to `rval` and updates the speed restriction value to the strictest speed restriction in the table, or `nil` if all speed restrictions are `nil` or `-1`. If the speed restriction table does not exist, it is created with the `"main"` speed restriction being the speed restriction value of `train`.

The `advtrains.speed.merge_aspect` function merges the main aspect of `asp` into the speed restriction table with the same procedure described above. If the signal aspect table does not provide the type of speed restriction, the restriction type `"main"` is assumed.

# SIDE EFFECTS

Both functions modify `train.speed_restriction` and `train.speed_restrictions_t`.
