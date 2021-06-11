import execit/compare/rank as rank
import docopt
import tables

let
  subcmd = {
    "rank": rank.compare,
    }.toTable

proc command*(args: Table[string, Value]): bool =
  for cmd, fun in subcmd:
    if args[cmd]:
      discard fun(args)
      break
  true
