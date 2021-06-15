import docopt
import os
import pegs
import strformat
import strutils
import tables

proc parse*(args: Table[string, Value]): bool =
  var file = stdin
  if true:
    let filename = args["<filename>"]
    if filename and not open(file, $filename):
      return false

    let
      module_name = currentSourcePath().splitfile().name
      filename_str = if filename: $filename else: "stdin"
    echo &"""Parse {module_name} <{filename_str}> ..."""

  type
    Insn = object
      match, mask: int
      mne: string
  #[
    #define MATCH_SLLI_RV32 0x1013
    #define MASK_SLLI_RV32  0xfe00707f
  ]#
  var
    tab = initOrderedTable[string, Insn]()
  try:
    for line in file.lines:
      if line =~ peg"^ '#define' \s+ {\w+} \s+ '0x' {\w+}":
        let
          mm = matches[0]
          va = matches[1].parseHexInt
        var
          key = "?"
          atr = ""
        if mm =~ peg"^ {('MATCH' / 'MASK')} '_' {\w+}":
          atr = matches[0]
          key = matches[1]
        if not tab.hasKey(key): tab[key] = Insn()
        if tab[key].mne == "": tab[key].mne = key
        case atr:
        of "MATCH": tab[key].match = va
        of "MASK": tab[key].mask = va
        else: echo &"Prefix <{atr}> not supported!"
  except:
    let
      e = getCurrentException()
      msg = getCurrentExceptionMsg()
    echo "Got exception ", repr(e), " with message ", msg

  # report
  let
    prefix = """  
type
  Insn = object
    mne: string
    match, mask: int64

proc initInsn(mne: string, match, mask: int64): Insn =
  Insn(mne: mne, match: match, mask: mask)

let tab: seq[Insn] = @["""
    # initInsn("VLSEG6E256V", 0xb0005007, 0xfdf0707f),
    postfix = """
  ]

proc parse*(code: int64): string =
  for x in tab:
    if (code and x.mask) == x.match:
      return x.mne
  "?"
"""

  echo prefix
  for k, v in tab:
    echo &"""  initInsn("{v.mne}", 0x{v.match:x}, 0x{v.mask:x}),"""
  echo postfix

  true

