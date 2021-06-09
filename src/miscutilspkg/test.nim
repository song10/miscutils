import test/docopt_test as docopt_test
import docopt

let
  subcmd = {
    "docopt": docopt_test.command,
    }.toTable

proc command*(args: Table[string, Value]): bool =
  for cmd, fun in subcmd:
    if args[cmd]:
      discard fun(args)
      break
  true
