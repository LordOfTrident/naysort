import std/[random, math, strformat, sequtils, strutils]

import raylib as ray, malebolgia/lockers

import algorithms, timers, utils

type StateKind = enum
    StateIdle
    StateIntro
    StateRandomizing
    StateSorting
    StatePaused

const
    graphWidth   = 150
    graphHeight  = 500
    spacing      = 5
    padding      = 10
    winMinWidth  = graphWidth
    winMinHeight = graphWidth div 2
    title        = "naysort"

    fgColor    = hexColor 0xF5FEFF
    bgColor1   = hexColor 0x3A3D59
    bgColor2   = hexColor 0x2C2A46
    graphColor = hexColor 0x30B7C0

var
    winWidth:  int32 = graphWidth * spacing
    winHeight: int32 = graphHeight

    randomizeTimer: Timer
    current     = 0
    sortTimeMs  = -1.0.initLocker()
    hookDelayMs = 2.0
    state       = StateIntro.initLocker()
    graph       = newSeqWith[int](graphWidth, graphHeight div 2).initLocker()
    its         = [-1, -1, -1, -1].initLocker()

    thread: Thread[Algorithm]

proc setState(kind: StateKind) =
    lock state as state:
        state = kind

proc getState(): StateKind =
    lock state as state:
        result = state

proc getGraphPoints(): seq[Vector2] =
    lock graph as graph:
        result = newSeq[Vector2](graph.len)
        for x, y in graph:
            result[x] = Vector2(
                x: x / graphWidth  * (winWidth  - padding * 2).float + padding,
                y: y / graphHeight * (winHeight - padding * 2).float + padding,
            )

proc hook(swaps, bounds: (int, int)) =
    lock its as its:
        (its[0], its[1]) = swaps
        (its[2], its[3]) = bounds

    while true:
        if getState() != StatePaused:
            break

    delayMsWith(hookDelayMs):
        if getState() == StateIdle or ray.windowShouldClose():
            raise Interrupt()

proc runAlgorithm(algo: Algorithm) {.thread.} =
    let start = ray.getTime()

    setState(StateSorting)
    defer: setState(StateIdle)

    try: algo.sorter(graph, hook) except Interrupt: discard

    lock sortTimeMs as sortTimeMs:
        sortTimeMs = (ray.getTime() - start) * 1000

proc sortGraph() =
    lock graph as graph:
        if graph.isSorted():
            return

    # Using basic Nim threads instead of malebolgia because malebolgia spawn gives weird warnings
    # and errors but this does not
    thread.createThread(runAlgorithm, sortAlgos[current])
    # With malebolgia master.spawn runAlgorithm(sortAlgos[current]) i get:
    # Warning: `=destroy`(dest.value) can raise an unlisted exception: Exception
    # Error: expression cannot be isolated: sortAlgos[current]

proc randomizeGraph() =
    var a, b: seq[int]
    lock graph as graph:
        a = graph.copy()
        b = randomGraph(graphWidth, graphHeight)

    randomizeTimer = newTimer(milliseconds = 500, proc (timer: var Timer) =
        lock graph as graph:
            for x, _ in graph:
                graph[x] = lerp(a[x].float, b[x].float, easeInOutQuad(timer.progress())).int

        if timer.isDone():
            setState(StateIdle)
    )

    setState(StateRandomizing)

proc input() =
    if ray.isWindowResized():
        winWidth  = ray.getScreenWidth()
        winHeight = ray.getScreenHeight()

    if ray.isKeyDown(Down):
        hookDelayMs -= 2 * getFrameTime()
        if hookDelayMs <= 0:
            hookDelayMs = 0

    if ray.isKeyDown(Up):
        hookDelayMs += 2 * getFrameTime()
        if hookDelayMs >= 100:
            hookDelayMs = 100

    case getState()
    of StateIdle, StateRandomizing:
        if ray.isKeyPressed(Left):
            if current == 0:
                current = sortAlgos.len
            dec current

        if ray.isKeyPressed(Right):
            inc current
            if current == sortAlgos.len:
                current = 0

        if ray.isKeyPressed(Enter):
            sortGraph()

        if ray.isKeyPressed(Space):
            randomizeGraph()

    of StateSorting:
        if ray.isKeyPressed(Enter):
            setState(StateIdle)

        if ray.isKeyPressed(Space):
            setState(StatePaused)

    of StatePaused:
        if ray.isKeyPressed(Enter):
            setState(StateIdle)

        if ray.isKeyPressed(Space):
            setState(StateSorting)

    of StateIntro:
        if ray.isKeyPressed(Enter):
            randomizeGraph()

proc renderIterators(points: seq[Vector2]) =
    lock its as its:
        for i, it in its:
            if it < 0 or it >= points.len:
                continue
            let
                color = ray.colorAlpha(ray.colorFromHSV(i / 4 * 360, 0.7, 1), 0.8)
                point = points[it]

            ray.drawLine(Vector2(x: point.x, y: padding),
                         Vector2(x: point.x, y: (winHeight - padding).float), 2, color)
            ray.drawCircle(point, 3, fgColor)

proc renderGraph() =
    let points = getGraphPoints()
    ray.drawSplineLinear(points, 2, graphColor)

    if getState() in [StateSorting, StatePaused]:
        renderIterators(points)

proc render() =
    ray.drawRectangleGradientV(0, 0, winWidth, winHeight, bgColor1, bgColor2)

    renderGraph()

    ray.drawText(sortAlgos[current].name.cstring, 10, winHeight - 40, 30, fgColor)
    ray.drawText((&"delay (ms): {hookDelayMs.formatFloat(ffDecimal, 2)}").cstring,
                 10, winHeight - 70, 30, ray.colorAlpha(fgColor, 0.5))

    case getState()
    of StateIdle:
        lock sortTimeMs as sortTimeMs:
            if sortTimeMs > 0:
                # String interpolation does not work with locked variable for some reason, so this
                # is a simple workround
                let formatted = sortTimeMs.formatFloat(ffDecimal, 2)
                ray.drawText((&"Sort time (ms): {formatted}").cstring, 10, 10, 30, fgColor)

    of StateRandomizing:
        ray.drawText("Randomizing...", 10, 10, 30, fgColor)

    of StateSorting:
        ray.drawText("sorting...", 10, 10, 30, fgColor)
        ray.drawText((&"FPS (vsync): {ray.getFPS()}").cstring, 10, 40, 30, ray.colorAlpha(fgColor, 0.5))

    of StatePaused:
        ray.drawText("paused", 10, 10, 30, fgColor)

    of StateIntro:
        ray.drawRectangle(0, 0, winWidth, winHeight, ray.colorAlpha(Black, 0.5))
        ray.drawText("""
SPACE - Randomize graph/pause sorting
ENTER - Sort graph/interrupt sorting
ESCAPE - Quit
HORIZONTAL ARROWS - Switch algorithm
VERTICAL ARROWS - Change sorting speed

Press enter to close this message
""", 10, 10, 30, fgColor)

proc update() =
    if getState() == StateRandomizing:
        randomizeTimer.update(getFrameTime() * 1000)

proc audioStreamCallback(raw: pointer, framesCount: uint32) {.cdecl.} =
    if getState() != StateSorting:
        return

    # I have no idea how any audio and frequency stuff works, this is something i somehow hacked
    # together by experimenting and it sounds ok enough. Dont think i can do better
    var
        a {.global.} = 0
        b {.global.} = 0.0

    var value: float
    lock its as its:
        lock graph as graph:
            value = 1.0 - graph[its[0]] / graphHeight

    var buf = cast[ptr UncheckedArray[uint16]](raw)
    for i in 0 ..< framesCount:
        buf[i] = (18000.0 * sin(a.float * (value / 4)) ^ 2 + sin(b) * 100).uint16
        inc a
        b += 0.0005

proc main() =
    randomize()

    ray.setConfigFlags(flags(WindowResizable))
    ray.setConfigFlags(flags(Msaa4xHint))
    ray.setConfigFlags(flags(VsyncHint))

    ray.initWindow(winWidth, winHeight, title)
    ray.setWindowMinSize(winMinWidth, winMinHeight)
    defer: ray.closeWindow()

    ray.initAudioDevice()
    defer: ray.closeAudioDevice()

    ray.setAudioStreamBufferSizeDefault(1024)
    let audioStream = ray.loadAudioStream(44100, 16, 1)
    audioStream.setAudioStreamVolume(1.0)
    audioStream.setAudioStreamCallback(audioStreamCallback)
    audioStream.playAudioStream()
    defer: audioStream.stopAudioStream()

    while not ray.windowShouldClose():
        input()
        ray.drawing: render()
        update()

    if getState() == StateSorting:
        thread.joinThread()

when isMainModule:
    main()
