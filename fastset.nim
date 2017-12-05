from math import pow

const seqs = true

type
  FastSet*[T: uint8 | uint16] = object
    when seqs:
      data: seq[uint32]
    else:
      maxbyte: int
      when T is uint8:
        data: array[(high(uint8)+1) div 32, uint32]
      when T is uint16:
        data: array[(high(uint16)+1) div 32, uint32]


proc incl*[T](self: var FastSet[T], v: T)
proc excl*[T](self: var FastSet[T], v: T)
proc `*`*[T](a, b: FastSet[T]): FastSet[T]
proc `+=`*[T](a: var FastSet[T], b: FastSet[T])
proc `-=`*[T](a: var FastSet[T], b: FastSet[T])
proc `+`*[T](a, b: FastSet[T]): FastSet[T]
proc `-`*[T](a, b: FastSet[T]): FastSet[T]
proc `==`*[T](a, b: FastSet[T]): bool
proc intersects*[T](a, b: FastSet[T]): bool
proc empty*[T](a: FastSet[T]): bool
proc contains*[T](a: FastSet[T], x: T): bool
#proc contains*[T](a, b: FastSet[T]): bool
proc card*[T](a: FastSet[T]): int
proc pop*[T](a: var FastSet[T]): T
proc clear*[T](a: var FastSet[T])
export items

from bitops import popcount, countLeadingZeroBits, countTrailingZeroBits

proc incl[T](self: var FastSet[T], v: T) =
  var i = v mod 32
  var bn = (v div 32).int
  when seqs:
    if self.data.isNil():
      self.data = newSeq[uint32](bn+1)
    self.data.setLen(max(self.data.len(), bn+1))
  else:
    self.maxbyte = max(bn, self.maxbyte)
  self.data[bn] = self.data[bn] or (0x1'u32 shl i)
proc excl[T](self: var FastSet[T], v: T) =
  var i = v mod 32
  var bn = (v div 32).int
  when seqs:
    if self.data.isNil or self.data.len <= bn:
      return
  self.data[bn] = self.data[bn] and (0xFFFFFFFF'u32 xor (0x1'u32 shl i))
proc `==`[T](a, b: FastSet[T]): bool =
  when seqs:
    let (least, maxbyte) =
      if a.data.len() > b.data.len():
        (a.data, b.data.len-1)
      elif a.data.len() < b.data.len():
        (b.data, a.data.len-1)
      else:
        (nil, b.data.len-1)
    for i in (maxbyte+1)..<least.len:
      if least[i] != 0: return false
  else:
    let maxbyte = max(a.maxbyte, b.maxbyte)
  for i in 0..maxbyte:
    if a.data[i] != b.data[i]:
      return false
  return true
#{.push checks:off.}
proc intersects[T](a, b: FastSet[T]): bool =
  when seqs:
    if a.data.isNil or b.data.isNil:
      return false
    let maxbyte = min(a.data.len, b.data.len) - 1
  else:
    let maxbyte = min(a.maxbyte, b.maxbyte)
  for i in 0..maxbyte:
    if (b.data[i] and a.data[i]) != 0'u32:
      return true
  return false
#{.pop.}
proc `*`[T](a, b: FastSet[T]): FastSet[T] =
  when seqs:
    if a.data.isNil or b.data.isNil:
      return
    let maxbyte = min(a.data.len, b.data.len) - 1
    result.data = newSeq[uint32](maxbyte + 1)
  else:
    let maxbyte = min(a.maxbyte, b.maxbyte)
  for i in 0..maxbyte:
    result.data[i] = b.data[i] and a.data[i]
proc `+=`[T](a: var FastSet[T], b: FastSet[T]) =
  when seqs:
    let maxbyte = b.data.len - 1
    if b.data.isNil():
      return
    elif a.data.isNil:
      a.data.deepCopy(b.data)
      return
    elif b.data.len > a.data.len:
      a.data.setLen(b.data.len)
  else:
    let maxbyte = max(a.maxbyte, b.maxbyte)
    a.maxbyte = maxbyte
  for i in 0..maxbyte:
    a.data[i] = a.data[i] or b.data[i]
proc `+`[T](a, b: FastSet[T]): FastSet[T] =
  result.deepCopy(a)
  result += b
proc `-=`[T](a: var FastSet[T], b: FastSet[T]) =
  when seqs:
    let maxbyte = min(a.data.len, b.data.len) - 1
  else:
    let maxbyte = a.maxbyte
  for i in 0..maxbyte:
    a.data[i] = (0xFFFFFFFF'u32 xor b.data[i]) and a.data[i]
proc `-`[T](a, b: FastSet[T]): FastSet[T] =
  result.deepCopy(a)
  result -= b
proc empty[T](a: FastSet[T]): bool =
  when seqs:
    if a.data.isNil() or a.data.len() == 0:
      return true
    let maxbyte = a.data.len - 1
  else:
    let maxbyte = a.maxbyte
  for i in 0..maxbyte:
    if a.data[i] > 0'u32:
      return false
  return true

proc contains[T](a: FastSet[T], x: T): bool =
  let bn = int(x div 32)
  let bitn = x mod 32
  when seqs:
    if a.data.isNil() or a.data.len <= bn:
      return false
  (a.data[bn] and (1'u32 shl bitn)) > 0'u32
#proc contains[T](a, b: FastSet[T]): bool =
#  when seqs:
#    if b.isNil: return true
#    elif a.isNil: return false
#    let maxbyte = max(a.data.len(), b.data.len())
#  else:
#    let maxbyte = max(a.maxbyte, b.maxbyte)
#  for i in 0..maxbyte:
#    let achunk: uint32 =
#      if i >= a.data.len: 0
#      else: a.data[i]
#    let bchunk: uint32 =
#      if i >= b.data.len: 0
#      else: b.data[i]
#    if a.data[i] and achunk != bchunk:
#      return false
#  return true

proc card[T](a: FastSet[T]): int =
  when seqs:
    if a.data.isNil or a.data.len == 0:
      return 0
    let maxbyte = a.data.len()-1
  else:
    let maxbyte = a.maxbyte
  for i in 0..maxbyte:
    result += popcount(a.data[i])
#proc pickImpl[T](a: FastSet[T]): tuple[val: T, valid: bool] =
#  for i in 0..a.maxbyte:
#    if a.data[i] == 0:
#      result.val += 32
#      continue
#    else:
#      result.val += countTrailingZeroBits(a.data[i]).T
#      result.valid = true
#      return
proc popImpl[T](a: var FastSet[T]): tuple[val: T, valid: bool] =
  result.valid = false
  when seqs:
    if a.data.isNil or a.data.len == 0:
      return
    let maxbyte = a.data.len() - 1
  else:
    let maxbyte = a.maxbyte
  for i in 0..maxbyte:
    if a.data[i] == 0:
      result.val += 32
      continue
    else:
      let bitn = countTrailingZeroBits(a.data[i])
      result.val += bitn.T
      a.data[i] = a.data[i] xor (1'u32 shl bitn)
      result.valid = true
      return
proc pop[T](a: var FastSet[T]): T =
  let r = popImpl(a)
  if r.valid:
    return r.val
  else:
    raise newException(IndexError, "Set is empty!")

proc clear[T](a: var FastSet[T]) =
  a.reset()

iterator items*[T](s: FastSet[T]): T =
  when seqs:
    let maxbyte =
      if s.data.isNil: -1
      else: s.data.len() - 1
  else:
    let maxbyte = s.maxbyte
  if maxbyte >= 0:
    var x = s.data
    for byten in 0..maxbyte:
      while x[byten] != 0'u32:
        let bitn = countTrailingZeroBits(x[byten])
        yield (bitn + byten * 32).T
        x[byten] = x[byten] xor (1'u32 shl bitn)
when isMainModule:
  var a: FastSet[uint8]
  assert(a.empty())
  a.incl(5'u8)
  #echo a.card()
  assert(a.card() == 1)
  a.incl(80'u8)
  a.incl(150'u8)
  #echo a.card()
  assert(a.card() == 3)
  assert(80'u8 in a)
  for i in a:
    assert(i in a)
    #echo i
  assert(a.pop() == 5)
  a.excl(80'u8)
  a.excl(130'u8)
  #echo a.card()
  #echo a.empty()
  assert(a.card() == 1)
  #echo a.pop()
  assert(a.pop() == 150)

