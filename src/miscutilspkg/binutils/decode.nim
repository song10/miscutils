import binutils/decode/rank as rank
import docopt
import tables

let
  subcmd = {
    "decode": rank.decode,
    }.toTable

proc command*(args: Table[string, Value]): bool =
  for cmd, fun in subcmd:
    if args[cmd]:
      discard fun(args)
      break
  true
