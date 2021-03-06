import binutils/parse as parse
import binutils/decode as decode
import docopt

let
  subcmd = {
    "parse": parse.command,
    "decode": decode.command,
    }.toTable

proc command*(args: Table[string, Value]): bool =
  for cmd, fun in subcmd:
    if args[cmd]:
      discard fun(args)
      break
  true
