let doc = """
Misc Utility.

Usage:
  miscutils execit (parse|compare) (objdump|size|report|remain|rank) [<filename>] [<filenameB>] [--limit=LIMIT]
  miscutils binutils (parse|decode) (opcode|rank) [<filename>]
  miscutils test docopt option [<name>]
  miscutils ship shoot <x> <y>
  miscutils mine (set|remove) <x> <y> [--moored | --drifting]
  miscutils (-h | --help)
  miscutils --version

Options:
  -h --help     Show this screen.
  --version     Show version.
  --speed=<kn>  Speed in knots [default: 10].
  --moored      Moored (anchored) mine.
  --drifting    Drifting mine.
"""

import miscutilspkg/execit as execit
import miscutilspkg/test as test
import miscutilspkg/binutils as binutils
import docopt
import tables

let
  args = docopt(doc, version = "Misc Utility 0.1.0")
  subcmd = {
    "execit": execit.command,
    "test": test.command,
    "binutils": binutils.command,
    }.toTable

for cmd, fun in subcmd:
  if args[cmd]:
    discard fun(args)
    break
