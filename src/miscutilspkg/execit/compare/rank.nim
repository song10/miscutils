import docopt
import os
import pegs
import strformat
import strutils
import tables

proc compare*(args: Table[string, Value]): bool =
  var
    file = stdin
    fileB: File
  if true:
    let filename = args["<filename>"]
    if filename and not open(file, $filename):
      return false
    let filenameB = args["<filenameB>"]
    if not filenameB or not open(fileB, $filenameB):
      return false

    let
      module_name = currentSourcePath().splitfile().name
      filename_str = if filename: $filename else: "stdin"
      filenameB_str = $filenameB
    echo &"""Compare {module_name} <{filename_str}> <{filenameB_str}>..."""

  type
    Line = object
      insn: int
      count: int
      dis: string
  #[
    [  19]     0ff00893|00000000|00000000|-
    0ff00d93:   64   li     s11,255
  ]#
  var
    tab = initOrderedTable[string, Line]()
    tabB = initTable[string, Line]()
  try:
    # parse base
    var item: Line
    for line in fileB.lines:
      if line =~ peg"^ '[' \s* {\w+} ']' @ ({\w+} '|')":
        item.insn = matches[1].parseHexInt
        item.count = matches[0].parseInt
        item.dis = ""
      elif line =~ peg"^ {\w+} ':' \s+ {\d+} \s+ {.+}":
        item.insn = matches[0].parseHexInt
        item.count = matches[1].parseInt
        item.dis = matches[2]
      else:
        continue
      let key = &"{item.insn:08x}"
      if tabB.hasKey(key): echo &"Duplicated base key <{key}>"
      tabB[key] = item

    # parse file
    for line in file.lines:
      if line =~ peg"^ '[' \s* {\w+} ']' @ ({\w+} '|')":
        item.insn = matches[1].parseHexInt
        item.count = matches[0].parseInt
        item.dis = ""
      elif line =~ peg"^ {\w+} ':' \s+ {\d+} \s+ {.+}":
        item.insn = matches[0].parseHexInt
        item.count = matches[1].parseInt
        item.dis = matches[2]
      else:
        continue
      let key = &"{item.insn:08x}"
      if tab.hasKey(key): echo &"Duplicated key <{key}>"
      tab[key] = item
  except:
    let
      e = getCurrentException()
      msg = getCurrentExceptionMsg()
    echo "Got exception ", repr(e), " with message ", msg

  # report
  for k, v in tab:
    var prefix = "----"
    var dis = v.dis
    if tabB.hasKey(k):
      let delta = v.count - tabB[k].count
      prefix = &"{delta:>4d}"
      if tabB[k].dis != "": dis = tabB[k].dis

    echo &"[{prefix}] {k} [{v.count:>4d}]  {dis}"

  true

