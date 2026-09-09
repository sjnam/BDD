//line zdd.w:42
package bdd

import (
	"iter"
	"math/big"
	"math/rand/v2"
	"slices"
)

//line zdd.w:63
type ZDD struct {
	base
	n int32 // 원소의 수
}

//line zdd.w:152
const (
	zopAnd     = int32(1)  // 교집합
	zopButnot  = int32(2)  // 차집합
	zopProd    = int32(5)  // 결합 $f\sqcup g$
	zopXor     = int32(6)  // 대칭차
	zopOr      = int32(7)  // 합집합
	zopCoprod  = int32(8)  // 만남 $f\sqcap g$
	zopQuot    = int32(9)  // 몫 $f/g$
	zopRem     = int32(10) // 나머지 $f\bmod g$
	zopDelta   = int32(11) // $f\mathbin{\Delta}g$
	zopDisprod = int32(12) // 서로소 결합
)

//line zdd.w:719
const (
	zternMux   = int32(0) // $f{?}\,g{:}\,h$
	zternMed   = int32(1) // $\langle fgh\rangle$
	zternAnd3  = int32(2) // $f\cap g\cap h$
	zternBuild = int32(3) // 노드 하나를 손수 짓는다
	zternSym   = int32(4) // 대칭 함수
)

//line zdd.w:77
func NewZDD(n int) *ZDD {
	b := &ZDD{n: int32(n)}
	b.init(true)

//line zdd.w:95
	for k := int32(0); k < b.n; k++ {
		b.newLevel(k)
		b.vars[k].name, b.vmap = k, append(b.vmap, k)
	}
	b.vars = append(b.vars, variable{name: -1, taut: topsink}) // 싱크의 자리
	b.mem[botsink].lvl, b.mem[topsink].lvl = b.n, b.n
	p := topsink
	for k := b.n - 1; k >= 0; k-- {
		if k < b.n-1 {
			b.ref(p) // 슬롯이 쥐고 있던 참조에 하나를 더해 둘을 만든다
		}
		r := b.uniqueFind(k, p, p)
		b.vars[k].taut = r
		b.vars[k].elt = b.uniqueFind(k, botsink, topsink)
		p = r
	}

//line zdd.w:81
	return b
}

//line zdd.w:117
func (b *ZDD) Empty() Func { return b.wrap(botsink) }

//line zdd.w:118
func (b *ZDD) Unit() Func { return b.wrap(topsink) }

func (b *ZDD) Universe() Func {
	b.drain()
	p := b.taut(0)
	b.ref(p)
	return b.wrap(p)
}

func (b *ZDD) N() int { return int(b.n) }

func (b *ZDD) taut(v int32) int32 { return b.vars[v].taut }

//line zdd.w:135
func (b *ZDD) Elt(k int) Func {
	b.drain()
	p := b.vars[b.level(int32(k))].elt
	b.ref(p)
	return b.wrap(p)
}

func (b *ZDD) Var(k int) Func {
	b.drain()
	return b.wrap(b.projection(b.level(int32(k))))
}

//line zdd.w:167
func (b *ZDD) binary(op int32, f, g Func) Func {
	p, q := b.node(f), b.node(g)
	b.drain()
	return b.wrap(b.binaryRec(op, p, q))
}

func (b *ZDD) binaryRec(op, f, g int32) int32 {
	switch op {
	case zopAnd:
		return b.andRec(f, g)
	case zopButnot:
		return b.butNotRec(f, g)
	case zopProd:
		return b.prodRec(f, g)
	case zopXor:
		return b.xorRec(f, g)
	case zopOr:
		return b.orRec(f, g)
	case zopCoprod:
		return b.coprodRec(f, g)
	case zopQuot:
		return b.quotRec(f, g)
	case zopRem:
		return b.remRec(f, g)
	case zopDelta:
		return b.deltaRec(f, g)
	}
	return b.disprodRec(f, g)
}

//line zdd.w:205
func (b *ZDD) andRec(f, g int32) int32 {
	vf, vg := b.mem[f].lvl, b.mem[g].lvl
	for vf != vg {
		if vf < vg {
			if g == botsink {
				return botsink
			}
			f = b.mem[f].lo
			vf = b.mem[f].lvl
		} else {
			if f == botsink {
				return botsink
			}
			g = b.mem[g].lo
			vg = b.mem[g].lvl
		}
	}

//line zdd.w:226
	if f == g {
		b.ref(f)
		return f
	}
	if f > g {
		f, g = g, f
	}
	if f == b.taut(vf) {
		b.ref(g)
		return g // $1\land g=g$
	}
	if g == b.taut(vf) {
		b.ref(f)
		return f
	}
	if r := b.cacheLookup(f, g, zopAnd); r != null {
		return r
	}
	r0 := b.andRec(b.mem[f].lo, b.mem[g].lo)
	r1 := b.andRec(b.mem[f].hi, b.mem[g].hi)
	return b.memo(f, g, zopAnd, b.uniqueFind(vf, r0, r1))

//line zdd.w:223
}

//line zdd.w:253
func (b *ZDD) orRec(f, g int32) int32 {
	if f == g {
		b.ref(f)
		return f
	}
	if f > g {
		f, g = g, f
	}
	if f == botsink {
		b.ref(g)
		return g
	}
	if r := b.cacheLookup(f, g, zopOr); r != null {
		return r
	}

//line zdd.w:272
	vf, vg := b.mem[f].lvl, b.mem[g].lvl
	var v, r0, r1 int32
	switch {
	case vf < vg:
		if v = vf; f == b.taut(vf) {
			b.ref(f)
			return f // $1\lor g=1$
		}
		r0, r1 = b.orRec(b.mem[f].lo, g), b.mem[f].hi
		b.ref(r1)
	case vg < vf:
		if v = vg; g == b.taut(vg) {
			b.ref(g)
			return g
		}
		r0, r1 = b.orRec(f, b.mem[g].lo), b.mem[g].hi
		b.ref(r1)
	default:
		if v = vg; g == b.taut(vg) {
			b.ref(g)
			return g
		}
		r0 = b.orRec(b.mem[f].lo, b.mem[g].lo)
		r1 = b.orRec(b.mem[f].hi, b.mem[g].hi)
	}
	return b.memo(f, g, zopOr, b.uniqueFind(v, r0, r1))

//line zdd.w:269
}

//line zdd.w:301
func (b *ZDD) xorRec(f, g int32) int32 {
	if f == g {
		return botsink
	}
	if f > g {
		f, g = g, f
	}
	if f == botsink {
		b.ref(g)
		return g
	}
	if r := b.cacheLookup(f, g, zopXor); r != null {
		return r
	}

//line zdd.w:319
	vf, vg := b.mem[f].lvl, b.mem[g].lvl
	var v, r0, r1 int32
	switch {
	case vf < vg:
		v, r1 = vf, b.mem[f].hi
		r0 = b.xorRec(b.mem[f].lo, g)
		b.ref(r1)
	case vg < vf:
		v, r1 = vg, b.mem[g].hi
		r0 = b.xorRec(f, b.mem[g].lo)
		b.ref(r1)
	default:
		v = vf
		r0 = b.xorRec(b.mem[f].lo, b.mem[g].lo)
		r1 = b.xorRec(b.mem[f].hi, b.mem[g].hi)
	}
	return b.memo(f, g, zopXor, b.uniqueFind(v, r0, r1))

//line zdd.w:316
}

//line zdd.w:344
func (b *ZDD) butNotRec(f, g int32) int32 {
	if f == g || f == botsink {
		return botsink
	}
	if g == botsink {
		b.ref(f)
		return f
	}
	vf, vg := b.mem[f].lvl, b.mem[g].lvl
	for vg < vf {
		g = b.mem[g].lo
		vg = b.mem[g].lvl
		if f == g {
			return botsink
		}
		if g == botsink {
			b.ref(f)
			return f
		}
	}

//line zdd.w:368
	if r := b.cacheLookup(f, g, zopButnot); r != null {
		return r
	}
	var r0, r1 int32
	if vf < vg {
		r0, r1 = b.butNotRec(b.mem[f].lo, g), b.mem[f].hi
		b.ref(r1)
	} else {
		r0 = b.butNotRec(b.mem[f].lo, b.mem[g].lo)
		r1 = b.butNotRec(b.mem[f].hi, b.mem[g].hi)
	}
	return b.memo(f, g, zopButnot, b.uniqueFind(vf, r0, r1))

//line zdd.w:365
}

//line zdd.w:384
func (b *ZDD) Union(f, g Func) Func { return b.binary(zopOr, f, g) }

//line zdd.w:385
func (b *ZDD) Intersect(f, g Func) Func { return b.binary(zopAnd, f, g) }

//line zdd.w:386
func (b *ZDD) Diff(f, g Func) Func { return b.binary(zopButnot, f, g) }

//line zdd.w:387
func (b *ZDD) Xor(f, g Func) Func { return b.binary(zopXor, f, g) }

//line zdd.w:402
func (b *ZDD) prodRec(f, g int32) int32 {
	if f > g {
		f, g = g, f
	}
	if f <= topsink {
		if f == botsink {
			return botsink // $\emptyset\sqcup g=\emptyset$
		}
		b.ref(g)
		return g // $\epsilon\sqcup g=g$
	}
	vf, vg := b.mem[f].lvl, b.mem[g].lvl
	v := vf
	if vf > vg {
		f, g, v = g, f, vg
	}
	if r := b.cacheLookup(f, g, zopProd); r != null {
		return r
	}

//line zdd.w:431
	var r0, r1 int32
	if vf != vg {
		r0 = b.prodRec(b.mem[f].lo, g)
		r1 = b.prodRec(b.mem[f].hi, g)
	} else {
		t := b.orRec(b.mem[g].lo, b.mem[g].hi)
		x := b.prodRec(b.mem[f].hi, t)
		b.deref(t)
		y := b.prodRec(b.mem[f].lo, b.mem[g].hi)
		r1 = b.orRec(x, y)
		b.deref(x)
		b.deref(y)
		r0 = b.prodRec(b.mem[f].lo, b.mem[g].lo)
	}
	return b.memo(f, g, zopProd, b.uniqueFind(v, r0, r1))

//line zdd.w:422
}

//line zdd.w:453
func (b *ZDD) disprodRec(f, g int32) int32 {
	if f > g {
		f, g = g, f
	}
	if f <= topsink {
		if f == botsink {
			return botsink
		}
		b.ref(g)
		return g
	}
	vf, vg := b.mem[f].lvl, b.mem[g].lvl
	v := vf
	if vf > vg {
		f, g, v = g, f, vg
	}
	if r := b.cacheLookup(f, g, zopDisprod); r != null {
		return r
	}

//line zdd.w:478
	var r0, r1 int32
	if vf != vg {
		r0 = b.disprodRec(b.mem[f].lo, g)
		r1 = b.disprodRec(b.mem[f].hi, g)
	} else {
		x := b.disprodRec(b.mem[f].hi, b.mem[g].lo)
		y := b.disprodRec(b.mem[f].lo, b.mem[g].hi)
		r1 = b.orRec(x, y)
		b.deref(x)
		b.deref(y)
		r0 = b.disprodRec(b.mem[f].lo, b.mem[g].lo)
	}
	return b.memo(f, g, zopDisprod, b.uniqueFind(v, r0, r1))

//line zdd.w:473
}

//line zdd.w:497
func (b *ZDD) coprodRec(f, g int32) int32 {
	if f > g {
		f, g = g, f
	}
	if f <= topsink {
		b.ref(f)
		return f // $\emptyset\sqcap g=\emptyset$, $\epsilon\sqcap g=\epsilon$
	}
	if r := b.cacheLookup(f, g, zopCoprod); r != null {
		return r
	}

//line zdd.w:515
	v, vf, vg := b.mem[f].lvl, b.mem[f].lvl, b.mem[g].lvl
	var r int32
	if vf != vg {
		if vf > vg {
			f, g = g, f
		}
		t := b.orRec(b.mem[f].lo, b.mem[f].hi)
		r = b.coprodRec(t, g)
		b.deref(t)
	} else {
		t := b.orRec(b.mem[f].lo, b.mem[f].hi)
		x := b.coprodRec(t, b.mem[g].lo)
		b.deref(t)
		y := b.coprodRec(b.mem[f].lo, b.mem[g].hi)
		r0 := b.orRec(x, y)
		b.deref(x)
		b.deref(y)
		r1 := b.coprodRec(b.mem[f].hi, b.mem[g].hi)
		r = b.uniqueFind(v, r0, r1)
	}
	return b.memo(f, g, zopCoprod, r)

//line zdd.w:509
}

//line zdd.w:544
func (b *ZDD) deltaRec(f, g int32) int32 {
	if f > g {
		f, g = g, f
	}
	if f <= topsink {
		if f == botsink {
			return botsink
		}
		b.ref(g)
		return g
	}
	vf, vg := b.mem[f].lvl, b.mem[g].lvl
	v := vf
	if vf > vg {
		f, g, v = g, f, vg
	}
	if r := b.cacheLookup(f, g, zopDelta); r != null {
		return r
	}

//line zdd.w:567
	var r0, r1 int32
	if vf != vg {
		r0 = b.deltaRec(b.mem[f].lo, g)
		r1 = b.deltaRec(b.mem[f].hi, g)
	} else {
		x := b.deltaRec(b.mem[f].lo, b.mem[g].hi)
		y := b.deltaRec(b.mem[f].hi, b.mem[g].lo)
		r1 = b.orRec(x, y)
		b.deref(x)
		b.deref(y)
		x = b.deltaRec(b.mem[f].hi, b.mem[g].hi)
		y = b.deltaRec(b.mem[f].lo, b.mem[g].lo)
		r0 = b.orRec(x, y)
		b.deref(x)
		b.deref(y)
	}
	return b.memo(f, g, zopDelta, b.uniqueFind(v, r0, r1))

//line zdd.w:564
}

//line zdd.w:599
func (b *ZDD) ezremRec(f, vg int32) int32 {
	vf := b.mem[f].lvl
	if vf == vg {
		r := b.mem[f].lo
		b.ref(r)
		return r
	}
	if vf > vg {
		b.ref(f)
		return f
	}
	e := b.vars[vg].elt
	if r := b.cacheLookup(f, e, zopRem); r != null {
		return r
	}
	r0 := b.ezremRec(b.mem[f].lo, vg)
	r1 := b.ezremRec(b.mem[f].hi, vg)
	return b.memo(f, e, zopRem, b.uniqueFind(vf, r0, r1))
}

//line zdd.w:620
func (b *ZDD) ezquotRec(f, vg int32) int32 {
	vf := b.mem[f].lvl
	if vf == vg {
		r := b.mem[f].hi
		b.ref(r)
		return r
	}
	if vf > vg {
		return botsink
	}
	e := b.vars[vg].elt
	if r := b.cacheLookup(f, e, zopQuot); r != null {
		return r
	}
	r0 := b.ezquotRec(b.mem[f].lo, vg)
	r1 := b.ezquotRec(b.mem[f].hi, vg)
	return b.memo(f, e, zopQuot, b.uniqueFind(vf, r0, r1))
}

//line zdd.w:643
func (b *ZDD) quotRec(f, g int32) int32 {
	switch {
	case g == topsink:
		b.ref(f)
		return f // $f/\epsilon=f$
	case g == botsink:
		p := b.taut(0)
		b.ref(p)
		return p // $f/\emptyset=\wp$
	case f <= topsink:
		return botsink
	case f == g:
		return topsink
	case b.mem[g].lo == botsink && b.mem[g].hi == topsink:
		return b.ezquotRec(f, b.mem[g].lvl) // $g$가 원소 하나다
	}
	if r := b.cacheLookup(f, g, zopQuot); r != null {
		return r
	}

//line zdd.w:666
	vg := b.mem[g].lvl
	f1 := b.ezquotRec(f, vg)
	r := b.quotRec(f1, b.mem[g].hi)
	b.deref(f1)
	if r != botsink && b.mem[g].lo != botsink {
		f0 := b.ezremRec(f, vg)
		r0 := b.quotRec(f0, b.mem[g].lo)
		b.deref(f0)
		r1 := r
		r = b.andRec(r1, r0)
		b.deref(r1)
		b.deref(r0)
	}
	return b.memo(f, g, zopQuot, r)

//line zdd.w:663
}

//line zdd.w:683
func (b *ZDD) remRec(f, g int32) int32 {
	switch {
	case g == botsink:
		b.ref(f)
		return f // $f\bmod\emptyset=f$
	case g == topsink:
		return botsink // $f\bmod\epsilon=\emptyset$
	case b.mem[g].lo == botsink && b.mem[g].hi == topsink:
		return b.ezremRec(f, b.mem[g].lvl)
	}
	if r := b.cacheLookup(f, g, zopRem); r != null {
		return r
	}
	q := b.quotRec(f, g)
	p := b.prodRec(q, g)
	b.deref(q)
	r := b.butNotRec(f, p)
	b.deref(p)
	return b.memo(f, g, zopRem, r)
}

//line zdd.w:708
func (b *ZDD) Join(f, g Func) Func { return b.binary(zopProd, f, g) }

//line zdd.w:709
func (b *ZDD) DisjointJoin(f, g Func) Func { return b.binary(zopDisprod, f, g) }

//line zdd.w:710
func (b *ZDD) Meet(f, g Func) Func { return b.binary(zopCoprod, f, g) }

//line zdd.w:711
func (b *ZDD) Delta(f, g Func) Func { return b.binary(zopDelta, f, g) }

func (b *ZDD) Quotient(f, g Func) Func { return b.binary(zopQuot, f, g) }

//line zdd.w:714
func (b *ZDD) Remainder(f, g Func) Func { return b.binary(zopRem, f, g) }

//line zdd.w:735
func (b *ZDD) muxRec(f, g, h int32) int32 {
	switch {
	case f == botsink:
		b.ref(h)
		return h
	case g == botsink:
		return b.butNotRec(h, f) // $(f{?}\,\emptyset{:}\,h)=h\setminus f$
	case h == botsink || f == h:
		return b.andRec(f, g)
	case f == g:
		return b.orRec(f, h)
	case g == h:
		b.ref(g)
		return g
	}
	vf, vg, vh := b.mem[f].lvl, b.mem[g].lvl, b.mem[h].lvl

//line zdd.w:756
	for {
		for vg < vf && vg < vh {
			g = b.mem[g].lo
			vg = b.mem[g].lvl
			switch {
			case g == botsink:
				return b.butNotRec(h, f)
			case f == g:
				return b.orRec(f, h)
			case g == h:
				b.ref(g)
				return g
			}
		}
		for vf < vg && vf < vh {
			f = b.mem[f].lo
			vf = b.mem[f].lvl
			switch {
			case f == botsink:
				b.ref(h)
				return h
			case f == h:
				return b.andRec(f, g)
			case f == g:
				return b.orRec(f, h)
			}
		}
		if !(vg < vf && vg < vh) {
			break
		}
	}

//line zdd.w:752

//line zdd.w:789
	v := min(vf, vg, vh)
	if f == b.taut(v) {
		b.ref(g)
		return g // $(1{?}\,g{:}\,h)=g$
	}
	if g == b.taut(v) {
		return b.orRec(f, h) // $(f{?}\,1{:}\,h)=f\cup h$
	}
	key := ternKey(h, zternMux)
	if r := b.cacheLookup(f, g, key); r != null {
		return r
	}
	var r0, r1 int32
	if v < vf { // 이때는 |v==vh|다
		g0 := g
		if vg == v {
			g0 = b.mem[g].lo
		}
		r0, r1 = b.muxRec(f, g0, b.mem[h].lo), b.mem[h].hi
		b.ref(r1)
	} else {

//line zdd.w:817
		g0, g1, h0, h1 := g, botsink, h, botsink
		if vg == v {
			g0, g1 = b.mem[g].lo, b.mem[g].hi
		}
		if vh == v {
			h0, h1 = b.mem[h].lo, b.mem[h].hi
		}
		r0 = b.muxRec(b.mem[f].lo, g0, h0)
		r1 = b.muxRec(b.mem[f].hi, g1, h1)

//line zdd.w:811
	}
	return b.memo(f, g, key, b.uniqueFind(v, r0, r1))

//line zdd.w:753
}

//line zdd.w:831
func (b *ZDD) medRec(f, g, h int32) int32 {
	vf, vg, vh := b.mem[f].lvl, b.mem[g].lvl, b.mem[h].lvl
	for {

//line zdd.w:857
		if vg < vf || (vg == vf && g < f) {
			f, g, vf, vg = g, f, vg, vf
		}
		if vh < vg || (vh == vg && h < g) {
			g, h, vg, vh = h, g, vh, vg
		}
		if vg < vf || (vg == vf && g < f) {
			f, g, vf, vg = g, f, vg, vf
		}

//line zdd.w:835
		switch {
		case h == botsink:
			return b.andRec(f, g) // $\langle fg\emptyset\rangle=f\cap g$
		case f == g:
			b.ref(f)
			return f
		case g == h:
			b.ref(g)
			return g
		}
		if vf >= vg {
			break
		}
		for vf < vg {
			f = b.mem[f].lo
			vf = b.mem[f].lvl
		}
	}

//line zdd.w:868
	key := ternKey(h, zternMed)
	if r := b.cacheLookup(f, g, key); r != null {
		return r
	}
	h0 := h
	if vh == vf {
		h0 = b.mem[h].lo
	}
	r0 := b.medRec(b.mem[f].lo, b.mem[g].lo, h0)
	var r1 int32
	if vf < vh {
		r1 = b.andRec(b.mem[f].hi, b.mem[g].hi)
	} else {
		r1 = b.medRec(b.mem[f].hi, b.mem[g].hi, b.mem[h].hi)
	}
	return b.memo(f, g, key, b.uniqueFind(vf, r0, r1))

//line zdd.w:854
}

//line zdd.w:888
func (b *ZDD) and3Rec(f, g, h int32) int32 {
	vf, vg, vh := b.mem[f].lvl, b.mem[g].lvl, b.mem[h].lvl
restart:
	for vf != vg {
		if vf < vg {
			if g == botsink {
				return botsink
			}
			f, vf = b.mem[f].lo, b.mem[b.mem[f].lo].lvl
		} else {
			if f == botsink {
				return botsink
			}
			g, vg = b.mem[g].lo, b.mem[b.mem[g].lo].lvl
		}
	}
	if f == g {
		return b.andRec(g, h)
	}

//line zdd.w:912
	for vf != vh {
		if vf < vh {
			if h == botsink {
				return botsink
			}
			f, g = b.mem[f].lo, b.mem[g].lo
			vf, vg = b.mem[f].lvl, b.mem[g].lvl
			goto restart
		}
		h, vh = b.mem[h].lo, b.mem[b.mem[h].lo].lvl
	}

//line zdd.w:908

//line zdd.w:947
	if f > g {
		f, g = g, f
	}
	if g > h {
		g, h = h, g
	}
	if f > g {
		f, g = g, f
	}

//line zdd.w:926
	switch {
	case f == g:
		return b.andRec(g, h)
	case g == h:
		return b.andRec(f, g)
	case f == b.taut(vf):
		return b.andRec(g, h)
	case g == b.taut(vf):
		return b.andRec(f, h)
	case h == b.taut(vf):
		return b.andRec(f, g)
	}
	key := ternKey(h, zternAnd3)
	if r := b.cacheLookup(f, g, key); r != null {
		return r
	}
	r0 := b.and3Rec(b.mem[f].lo, b.mem[g].lo, b.mem[h].lo)
	r1 := b.and3Rec(b.mem[f].hi, b.mem[g].hi, b.mem[h].hi)
	return b.memo(f, g, key, b.uniqueFind(vf, r0, r1))

//line zdd.w:909
}

//line zdd.w:962
func (b *ZDD) buildRec(f, g, h int32) int32 {
	if f <= topsink {
		b.ref(f)
		return f
	}
	vf := b.mem[f].lvl
	for b.mem[g].lvl <= vf {
		g = b.mem[g].lo
	}
	for b.mem[h].lvl <= vf {
		h = b.mem[h].lo
	}
	b.ref(g)
	b.ref(h)
	return b.uniqueFind(vf, g, h)
}

//line zdd.w:982
func (b *ZDD) ternary(op int32, f, g, h Func) Func {
	p, q, s := b.node(f), b.node(g), b.node(h)
	b.drain()
	switch op {
	case zternMux:
		return b.wrap(b.muxRec(p, q, s))
	case zternMed:
		return b.wrap(b.medRec(p, q, s))
	case zternAnd3:
		return b.wrap(b.and3Rec(p, q, s))
	}
	return b.wrap(b.buildRec(p, q, s))
}

func (b *ZDD) Ite(f, g, h Func) Func { return b.ternary(zternMux, f, g, h) }

//line zdd.w:997
func (b *ZDD) Median(f, g, h Func) Func { return b.ternary(zternMed, f, g, h) }

//line zdd.w:998
func (b *ZDD) And3(f, g, h Func) Func { return b.ternary(zternAnd3, f, g, h) }

func (b *ZDD) Build(e, lo, hi Func) Func {
	return b.ternary(zternBuild, e, lo, hi)
}

//line zdd.w:1016
func (b *ZDD) symfunc(p, v, k int32) int32 {
	vp := b.mem[p].lvl
	for vp < v {
		p = b.mem[p].lo
		vp = b.mem[p].lvl
	}
	if vp == b.n {

//line zdd.w:1035
		if k > 0 {
			return botsink
		}
		q := b.taut(v)
		b.ref(q)
		return q

//line zdd.w:1024
	}
	key := ternKey(b.taut(k), zternSym)
	if r := b.cacheLookup(p, b.taut(v), key); r != null {
		return r
	}

//line zdd.w:1048
	q := b.symfunc(b.mem[p].lo, vp+1, k)
	if k > 0 {
		r := b.symfunc(b.mem[p].lo, vp+1, k-1)
		q = b.uniqueFind(vp, q, r)
	}
	for vp > v {
		vp--
		b.ref(q)
		q = b.uniqueFind(vp, q, q)
	}
	return b.memo(p, b.taut(v), key, q)

//line zdd.w:1030
}

//line zdd.w:1066
func (b *ZDD) projection(v int32) int32 {
	if b.vars[v].proj == null {
		b.vars[v].proj = b.symfunc(b.vars[v].elt, 0, 1)
	}
	p := b.vars[v].proj
	b.ref(p)
	return p
}

func (b *ZDD) Sym(p Func, k int) Func {
	q := b.node(p)
	b.drain()
	if k < 0 || int32(k) > b.n {
		return b.wrap(botsink)
	}
	return b.wrap(b.symfunc(q, 0, int32(k)))
}

//line zdd.w:1090
func (b *ZDD) Count(f Func) *big.Int {
	p := b.node(f)
	b.drain()
	return b.countRec(p, map[int32]*big.Int{})
}

func (b *ZDD) countRec(p int32, seen map[int32]*big.Int) *big.Int {
	if p <= topsink {
		return big.NewInt(int64(p - botsink))
	}
	if c, ok := seen[p]; ok {
		return c
	}
	c := new(big.Int).Add(b.countRec(b.mem[p].lo, seen),
		b.countRec(b.mem[p].hi, seen))
	seen[p] = c
	return c
}

//line zdd.w:1112
func (b *ZDD) Size(f Func) int {
	seen := map[int32]bool{}
	b.reach(b.node(f), seen)
	return len(seen)
}

func (b *ZDD) Profile(f Func) []int {
	seen := map[int32]bool{}
	b.reach(b.node(f), seen)
	rk, lv := b.ranks(), b.levels()
	prof := make([]int, len(lv))
	for p := range seen {
		if p > topsink {
			prof[rankOf(rk, b.mem[p].lvl)]++
		}
	}
	return prof
}

//line zdd.w:1132
func (b *ZDD) Support(f Func) []int {
	seen := map[int32]bool{}
	b.reach(b.node(f), seen)
	out := []int{}
	for p := range seen {
		if p > topsink {
			out = append(out, int(b.vars[b.mem[p].lvl].name))
		}
	}
	slices.Sort(out)
	return slices.Compact(out)
}

//line zdd.w:1149
func (b *ZDD) Contains(f Func, set []int) bool {
	p := b.node(f)
	in := make(map[int32]bool, len(set))
	for _, e := range set {
		in[b.level(int32(e))] = true
	}
	need := len(in)
	for p > topsink {
		if in[b.mem[p].lvl] {
			need--
			p = b.mem[p].hi
		} else {
			p = b.mem[p].lo
		}
	}
	return p == topsink && need == 0
}

//line zdd.w:1171
func (b *ZDD) Subsets(f Func) iter.Seq[[]int] {
	p := b.node(f)
	b.drain()
	return func(yield func([]int) bool) {
		b.walkSubsets(p, nil, yield)
	}
}

func (b *ZDD) walkSubsets(p int32, cur []int, yield func([]int) bool) bool {
	switch p {
	case botsink:
		return true
	case topsink:
		s := slices.Clone(cur)
		slices.Sort(s)
		return yield(s)
	}
	if !b.walkSubsets(b.mem[p].lo, cur, yield) {
		return false
	}
	name := int(b.vars[b.mem[p].lvl].name)
	return b.walkSubsets(b.mem[p].hi, append(cur, name), yield)
}

//line zdd.w:1199
func (b *ZDD) Random(f Func, rnd *rand.Rand) ([]int, bool) {
	p := b.node(f)
	b.drain()
	if rnd == nil {
		rnd = rand.New(rand.NewPCG(rand.Uint64(), rand.Uint64()))
	}
	seen := map[int32]*big.Int{}
	if b.countRec(p, seen).Sign() == 0 {
		return nil, false
	}
	var out []int
	for p > topsink {
		c0 := b.countRec(b.mem[p].lo, seen)
		tot := new(big.Int).Add(c0, b.countRec(b.mem[p].hi, seen))
		if randBelow(rnd, tot).Cmp(c0) < 0 {
			p = b.mem[p].lo
		} else {
			out = append(out, int(b.vars[b.mem[p].lvl].name))
			p = b.mem[p].hi
		}
	}
	slices.Sort(out)
	return out, true
}

//line zdd.w:1242
func (b *ZDD) weightAt(p int32, w []int) int {
	if e := int(b.vars[b.mem[p].lvl].name); e < len(w) {
		return w[e]
	}
	return 0
}

func (b *ZDD) bestRec(p int32, w []int, best map[int32]int) int {
	if p <= topsink {
		return 0
	}
	if v, ok := best[p]; ok {
		return v
	}
	v := b.weightAt(p, w) + b.bestRec(b.mem[p].hi, w, best)
	if lo := b.mem[p].lo; lo != botsink {
		v = max(v, b.bestRec(lo, w, best))
	}
	best[p] = v
	return v
}

//line zdd.w:1268
func (b *ZDD) MaxWeight(f Func, w []int) ([]int, int, bool) {
	p := b.node(f)
	b.drain()
	if p == botsink {
		return nil, 0, false
	}
	best := map[int32]int{}
	total := b.bestRec(p, w, best)

//line zdd.w:1283
	var out []int
	for p > topsink {
		if b.weightAt(p, w)+b.bestRec(b.mem[p].hi, w, best) == best[p] {
			out = append(out, int(b.vars[b.mem[p].lvl].name))
			p = b.mem[p].hi
		} else {
			p = b.mem[p].lo
		}
	}
	slices.Sort(out)
	return out, total, true

//line zdd.w:1277
}
