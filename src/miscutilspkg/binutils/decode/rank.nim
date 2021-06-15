import binutils/decode/opcode as opcode
import docopt
import os
import pegs
import strformat
import strutils
import tables

proc decode*(args: Table[string, Value]): bool =
  var file = stdin
  if true:
    let filename = args["<filename>"]
    if filename and not open(file, $filename):
      return false

    let
      module_name = currentSourcePath().splitfile().name
      filename_str = if filename: $filename else: "stdin"
    echo &"""Decode {module_name} <{filename_str}> ..."""

  #[
    rank: [  33] hash=000005b7|00000000|00000000|=
    rank: [   1] hash=000805b7|00000000|00000000|-
  ]#
  try:
    for line in file.lines:
      if line =~ peg"^ 'rank:' @ '=' {\w+} '|'":
        let
          insn = matches[0].parseHexInt
          dis = opcode.decode(insn)
        echo &"{line} {dis}"
  except:
    let
      e = getCurrentException()
      msg = getCurrentExceptionMsg()
    echo "Got exception ", repr(e), " with message ", msg

  true

