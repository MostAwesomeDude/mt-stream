exports (wrapStream)

def wrapStream(Stream, makeStream, stream) as DeepFrozen:
    "Wrap a stream with a bevy of useful tools."

    return object wrappedStream extends stream as Stream:
        "A stream with many useful methods."

        to _printOn(out):
            super._printOn(out)

        to asList():
            def listFold(l :List, x) :List:
                return l.with(x)
            return stream<-fold(listFold, [])

        to size():
            def sizeFold(counter :Int, _) :Int:
                return counter + 1
            return stream<-fold(sizeFold, 0)

        to mapVia(transformer):
            "Apply a via-like transformation to the stream, discarding any
             elements which don't apply."

            object sentinel {}
            def viaMap(x):
                return escape ej { transformer(x, ej) } catch _ { sentinel }
            return stream<-map(viaMap)<-filter(fn x { x != sentinel })
