import std/[math, random]

import raylib as ray

func easeInOutQuad*(t: float): float = (if t < 0.5: 2 * t ^ 2 else: t * (4 - 2 * t) - 1)
func lerp*(a, b, t: float): float = a * (1.0 - t) + b * t

proc takeOutRandom*[T](self: var seq[T]): T =
    assert self.len > 0
    let i = rand(self.len - 1)
    result = self[i]
    self.delete(i)

# Generates a random graph thats linear when sorted
#proc randomGraph*(w, h: int): seq[int] =
#    var linear = newSeq[int](w)
#    for x, _ in linear:
#        linear[x] = (x / w * h.float).round().int
#
#    result = newSeq[int](w)
#    for i, _ in result:
#        result[i] = linear.takeOutRandom()

proc randomGraph*(w, h: int): seq[int] =
    result = newSeq[int](w)
    for i, _ in result:
        result[i] = rand(h - 1)

func copy*[T](self: openarray[T]): seq[T] =
    result = newSeq[T](self.len)
    for i, value in self:
        result[i] = value

template delayMsWith*(ms: float, body: untyped): untyped =
    let start = ray.getTime()
    while ray.getTime() < start + ms / 1000:
        body

func hexColor*(color: int): Color = ray.getColor(color.uint32 shl 8 or 0xFF)

func isSorted*(self: openarray[int]): bool =
    for i in 1 ..< self.len:
        if self[i] > self[i - 1]:
            return false
    return true
