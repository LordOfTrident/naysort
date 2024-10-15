import std/math

import malebolgia/lockers

import utils

type
    Sorter*    = proc (values: Locker[seq[int]], hook: Hook) {.gcsafe.}
    Hook*      = proc (swaps, bounds: (int, int)) {.gcsafe.}
    Interrupt* = ref object of CatchableError

    Algorithm* = object
        name*:   string
        sorter*: Sorter

proc len(values: Locker[seq[int]]): int =
    lock values as values:
        result = values.len

proc `[]`*(values: Locker[seq[int]], at: int): int =
    lock values as values:
        result = values[at]

proc bubbleSort*(values: Locker[seq[int]], hook: Hook) =
    let valuesCount = values.len

    for i in 0 ..< valuesCount:
        var swapped = false
        for j in 1 ..< valuesCount - i:
            lock values as values:
                if values[j] > values[j - 1]:
                    swap values[j], values[j - 1]
                    swapped = true
            hook((j, j - 1), (valuesCount - i, -1))

        if not swapped:
            break


proc quickSort(values: Locker[seq[int]], first, last: int, hook: Hook) =
    if first >= last:
        return

    proc partition(values: Locker[seq[int]], first, last: int): int =
        result = first - 1
        for i in first ..< last:
            lock values as values:
                if values[i] > values[last]:
                    inc  result
                    swap values[i], values[result]
            hook((i, result), (first, last))

        lock values as values:
            inc  result
            swap values[last], values[result]
        hook((last, result), (first, -1))

    let pivot = values.partition(first, last)
    values.quicksort(first,     pivot - 1, hook)
    values.quicksort(pivot + 1, last,      hook)

proc quickSort*(values: Locker[seq[int]], hook: Hook) = values.quicksort(0, values.len - 1, hook)

proc selectionSort*(values: Locker[seq[int]], hook: Hook) =
    let valuesCount = values.len

    for i in 0 ..< valuesCount:
        var smallest = i
        for j in i + 1 ..< valuesCount:
            lock values as values:
                if values[j] > values[smallest]:
                    smallest = j
            hook((smallest, j), (i, -1))

        lock values as values:
            swap values[i], values[smallest]
        hook((smallest, i), (-1, -1))

proc mergeSort(values: Locker[seq[int]], first, last: int, hook: Hook) =
    if first >= last:
        return

    proc merge(values: Locker[seq[int]], first, last, pivot: int) =
        var a, b: seq[int]
        lock values as values:
            a = values[first     .. pivot].copy()
            b = values[pivot + 1 .. last].copy()

        var
            i = 0
            j = 0
            k = first
        while i < a.len and j < b.len:
            if a[i] > b[j]:
                lock values as values:
                    values[k] = a[i]
                hook((k, i + first), (first, last))
                inc i
            else:
                lock values as values:
                    values[k] = b[j]
                hook((k, j + first), (first, last))
                inc j
            inc k

        while i < a.len:
            lock values as values:
                values[k] = a[i]
            inc i
            inc k

        while j < b.len:
            lock values as values:
                values[k] = b[j]
            inc j
            inc k

    let pivot = first + (last - first) div 2
    values.mergeSort(first,     pivot, hook)
    values.mergeSort(pivot + 1, last,  hook)

    values.merge(first, last, pivot)

proc mergeSort*(values: Locker[seq[int]], hook: Hook) = values.mergeSort(0, values.len - 1, hook)

proc insertionSort*(values: Locker[seq[int]], hook: Hook) =
    let valuesCount = values.len

    for i in 0 ..< valuesCount:
        let key = values[i]
        var j = i - 1

        while j >= 0 and values[j] < key:
            lock values as values:
                values[j + 1] = values[j]
            hook((j + 1, j), (i, -1))

            dec j

        lock values as values:
            values[j + 1] = key

proc heapSort*(values: Locker[seq[int]], hook: Hook) =
    let valuesCount = values.len

    proc heapify(values: Locker[seq[int]], n, i: int) =
        var
            largest = i
            left    = i * 2 + 1
            right   = left + 1

        lock values as values:
            if (left < n and values[left] < values[largest]):
                largest = left

            if (right < n and values[right] < values[largest]):
                largest = right

        if largest != i:
            lock values as values:
                swap values[i], values[largest]
            hook((i, largest), (n, -1))

            values.heapify(n, largest)

    for i in countdown(valuesCount div 2 - 1, 0):
        values.heapify(valuesCount, i)

    for i in countdown(valuesCount - 1, 1):
        lock values as values:
            swap values[0], values[i]

        values.heapify(i, 0)

proc cocktailSort*(values: Locker[seq[int]], hook: Hook) =
    let valuesCount = values.len

    var
        first   = 0
        last    = valuesCount - 1
        swapped = true
    while swapped:
        swapped = false
        for i in first ..< last:
            lock values as values:
                if values[i] < values[i + 1]:
                    swap values[i], values[i + 1]
                    swapped = true

            hook((i, i + 1), (first, last - 1))

        if not swapped:
            break

        dec last

        swapped = false
        for i in countdown(last - 1, first):
            lock values as values:
                if values[i] < values[i + 1]:
                    swap values[i], values[i + 1]
                    swapped = true

            hook((i, i + 1), (first, last - 1))

        inc first

let sortAlgos* = [
    Algorithm(name: "bubblesort",      sorter: bubbleSort),
    Algorithm(name: "selectionsort",   sorter: selectionSort),
    Algorithm(name: "insertionsort",   sorter: insertionSort),
    Algorithm(name: "quicksort",       sorter: quickSort),
    Algorithm(name: "mergesort",       sorter: mergeSort),
    Algorithm(name: "heapsort",        sorter: heapsort),
    Algorithm(name: "cocktailsort",    sorter: cocktailSort),
]
