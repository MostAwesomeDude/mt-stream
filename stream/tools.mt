exports (wrapStream)

def wrapStream(makeStream, stream) as DeepFrozen:
    "Wrap a stream with a bevy of useful tools."

    return object wrappedStream extends stream:
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
