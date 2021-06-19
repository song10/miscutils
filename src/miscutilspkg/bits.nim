import bitops

export bitops

type Field = tuple
  bit, len: int

proc extract*(bits: seq[Field], shift, num: int, signed = true): int =
  result = 0
  var bc = 0
  for x in bits:
    let
      msb = x.bit + x.len
      field = num.bitsliced(x.bit ..< msb)
    result = result or (field shl bc)
    bc.inc(x.len)
  # sign extension
  if signed and (bc > 0) and result.testBit(bc - 1):
      let se = (not result) shr bc shl bc
      result = result or se
  result = result shl shift
