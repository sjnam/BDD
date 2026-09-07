\input kotexgweb

\def\title{변수 재정렬}

@s Func int
@s base int

@* 변수 재정렬.
BDD의 크기는 변수 차례에 목을 맨다. 같은 함수라도 어떤 차례에서는 노드가
$n$개면 되고 다른 차례에서는 $2^n$개가 든다. 고전적인 예가
$x_1x_2\lor x_3x_4\lor\cdots\lor x_{2n-1}x_{2n}$이다. 이 차례로는 노드가
$2n+2$개인데, 홀수를 다 앞에 놓고 짝수를 다 뒤에 놓으면 $2^{n+1}$개가 된다.
그러니 좋은 차례를 찾는 일은 곁다리가 아니라 본론이다.

가장 좋은 차례를 찾는 것은 NP-어려운 문제다. 그래서 다들 어림으로 간다.
1993년에 Richard Rudell이 낸 {\it 체질\/}(sifting)이 그 가운데 가장 널리
쓰인다. 변수 하나를 골라 위에서 아래까지 죽 밀어 보고, 노드가 가장 적었던
자리에 놓아 두는 것이다. 그 단순한 생각이 놀랄 만큼 잘 듣는다.
@^Rudell, Richard Lyle@>

@ 모든 것이 {\it 제자리 맞바꿈\/} 하나에 얹혀 있다. 이웃한 두 준위
$x_u\leftrightarrow x_v$를 맞바꾸는 일이다($x_u$가 $x_v$ 바로 위에 있다고
하자). 이 일을 하는 동안 죽는 노드는 하나도 없고, 준위 $u$나 $v$에서
갈라지는 노드 바깥으로는 화살표 하나 바뀌지 않는다. 바깥에서든 위에서든
닿을 수 있는 노드는 맞바꿈 뒤에도 여전히 같은 부분함수를 나타낸다. 다만
나타내는 {\it 방식\/}이 달라질 뿐이다.

이 글은 그 맞바꿈과, 그 위에 얹힌 체질을 담는다. BDD와 ZDD가 나눠 쓰므로
밑준위의 메서드로 둔다. 다른 것은 두 곳뿐이다---맞바꿈이 만들어 내는 새
노드의 축약 규칙과, 준위마다 딸린 특별한 노드를 뒤처리하는 방식.
@c
package bdd

@<함수들@>

@* 네 갈래.
맞바꿈을 이해하는 열쇠는 두 준위의 노드를 넷으로 가르는 데 있다.

준위~$u$의 노드 가운데 준위~$v$의 노드로 가지를 뻗은 것을 {\it 얽힌\/}
노드라 하고, 그렇지 않은 것을 {\it 홀로\/} 노드라 하자. 준위~$v$의 노드
가운데 $u$보다 위에서 또는 바깥에서 닿을 수 있는 것을 {\it 바깥에 걸린\/}
노드라 하고, 오직 준위~$u$에서만 닿을 수 있는 것을 {\it 숨은\/} 노드라 하자.

맞바꿈 뒤에 이들이 가는 곳은 이렇다. 얽힌 노드는 준위~$u$에 남지만 이제
옛 $x_v$를 갈라 보고, 두 화살표가 죄다 바뀐다. 홀로 노드는 준위~$v$로
내려가고, 거기서 바깥에 걸린 노드가 된다. 바깥에 걸린 노드는 준위~$u$로
올라가서 홀로 노드가 된다. 숨은 노드는 사라진다. 그 자리에 {\it 새내기\/}
노드들이 태어나는데, 이들은 준위~$v$에서 옛 $x_u$를 갈라 본다.

얽힌 노드가 $m$개면 숨은 노드는 많아야 $2m$개이고 새내기도 많아야 $2m$개다.
그러니 맞바꿈이 남는 장사인 것은 숨은 노드가 새내기보다 많을 때다.

@ 숨은 노드를 어떻게 알아볼까. 크누스의 수가 곱다. 얽힌 노드를 가려내면서
그 자식들의 참조 계수를 하나씩 {\it 내려\/} 둔다. 그러고 나면 준위~$v$의
노드 가운데 계수가 음수가 된 것이 곧 숨은 노드다. 오직 준위~$u$에서만
닿을 수 있었다는 뜻이니까.

여기서 내리는 것은 날 것 그대로의 뺄셈이라, 죽음의 행렬을 부르지도 않고
죽은 노드로 세지도 않는다. 잠깐 음수가 되었다가 맞바꿈이 끝날 즈음에는
셈이 도로 맞는다.
@<함수들@>=
func (b *base) decChild(p int32) {
	if p > topsink {
		b.mem[p].xref--
	}
}

@ 맞바꿈의 뼈대. 크누스는 옛 유일 테이블을 제자리에서 뒤집어 홀로 노드는
앞쪽에, 얽힌 노드는 뒤쪽에 몰아넣는다---퀵정렬의 안쪽 고리를 닮은 예쁜
되풀이다. 페이지를 새로 잡을 수 없으니 있는 자리를 빌려 쓴 것이다. 우리는
슬라이스 둘을 잡으면 그만이다.
@<함수들@>=
func (b *base) swap(u, v int32) {
	@<준위 |u|를 홀로와 얽힘으로 가른다@>@;
	@<준위 |v|를 바깥에 걸린 것과 숨은 것으로 가른다@>@;
	@<표 둘을 새로 짓고 옮길 것을 옮긴다@>@;
	@<얽힌 노드를 뒤바꾼다@>@;
	for _, p := range hidden {
		b.freeNode(p)
	}
	@<이름과 딸린 노드들을 맞바꾼다@>@;
}

@ @<준위 |u|를 홀로와 얽힘으로 가른다@>=
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

@ 숨은 노드는 사라질 것이므로, 그 자식들이 걸고 있던 참조도 함께 거둔다.
자리는 아직 놓아 주지 않는다---뒤바꾸는 동안 그 |lo|와 |hi|를 다시 봐야 하기
때문이다.
@<준위 |v|를 바깥에 걸린 것과 숨은 것으로 가른다@>=
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

@ 두 표를 통째로 버리고 새로 짓는다. 크누스가 이 길을 고른 까닭을 적어
두었다. 준위~$u$의 노드는 거의 다 얽혀 있고 준위~$v$의 노드는 거의 다
숨어 있으리라고 보면, 남는 것만 지우고 나머지를 끼워 넣는 것보다 통째로
다시 짓는 편이 싸다는 것이다.
@<표 둘을 새로 짓고 옮길 것을 옮긴다@>=
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

@ 맞바꿈에서 가장 극적인 일이 여기서 벌어진다.

얽힌 노드 |f|가 준위~$u$에 있고 그 두 자식 |g|와 |h|가 준위~$v$에 있다고
하자. 맞바꿈 뒤에 |f|의 두 자식은 새내기 |gg|와 |hh|여야 하는데,
$$|gg|=(v,\,g_l,\,h_l),\qquad |hh|=(v,\,g_h,\,h_h)$$
이다. 네 손자를 두 줄로 늘어놓았다가 열로 다시 읽는 셈이다. 두 자식 |g|나 |h|가
준위~$v$보다 아래에 있으면 그 자리에는 저 자신이 들어간다.
@<얽힌 노드를 뒤바꾼다@>=
for _, f := range tangled {
	g, h := b.mem[f].lo, b.mem[f].hi
	gg := b.swapFind(v, b.cofactor(g, v, false), b.cofactor(h, v, false))
	hh := b.swapFind(v, b.cofactor(g, v, true), b.cofactor(h, v, true))
	b.mem[f].lo, b.mem[f].hi = gg, hh
	b.insertNode(u, f)
}

@ 자식을 고르는 자리에서 두 세계가 갈린다. 준위~$v$보다 아래에 있는 노드를
1쪽 갈래에서 어떻게 볼 것인가. BDD에서는 그 변수가 상관없다는 뜻이므로
저 자신이 그대로 오고, ZDD에서는 그 원소가 없다는 뜻이므로 |botsink|가 온다.
@<함수들@>=
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

@ |swapFind|는 |uniqueFind|와 거의 같은데 참조 계수를 다루는 결이 다르다. 앞의 것
|uniqueFind|는 얹혀 온 참조를 삼키지만, 여기서는 아무것도 삼키지 않고 결과에
참조를 하나 얹어 준다. 지금 죽은 노드가 하나도 없다는 것도 알고 있으므로
되살리는 대목이 없다.
@<함수들@>=
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
		@<이미 있으면 그것을 돌려준다@>@;
		@<없으면 새내기를 하나 만든다@>@;
	}
}

@ @<이미 있으면 그것을 돌려준다@>=
for tab[k] != null {
	if p := tab[k]; b.mem[p].lo == l && b.mem[p].hi == h {
		b.ref(p)
		return p
	}
	k = (k + 1) & mask
}

@ @<없으면 새내기를 하나 만든다@>=
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

@ 표를 새로 잡는 일과, 유일한 줄 이미 아는 노드를 끼워 넣는 일. 새 표는
노드 |m|개를 담고도 아직 두 배로 늘 일이 없을 만큼 크게 잡는다---곧
빽빽함이 3/4을 넘지 않을 만큼.
@<함수들@>=
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

@ 마지막 뒤처리. 이름과 |aux| 표식과 투영 함수는 변수를 따라다니므로
맞바꾼다. 표식 |aux|의 부호가 이름을 따라가도록 손보는 것은 체질이 ``이 변수는
이미 훑었다''를 그 부호에 적어 두기 때문이다.
@<이름과 딸린 노드들을 맞바꾼다@>=
j, k := b.vars[u].name, b.vars[v].name
b.vars[u].name, b.vars[v].name = k, j
b.vmap[j], b.vmap[k] = v, u
if a, c := b.vars[u].aux, b.vars[v].aux; a*c < 0 {
	b.vars[u].aux, b.vars[v].aux = -a, -c
}
b.vars[u].proj, b.vars[v].proj = b.vars[v].proj, b.vars[u].proj
if b.zdd {
	@<원소 함수와 항진 노드를 손본다@>@;
} else {
	@<치환 함수와 도장을 손본다@>@;
}

@ 원소 함수 $e_k$도 변수를 따라다니므로 맞바꾼다. 항진 노드는 다르다.
그것은 변수가 아니라 {\it 준위\/}에 매인 것이라 맞바꾸지 않는다. 게다가
준위~$v$의 옛 항진 노드는 숨은 노드였다면 사라져 버렸을 수도 있다.

그래서 크누스는 새 $t_v$를 $t_u$에서 캐낸다. $t_u$는 두 자식이 모두 $t_v$인
얽힌 노드이므로, 뒤바꿈을 거치면서 그 두 자식이 새 준위~$v$의 항진 노드로
다시 태어난다. 그 자식이 곧 새 $t_v$다. (곰곰이 생각해 보시라.)
@<원소 함수와 항진 노드를 손본다@>=
b.vars[u].elt, b.vars[v].elt = b.vars[v].elt, b.vars[u].elt
b.vars[v].taut = b.mem[b.vars[u].taut].lo

@ BDD 쪽에서는 치환 함수를 맞바꾸고, 준위~$v$의 시각 도장을 손본다.
치환이 새로 생겼는데 도장이 없으면 찍어 주고, 치환이 사라졌는데 아래로도
치환이 없으면 거둔다.
@<치환 함수와 도장을 손본다@>=
b.vars[u].repl, b.vars[v].repl = b.vars[v].repl, b.vars[u].repl
switch {
case b.vars[v].repl != null && b.vars[v].stamp == 0:
	b.vars[v].stamp = 1
case b.vars[v].repl == null && b.vars[v].stamp != 0 &&
	(int(v+1) >= len(b.vars) || b.vars[v+1].stamp == 0):
	b.vars[v].stamp = 0
}

@* 체질.
맞바꿈처럼 예민한 일에 손대기 전에 채비가 필요하다. 캐시에 적힌 것은 죄다
뜻을 잃으므로 통째로 비우고, 죽은 노드도 걷어낸다---그것들이 길을 막기
때문이다. 그러고서 활성 준위들을 위아래로 꿰는 |up|과 |down| 링크를 걸고,
|aux|에 위에서부터 몇 번째인지를 적어 둔다.
@<함수들@>=
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

@ 한 방향으로 끝까지 밀어 보는 일. 미는 동안 노드 수가 가장 적었던 값을
|best|에 적어 둔다.

크누스는 이 자리에 재미난 계기를 하나 달아 두었다. 실전이라면
|totalnodes/bestscore|가 어떤 문턱을 넘는 순간 그 방향을 포기해야 하는데,
그는 끝까지 밀어 보면서 ``그 문턱이 얼마였다면 끝까지 민 것과 같은 답을
얻었을까''를 재었다. 그 값을 |saferatio|라 불렀다. 우리는 그냥 끝까지 민다.
@<함수들@>=
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

@ 변수를 준위 하나만큼 옮기는 두 걸음. 준위의 |up|과 |down| 링크는 준위에
매인 것이라 맞바꿈에도 그대로 남는다는 점을 눈여겨보자. 움직이는 것은
변수뿐이다.
@<함수들@>=
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

@ 이제 체질이다. 준위~|v|의 변수를 위아래로 끝까지 밀어 보고 가장 좋았던
자리에 놓는다. 먼 쪽을 먼저 훑는 것은 되돌아오는 걸음을 아끼기 위해서다.

첫 방향을 다 훑고 나면 출발점으로 되돌아왔다가 반대 방향으로 간다. 그러고는
노드 수가 |best|와 같아질 때까지 되짚어 온다. 되짚는 길에서 노드 수가 갈
때와 똑같은 차례로 나타나므로, 그 값을 만나면 바로 거기가 가장 좋았던
자리다.
@<함수들@>=
func (b *base) sift(v int32) {
	best, u := b.total, v
	up := b.totalvars-b.vars[v].aux >= b.vars[v].aux
	u = b.explore(u, up, &best)
	@<출발점으로 되돌아온다@>@;
	u = b.explore(u, !up, &best)
	@<가장 좋았던 자리로 되짚어 온다@>@;
	b.vars[u].aux = -b.vars[u].aux // 이 변수는 체질을 마쳤다
}

@ @<출발점으로 되돌아온다@>=
for u != v {
	if u < v {
		u = b.stepDown(u)
	} else {
		u = b.stepUp(u)
	}
}

@ @<가장 좋았던 자리로 되짚어 온다@>=
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

@ 모든 변수를 차례로 체질한다. 어느 차례로 체질하느냐가 결과를 바꾸는 것은
분명한데, 크누스가 Rudell에게 물었더니 ``어느 것도 딱히 낫지 않다''는 답을
들었다고 한다. 그래서 그는 맨 처음 떠오른 차례를 썼다. 우리도 그렇게 한다.
@^Rudell, Richard Lyle@>
@<함수들@>=
func (b *base) siftAll() {
	for v := b.first; v >= 0; {
		if b.vars[v].aux < 0 {
			v = b.vars[v].down // 이미 훑은 변수다
			continue
		}
		b.sift(v)
	}
}

@* 바깥으로 내는 문.
다섯을 낸다. 지금 차례 보기, 이웃과 맞바꾸기, 변수 하나 체질하기, 모두
체질하기, 그리고 차례를 통째로 정해 주기. 모두 |base|의 메서드이므로
BDD와 ZDD가 그대로 물려받는다.
@<함수들@>=
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

@ 체질은 둘로 낸다. 변수 하나를 위아래로 밀어 보고 노드가 가장 적은 자리에
놓는 것과, 모든 변수가 제 자리를 찾을 때까지 차례로 훑는 것.
@<함수들@>=
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

@ 차례를 통째로 정해 주고 싶을 때도 있다. 위에서부터 한 자리씩 채워 나가되,
채울 변수를 제자리에서 위로 밀어 올린다. 이미 채운 자리는 그 위에 있으므로
흐트러지지 않는다. 차례에 빠진 변수는 그 아래에 있던 차례대로 남는다.
@<함수들@>=
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

@* 시험.
재정렬의 시험은 하나로 요약된다. {\it 차례를 아무리 뒤흔들어도 함수는 그대로여야
한다\/}. 사용자가 붙든 함수 열두 개의 진리표를 적어 두고, 맞바꾸고 체질하고
통째로 뒤섞기를 이백 번 되풀이하면서 그때마다 열두 개를 모두 다시 재어 본다.
밑준위의 온전성 검사도 함께 돌린다---맞바꿈은 참조 계수를 손으로 만지작거리는
일이라 어긋나기 딱 좋은 자리다.
@(reorder_test.go@>=
package bdd

import (
	"math/rand/v2"
	"slices"
	"testing"
)

func TestReorderBDD(t *testing.T) {
	b := New()
	rnd := rand.New(rand.NewPCG(41, 42))
	vars := make([]Func, nv)
	for k := range vars {
		vars[k] = b.Var(k)
	}
	var fs []Func
	var ts []tt
	for i := 0; i < 12; i++ {
		f, m := randFunc(b, rnd, vars)
		fs, ts = append(fs, f), append(ts, m)
	}
	@<차례를 뒤흔들며 함수가 그대로인지 본다@>@;
}

@ @<차례를 뒤흔들며 함수가 그대로인지 본다@>=
verify := func(tag string) {
	for i, f := range fs {
		if got := ttOf(b, f); got != ts[i] {
			t.Fatalf("%s: f%d가 %x여야 하는데 %x", tag, i, ts[i], got)
		}
	}
	if err := b.Check(); err != nil {
		t.Fatalf("%s: %v", tag, err)
	}
}
verify("처음")
for it := 0; it < 200; it++ {
	@<네 가지 재정렬 가운데 하나를 한다@>@;
	verify("재정렬 뒤")
	@<차례가 순열인지 본다@>@;
}

@ @<네 가지 재정렬 가운데 하나를 한다@>=
switch rnd.IntN(4) {
case 0:
	b.Swap(rnd.IntN(nv))
case 1:
	b.Sift(rnd.IntN(nv))
case 2:
	b.SiftAll()
case 3:
	ord := b.Order()
	rnd.Shuffle(len(ord), func(i, j int) { ord[i], ord[j] = ord[j], ord[i] })
	b.Reorder(ord)
}

@ @<차례가 순열인지 본다@>=
ord := b.Order()
s := slices.Clone(ord)
slices.Sort(s)
for k := range s {
	if s[k] != k {
		t.Fatalf("차례가 순열이 아니다: %v", ord)
	}
}

@ 체질이 실제로 값을 하는지도 봐야겠다. 고전적인 예를 쓴다.
$$x_0x_m\lor x_1x_{m+1}\lor\cdots\lor x_{m-1}x_{2m-1}$$
을 짝을 갈라놓는 최악의 차례로 지으면 노드가 $2^{m+1}$개쯤 되고, 짝을
붙여 놓은 가장 좋은 차례에서는 $2m+2$개면 된다. $m=7$이면 256개와 16개다.
체질을 몇 바퀴 돌리면 그 이론값에 이른다.
@(reorder_test.go@>=
func TestSiftShrinks(t *testing.T) {
	const m = 7
	b := New()
	f := b.Zero()
	for i := 0; i < m; i++ {
		f = b.Or(f, b.And(b.Var(i), b.Var(m+i)))
	}
	before := b.Size(f)
	for r := 0; r < 4; r++ {
		b.SiftAll()
	}
	after := b.Size(f)
	if err := b.Check(); err != nil {
		t.Fatal(err)
	}
	t.Logf("노드 %d개에서 %d개로, 차례 %v", before, after, b.Order())
	if after != 2*m+2 {
		t.Errorf("이론값 %d개에 이르지 못했다: %d개", 2*m+2, after)
	}
}

@ ZDD 쪽도 같은 방식으로 본다. 족을 그대로 지키는지 보고, 재정렬 뒤에도
대수 연산이 여전히 맞는지 한 가지씩 곁들여 확인한다---차례가 바뀌면
결합처럼 준위를 오르내리는 연산이 가장 먼저 티가 날 것이기 때문이다.
@(reorder_test.go@>=
func TestReorderZDD(t *testing.T) {
	z := NewZDD(zn)
	rnd := rand.New(rand.NewPCG(51, 52))
	var fs []Func
	var ms []fam
	for i := 0; i < 8; i++ {
		m := fam(rnd.Uint32())
		fs, ms = append(fs, mk(z, m)), append(ms, m)
	}
	@<족이 그대로인지 보며 차례를 뒤흔든다@>@;
}

@ @<족이 그대로인지 보며 차례를 뒤흔든다@>=
verify := func(tag string) {
	for i, f := range fs {
		if got := famOf(z, f); got != ms[i] {
			t.Fatalf("%s: f%d가 %x여야 하는데 %x", tag, i, ms[i], got)
		}
	}
	if err := z.Check(); err != nil {
		t.Fatalf("%s: %v", tag, err)
	}
}
verify("처음")
union := func(a, b int) (int, bool) { return a | b, true }
for it := 0; it < 150; it++ {
	switch rnd.IntN(4) {
	case 0:
		z.Swap(rnd.IntN(zn))
	case 1:
		z.Sift(rnd.IntN(zn))
	case 2:
		z.SiftAll()
	case 3:
		ord := z.Order()
		rnd.Shuffle(len(ord), func(i, j int) { ord[i], ord[j] = ord[j], ord[i] })
		z.Reorder(ord)
	}
	verify("재정렬 뒤")
	i, j := rnd.IntN(len(fs)), rnd.IntN(len(fs))
	if got := famOf(z, z.Join(fs[i], fs[j])); got != pairOp(ms[i], ms[j], union) {
		t.Fatalf("%d번째: 재정렬 뒤 Join이 틀렸다", it)
	}
}

@* 색인.
