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
      cnt: int
  #[
    rank: [   3] hash=0000178b|00cdb9f0|00000000|#
    rank: [   1] hash=003c275b|00000000|00000000|-
    rank: [   1] hash=00058593|01096d60|0000001c|=
  ]#
  var
    tab = initTable[string, Line]()
  try:
    for line in file.lines:
      if line =~ peg"^ 'rank: [' \s+ {\d+} ']' @ '=' {.+}":
        let
          key = matches[1]
          cnt = matches[0].parseInt
          itm = Line(cnt: cnt)
        if tab.hasKey(key): echo &"duplicated key <{key}>"
        tab[key] = itm
  except:
    echo getCurrentExceptionMsg()

  # report
  var
    limit = 20
    threshold = 3
  if args["--limit"]: limit = parseInt($args["--limit"])
  if args["--threshold"]: threshold = parseInt($args["--threshold"])
  var count = initCountTable[string]()
  for k, v in tab:
    count.inc(k, v.cnt)
  count.sort()
  for k, v in count:
    if v < threshold: continue
    echo &"[{v:>4}] {k:>32}"
    limit.dec
    if limit == 0: break

  true

