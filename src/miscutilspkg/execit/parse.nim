import docopt
import strformat
import pegs
import tables
import strutils
import execit/parse/objdump as objdump
import execit/parse/rank as rank

type
  Cosz = tuple
    text, code, rodata, data, bss, dec, hex: string

proc parse_size(args: Table[string, Value]): bool =
  if not args["<filename>"]:
    return false

#[
rsa.nds
lld-O0_-bfd
   text	   code	 rodata	   data	    bss	    dec	    hex	filename
 102628	  92044	  10584	   7648	   5896	 116172	  1c5cc	lld-O0_-bfd/denbench/gcc/bin/rsa.nds
lld-Os0-bfd
   text	   code	 rodata	   data	    bss	    dec	    hex	filename
  62144	  54872	   7272	   7384	   5880	  75408	  12690	lld-Os0-bfd/denbench/gcc/bin/rsa.nds
]#

  echo &"""Parse size <{args["<filename>"]}> ..."""
  var
    tab = initOrderedTable[string, Cosz]()
    opt: string
  try:
    for line in lines($args["<filename>"]):
      # echo line
      if line =~ peg"^ {\w+} '-' {\w+} '-' {\w+}$":
        # "lld-O0_-bfd"
        opt = line.strip
      # elif line =~ peg"^ {(\w / [.])+} $":
      #   # rsa.nds
      #   discard
      elif line =~ peg"\s* {\d+} \s+ {\d+} \s+ {\d+} \s+ {\d+} \s+ {\d+} \s+ {\d+} \s+ {[0-9a-f]+} \s+ {(\w / [-/.])+}":
        #  102628	  92044	  10584	   7648	   5896	 116172	  1c5cc	lld-O0_-bfd/denbench/gcc/bin/rsa.nds
        tab[opt] = (matches[0], matches[1], matches[2], matches[3], matches[4],
            matches[5], matches[6])
      # elif line =~ peg"\s+ {\w+} \s+ {\w+} \s+ {\w+} \s+ {\w+} \s+ {\w+} \s+ {\w+} \s+ {\w+} \s+ {\w+}":
      #   #  text	   code	 rodata	   data	    bss	    dec	    hex	filename
      #   discard
  except:
    echo getCurrentExceptionMsg()

  # report
  let base = tab["lld-Os0-bfd"]
  let base_code = base.code.parseInt
  var pre_reduction = 0.0
  echo &"""{"option":^12} {"code":^12} {"reduction(%)":^12} {"delta(%)":^12}"""
  for k, v in tab:
    if k.find("O0") >= 0: continue
    if k.find("Os0") >= 0: pre_reduction = 0.0
    let code = v.code.parseInt
    let reduction = 100 * (code / base_code - 1)
    let delta = reduction - pre_reduction

    let code_str = &"{v.code:>6}"
    let reduction_str = &"{reduction:>6.2f}"
    let delta_str = &"{delta:>6.2f}"
    echo &"{k:^12} {code_str:^12} {reduction_str:^12} {delta_str:^12}"
    pre_reduction = reduction

  true

type
  Perf = object
    code: int
    reduction, delta: float
    name: string

proc `+=`(a: var Perf, b: Perf) =
  a.code += b.code
  a.reduction += b.reduction
  a.delta += b.delta

proc parse_report(args: Table[string, Value]): bool =
  let filename = args["<filename>"]
  var file = stdin
  if filename and not open(file, $filename):
    return false

  #[
    Parse size <dat/psnr.nds.size> ...
    option        code     reduction(%)   delta(%)  
    lld-Os0-bfd      50840         0.00         0.00   
    lld-Os1-bfd      44520       -12.43       -12.43   
  ]#

  let filename_str = if filename: $filename else: "stdin"
  echo &"""Parse report <{filename_str}> ..."""
  var
    tab = initOrderedTable[string, Perf]()
    name: string
    files = 0
    lld, bfd, max, min: Perf
    bfd1, emax, emin: Perf
  try:
    for line in file.lines:
      if line =~ peg"^ 'Parse size <' {(\w / [/.-])+} '>' .+":
        name = matches[0]
        files.inc
      elif line =~ peg"^\s+ 'option' .+":
        discard
      elif line =~ peg"^ {(\w / [-])+} \s+ {\d+} \s+ {(\d / [-.])+} \s+ {(\d / [-.])+} .+":
        let opt = matches[0]
        let perf = Perf(code: matches[1].parseInt, reduction: matches[
              2].parseFloat, delta: matches[3].parseFloat)
        if tab.hasKey(opt):
          tab[opt] += perf
        else:
          tab[opt] = perf

        # min/max
        case opt:
        of "lld-Os_-bfd":
          lld = perf
          lld.name = name
        of "bfd-Os2-bfd":
          bfd1 = perf
          bfd1.name = name
        of "bfd-Os_-bfd":
          bfd = perf
          bfd.name = name
          # min/max (bfd - lld)
          let delta = bfd.reduction - lld.reduction
          if max.name == "":
            max = Perf(name: name, delta: delta)
            min = max
          else:
            if max.delta > delta:
              max = Perf(name: name, delta: delta)
            if min.delta < delta:
              min = Perf(name: name, delta: delta)
          # min/max (bfd Os_ - Os2)
          let delta2 = bfd.reduction - bfd1.reduction
          if emax.name == "":
            emax = Perf(name: name, delta: delta2)
            emin = emax
          else:
            if emax.delta > delta2:
              emax = Perf(name: name, delta: delta2)
            if emin.delta < delta2:
              emin = Perf(name: name, delta: delta2)
  except:
    echo getCurrentExceptionMsg()

  # report
  let base = tab["lld-Os0-bfd"]
  var pre_reduction: float
  echo &"""{"option":^12} {"code":^12} {"reduction(%)":^12} {"delta(%)":^12} {"reduction2(%)":^13}  {"delta2(%)":^12}"""
  for k, v in tab:
    # if k.find("O0") >= 0: continue
    if k.find("Os0") >= 0: pre_reduction = 0
    let
      code = v.code div files
      reduction = v.reduction / files.float
      delta = v.delta / files.float
      reduction2 = 100 * (v.code.float / base.code.float - 1)
      delta2 = reduction2 - pre_reduction
    pre_reduction = reduction2
    let
      code_str = &"{code:>6d}"
      reduction_str = &"{reduction:>6.2f}"
      delta_str = &"{delta:>6.2f}"
      reduction2_str = &"{reduction2:>6.2f}"
      delta2_str = &"{delta2:>6.2f}"
    echo &"{k:^12} {code_str:^12} {reduction_str:^12} {delta_str:^12} {reduction2_str:^13} {delta2_str:^12}  "
  # min/max
  echo &"max(bfd - lld): {max}"
  echo &"min(bfd - lld): {min}"
  echo &"max(Os2 - Os_): {emax}"
  echo &"min(Os2 - Os_): {emin}"

  true


type
  Kind = object
    matches, count: int
  Itable = object
    entries, icount: int
    classes: array[4, Kind]
  Remain = object
    itable: Itable
    entries, icount: int
    name: string
  RemainRef = ref Remain

proc `+=`(a: var array[4, Kind], b: array[4, Kind]) =
  for i in 0 ..< 4:
    a[i].matches += b[i].matches
    a[i].count += b[i].count

proc `div`(a: array[4, Kind], b: int): array[4, Kind] =
  for i in 0 ..< 4:
    result[i].matches = a[i].matches div b
    result[i].count = a[i].count div b

proc `+=`(a: var Remain, b: Remain) =
  a.itable.entries += b.itable.entries
  a.itable.icount += b.itable.icount
  a.itable.classes += b.itable.classes
  a.entries += b.entries
  a.icount += b.icount

proc `div`(a: Remain, b: int): Remain =
  result.itable.entries = a.itable.entries div b
  result.itable.icount = a.itable.icount div b
  result.itable.classes = a.itable.classes div b
  result.entries = a.entries div b
  result.icount = a.icount div b

proc parse_remain(args: Table[string, Value]): bool =
  let filename = args["<filename>"]
  var file = stdin
  if filename and not open(file, $filename):
    return false

  #[
    rsa.nds
    bfd-Os_-bfd
    itable entries = 403, insn count = 2428
    entry class/counts = [0, 3, 0, 400] [0, 3, 0, 2428]
    Remain: itable entries = 66, insn count = 269
  ]#

  let filename_str = if filename: $filename else: "stdin"
  echo &"""Parse remain <{filename_str}> ..."""
  var
    tab = initOrderedTable[string, RemainRef]()
    avg = Remain()
    cur, max: RemainRef
    name = ""
    files = 0
  try:
    for line in file.lines:
      if line =~ peg"^ {\w+ '.nds'}":
        name = matches[0]
        files.inc
        tab[name] = RemainRef(name: name)
        cur = tab[name]
        if max == nil: max = cur
      elif line =~ peg"^ ('bfd' / 'lld') .+":
        discard
      elif line =~ peg"^ 'itable' @'= ' {\d+} ',' @'= ' {\d+}":
        cur.itable.entries = matches[0].parseInt
        cur.itable.icount = matches[1].parseInt
      elif line =~ peg"^ 'entry' @'= ' '[' {@} ']' \s+ '[' {@} ']'":
        let class = matches[0]
        let count = matches[1]
        discard class =~ peg"{\d+} ', ' {\d+} ', ' {\d+} ', ' {\d+}"
        for i in 0 ..< 4:
          cur.itable.classes[i].matches = matches[i].parseInt
        discard count =~ peg"{\d+} ', ' {\d+} ', ' {\d+} ', ' {\d+}"
        for i in 0 ..< 4:
          cur.itable.classes[i].count = matches[i].parseInt
      elif line =~ peg"^ 'Remain:' @'= ' {\d+} ',' @'= ' {\d+}":
        cur.entries = matches[0].parseInt
        cur.icount = matches[1].parseInt
        avg += cur[]
        if max.icount < cur.icount: max = cur
  except:
    echo getCurrentExceptionMsg()

  # report
  for k, v in tab:
    echo k, v[]
  avg = avg div files
  echo "avg:", avg
  echo "max:", max[]

  true

let
  subcmd = {
    "objdump": objdump.parse,
    "rank": rank.parse,
    "size": parse_size,
    "report": parse_report,
    "remain": parse_remain,
    }.toTable

proc command*(args: Table[string, Value]): bool =
  for cmd, fun in subcmd:
    if args[cmd]:
      discard fun(args)
      break
  true
