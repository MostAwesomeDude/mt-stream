import "unittest" =~ [=> unittest]
import "stream/tools" =~ [=> wrapStream :DeepFrozen]
exports (main)

def snd([_, x]) as DeepFrozen:
    return x

def makeOnce(f) as DeepFrozen:
    var b :Bool := false
    return def once(x):
        if (!b):
            b := true
            f(x)

object makeStream as DeepFrozen:
    "Produce streams of values."

    to run(stream):
        return when (stream) -> {
            wrapStream(makeStream, if (_equalizer.sameYet(stream, null)) {
                object nullStream {
                    to _printOn(out) { out.print("null") }
                    to map(_) { return nullStream }
                    to fold(_, x) { return x }
                    to filter(_) { return nullStream }
                    to zip(_) { return nullStream }
                    to chain(stream) { return stream }
                    to asStream() { return null }

                    to scan(_, z) {
                        return makeStream([z, fn _ {null}, nullStream])
                    }
                }
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
                        return when (def p := stream<-asStream()) -> {
                            if (_equalizer.sameYet(p, null)) {
                                makeStream(null)
                            } else {
                                def [v, r, n] := p
                                makeStream([[value, v],
                                            fn b {resume(b); r(b)},
                                            next<-zip(n)])
                            }
                        }
                    }

                    to chain(stream) {
                        "Fuse two streams together lengthwise.

                         Named after itertools.chain(), because Haskell's (++) is
                         pronounced 'append'."

                        # As with .map(), cheat on resuming.
                        return makeStream([value, resume,
                                           next<-chain(stream)])
                    }

                    to scan(f, x) {
                        def [p, r] := Ref.promise()
                        def resumeScan(b :Bool) {
                            if (b) {
                                # Ugh, we gotta pass stuff on manually here.
                                # There's no way to auto-chain this that I
                                # know of.
                                when (def y := f<-(x, value)) -> {
                                    r.resolve(next<-scan(f, y), false)
                                } catch problem {
                                    r.smash(problem)
                                }
                            } else {
                                r.smash("stream.scan/2: Cancelled")
                            }
                        }
                        return makeStream([x, makeOnce(resumeScan), p])
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
            def resumeUnfold(b :Bool):
                if (b):
                    r.resolve(makeStream.unfold(f), false)
                else:
                    r.smash("makeStream.unfold/1: Cancelled")
            makeStream([value, makeOnce(resumeUnfold), p])
        catch _:
            makeStream(null)

    to fromIterator(iterator):
        return makeStream.unfold(iterator.next)

    to fromIterable(iterable):
        return makeStream.fromIterator(iterable._makeIterator())

def testStreamChain(assert):
    def first := makeStream.fromIterable([1, 2, 3])<-map(snd)
    def second := makeStream.fromIterable([4, 5, 6])<-map(snd)
    return when (def l := first<-chain(second)<-asList()) ->
        assert.equal(l, [1, 2, 3, 4, 5, 6])

def testStreamScan(assert):
    def stream := makeStream.fromIterable([1, 2, 3, 4, 5])<-map(snd)
    return when (def l := stream<-scan(fn x, y { x + y }, 0)<-asList()) ->
        assert.equal(l, [0, 1, 3, 6, 10, 15])

def testStreamAsList(assert):
    def stream := makeStream.fromIterable([1, 2, 3, 4, 5])<-map(snd)
    return when (def l := stream<-asList()) ->
        assert.equal(l, [1, 2, 3, 4, 5])

def testStreamSize(assert):
    def stream := makeStream.fromIterable([1, 2, 3, 4, 5])
    return when (def size := stream<-size()) ->
        assert.equal(size, 5)

def testStreamMapVia(assert):
    def stream := makeStream.fromIterable([1, 2, 3, 4, 5])<-map(snd)
    def v(x, ej):
        if (x % 2 == 0):
            ej()
        return x + 1
    return when (def l := stream<-mapVia(v)<-asList()) ->
        assert.equal(l, [2, 4, 6])

unittest([
    testStreamChain,
    testStreamScan,
    testStreamAsList,
    testStreamSize,
    testStreamMapVia,
])

def main(argv) as DeepFrozen:
    def l := makeStream.fromIterable([1, 2, 3, 4, 5])
    def p := l<-map(snd)<-map(fn x {x + 1})
    def z := l<-zip(p)<-asList()
    def y := l<-map(snd)<-scan(fn x, y {x + y}, 0)<-asList()
    traceln(`Before: $z, $y`)
    return when (z, y) ->
        traceln(`After: $z, $y`)
        when (null) -> {0}
    catch p:
        traceln.exception(p)
        1
