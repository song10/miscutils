import execit/parse as parse
import docopt

let
  subcmd = {
    "parse": parse.command,
    }.toTable

proc command*(args: Table[string, Value]): bool =
  for cmd, fun in subcmd:
    if args[cmd]:
      discard fun(args)
      break
  true
