from math import pow

type
  FastSet*[T: uint8 | uint16] = object
    maxbyte: int
    when T is uint8:
      data: array[(high(uint8)+1) div 32, uint32]
    when T is uint16:
      data: array[(high(uint16)+1) div 32, uint32]


proc incl*[T](self: var FastSet[T], v: T)
proc excl*[T](self: var FastSet[T], v: T)
proc `*`*[T](a, b: FastSet[T]): FastSet[T]
proc `+`*[T](a, b: FastSet[T]): FastSet[T]
proc `-`*[T](a, b: FastSet[T]): FastSet[T]
proc `==`*[T](a, b: FastSet[T]): bool
proc empty*[T](a: FastSet[T]): bool
proc contains*[T](a: FastSet[T], x: T): bool
proc contains*[T](a, b: FastSet[T]): bool
proc card*[T](a: FastSet[T]): int
proc pop*[T](a: var FastSet[T]): T
proc clear*[T](a: var FastSet[T])
export items

from bitops import popcount, countLeadingZeroBits, countTrailingZeroBits

proc incl[T](self: var FastSet[T], v: T) =
  var i = v mod 32
  var bn = (v div 32).int
  self.maxbyte = max(bn, self.maxbyte)
  self.data[bn] = self.data[bn] or (0x1'u32 shl i)
proc excl[T](self: var FastSet[T], v: T) =
  var i = v mod 32
  var bn = v div 32
  self.data[bn] = self.data[bn] and (0xFFFFFFFF'u32 xor (0x1'u32 shl i))
proc `==`[T](a, b: FastSet[T]): bool =
  let maxbyte = max(a.maxbyte, b.maxbyte)
  for i in 0..maxbyte:
    if a.data[i] != b.data[i]:
      return false
  return true
proc `*`[T](a, b: FastSet[T]): FastSet[T] =
  result.maxbyte = max(a.maxbyte, b.maxbyte)
  for i in 0..result.maxbyte:
    result.data[i] = b.data[i] and a.data[i]
proc `+`[T](a, b: FastSet[T]): FastSet[T] =
  result.maxbyte = max(a.maxbyte, b.maxbyte)
  for i in 0..result.maxbyte:
    result.data[i] = b.data[i] or a.data[i]
proc `-`[T](a, b: FastSet[T]): FastSet[T] =
  result.maxbyte = a.maxbyte
  for i in 0..result.maxbyte:
    result.data[i] = (0xFFFFFFFF'u32 xor b.data[i]) and a.data[i]
proc empty[T](a: FastSet[T]): bool =
  for i in 0..a.maxbyte:
    if a.data[i] > 0'u32:
      return false
  return true

proc contains[T](a: FastSet[T], x: T): bool =
  let bn = x div 32
  let bitn = x mod 32
  (a.data[bn] and (1'u32 shl bitn)) > 0'u32
proc contains[T](a, b: FastSet[T]): bool =
  let maxbyte = max(a.maxbyte, b.maxbyte)
  for i in 0..maxbyte:
    if a.data[i] and b.data[i] != b.data[i]:
      return false
  return true

proc card[T](a: FastSet[T]): int =
  for i in 0..a.maxbyte:
    result += popcount(a.data[i])
proc pickImpl[T](a: FastSet[T]): tuple[val: T, valid: bool] =
  for i in 0..a.maxbyte:
    if a.data[i] == 0:
      result.val += 32
      continue
    else:
      result.val += countTrailingZeroBits(a.data[i]).T
      result.valid = true
      return
proc popImpl[T](a: var FastSet[T]): tuple[val: T, valid: bool] =
  result.valid = false
  for i in 0..a.maxbyte:
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
   var x = s.data
   for byten in 0..s.maxbyte:
    if x[byten] == 0:
      continue
    else:
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

