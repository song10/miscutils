import docopt
import strformat
import pegs
import tables
import strutils

proc parse_objdump(args: Table[string, Value]): bool =
  if not args["<filename>"]:
    return false

  echo &"""Parse objdump <{args["<filename>"]}> ..."""
  true

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

let
  subcmd = {
    "objdump": parse_objdump,
    "size": parse_size,
    "report": parse_report,
    }.toTable

proc command*(args: Table[string, Value]): bool =
  for cmd, fun in subcmd:
    if args[cmd]:
      discard fun(args)
      break
  true
