//line bdd.w:39
package bdd

import (
	"iter"
	"math/big"
	"math/rand/v2"
)

//line bdd.w:54
type BDD struct{ base }

//line bdd.w:105
const (
	opAnd       = int32(1)  // $f\land g$
	opButnot    = int32(2)  // $f\land\bar g$
	opNotbut    = int32(4)  // $\bar f\land g$
	opXor       = int32(6)  // $f\oplus g$
	opOr        = int32(7)  // $f\lor g$
	opConstrain = int32(8)  // $f\downarrow g$
	opAll       = int32(9)  // $\forall$
	opNo        = int32(10) // ``아니오'' 한정사
	opYes       = int32(12) // ``예'' 한정사
	opDiff      = int32(14) // 불 미분
	opExist     = int32(15) // $\exists$
)

//line bdd.w:546
const (
	ternMux      = int32(0) // $f{?}\,g{:}\,h$
	ternMed      = int32(1) // $\langle fgh\rangle$
	ternAndAnd   = int32(2) // $f\land g\land h$
	ternAndExist = int32(3) // $(f\land g)\mathbin{\rm E}h$
)

//line bdd.w:59
func New() *BDD {
	b := new(BDD)
	b.init(false)
	return b
}

//line bdd.w:72
func (b *BDD) projection(name int32) int32 {
	v := b.level(name)
	b.newLevel(v)
	p := b.vars[v].proj
	if p == null {
		p = b.uniqueFind(v, botsink, topsink)
		b.vars[v].proj, b.vars[v].name = p, name
	}
	b.ref(p)
	return p
}

//line bdd.w:87
func (b *BDD) Zero() Func { return b.wrap(botsink) }

//line bdd.w:88
func (b *BDD) One() Func { return b.wrap(topsink) }

func (b *BDD) Var(k int) Func {
	b.drain()
	return b.wrap(b.projection(int32(k)))
}

//line bdd.w:122
func (b *BDD) binary(op int32, f, g Func) Func {
	p, q := b.node(f), b.node(g)
	b.drain()
	return b.wrap(b.binaryRec(op, p, q))
}

func (b *BDD) binaryRec(op, f, g int32) int32 {
	switch op {
	case opAnd:
		return b.andRec(f, g)
	case opButnot:
		return b.muxRec(g, botsink, f) // $f\land\bar g=(g{?}\,0{:}\,f)$
	case opNotbut:
		return b.muxRec(f, botsink, g) // $\bar f\land g=(f{?}\,0{:}\,g)$
	case opXor:
		return b.xorRec(f, g)
	case opOr:
		return b.orRec(f, g)
	case opConstrain:
		return b.constrainRec(f, g)
	case opAll:
		return b.allRec(f, g)
	case opNo, opYes:
		return b.yesNoRec(op, f, g)
	case opDiff:
		return b.diffRec(f, g)
	}
	return b.existRec(f, g)
}

//line bdd.w:155
func (b *BDD) And(f, g Func) Func { return b.binary(opAnd, f, g) }

//line bdd.w:156
func (b *BDD) Or(f, g Func) Func { return b.binary(opOr, f, g) }

//line bdd.w:157
func (b *BDD) Xor(f, g Func) Func { return b.binary(opXor, f, g) }

func (b *BDD) Butnot(f, g Func) Func { return b.binary(opButnot, f, g) }

//line bdd.w:160
func (b *BDD) Notbut(f, g Func) Func { return b.binary(opNotbut, f, g) }

//line bdd.w:165
func (b *BDD) Not(f Func) Func {
	p := b.node(f)
	b.drain()
	return b.wrap(b.xorRec(topsink, p))
}

//line bdd.w:178
func (b *BDD) andRec(f, g int32) int32 {
	if f == g {
		b.ref(f)
		return f // $f\land f=f$
	}
	if f > g {
		f, g = g, f
	}
	if f <= topsink {
		if f == topsink {
			b.ref(g)
			return g // $1\land g=g$
		}
		return botsink // $0\land g=0$
	}
	if r := b.cacheLookup(f, g, opAnd); r != null {
		return r
	}

//line bdd.w:214
	v := min(b.mem[f].lvl, b.mem[g].lvl)
	f0, f1, g0, g1 := f, f, g, g
	if b.mem[f].lvl == v {
		f0, f1 = b.mem[f].lo, b.mem[f].hi
	}
	if b.mem[g].lvl == v {
		g0, g1 = b.mem[g].lo, b.mem[g].hi
	}

//line bdd.w:205
	r0 := b.andRec(f0, g0)
	r1 := b.andRec(f1, g1)
	r := b.uniqueFind(v, r0, r1)
	b.cacheInsert(f, g, opAnd, r)
	return r

//line bdd.w:197
}

//line bdd.w:226
func (b *BDD) orRec(f, g int32) int32 {
	if f == g {
		b.ref(f)
		return f // $f\lor f=f$
	}
	if f > g {
		f, g = g, f
	}
	if f <= topsink {
		if f == topsink {
			return topsink // $1\lor g=1$
		}
		b.ref(g)
		return g // $0\lor g=g$
	}
	if r := b.cacheLookup(f, g, opOr); r != null {
		return r
	}

//line bdd.w:214
	v := min(b.mem[f].lvl, b.mem[g].lvl)
	f0, f1, g0, g1 := f, f, g, g
	if b.mem[f].lvl == v {
		f0, f1 = b.mem[f].lo, b.mem[f].hi
	}
	if b.mem[g].lvl == v {
		g0, g1 = b.mem[g].lo, b.mem[g].hi
	}

//line bdd.w:249
	r0 := b.orRec(f0, g0)
	r1 := b.orRec(f1, g1)
	r := b.uniqueFind(v, r0, r1)
	b.cacheInsert(f, g, opOr, r)
	return r

//line bdd.w:245
}

//line bdd.w:262
func (b *BDD) xorRec(f, g int32) int32 {
	if f == g {
		return botsink // $f\oplus f=0$
	}
	if f > g {
		f, g = g, f
	}
	if f == botsink {
		b.ref(g)
		return g // $0\oplus g=g$
	}
	if r := b.cacheLookup(f, g, opXor); r != null {
		return r
	}

//line bdd.w:214
	v := min(b.mem[f].lvl, b.mem[g].lvl)
	f0, f1, g0, g1 := f, f, g, g
	if b.mem[f].lvl == v {
		f0, f1 = b.mem[f].lo, b.mem[f].hi
	}
	if b.mem[g].lvl == v {
		g0, g1 = b.mem[g].lo, b.mem[g].hi
	}

//line bdd.w:281
	r0 := b.xorRec(f0, g0)
	r1 := b.xorRec(f1, g1)
	r := b.uniqueFind(v, r0, r1)
	b.cacheInsert(f, g, opXor, r)
	return r

//line bdd.w:277
}

//line bdd.w:295
func (b *BDD) constrainRec(f, g int32) int32 {
	switch {
	case g == botsink:
		return botsink // $f\downarrow0=0$
	case g == topsink || f <= topsink:
		b.ref(f)
		return f // $f\downarrow1=f$, 그리고 $g\ne0$일 때 상수는 그대로
	case f == g:
		return topsink // $f\downarrow f=1$
	}
	if r := b.cacheLookup(f, g, opConstrain); r != null {
		return r
	}

//line bdd.w:214
	v := min(b.mem[f].lvl, b.mem[g].lvl)
	f0, f1, g0, g1 := f, f, g, g
	if b.mem[f].lvl == v {
		f0, f1 = b.mem[f].lo, b.mem[f].hi
	}
	if b.mem[g].lvl == v {
		g0, g1 = b.mem[g].lo, b.mem[g].hi
	}

//line bdd.w:316
	if b.mem[g].lvl <= b.mem[f].lvl {
		if g0 == botsink {
			return b.memo(f, g, opConstrain, b.constrainRec(f1, g1))
		}
		if g1 == botsink {
			return b.memo(f, g, opConstrain, b.constrainRec(f0, g0))
		}
	}
	r0 := b.constrainRec(f0, g0)
	r1 := b.constrainRec(f1, g1)
	r := b.uniqueFind(v, r0, r1)
	b.cacheInsert(f, g, opConstrain, r)
	return r

//line bdd.w:309
}

//line bdd.w:349
func (b *BDD) existRec(f, g int32) int32 {
	for {
		if g <= topsink || f <= topsink {
			b.ref(f)
			return f // $f\mathbin{\rm E}1=f$, 그리고 상수는 그대로
		}
		v, vg := b.mem[f].lvl, b.mem[g].lvl
		if v > vg {
			g = b.mem[g].hi
			continue
		}
		if r := b.cacheLookup(f, g, opExist); r != null {
			return r
		}

//line bdd.w:374
		g1 := g
		if vg == v {
			g1 = b.mem[g].hi
		}
		r := b.existRec(b.mem[f].lo, g1)
		if r != topsink || vg != v {
			r1 := b.existRec(b.mem[f].hi, g1)
			if vg > v {
				r = b.uniqueFind(v, r, r1)
			} else {
				r0 := r
				r = b.orRec(r0, r1)
				b.deref(r0)
				b.deref(r1)
			}
		}
		return b.memo(f, g, opExist, r)

//line bdd.w:364
	}
}

//line bdd.w:395
func (b *BDD) allRec(f, g int32) int32 {
	for {
		if g <= topsink || f <= topsink {
			b.ref(f)
			return f
		}
		v, vg := b.mem[f].lvl, b.mem[g].lvl
		if v > vg {
			g = b.mem[g].hi
			continue
		}
		if r := b.cacheLookup(f, g, opAll); r != null {
			return r
		}

//line bdd.w:414
		g1 := g
		if vg == v {
			g1 = b.mem[g].hi
		}
		r := b.allRec(b.mem[f].lo, g1)
		if r != botsink || vg != v {
			r1 := b.allRec(b.mem[f].hi, g1)
			if vg > v {
				r = b.uniqueFind(v, r, r1)
			} else {
				r0 := r
				r = b.andRec(r0, r1)
				b.deref(r0)
				b.deref(r1)
			}
		}
		return b.memo(f, g, opAll, r)

//line bdd.w:410
	}
}

//line bdd.w:435
func (b *BDD) diffRec(f, g int32) int32 {
	if g <= topsink {
		b.ref(f)
		return f // $f\mathbin{\rm D}1=f$
	}
	if f <= topsink {
		return botsink // 상수는 어느 변수에도 기대지 않는다
	}
	v, vg := b.mem[f].lvl, b.mem[g].lvl
	if v > vg {
		return botsink
	}
	if r := b.cacheLookup(f, g, opDiff); r != null {
		return r
	}

//line bdd.w:454
	g1 := g
	if vg == v {
		g1 = b.mem[g].hi
	}
	r0 := b.diffRec(b.mem[f].lo, g1)
	r1 := b.diffRec(b.mem[f].hi, g1)
	var r int32
	if vg > v {
		r = b.uniqueFind(v, r0, r1)
	} else {
		r = b.xorRec(r0, r1) // 미분이 일어나는 자리
		b.deref(r0)
		b.deref(r1)
	}
	return b.memo(f, g, opDiff, r)

//line bdd.w:451
}

//line bdd.w:480
func (b *BDD) yesNoRec(op, f, g int32) int32 {
	if g <= topsink {
		b.ref(f)
		return f
	}
	if f <= topsink {
		return botsink
	}
	v, vg := b.mem[f].lvl, b.mem[g].lvl
	if v > vg {
		return botsink
	}
	if r := b.cacheLookup(f, g, op); r != null {
		return r
	}

//line bdd.w:501
	g1 := g
	if vg == v {
		g1 = b.mem[g].hi
	}
	r := b.yesNoRec(op, b.mem[f].lo, g1)
	if !(r <= topsink && vg == v && (r == topsink) == (op == opYes)) {
		r0, r1 := r, b.yesNoRec(op, b.mem[f].hi, g1)
		if vg > v {
			r = b.uniqueFind(v, r0, r1)
		} else if op == opYes {
			r = b.muxRec(r0, botsink, r1) // $\bar r_0\land r_1$
			b.deref(r0)
			b.deref(r1)
		} else {
			r = b.muxRec(r1, botsink, r0) // $r_0\land\bar r_1$
			b.deref(r0)
			b.deref(r1)
		}
	} else {
		r = botsink
	}
	return b.memo(f, g, op, r)

//line bdd.w:496
}

//line bdd.w:528
func (b *BDD) Exists(f, g Func) Func { return b.binary(opExist, f, g) }

//line bdd.w:529
func (b *BDD) Forall(f, g Func) Func { return b.binary(opAll, f, g) }

func (b *BDD) Diff(f, g Func) Func { return b.binary(opDiff, f, g) }

//line bdd.w:532
func (b *BDD) Yes(f, g Func) Func { return b.binary(opYes, f, g) }

//line bdd.w:533
func (b *BDD) No(f, g Func) Func { return b.binary(opNo, f, g) }

func (b *BDD) Constrain(f, g Func) Func { return b.binary(opConstrain, f, g) }

//line bdd.w:560
func (b *BDD) muxRec(f, g, h int32) int32 {
	switch {
	case f <= topsink:
		if f == topsink {
			b.ref(g)
			return g
		}
		b.ref(h)
		return h
	case g == f || g == topsink:
		return b.orRec(f, h) // $(f{?}\,f{:}\,h)=(f{?}\,1{:}\,h)=f\lor h$
	case h == f || h == botsink:
		return b.andRec(f, g) // $(f{?}\,g{:}\,f)=(f{?}\,g{:}\,0)=f\land g$
	case g == h:
		b.ref(g)
		return g
	case g == botsink && h == topsink:
		return b.xorRec(topsink, f) // $(f{?}\,0{:}\,1)=1\oplus f$
	}
	if r := b.cacheLookup(f, g, ternKey(h, ternMux)); r != null {
		return r
	}

//line bdd.w:594
	v := min(b.mem[f].lvl, b.mem[g].lvl, b.mem[h].lvl)
	f0, f1, g0, g1, h0, h1 := f, f, g, g, h, h
	if b.mem[f].lvl == v {
		f0, f1 = b.mem[f].lo, b.mem[f].hi
	}
	if b.mem[g].lvl == v {
		g0, g1 = b.mem[g].lo, b.mem[g].hi
	}
	if b.mem[h].lvl == v {
		h0, h1 = b.mem[h].lo, b.mem[h].hi
	}

//line bdd.w:587
	r0 := b.muxRec(f0, g0, h0)
	r1 := b.muxRec(f1, g1, h1)
	r := b.uniqueFind(v, r0, r1)
	return b.memo(f, g, ternKey(h, ternMux), r)

//line bdd.w:583
}

//line bdd.w:610
func (b *BDD) medRec(f, g, h int32) int32 {

//line bdd.w:632
	if f > g {
		f, g = g, f
	}
	if g > h {
		g, h = h, g
	}
	if f > g {
		f, g = g, f
	}

//line bdd.w:612
	switch {
	case f <= topsink:
		if f == topsink {
			return b.orRec(g, h) // $\langle1gh\rangle=g\lor h$
		}
		return b.andRec(g, h) // $\langle0gh\rangle=g\land h$
	case f == g:
		b.ref(f)
		return f // $\langle ffh\rangle=f$
	case g == h:
		b.ref(g)
		return g // $\langle fgg\rangle=g$
	}
	if r := b.cacheLookup(f, g, ternKey(h, ternMed)); r != null {
		return r
	}

//line bdd.w:594
	v := min(b.mem[f].lvl, b.mem[g].lvl, b.mem[h].lvl)
	f0, f1, g0, g1, h0, h1 := f, f, g, g, h, h
	if b.mem[f].lvl == v {
		f0, f1 = b.mem[f].lo, b.mem[f].hi
	}
	if b.mem[g].lvl == v {
		g0, g1 = b.mem[g].lo, b.mem[g].hi
	}
	if b.mem[h].lvl == v {
		h0, h1 = b.mem[h].lo, b.mem[h].hi
	}

//line bdd.w:644
	r0 := b.medRec(f0, g0, h0)
	r1 := b.medRec(f1, g1, h1)
	r := b.uniqueFind(v, r0, r1)
	return b.memo(f, g, ternKey(h, ternMed), r)

//line bdd.w:629
}

//line bdd.w:652
func (b *BDD) andAndRec(f, g, h int32) int32 {

//line bdd.w:632
	if f > g {
		f, g = g, f
	}
	if g > h {
		g, h = h, g
	}
	if f > g {
		f, g = g, f
	}

//line bdd.w:654
	switch {
	case f <= topsink:
		if f == topsink {
			return b.andRec(g, h)
		}
		return botsink
	case f == g:
		return b.andRec(g, h)
	case g == h:
		return b.andRec(f, g)
	}
	if r := b.cacheLookup(f, g, ternKey(h, ternAndAnd)); r != null {
		return r
	}

//line bdd.w:594
	v := min(b.mem[f].lvl, b.mem[g].lvl, b.mem[h].lvl)
	f0, f1, g0, g1, h0, h1 := f, f, g, g, h, h
	if b.mem[f].lvl == v {
		f0, f1 = b.mem[f].lo, b.mem[f].hi
	}
	if b.mem[g].lvl == v {
		g0, g1 = b.mem[g].lo, b.mem[g].hi
	}
	if b.mem[h].lvl == v {
		h0, h1 = b.mem[h].lo, b.mem[h].hi
	}

//line bdd.w:673
	r0 := b.andAndRec(f0, g0, h0)
	r1 := b.andAndRec(f1, g1, h1)
	r := b.uniqueFind(v, r0, r1)
	return b.memo(f, g, ternKey(h, ternAndAnd), r)

//line bdd.w:669
}

//line bdd.w:683
func (b *BDD) andExistRec(f, g, h int32) int32 {
	for {
		switch {
		case h <= topsink:
			return b.andRec(f, g)
		case f == g:
			return b.existRec(f, h)
		}
		if f > g {
			f, g = g, f
		}
		if f <= topsink {
			if f == topsink {
				return b.existRec(g, h)
			}
			return botsink
		}
		if r := b.cacheLookup(f, g, ternKey(h, ternAndExist)); r != null {
			return r
		}
		v := min(b.mem[f].lvl, b.mem[g].lvl)
		if v > b.mem[h].lvl {
			h = b.mem[h].hi // |f|와 |g|가 |h|의 꼭대기 변수에 기대지 않는다
			continue
		}

//line bdd.w:713
		vh := b.mem[h].lvl
		f0, f1, g0, g1, h1 := f, f, g, g, h
		if b.mem[f].lvl == v {
			f0, f1 = b.mem[f].lo, b.mem[f].hi
		}
		if b.mem[g].lvl == v {
			g0, g1 = b.mem[g].lo, b.mem[g].hi
		}
		if vh == v {
			h1 = b.mem[h].hi
		}
		r := b.andExistRec(f0, g0, h1)
		if r != topsink || vh != v {
			r1 := b.andExistRec(f1, g1, h1)
			if vh > v {
				r = b.uniqueFind(v, r, r1)
			} else {
				r0 := r
				r = b.orRec(r0, r1) // 존재 한정이 일어나는 자리
				b.deref(r0)
				b.deref(r1)
			}
		}
		return b.memo(f, g, ternKey(h, ternAndExist), r)

//line bdd.w:709
	}
}

//line bdd.w:742
func (b *BDD) ternary(op int32, f, g, h Func) Func {
	p, q, s := b.node(f), b.node(g), b.node(h)
	b.drain()
	switch op {
	case ternMux:
		return b.wrap(b.muxRec(p, q, s))
	case ternMed:
		return b.wrap(b.medRec(p, q, s))
	case ternAndAnd:
		return b.wrap(b.andAndRec(p, q, s))
	}
	return b.wrap(b.andExistRec(p, q, s))
}

func (b *BDD) Ite(f, g, h Func) Func { return b.ternary(ternMux, f, g, h) }

//line bdd.w:757
func (b *BDD) Median(f, g, h Func) Func { return b.ternary(ternMed, f, g, h) }

//line bdd.w:758
func (b *BDD) And3(f, g, h Func) Func { return b.ternary(ternAndAnd, f, g, h) }

//line bdd.w:759
func (b *BDD) AndExists(f, g, h Func) Func {
	return b.ternary(ternAndExist, f, g, h)
}

//line bdd.w:789
func (b *BDD) setRepl(name, q int32) {
	if b.stamp == ^uint32(0) {
		b.collectGarbage(true) // 도장이 한 바퀴 돌았다 (그럴 성싶지 않지만)
	}
	v := b.level(name)
	b.newLevel(v)
	old := b.vars[v].repl
	if old == q {
		return
	}
	if old != null {
		b.deref(old)
	}
	b.vars[v].repl = q
	if q != null {
		b.ref(q)

//line bdd.w:833
		if !b.stampChg {
			b.stampChg = true
			b.stamp++
		}
		for v >= 0 && b.vars[v].stamp != b.stamp {
			b.vars[v].stamp = b.stamp
			v--
		}

//line bdd.w:806
		return
	}

//line bdd.w:812
	if v+1 < int32(len(b.vars)) && b.vars[v+1].stamp != 0 {

//line bdd.w:833
		if !b.stampChg {
			b.stampChg = true
			b.stamp++
		}
		for v >= 0 && b.vars[v].stamp != b.stamp {
			b.vars[v].stamp = b.stamp
			v--
		}

//line bdd.w:814
		return
	}
	for v >= 0 && b.vars[v].repl == null {
		b.vars[v].stamp = 0
		v--
	}
	if v >= 0 {

//line bdd.w:833
		if !b.stampChg {
			b.stampChg = true
			b.stamp++
		}
		for v >= 0 && b.vars[v].stamp != b.stamp {
			b.vars[v].stamp = b.stamp
			v--
		}

//line bdd.w:822
		return
	}
	if b.stampChg {
		b.stamp--
	}
	b.stampChg = false

//line bdd.w:809
}

//line bdd.w:844
func (b *BDD) composeRec(f int32) int32 {
	if f <= topsink {
		return f
	}
	vf := b.mem[f].lvl
	if b.vars[vf].stamp == 0 {
		b.ref(f)
		return f // |f|는 어떤 $y$에도 기대지 않는다
	}
	stamp := int32(b.vars[vf].stamp)
	if r := b.cacheLookup(f, stamp, 0); r != null {
		return r
	}

//line bdd.w:864
	r0 := b.composeRec(b.mem[f].lo)
	r1 := b.composeRec(b.mem[f].hi)
	y := b.vars[vf].repl
	if y == null {
		y = b.vars[vf].proj
	}
	r := b.muxRec(y, r1, r0) // 치환이 일어나는 자리
	b.deref(r0)
	b.deref(r1)
	return b.memo(f, stamp, 0, r)

//line bdd.w:858
}

//line bdd.w:880
func (b *BDD) Compose(f Func, y map[int]Func) Func {
	p := b.node(f)
	names := make([]int32, 0, len(y))
	qs := make([]int32, 0, len(y))
	for k, g := range y {
		names = append(names, int32(k))
		qs = append(qs, b.node(g))
	}
	b.drain()
	for i, k := range names {
		b.setRepl(k, qs[i])
	}
	b.stampChg = false
	r := b.composeRec(p)
	for _, k := range names {
		b.setRepl(k, null)
	}
	return b.wrap(r)
}

//line bdd.w:913
func (b *BDD) Count(f Func) *big.Int {
	p := b.node(f)
	b.drain()
	rk := b.ranks()
	c := b.countRec(p, rk, map[int32]*big.Int{})
	return new(big.Int).Lsh(c, uint(rankOf(rk, b.mem[p].lvl)))
}

func (b *BDD) countRec(p int32, rk []int32, seen map[int32]*big.Int) *big.Int {
	if p <= topsink {
		return big.NewInt(int64(p - botsink))
	}
	if c, ok := seen[p]; ok {
		return c
	}
	c, rp := new(big.Int), rankOf(rk, b.mem[p].lvl)
	for _, q := range [2]int32{b.mem[p].lo, b.mem[p].hi} {
		t := b.countRec(q, rk, seen)
		c.Add(c, new(big.Int).Lsh(t, uint(rankOf(rk, b.mem[q].lvl)-rp-1)))
	}
	seen[p] = c
	return c
}

//line bdd.w:941
func (b *BDD) Size(f Func) int {
	seen := map[int32]bool{}
	b.reach(b.node(f), seen)
	return len(seen)
}

//line bdd.w:951
func (b *BDD) Profile(f Func) []int {
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

func (b *BDD) Support(f Func) []int {
	seen := map[int32]bool{}
	b.reach(b.node(f), seen)
	on := map[int32]bool{}
	for p := range seen {
		if p > topsink {
			on[b.mem[p].lvl] = true
		}
	}
	out := []int{}
	for _, v := range b.levels() {
		if on[v] {
			out = append(out, int(b.vars[v].name))
		}
	}
	return out
}

//line bdd.w:985
func (b *BDD) Eval(f Func, x []bool) bool {
	p := b.node(f)
	for p > topsink {
		name := b.vars[b.mem[p].lvl].name
		if int(name) < len(x) && x[name] {
			p = b.mem[p].hi
		} else {
			p = b.mem[p].lo
		}
	}
	return p == topsink
}

//line bdd.w:1006
func (b *BDD) All(f Func) iter.Seq[[]bool] {
	p := b.node(f)
	b.drain()
	lv := b.levels()
	names, width := make([]int32, len(lv)), 0
	for i, v := range lv {
		names[i] = b.vars[v].name
		width = max(width, int(names[i])+1)
	}
	return func(yield func([]bool) bool) {
		x := make([]bool, width)
		b.walkAll(p, 0, lv, names, x, yield)
	}
}

//line bdd.w:1024
func (b *BDD) walkAll(p int32, i int, lv, names []int32, x []bool,
	yield func([]bool) bool) bool {
	switch {
	case p == botsink:
		return true
	case i == len(lv):
		return yield(append([]bool(nil), x...))
	}
	lo, hi := p, p
	if b.mem[p].lvl == lv[i] {
		lo, hi = b.mem[p].lo, b.mem[p].hi
	}
	x[names[i]] = false
	if !b.walkAll(lo, i+1, lv, names, x, yield) {
		return false
	}
	x[names[i]] = true
	return b.walkAll(hi, i+1, lv, names, x, yield)
}

//line bdd.w:1049
func (b *BDD) Random(f Func, rnd *rand.Rand) ([]bool, bool) {
	p := b.node(f)
	b.drain()
	if rnd == nil {
		rnd = rand.New(rand.NewPCG(rand.Uint64(), rand.Uint64()))
	}
	rk, lv, seen := b.ranks(), b.levels(), map[int32]*big.Int{}
	if b.countRec(p, rk, seen).Sign() == 0 {
		return nil, false
	}

//line bdd.w:1063
	width := 0
	for _, v := range lv {
		width = max(width, int(b.vars[v].name)+1)
	}
	x := make([]bool, width)
	for _, v := range lv {
		name := b.vars[v].name
		if b.mem[p].lvl != v {
			x[name] = rnd.IntN(2) == 1 // 상관없는 변수
			continue
		}
		rp := rankOf(rk, v)
		w := func(q int32) *big.Int {
			t := b.countRec(q, rk, seen)
			return new(big.Int).Lsh(t, uint(rankOf(rk, b.mem[q].lvl)-rp-1))
		}
		c0 := w(b.mem[p].lo)
		tot := new(big.Int).Add(c0, w(b.mem[p].hi))
		if randBelow(rnd, tot).Cmp(c0) < 0 {
			p = b.mem[p].lo
		} else {
			x[name] = true
			p = b.mem[p].hi
		}
	}
	return x, true

//line bdd.w:1060
}
