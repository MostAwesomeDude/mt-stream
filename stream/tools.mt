exports (wrapStream)

def wrapStream(stream) as DeepFrozen:
    "Wrap a stream with a bevy of useful tools."

    return object wrappedStream extends stream:
        "A stream with many useful methods."

        to _printOn(out):
            super._printOn(out)

        to size():
            def sizeFold(counter :Int, _) :Int:
                return counter + 1
            return stream<-fold(sizeFold, 0)

        to asList():
            def listFold(l :List, x) :List:
                return l.with(x)
            return stream<-fold(listFold, [])
