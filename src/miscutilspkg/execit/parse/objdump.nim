import docopt
import os
import pegs
import strformat
import strutils
import tables

type Field = tuple
  bit, len: int

proc extract(bits: seq[Field], shift, num: int, signed = true): int =
  result = 0
  var bc = 0
  for x in bits:
    let
      mask = not -(1 shl x.len)
      field = (num shr x.bit) and mask
    result = result or (field shl bc)
    bc.inc(x.len)
  if signed and bc > 0:
    let msb = result shr (bc - 1)
    if msb != 0:
      let m = (not result) shr bc shl bc
      result = result or m
  result = result shl shift

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
  const
    MATCH_JAL = 0x6f
    MASK_JAL = 0x7f
    MASK_JAL_RD = 0xfff

  proc render_key(x: Line, code: string): string =
    # if code.len == 4: return code
    if (x.ins and MASK_JAL) == MATCH_JAL:
      let
        off = extract(@[(21, 10), (20, 1), (12, 8), (31, 1)], 1, x.ins)
        tpc = x.adr + off
        hi11 = tpc shr 21 shl 21
        hi11p = x.adr shr 21 shl 21
        mark = if (hi11 == hi11p): 'V' else: 'X'
      result = &"{tpc:08x}|{x.ins and 0xfff:03x}|{mark}"
    else:
      result = code

  #[
    00000088 <reset_vector>:
      88:   342022f3                csrr    t0,mcause
    Disassembly of section .exec.itable:
  ]#
  var
    tab = initTable[string, seq[Line]]()
  try:
    for line in file.lines:
      if line =~ peg"^ \s+ {\w+} ':' \s+ {\w+} @ {\w .+}":
        let
          cod = matches[1]
          adr = matches[0].parseHexInt
          ins = matches[1].parseHexInt
          dis = matches[2]
          itm = Line(adr: adr, ins: ins, dis: dis)
          key = itm.render_key(cod)
        if not tab.hasKey(key): tab[key] = @[]
        tab[key].add(itm)
      elif line =~ peg"^ 'Disassembly' @ '.exec.itable:'":
        echo "TODO: parse .exec.itable"
        break
  except:
    echo getCurrentExceptionMsg()

  # report
  var count = initCountTable[string]()
  for k, v in tab:
    if k.len == 4: continue # skip RVC
    count.inc(k, v.len)
  count.sort()
  var limit = 20
  if args["--limit"]: limit = parseInt($args["--limit"])
  try:
    for k, v in count:
      echo &"{k:>16}: {v:>4}   {tab[k][0].dis}"
      limit.dec
      if limit == 0: break
  except:
    let
      e = getCurrentException()
      msg = getCurrentExceptionMsg()
    echo "Got exception ", repr(e), " with message ", msg

  true

