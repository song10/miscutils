import binutils/parse/opcode as opcode
import docopt
import tables

let
  subcmd = {
    "opcode": opcode.parse,
    }.toTable

proc command*(args: Table[string, Value]): bool =
  for cmd, fun in subcmd:
    if args[cmd]:
      discard fun(args)
      break
  true
