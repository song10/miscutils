import execit/parse as parse
import execit/compare as compare
import docopt

let
  subcmd = {
    "parse": parse.command,
    "compare": compare.command,
    }.toTable

proc command*(args: Table[string, Value]): bool =
  for cmd, fun in subcmd:
    if args[cmd]:
      discard fun(args)
      break
  true
