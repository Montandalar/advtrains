% signal_aspect(7advtrains) | Advtrains Developer's Manual

# DESCRIPTION

The signal aspect table used by advtrains has the following fields:

* `main`: The main speed restriction
* `dst`: The `main` aspect of the distant signal (not implemented)
* `type`: The type of speed restriction given by the signal
* `shunt`: Whether shunting is allowed
* `proceed_as_main`: Whether to proceed without shunting

The `main` and `dst` fields may contain the following values:
* `-1`: No speed restriction
* `nil`: No information is available

The `type` field can be any valid table index, but it should usually be one of the following values:
* "main": The main signal aspect used before the introduction of speed restriction types. This is the default value if the `type` field is absent.
* "line": The speed limit for the physical line.
* "temp": The speed limit that is temporarily introduced.

# NOTES

A signal with the `main` aspect of zero should not provide distant signal aspect.
