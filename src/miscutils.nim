let doc = """
Misc Utility.

Usage:
  mu execit parse (objdump|size|report|remain) [<filename>]
  mu ship <name> move <x> <y> [--speed=<kn>]
  mu ship shoot <x> <y>
  mu mine (set|remove) <x> <y> [--moored | --drifting]
  mu (-h | --help)
  mu --version

Options:
  -h --help     Show this screen.
  --version     Show version.
  --speed=<kn>  Speed in knots [default: 10].
  --moored      Moored (anchored) mine.
  --drifting    Drifting mine.
"""

import miscutilspkg/execit as execit
import tables
import docopt

let
  args = docopt(doc, version = "Misc Utility 0.1.0")
  subcmd = {
    "execit": execit.command,
    }.toTable

for cmd, fun in subcmd:
  if args[cmd]:
    discard fun(args)
    break
