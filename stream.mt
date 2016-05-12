import "unittest" =~ [=> unittest]
import "stream/tools" =~ [=> wrapStream :DeepFrozen]
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

object makeStream as DeepFrozen:
    "Produce streams of values."

    to run(stream):
        return when (stream) -> {
            wrapStream(if (_equalizer.sameYet(stream, null)) {
                nullStream
            } else {
                def [value, resume, next] := stream
                object valueStream {
                    to _printOn(out) {
                        out.print(`[$value, $next]`)
                    }

                    to map(f) {
                        # As an optimization, pass the resumer directly
                        # onwards. To keep track of errors, and to allow
                        # returning promises, use a when-block.
                        return when (def p := f<-(value)) -> {
                            makeStream([p, resume, next<-map(f)])
                        }
                    }

                    to fold(f, x) {
                        def p := f<-(x, value)
                        return when (resume<-(true), p) -> { next<-fold(f, p) }
                    }

                    to filter(f) {
                        return if (f(value)) {
                            makeStream([value, resume, next<-filter(f)])
                        } else {
                            when (resume<-(true)) -> {
                                next<-filter(f)
                            }
                        }
                    }

                    to zip(stream) {
                        # We've gotta unwrap. Assume it responds to
                        # .asStream/0.
                        return when (stream) -> {
                            when (def p := stream<-asStream()) -> {
                                if (_equalizer.sameYet(p, null)) {
                                    nullStream
                                } else {
                                    def [v, r, n] := p
                                    makeStream([[value, v],
                                                fn b {resume(b); r(b)},
                                                next<-zip(n)])
                                }
                            }
                        }
                    }

                    to asStream() {
                        return stream
                    }
                }
            })
        }

    to unfold(f):
        return escape ej:
            def value := f(ej)
            def [p, r] := Ref.promise()
            var once :Bool := false
            def resume(b):
                if (once):
                    return
                once := true
                if (b):
                    r.resolve(makeStream.unfold(f), false)
                else:
                    r.smash("makeStream.unfold/1: Cancelled")
            makeStream([value, resume, p])
        catch _:
            makeStream(null)

    to fromIterator(iterator):
        return makeStream.unfold(iterator.next)

    to fromIterable(iterable):
        return makeStream.fromIterator(iterable._makeIterator())

def testStreamAsList(assert):
    def stream := makeStream.fromIterable([1, 2, 3, 4, 5])
    def snd([_, x]) {return x}
    return when (def l := stream<-map(snd)<-asList()) ->
        assert.equal(l, [1, 2, 3, 4, 5])

def testStreamSize(assert):
    def stream := makeStream.fromIterable([1, 2, 3, 4, 5])
    return when (def size := stream<-size()) ->
        assert.equal(size, 5)

unittest([
    testStreamAsList,
    testStreamSize,
])

def main(argv) as DeepFrozen:
    def l := makeStream.fromIterable([1, 2, 3, 4, 5])
    def p := l<-map(fn [_, x] {x})<-map(fn x {x + 1})
    def z := l<-zip(p)<-asList()
    traceln(`Before: $l, $p, $z`)
    return when (z) ->
        traceln(`After: $l, $p, $z`)
        when (null) -> {0}
    catch p:
        traceln.exception(p)
        1
