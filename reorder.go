//line reorder.w:32
package bdd

//line reorder.w:62
func (b *base) decChild(p int32) {
	if p > topsink {
		b.mem[p].xref--
	}
}

//line reorder.w:73
func (b *base) swap(u, v int32) {

//line reorder.w:85
	var solitary, tangled []int32
	for _, p := range b.vars[u].tab {
		if p == null {
			continue
		}
		lo, hi := b.mem[p].lo, b.mem[p].hi
		if b.mem[lo].lvl == v || b.mem[hi].lvl == v {
			b.decChild(lo)
			b.decChild(hi)
			tangled = append(tangled, p)
		} else {
			solitary = append(solitary, p)
		}
	}

//line reorder.w:75

//line reorder.w:104
	var remote, hidden []int32
	for _, p := range b.vars[v].tab {
		if p == null {
			continue
		}
		if b.mem[p].xref < 0 {
			hidden = append(hidden, p)
			b.decChild(b.mem[p].lo)
			b.decChild(b.mem[p].hi)
		} else {
			remote = append(remote, p)
		}
	}

//line reorder.w:76

//line reorder.w:123
	b.newTable(u, len(tangled)+len(remote))
	b.newTable(v, len(solitary))
	for _, p := range remote {
		b.mem[p].lvl = u
		b.insertNode(u, p)
	}
	for _, p := range solitary {
		b.mem[p].lvl = v
		b.insertNode(v, p)
	}

//line reorder.w:77

//line reorder.w:142
	for _, f := range tangled {
		g, h := b.mem[f].lo, b.mem[f].hi
		gg := b.swapFind(v, b.cofactor(g, v, false), b.cofactor(h, v, false))
		hh := b.swapFind(v, b.cofactor(g, v, true), b.cofactor(h, v, true))
		b.mem[f].lo, b.mem[f].hi = gg, hh
		b.insertNode(u, f)
	}

//line reorder.w:78
	for _, p := range hidden {
		b.freeNode(p)
	}

//line reorder.w:246
	j, k := b.vars[u].name, b.vars[v].name
	b.vars[u].name, b.vars[v].name = k, j
	b.vmap[j], b.vmap[k] = v, u
	if a, c := b.vars[u].aux, b.vars[v].aux; a*c < 0 {
		b.vars[u].aux, b.vars[v].aux = -a, -c
	}
	b.vars[u].proj, b.vars[v].proj = b.vars[v].proj, b.vars[u].proj
	if b.zdd {

//line reorder.w:267
		b.vars[u].elt, b.vars[v].elt = b.vars[v].elt, b.vars[u].elt
		b.vars[v].taut = b.mem[b.vars[u].taut].lo

//line reorder.w:255
	} else {

//line reorder.w:274
		b.vars[u].repl, b.vars[v].repl = b.vars[v].repl, b.vars[u].repl
		switch {
		case b.vars[v].repl != null && b.vars[v].stamp == 0:
			b.vars[v].stamp = 1
		case b.vars[v].repl == null && b.vars[v].stamp != 0 &&
			(int(v+1) >= len(b.vars) || b.vars[v+1].stamp == 0):
			b.vars[v].stamp = 0
		}

//line reorder.w:257
	}

//line reorder.w:82
}

//line reorder.w:154
func (b *base) cofactor(x, v int32, hi bool) int32 {
	if b.mem[x].lvl > v {
		if hi && b.zdd {
			return botsink
		}
		return x
	}
	if hi {
		return b.mem[x].hi
	}
	return b.mem[x].lo
}

//line reorder.w:172
func (b *base) swapFind(v, l, h int32) int32 {
	if b.zdd {
		if h == botsink {
			b.ref(l)
			return l
		}
	} else if l == h {
		b.ref(l)
		return l
	}
	for {
		tab := b.vars[v].tab
		mask := int32(len(tab)) - 1
		k := int32(hash2(l, h)) & mask

//line reorder.w:192
		for tab[k] != null {
			if p := tab[k]; b.mem[p].lo == l && b.mem[p].hi == h {
				b.ref(p)
				return p
			}
			k = (k + 1) & mask
		}

//line reorder.w:187

//line reorder.w:201
		if b.vars[v].free-1 <= len(tab)/4 {
			b.resizeTable(v, 2*len(tab))
			continue
		}
		p := b.reserveNode()
		tab[k] = p
		b.vars[v].free--
		b.mem[p] = node{lo: l, hi: h, xref: 0, lvl: v}
		b.ref(l)
		b.ref(h)
		return p

//line reorder.w:188
	}
}

//line reorder.w:217
func (b *base) newTable(v int32, m int) {
	n := 2
	for 3*n < 4*m {
		n <<= 1
	}
	b.vars[v].tab, b.vars[v].free = make([]int32, n), n
}

func (b *base) insertNode(v, q int32) {
	for {
		tab := b.vars[v].tab
		if b.vars[v].free-1 <= len(tab)/4 {
			b.resizeTable(v, 2*len(tab))
			continue
		}
		mask := int32(len(tab)) - 1
		k := int32(hash2(b.mem[q].lo, b.mem[q].hi)) & mask
		for tab[k] != null {
			k = (k + 1) & mask
		}
		tab[k], b.vars[v].free = q, b.vars[v].free-1
		return
	}
}

//line reorder.w:289
func (b *base) reorderInit() {
	b.collectGarbage(true)
	b.totalvars, b.first = 0, -1
	prev := int32(-1)
	for v := range b.vars {
		if b.vars[v].tab == nil {
			continue
		}
		b.totalvars++
		b.vars[v].aux, b.vars[v].up = b.totalvars, prev
		if prev >= 0 {
			b.vars[prev].down = int32(v)
		} else {
			b.first = int32(v)
		}
		prev = int32(v)
	}
	if prev >= 0 {
		b.vars[prev].down = -1
	}
}

func (b *base) reorderFin() { b.cacheInit() }

//line reorder.w:321
func (b *base) explore(u int32, up bool, best *int) int32 {
	for {
		nxt := b.vars[u].down
		if up {
			nxt = b.vars[u].up
		}
		if nxt < 0 {
			return u
		}
		if up {
			b.swap(nxt, u)
		} else {
			b.swap(u, nxt)
		}
		u = nxt
		if *best > b.total {
			*best = b.total
		}
	}
}

//line reorder.w:346
func (b *base) stepUp(u int32) int32 {
	p := b.vars[u].up
	b.swap(p, u)
	return p
}

func (b *base) stepDown(u int32) int32 {
	d := b.vars[u].down
	b.swap(u, d)
	return d
}

//line reorder.w:366
func (b *base) sift(v int32) {
	best, u := b.total, v
	up := b.totalvars-b.vars[v].aux >= b.vars[v].aux
	u = b.explore(u, up, &best)

//line reorder.w:377
	for u != v {
		if u < v {
			u = b.stepDown(u)
		} else {
			u = b.stepUp(u)
		}
	}

//line reorder.w:371
	u = b.explore(u, !up, &best)

//line reorder.w:386
	for b.total != best {
		if up { // 두 번째 방향은 아래쪽이었으니 위로 되짚는다
			if b.vars[u].up < 0 {
				break
			}
			u = b.stepUp(u)
		} else {
			if b.vars[u].down < 0 {
				break
			}
			u = b.stepDown(u)
		}
	}

//line reorder.w:373
	b.vars[u].aux = -b.vars[u].aux // 이 변수는 체질을 마쳤다
}

//line reorder.w:405
func (b *base) siftAll() {
	for v := b.first; v >= 0; {
		if b.vars[v].aux < 0 {
			v = b.vars[v].down // 이미 훑은 변수다
			continue
		}
		b.sift(v)
	}
}

//line reorder.w:420
func (b *base) Order() []int {
	out := []int{}
	for _, v := range b.levels() {
		out = append(out, int(b.vars[v].name))
	}
	return out
}

func (b *base) Swap(k int) {
	b.drain()
	v := b.level(int32(k))
	if int(v) >= len(b.vars) || b.vars[v].tab == nil {
		return
	}
	b.reorderInit()
	if u := b.vars[v].up; u >= 0 {
		b.swap(u, v)
	}
	b.reorderFin()
}

//line reorder.w:444
func (b *base) Sift(k int) {
	b.drain()
	v := b.level(int32(k))
	if int(v) >= len(b.vars) || b.vars[v].tab == nil {
		return
	}
	b.reorderInit()
	b.sift(v)
	b.reorderFin()
}

func (b *base) SiftAll() {
	b.drain()
	b.reorderInit()
	b.siftAll()
	b.reorderFin()
}

//line reorder.w:466
func (b *base) Reorder(order []int) {
	b.drain()
	b.reorderInit()
	lv := b.levels()
	for i, name := range order {
		if i >= len(lv) {
			break
		}
		for cur := b.level(int32(name)); cur != lv[i]; {
			cur = b.stepUp(cur)
		}
	}
	b.reorderFin()
}
