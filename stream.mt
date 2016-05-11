exports (main)

object nullStream as DeepFrozen:
    to _printOn(out):
        out.print("null")

    to map(_):
        return nullStream

    to fold(_, x):
        return x

    to filter(_):
        return nullStream

    to zip(_):
        return nullStream

    to asStream():
        return null

    to asList():
        return []

object makeStream as DeepFrozen:
    "Produce streams of values."

    to run(stream):
        return when (stream) ->
            if (_equalizer.sameYet(stream, null)):
                nullStream
            else:
                def [value, resume, next] := stream
                var resumed :Bool := false
                def resumeOnce():
                    return if (!resumed):
                        resumed := true
                        resume<-(true)
                object valueStream:
                    to _printOn(out):
                        out.print(`[$value, $next]`)

                    to map(f):
                        # Optimization: Pass the resumer directly onwards.
                        return makeStream([f(value), resume, next<-map(f)])

                    to fold(f, x):
                        return when (resumeOnce()) ->
                            next<-fold(f, f(x, value))

                    to filter(f):
                        return if (f(value)):
                            makeStream([value, resume, next<-filter(f)])
                        else:
                            when (resumeOnce()) ->
                                next<-filter(f)

                    to zip(stream):
                        # We've gotta unwrap. Assume it responds to
                        # .asStream/0.
                        return when (stream) ->
                            when (def p := stream<-asStream()) ->
                                if (_equalizer.sameYet(p, null)):
                                    nullStream
                                else:
                                    def [v, r, n] := p
                                    makeStream([[value, v],
                                                fn b {resume(b); r(b)},
                                                next<-zip(n)])

                    to asStream():
                        return stream

                    to asList():
                        return when (def xs := next<-asList()) ->
                            [value] + xs

    to unfold(f):
        return escape ej:
            def value := f(ej)
            def [p, r] := Ref.promise()
            def resume(b :Bool):
                if (b):
                    r.resolve(makeStream.unfold(f))
                else:
                    r.smash("makeStream.unfold/1: Cancelled")
            makeStream([value, resume, p])
        catch _:
            makeStream(null)

    to fromIterator(iterator):
        return makeStream.unfold(iterator.next)

    to fromIterable(iterable):
        return makeStream.fromIterator(iterable._makeIterator())

def main(argv) as DeepFrozen:
    def l := makeStream.fromIterable([1, 2, 3, 4, 5])
    def p := l<-map(fn [_, x] {x})<-map(fn x {x + 1})
    def q := p<-fold(fn x, y { x + y }, 0)
    def r := p<-filter(fn x {(x % 2) == 0})<-asList()
    def z := l<-zip(p)
    traceln(`Before: $l, $p, $q, $r, $z`)
    return when (p, q, r) ->
        traceln(`After: $l, $p, $q, $r, $z`)
        when (null) -> {0}
