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
    Line = object
      adr, ins: int
      dis: string
  #[
    00000088 <reset_vector>:
      88:   342022f3                csrr    t0,mcause
  ]#
  var
    tab = initTable[string, seq[Line]]()
  try:
    for line in file.lines:
      if line =~ peg"^ \s+ {\w+} ':' \s+ {\w+} @ {\w .+}":
        let
          key = matches[1]
          adr = matches[0].parseHexInt
          ins = matches[1].parseHexInt
          dis = matches[2]
          itm = Line(adr: adr, ins: ins, dis: dis)
        if not tab.hasKey(key): tab[key] = @[]
        tab[key].add(itm)
  except:
    echo getCurrentExceptionMsg()

  # report
  var count = initCountTable[string]()
  for k, v in tab:
    if k.len == 4: continue
    count.inc(k, v.len)
  count.sort()
  var limit = 20
  if args["--limit"]: limit = parseInt($args["--limit"])
  try:
    for k, v in count:
      echo &"{k:>8}: {v:>4}   {tab[k][0].dis}"
      limit.dec
      if limit == 0: break
  except:
    let
      e = getCurrentException()
      msg = getCurrentExceptionMsg()
    echo "Got exception ", repr(e), " with message ", msg

  true

