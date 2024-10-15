type Timer* = object
    time, now: float
    hook: proc (timer: var Timer)

proc newTimer*(milliseconds: float, hook: proc (timer: var Timer)): Timer =
    Timer(time: milliseconds, now: milliseconds, hook: hook)

proc progress*(self: var Timer): float = 1.0 - self.now / self.time

proc update*(self: var Timer, dt: float) =
    if self.now <= 0:
        return

    self.now -= dt
    if self.now <= 0:
        self.now = 0

    self.hook(self)

proc isDone*(self: var Timer): bool = self.now == 0
