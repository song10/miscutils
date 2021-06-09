let doc = """
Misc Utility.

Usage:
  mu execit parse (objdump|size|report|remain|rank) [<filename>] [--limit=LIMIT]
  mu test docopt option [<name>]
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
import miscutilspkg/test as test
import docopt
import tables

let
  args = docopt(doc, version = "Misc Utility 0.1.0")
  subcmd = {
    "execit": execit.command,
    "test": test.command,
    }.toTable

for cmd, fun in subcmd:
  if args[cmd]:
    discard fun(args)
    break
