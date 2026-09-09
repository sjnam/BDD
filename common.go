//line common.w:81
package bdd

import (
	"fmt"
	"math/big"
	"math/rand/v2"
	"runtime"
	"sync"
)

//line common.w:113
const (
	null    = int32(0)       // 노드가 아님
	botsink = int32(1)       // 항상 0인 함수
	topsink = int32(2)       // 항상 1인 함수
	maxLvl  = int32(1) << 30 // 싱크의 준위: 어떤 변수보다도 아래
)

type node struct {
	lo, hi int32 // $x_v=0$일 때와 $x_v=1$일 때 갈 곳
	xref   int32 // 참조 계수 빼기 1; 음수면 죽은 노드
	lvl    int32 // 이 노드가 갈라 보는 변수의 준위
}

//line common.w:132
type base struct {
	mem   []node // 노드들이 사는 곳; |mem[0]|은 쓰지 않는다
	avail int32  // 되쓸 수 있는 노드들의 목록 머리
	total int    // 지금 쓰이는 노드 수 (싱크 둘을 포함)
	dead  int    // 그 가운데 죽은 것의 수

//line common.w:210
	vars []variable // 준위마다 하나씩
	vmap []int32    // 이름을 준위로 옮기는 표

//line common.w:344
	timer uint64 // |uniqueFind|가 새 노드를 만들려 한 횟수
	zdd   bool   // ZDD 축약 규칙을 쓰는가

//line common.w:444
	cache   []memo // 계산해 둔 결과들
	cmask   int32  // |len(cache)-1|
	inserts int    // 넣은 횟수
	thresh  int    // 이만큼 넣으면 캐시를 두 배로

//line common.w:694
	ext     map[int32]int32 // 노드마다 바깥에서 붙든 손잡이의 수
	mu      sync.Mutex      // 아래 대기표를 지킨다
	pending []int32         // 정리 훅이 얹어 둔 쪽지들

//line common.w:798
	gcs int // 쓰레기를 쓸어 담은 횟수

//line common.w:802
	totalvars int32 // 지금 쓰이는 변수의 수
	first     int32 // 그 가운데 가장 위에 있는 것의 준위

//line common.w:824
	stamp    uint32 // 지금까지 준비하거나 마친 합성의 수
	stampChg bool   // 마지막 합성 뒤에 도장이 바뀌었는가

//line common.w:138
}

//line common.w:196
type variable struct {
	proj     int32   // 투영 함수 $x_v$
	repl     int32   // 치환 함수 $y_v$ (BDD 전용)
	taut     int32   // 여기서부터 항진인 노드 (ZDD 전용)
	elt      int32   // 원소 함수 $e_v$ (ZDD 전용)
	tab      []int32 // 유일 테이블; 길이는 2의 거듭제곱
	free     int     // 그 가운데 빈 칸의 수
	name     int32   // 사용자가 부르는 이름
	stamp    uint32  // 합성에 쓰는 시각 도장
	aux      int32   // 체질 알고리즘이 쓰는 표식
	up, down int32   // 재정렬 때 이웃한 활성 준위
}

//line common.w:338
const (
	timerInterval = 1024 // 이만큼마다 한 번씩 살림을 본다
	deadFraction  = 8    // 죽은 노드가 이 분의 일을 넘으면 쓸어 담는다
)

//line common.w:436
type memo struct {
	f, g, h int32 // 피연산자와 연산 번호
	r       int32 // 결과; |null|이면 빈 자리
}

const maxBinop = 15 // 이 아래는 이항 연산 번호

//line common.w:476
const (
	minCacheSlots = 1 << 8
	maxCacheSlots = 1 << 24

//line common.w:479
)

//line common.w:685
type Func struct{ h *handle }

type handle struct {
	b  *base
	p  int32
	cl runtime.Cleanup
}

//line common.w:833
type Stats struct {
	Nodes       int // 쓰이는 노드 수 (싱크 둘을 포함)
	Dead        int // 그 가운데 죽은 것
	Vars        int // 만들어진 변수의 수
	CacheSlots  int // 캐시의 칸수
	Collections int // 쓰레기를 쓸어 담은 횟수
}

//line common.w:144
func (b *base) reserveNode() int32 {
	p := b.avail
	if p != null {
		b.avail = b.mem[p].xref
	} else {
		p = int32(len(b.mem))
		b.mem = append(b.mem, node{})
	}
	b.total++
	return p
}

func (b *base) freeNode(p int32) {
	b.mem[p].xref = b.avail
	b.avail = p
	b.total--
}

//line common.w:165
func (b *base) init(zdd bool) {
	b.zdd = zdd
	b.mem = make([]node, 3, 64)
	b.mem[botsink] = node{lo: botsink, hi: botsink, lvl: maxLvl}
	b.mem[topsink] = node{lo: topsink, hi: topsink, lvl: maxLvl}
	b.total = 2
	b.ext = make(map[int32]int32)
	b.cacheInit()
}

//line common.w:218
func (b *base) newLevel(v int32) {
	for int32(len(b.vars)) <= v {
		b.vars = append(b.vars, variable{name: -1})
	}
	if b.vars[v].tab == nil {
		b.vars[v].tab = make([]int32, 2)
		b.vars[v].free = 2
	}
}

func (b *base) level(name int32) int32 {
	for int32(len(b.vmap)) <= name {
		b.vmap = append(b.vmap, int32(len(b.vmap)))
	}
	return b.vmap[name]
}

//line common.w:241
const (
	mulA = 0x9E3779B1 // $2^{32}/\phi$, 황금비에서 온 승수
	mulB = 0x85EBCA77
	mulC = 0xC2B2AE35

//line common.w:245
)

func hash2(l, h int32) uint32 {
	x := uint32(l)*mulA + uint32(h)*mulB
	return x ^ (x >> 16)
}

//line common.w:266
func (b *base) uniqueFind(v, l, h int32) int32 {
	if b.zdd {
		if h == botsink {
			return l // |botsink|는 불사이니 계수를 손댈 것도 없다
		}
	} else if l == h {
		if l > topsink {
			b.mem[l].xref--
		}
		return l
	}
	for {
		tab := b.vars[v].tab
		mask := int32(len(tab)) - 1
		k := int32(hash2(l, h)) & mask

//line common.w:291
		for {
			p := tab[k]
			if p == null {
				break
			}
			if b.mem[p].lo == l && b.mem[p].hi == h {
				if b.mem[p].xref < 0 {
					b.dead--
					b.mem[p].xref = 0
					return p
				}
				if l > topsink {
					b.mem[l].xref--
				}
				if h > topsink {
					b.mem[h].xref--
				}
				b.mem[p].xref++
				return p
			}
			k = (k + 1) & mask
		}

//line common.w:282

//line common.w:321
		b.timer++
		if b.timer%timerInterval == 0 && b.dead > b.total/deadFraction {
			b.collectGarbage(false)
			continue
		}
		if b.vars[v].free-1 <= len(tab)/4 {
			b.resizeTable(v, 2*len(tab))
			continue
		}
		p := b.reserveNode()
		tab[k] = p
		b.vars[v].free--
		b.mem[p] = node{lo: l, hi: h, xref: 0, lvl: v}
		return p

//line common.w:283
	}
}

//line common.w:353
func (b *base) resizeTable(v int32, m int) {
	if m < 2 {
		m = 2
	}
	old := b.vars[v].tab
	tab := make([]int32, m)
	mask := int32(m - 1)
	n := 0
	for _, p := range old {
		if p == null {
			continue
		}
		k := int32(hash2(b.mem[p].lo, b.mem[p].hi)) & mask
		for tab[k] != null {
			k = (k + 1) & mask
		}
		tab[k] = p
		n++
	}
	b.vars[v].tab, b.vars[v].free = tab, m-n
}

//line common.w:384
func (b *base) tablePurge(v int32) {
	tab := b.vars[v].tab
	if tab == nil {
		return
	}
	n, del := 0, 0
	for k, p := range tab {
		switch {
		case p == null:
		case b.mem[p].xref < 0:
			b.freeNode(p)
			b.dead--
			tab[k] = null
			del++
		default:
			n++
		}
	}
	m := len(tab)
	for m > 2 && m/8 >= n {
		m /= 2
	}
	if del > 0 || m != len(tab) {
		b.resizeTable(v, m)
	}
}

//line common.w:459
func (b *base) chooseCacheSize(items int) int {
	m, live := minCacheSlots, b.total-b.dead
	for 4*m < live && m < maxCacheSlots {
		m <<= 1
	}
	for m < 4*items && m < maxCacheSlots {
		m <<= 1
	}
	return m
}

func (b *base) cacheInit() {
	b.resizeCache(b.chooseCacheSize(0))
}

//line common.w:487
func (b *base) resizeCache(m int) {
	old := b.cache
	b.cache, b.cmask = make([]memo, m), int32(m-1)
	n := 0
	for i := range old {
		if old[i].r != null {
			b.cache[b.cacheSlot(old[i].f, old[i].g, old[i].h)] = old[i]
			n++
		}
	}
	b.inserts, b.thresh = n, 1+m/2
}

func (b *base) cacheSlot(f, g, h int32) int32 {
	x := uint32(f)*mulA + uint32(g)*mulB + uint32(h)*mulC
	return int32(x^(x>>16)) & b.cmask
}

//line common.w:509
func (b *base) cacheLookup(f, g, h int32) int32 {
	m := &b.cache[b.cacheSlot(f, g, h)]
	r := m.r
	if r == null || m.f != f || m.g != g || m.h != h {
		return null
	}
	if r > topsink {
		if b.mem[r].xref < 0 {
			b.revive(r)
		} else {
			b.mem[r].xref++
		}
	}
	return r
}

func (b *base) cacheInsert(f, g, h, r int32) {
	b.inserts++
	if b.inserts >= b.thresh && len(b.cache) < maxCacheSlots {
		b.resizeCache(2 * len(b.cache))
	}
	b.cache[b.cacheSlot(f, g, h)] = memo{f, g, h, r}
}

//line common.w:536
func (b *base) isDead(p int32) bool {
	return p > topsink && b.mem[p].xref < 0
}

func (b *base) cachePurge() {
	items := 0
	for i := range b.cache {
		m := &b.cache[i]
		if m.r == null {
			continue
		}
		if b.staleMemo(m) {
			m.r = null
		} else {
			items++
		}
	}
	if n := b.chooseCacheSize(items); n < len(b.cache) {
		b.resizeCache(n)
	} else {
		b.inserts = items
	}
}

//line common.w:565
func (b *base) staleMemo(m *memo) bool {
	if b.isDead(m.r) || b.isDead(m.f) {
		return true
	}
	if m.h == 0 {
		return m.g != int32(b.vars[b.mem[m.f].lvl].stamp)
	}
	return b.isDead(m.g) || (m.h > maxBinop && b.isDead(m.h>>4))
}

func (b *base) clearCache() {
	clear(b.cache)
	b.inserts = 0
}

//line common.w:583
func (b *base) memo(f, g, h, r int32) int32 {
	b.cacheInsert(f, g, h, r)
	return r
}

//line common.w:594
func ternKey(h, op int32) int32 { return h<<4 | op }

//line common.w:607
func (b *base) ref(p int32) {
	if p > topsink {
		b.mem[p].xref++
	}
}

func (b *base) deref(p int32) {
	if p <= topsink {
		return // 싱크는 불사다
	}
	if b.mem[p].xref == 0 {
		b.kill(p)
	} else {
		b.mem[p].xref--
	}
}

//line common.w:629
func (b *base) kill(p int32) {
	for {
		b.mem[p].xref = -1
		b.dead++
		if q := b.mem[p].lo; q > topsink {
			if b.mem[q].xref == 0 {
				b.kill(q)
			} else {
				b.mem[q].xref--
			}
		}
		if p = b.mem[p].hi; p <= topsink {
			return
		}
		if b.mem[p].xref != 0 {
			b.mem[p].xref--
			return
		}
	}
}

//line common.w:653
func (b *base) revive(p int32) {
	for {
		b.mem[p].xref = 0
		b.dead--
		if q := b.mem[p].lo; q > topsink {
			if b.mem[q].xref < 0 {
				b.revive(q)
			} else {
				b.mem[q].xref++
			}
		}
		if p = b.mem[p].hi; p <= topsink {
			return
		}
		if b.mem[p].xref >= 0 {
			b.mem[p].xref++
			return
		}
	}
}

//line common.w:702
func (b *base) wrap(p int32) Func {
	h := &handle{b: b, p: p}
	if p > topsink {
		b.ext[p]++
		h.cl = runtime.AddCleanup(h, b.release, p)
	}
	return Func{h}
}

func (b *base) release(p int32) {
	b.mu.Lock()
	b.pending = append(b.pending, p)
	b.mu.Unlock()
}

//line common.w:720
func (b *base) drain() {
	b.mu.Lock()
	pend := b.pending
	b.pending = nil
	b.mu.Unlock()
	for _, p := range pend {
		b.unext(p)
	}
}

func (b *base) unext(p int32) {
	b.ext[p]--
	if b.ext[p] == 0 {
		delete(b.ext, p)
	}
	b.deref(p)
}

//line common.w:745
func (b *base) node(f Func) int32 {
	switch {
	case f.h == nil || f.h.b == nil:
		panic("bdd: 이미 놓아 버린 함수를 썼다")
	case f.h.b != b:
		panic("bdd: 다른 밑준위의 함수를 썼다")
	}
	return f.h.p
}

func (f Func) Equal(g Func) bool {
	return f.h != nil && g.h != nil && f.h.b == g.h.b && f.h.p == g.h.p
}

//line common.w:763
func (f Func) Free() {
	h := f.h
	if h == nil || h.b == nil {
		return
	}
	b, p := h.b, h.p
	h.b, h.p = nil, null
	if p > topsink {
		h.cl.Stop()
		b.drain()
		b.unext(p)
	}
}

//line common.w:784
func (b *base) collectGarbage(all bool) {
	b.gcs++
	if all {
		b.clearCache()
		b.resetStamps()
	} else {
		b.cachePurge()
	}
	for v := range b.vars {
		b.tablePurge(int32(v))
	}
}

//line common.w:809
func (b *base) resetStamps() {
	if len(b.vars) == 0 || b.vars[0].stamp == 0 {
		b.stamp, b.stampChg = 0, false
		return
	}
	b.stamp, b.stampChg = 1, true
	for v := range b.vars {
		if b.vars[v].stamp == 0 {
			break
		}
		b.vars[v].stamp = 1
	}
}

//line common.w:842
func (b *base) Stats() Stats {
	s := Stats{Nodes: b.total, Dead: b.dead,
		CacheSlots: len(b.cache), Collections: b.gcs}
	for v := range b.vars {
		if b.vars[v].tab != nil {
			s.Vars++
		}
	}
	return s
}

func (s Stats) String() string {
	return fmt.Sprintf("노드 %d개(죽은 것 %d개), 변수 %d개, 캐시 %d칸, 수거 %d번",
		s.Nodes, s.Dead, s.Vars, s.CacheSlots, s.Collections)
}

//line common.w:867
func (b *base) levels() []int32 {
	out := make([]int32, 0, len(b.vars))
	for v := range b.vars {
		if b.vars[v].tab != nil {
			out = append(out, int32(v))
		}
	}
	return out
}

//line common.w:880
func (b *base) ranks() []int32 {
	rk := make([]int32, len(b.vars)+1)
	n := int32(0)
	for v := range b.vars {
		rk[v] = n
		if b.vars[v].tab != nil {
			n++
		}
	}
	rk[len(b.vars)] = n
	return rk
}

func rankOf(rk []int32, lvl int32) int32 {
	if int(lvl) >= len(rk)-1 {
		return rk[len(rk)-1] // 싱크
	}
	return rk[lvl]
}

//line common.w:904
func (b *base) reach(p int32, seen map[int32]bool) {
	if seen[p] {
		return
	}
	seen[p] = true
	if p > topsink {
		b.reach(b.mem[p].lo, seen)
		b.reach(b.mem[p].hi, seen)
	}
}

//line common.w:921
func randBelow(rnd *rand.Rand, n *big.Int) *big.Int {
	k := n.BitLen()
	buf := make([]byte, (k+7)/8)
	x := new(big.Int)
	for {
		for i := range buf {
			buf[i] = byte(rnd.Uint32())
		}
		x.SetBytes(buf)
		x.Rsh(x, uint(8*len(buf)-k))
		if x.Cmp(n) < 0 {
			return x
		}
	}
}

//line common.w:952
func (b *base) Check() error {
	b.drain()
	want := make(map[int32]int32)

//line common.w:969
	for p, n := range b.ext {
		want[p] += n
	}
	for v := range b.vars {
		for _, q := range [3]int32{b.vars[v].proj, b.vars[v].repl, b.vars[v].elt} {
			if q > topsink {
				want[q]++
			}
		}
	}
	if len(b.vars) > 0 && b.vars[0].taut > topsink {
		want[b.vars[0].taut]++ // 나머지 항진 노드는 바로 위의 것이 붙든다
	}

//line common.w:956

//line common.w:987
	seen := make(map[[3]int32]bool)
	total, dead := 2, 0
	for v := range b.vars {
		for _, p := range b.vars[v].tab {
			if p == null {
				continue
			}
			total++
			nd := &b.mem[p]
			if nd.lvl != int32(v) {
				return fmt.Errorf("노드 %d는 준위 %d의 표에 있는데 lvl은 %d다", p, v, nd.lvl)
			}
			key := [3]int32{int32(v), nd.lo, nd.hi}
			if seen[key] {
				return fmt.Errorf("노드 (%d,%d,%d)가 둘 있다", v, nd.lo, nd.hi)
			}
			seen[key] = true
			if err := b.checkShape(p); err != nil {
				return err
			}
			if nd.xref < 0 {
				dead++
			} else {

//line common.w:1016
				if nd.lo > topsink {
					want[nd.lo]++
				}
				if nd.hi > topsink {
					want[nd.hi]++
				}

//line common.w:1011
			}
		}
	}

//line common.w:957

//line common.w:1059
	for p := range seen {
		q := b.find(p[0], p[1], p[2])
		if n := want[q]; b.mem[q].xref < 0 && n != 0 {
			return fmt.Errorf("죽은 노드 %d를 %d군데서 가리킨다", q, n)
		} else if b.mem[q].xref >= 0 && b.mem[q].xref != n-1 {
			return fmt.Errorf("노드 %d의 참조 계수는 %d여야 하는데 %d다",
				q, n-1, b.mem[q].xref)
		}
	}

//line common.w:1075
	nfree := 0
	for p := b.avail; p != null; p = b.mem[p].xref {
		if nfree++; nfree >= len(b.mem) {
			return fmt.Errorf("자유 목록이 고리를 이룬다")
		}
	}
	if b.total+nfree != len(b.mem)-1 {
		return fmt.Errorf("노드 %d개가 새어 나갔다", len(b.mem)-1-b.total-nfree)
	}

//line common.w:1069
	if total != b.total || dead != b.dead {
		return fmt.Errorf("노드는 %d(죽은 것 %d)여야 하는데 %d(죽은 것 %d)로 세고 있다",
			total, dead, b.total, b.dead)
	}

//line common.w:958
	return nil
}

//line common.w:1028
func (b *base) checkShape(p int32) error {
	nd := &b.mem[p]
	switch {
	case b.zdd && nd.hi == botsink:
		return fmt.Errorf("ZDD 노드 %d의 hi가 botsink다", p)
	case !b.zdd && nd.lo == nd.hi:
		return fmt.Errorf("BDD 노드 %d의 lo와 hi가 같다", p)
	case b.mem[nd.lo].lvl <= nd.lvl || b.mem[nd.hi].lvl <= nd.lvl:
		return fmt.Errorf("노드 %d가 준위 차례를 거스른다", p)
	case b.find(nd.lvl, nd.lo, nd.hi) != p:
		return fmt.Errorf("노드 %d를 유일 테이블에서 찾을 수 없다", p)
	}
	return nil
}

func (b *base) find(v, l, h int32) int32 {
	tab := b.vars[v].tab
	mask := int32(len(tab)) - 1
	for k := int32(hash2(l, h)) & mask; tab[k] != null; k = (k + 1) & mask {
		if p := tab[k]; b.mem[p].lo == l && b.mem[p].hi == h {
			return p
		}
	}
	return null
}
