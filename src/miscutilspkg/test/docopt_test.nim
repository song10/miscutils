import docopt
import strformat

proc test_option(args: Table[string, Value]): bool =
  let
    opt = args["<name>"]
    str = $args["<name>"]
  echo &"value: opt: {opt}, str: {str}"
  echo type(opt)
  echo type(str)

  true

let
  subcmd = {
    "option": test_option,
    }.toTable

proc command*(args: Table[string, Value]): bool =
  for cmd, fun in subcmd:
    if args[cmd]:
      discard fun(args)
      break
  true
