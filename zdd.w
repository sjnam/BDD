\input kotexgweb

\def\title{ZDD 엔진}

@s Func int
@s Int int
@s Seq int
@s Rand int
@s iter int
@s big int
@s rand int
@s slices int

@* ZDD 엔진.
BDD의 첫째 축약 규칙은 ``두 갈래가 같은 곳으로 가면 그 노드는 필요 없다''였다.
1993년에 미나토 신이치(南 眞一)는 그 규칙을 다른 것으로 갈아 끼워 보았다.
{\it 1쪽 갈래가 |botsink|로 가면 그 노드는 필요 없다\/}. 이 한 글자 차이로
태어난 것이 {\it 영 억제 결정 다이어그램\/}(zero-suppressed BDD), 곧 ZDD다.
@^Minato, Shin-ichi@>
@^미나토 신이치@>

갈아 끼운 규칙이 뜻하는 바를 보자. BDD에서 어떤 변수를 건너뛴 것은 ``그
변수가 무엇이든 상관없다''는 뜻이다. ZDD에서 건너뛴 것은 ``그 변수는 반드시
0이다''라는 뜻이다. 그래서 ZDD는 불 함수보다 {\it 집합족\/}을 나타내는 데
알맞다. 원소 $n$개 가운데 서너 개씩만 담은 집합들의 모임이라면, BDD는
``나머지 원소는 다 빠져 있다''를 노드로 일일이 적어야 하지만 ZDD는 그저
지나친다. 성긴 족일수록 ZDD가 이긴다.

@ 그러니 이 글에서 우리가 다루는 것은 함수가 아니라 {\it 집합족\/}이다.
크누스의 표기를 따라, 원소들을 $e_0$, $e_1$, \dots, $e_{n-1}$이라 하고
족 셋에 이름을 준다. $\emptyset$은 아무 집합도 없는 빈 족이고,
$\epsilon=\{\emptyset\}$은 공집합 하나만 든 족이며, $\wp$는 부분집합
$2^n$개가 다 든 족이다.

연산도 그에 맞춰 달라진다. 합집합·교집합·차집합은 여전히 있지만
(족을 집합으로 보고 하는 셈이다), 여기에 {\it 족의 대수\/}가 더해진다.
두 족의 원소를 짝지어 합집합을 만드는 {\it 결합\/} $f\sqcup g$, 교집합을
만드는 {\it 만남\/} $f\sqcap g$, 대칭차를 만드는 $f\mathbin{\Delta}g$,
그리고 나눗셈 $f/g$와 $f\bmod g$. 크누스의 \.{BDD14}에 있던 한정사와 합성은
여기 없고, 대신 이것들이 있다.

@ 밑바탕은 옆집 \.{common.w}에 있다. 노드도 유일 테이블도 캐시도 참조 계수도
BDD와 똑같은 것을 쓰고, 다른 것은 |uniqueFind| 안의 축약 규칙 한 줄뿐이다.
밑준위를 세울 때 |zdd| 깃발을 올리는 것으로 그 한 줄이 갈린다.
@c
package bdd

import (
	"iter"
	"math/big"
	"math/rand/v2"
	"slices"
)

@<자료 구조@>

@<함수들@>

@* 밑준위 세우기.
BDD와 달리 ZDD는 변수를 미리 다 만들어 놓아야 한다. 크누스가 적었듯
``모든 ZDD의 변수가 정해진 고정 집합에 속한다고 못 박으면 프로그램 논리가
크게 간단해진다.'' 그럴 만한 까닭이 있다. ZDD에서 ``건너뛴다''는 것이
``그 원소는 없다''는 뜻이므로, 어디까지가 원소인지를 모르면 족 자체가
정해지지 않는다. 그래서 밑준위가 원소의 수를 지니고 다닌다---여기 사는 것은
$\{e_0,\ldots,e_{n-1}\}$의 부분집합족들이다.
@<자료 구조@>=
type ZDD struct {
	base
	n int32 // 원소의 수
}

@ 준위마다 특별한 노드가 둘 있다. 하나인 |taut|은 ``여기서부터 아래로는 무엇이든
좋다''는 뜻의 노드다. 준위 $v$의 |taut|은 $\{e_v,\ldots,e_{n-1}\}$의 부분집합이
모두 든 족이고, 준위 0의 것이 곧 $\wp$다. 다른 하나인 |elt|는 원소 함수 $e_v$로,
집합 $\{e_v\}$ 하나만 든 족이다.

싱크의 준위를 |n|으로 둔다. 그리고 |vars|에 칸을 하나 더 붙여 그 |taut|을
|topsink|로 해 둔다. 이렇게 해 두면 ``이 준위의 1은 무엇인가''를 묻는 자리마다
싱크를 따로 가려낼 일이 없다. 크누스의 수였다.
@<함수들@>=
func NewZDD(n int) *ZDD {
	b := &ZDD{n: int32(n)}
	b.init(true)
	@<변수들을 한꺼번에 만든다@>@;
	return b
}

@ |taut|은 밑에서부터 쌓아 올린다. 준위 $n$의 것이 |topsink|이고, 준위 $v$의
것은 $(v,t_{v+1},t_{v+1})$이다. ZDD에서는 두 갈래가 같아도 노드가 사라지지
않는다는 것을 여기서 처음 눈으로 본다---BDD였다면 이 노드들은 죄다 |topsink|로
찌부러졌을 것이다.

참조 계수를 세는 방식이 조금 남다르다. 항진 노드 $t_k$를 바깥에서 붙드는 것은
맨 위의 $t_0$뿐이고, 나머지는 바로 위 항진 노드 $t_{k-1}$의 두 화살표가 붙든다.
그렇게 해 두어야 변수 순서를 바꿀 때 준위 $v$의 항진 노드가 {\it 숨은\/}
노드가 되어 사라질 수 있다(옆집 \.{reorder.w}를 보라). 그래서 아래 고리는
슬롯이 쥐고 있던 참조를 위 노드에게 물려주며 올라간다.
@<변수들을 한꺼번에 만든다@>=
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

@ 바깥으로 내는 상수들. 크누스의 \.{ZDDL}에서 \.{c0}, \.{c1}, \.{c2}라
부르던 것들이다. |Empty|는 아무 집합도 없는 빈 족 $\emptyset$, |Unit|은
공집합 하나만 든 족 $\epsilon$, |Universe|는 부분집합이 모두 든 족 $\wp$다.
원소의 수를 되묻는 |N|도 곁들여 둔다.
@<함수들@>=
func (b *ZDD) Empty() Func { return b.wrap(botsink) }
func (b *ZDD) Unit() Func  { return b.wrap(topsink) }

func (b *ZDD) Universe() Func {
	b.drain()
	p := b.taut(0)
	b.ref(p)
	return b.wrap(p)
}

func (b *ZDD) N() int { return int(b.n) }

func (b *ZDD) taut(v int32) int32 { return b.vars[v].taut }

@ 원소 하나로 이루어진 두 가지 족. 앞의 것 |Elt|는 집합 $\{e_k\}$ 하나만 든 족
$e_k$이고, |Var|는 $e_k$를 품은 부분집합이 모두 든 족 $x_k$다. 둘을
헷갈리지 말자---크누스가 \.{ZDDL}에서 \.e와 \.x로 나눠 적은 것이 이 둘이다.
@<함수들@>=
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

@* 이항 연산.
크누스의 번호를 그대로 쓰되 하나만 옮긴다. 그는 이접곱(disproduct)에 0을
주었는데, 우리 밑준위는 0을 합성 항목의 표시로 쓰기로 했으므로(옆집
\.{bdd.w}의 시각 도장을 보라) 빈 번호 12로 옮겼다.
@<자료 구조@>=
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

@ 겉껍질은 BDD 때와 같은 모양이다.
@<함수들@>=
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

@ 교집합부터. 여기서 ZDD가 BDD와 어떻게 다른지가 대뜸 드러난다.

두 족의 꼭대기 준위가 다르다고 하자. 족 |f|는 준위 $v$에서 갈라지는데 |g|는
그보다 아래에서 갈라진다면, |g|에 든 어느 집합도 $e_v$를 품지 않는다는 뜻이다.
그러니 교집합에도 $e_v$를 품은 집합이 있을 수 없다. 그러니 |f|의 0쪽으로 내려가면
된다. 준위가 맞을 때까지 이렇게 내려간다. BDD였다면 두 준위 가운데 위엣것에서
{\it 갈라\/} 두 번 재귀했을 자리다.
@<함수들@>=
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
	@<준위가 맞은 뒤의 교집합@>@;
}

@ @<준위가 맞은 뒤의 교집합@>=
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

@ 합집합은 교집합의 쌍대가 {\it 아니다\/}. 앞의 \.{BDD14}에서는 그랬지만 여기서는
아니다. 족 |f|가 준위 $v$에서 갈라지고 |g|는 그 아래에서 갈라진다면, 결과의
1쪽 갈래는 |f|의 1쪽 갈래 그대로다---$e_v$를 품은 집합은 |f|에서만 오기
때문이다. 그러니 재귀는 0쪽으로 한 번만 간다.
@<함수들@>=
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
	@<합집합을 재귀로 구한다@>@;
}

@ @<합집합을 재귀로 구한다@>=
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

@ 대칭차도 거의 같다. 항진에 걸리는 지름길이 없다는 것만 다르다.
@<함수들@>=
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
	@<대칭차를 재귀로 구한다@>@;
}

@ @<대칭차를 재귀로 구한다@>=
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

@ 차집합 $f\setminus g$. ZDD가 잘 어울리는 연산자는 $0\circ0=0$을 만족하는
``정상''(normal) 연산자들인데, $\land$, $\lor$, $\oplus$를 했으니 남은 것이
이것이다.

족 |g|가 |f|보다 위에서 갈라지면 |g|의 0쪽으로 내려간다. 족 |f|에는 그 준위의
원소를 품은 집합이 없으니, |g|에서 그것을 품은 쪽은 볼 것도 없기 때문이다.
@<함수들@>=
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
	@<차집합을 재귀로 구한다@>@;
}

@ @<차집합을 재귀로 구한다@>=
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

@ 네 연산의 문. 합집합 $f\cup g$, 교집합 $f\cap g$, 차집합 $f\setminus g$,
그리고 대칭차. 모두 족을 집합으로 보고 하는 셈이다.
@<함수들@>=
func (b *ZDD) Union(f, g Func) Func     { return b.binary(zopOr, f, g) }
func (b *ZDD) Intersect(f, g Func) Func { return b.binary(zopAnd, f, g) }
func (b *ZDD) Diff(f, g Func) Func      { return b.binary(zopButnot, f, g) }
func (b *ZDD) Xor(f, g Func) Func       { return b.binary(zopXor, f, g) }

@* 족의 대수.
여기서부터가 ZDD를 쓰는 참맛이다. 두 족의 원소를 하나씩 짝지어 새 집합을
만드는 연산들인데, 크누스가 \.{BDD15}에 새로 넣은 것들이다.

첫째는 {\it 결합\/} $f\sqcup g$다. 족으로 보면
$$f\sqcup g=\{\alpha\cup\beta\mid \alpha\in f,\ \beta\in g\}$$
이고, 함수로 보면
$f\sqcup g(z)=\exists x\,\exists y\,\bigl((z=x\lor y)\land f(x)\land g(y)\bigr)$이다.
$e_i\sqcup e_j\sqcup e_k$가 집합 $\{e_i,e_j,e_k\}$ 하나만 든 족이 되므로,
집합 하나를 짓는 가장 자연스러운 길이 이것이다. 미나토는 이 연산을 $\ast$로
적었다.
@^Minato, Shin-ichi@>
@<함수들@>=
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
	@<결합을 재귀로 구한다@>@;
}

@ 두 준위가 같을 때가 볼 만하다. 이 자리에서 크누스는 셋 가운데 하나를
골랐다. $g_l\lor g_h$를 먼저 만들어 $f_h$와 결합하는 길, $f_l\lor f_h$를
만들어 $g_h$와 결합하는 길, 그리고 세 결합의 합집합을 취하는 대칭적인 길.
그는 첫째를 골랐다. 대칭적인 길은 초고에 있었는데 대개 더 느렸다고 한다.
``세 길 가운데 어느 것을 언제 골라야 하는지에 대해 나는 좋은 생각이 없다''고
그는 적었다.
@<결합을 재귀로 구한다@>=
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

@ {\it 서로소 결합\/}은 결합과 비슷한데, 겹치지 않는 짝만 센다.
$$\{\alpha\cup\beta\mid \alpha\in f,\ \beta\in g,\ \alpha\cap\beta=\emptyset\}.$$
크누스가 7.1.4절 초고를 마친 직후에 덧붙인 실험적인 연산이다. ``문헌에서 본
적이 없다. 쓸모가 많다 해도 놀랍지 않겠다. 기호는 아직 못 정했다---$\sqcup$
가운데에 세로줄을 하나 더 그은 것쯤 어떨까.''
@<함수들@>=
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
	@<서로소 결합을 재귀로 구한다@>@;
}

@ 준위가 같을 때, 결과의 1쪽 갈래에는 $e_v$를 {\it 한쪽에서만\/} 가져온
짝들이 온다. 양쪽에서 가져오면 겹치기 때문이다.
@<서로소 결합을 재귀로 구한다@>=
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

@ {\it 만남\/} $f\sqcap g$는 결합의 짝이다. 합집합 대신 교집합을 짓는다.
$$f\sqcap g=\{\alpha\cap\beta\mid \alpha\in f,\ \beta\in g\}.$$
크누스는 ``이걸 어디다 쓸지는 모르겠지만, 있어야 할 자리에 있는 것 같다''고
적었다.
@<함수들@>=
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
	@<만남을 재귀로 구한다@>@;
}

@ 준위가 다르면 위쪽 족의 두 갈래를 합쳐 한 단 내려간다. 교집합을 짓는
연산이니 $e_v$가 한쪽에만 있으면 결과에 남지 못하기 때문이다. 꼬리 재귀처럼
보이지만 |r0|을 쓴 {\it 뒤에\/} 놓아 주어야 해서 고리로 접을 수 없다.
@<만남을 재귀로 구한다@>=
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

@ 그리고 대칭차를 짓는 $f\mathbin{\Delta}g$가 있다.
$$f\mathbin{\Delta}g=\{\alpha\mathbin{\Delta}\beta\mid
\alpha\in f,\ \beta\in g\}.$$
준위가 같을 때 네 갈래를 다 봐야 하는 것이 앞의 것들과 다르다. $e_v$가
결과에 남으려면 한쪽에만 있어야 하고(1쪽 갈래), 없으려면 양쪽에 다 있거나
양쪽에 다 없어야 한다(0쪽 갈래).
@<함수들@>=
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
	@<대칭차 족을 재귀로 구한다@>@;
}

@ @<대칭차 족을 재귀로 구한다@>=
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

@* 나눗셈.
몫과 나머지는 앞의 것들과 재귀의 결이 사뭇 다르다. 나쁜 경우에 얼마나 느릴지
크누스도 모르겠다고 했다. 흔한 경우에는 곱게 빠르다.

몫 $f/g$는 이런 족이다. 집합 $\alpha$가 $f/g$에 드는 것은, $g$에 든 모든
$\beta$에 대해 $\alpha\cap\beta=\emptyset$이고 $\alpha\cup\beta\in f$일
때다. (그래서 $0/0$이 1, 곧 모든 부분집합의 족이 된다.) 나머지는
$f\bmod g=f\setminus\bigl((f/g)\sqcup g\bigr)$이다.

가장 쉬운 경우는 $g$가 원소 하나 $e_i$일 때다. 그때
$f=f_0\lor(e_i\sqcup f_1)$인데, 여기서 $f_0=f\bmod e_i$이고 $f_1=f/e_i$다.
$f$가 준위 $i$에 뿌리를 두었다면 이 둘이 바로 그 뿌리의 두 갈래다.
쉬운 경우 둘을 먼저 짓는다.
@<함수들@>=
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

@ @<함수들@>=
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

@ 일반적인 나눗셈은 미나토가 1994년에 낸 알고리즘이다. $g$를 뿌리에서
두 쪽으로 가르고, 각각으로 나눈 몫의 교집합을 취한다.
@^Minato, Shin-ichi@>
@<함수들@>=
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
	@<몫을 재귀로 구한다@>@;
}

@ @<몫을 재귀로 구한다@>=
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

@ 나머지는 쉬운 경우 말고는 정의 그대로 힘들게 셈한다.
@<함수들@>=
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

@ 족 대수의 문들. 결합 $f\sqcup g$, 서로소 짝만 모은 결합, 만남
$f\sqcap g$, 대칭차 족 $f\mathbin{\Delta}g$, 그리고 몫 $f/g$와 나머지
$f\bmod g$.
@<함수들@>=
func (b *ZDD) Join(f, g Func) Func         { return b.binary(zopProd, f, g) }
func (b *ZDD) DisjointJoin(f, g Func) Func { return b.binary(zopDisprod, f, g) }
func (b *ZDD) Meet(f, g Func) Func         { return b.binary(zopCoprod, f, g) }
func (b *ZDD) Delta(f, g Func) Func        { return b.binary(zopDelta, f, g) }

func (b *ZDD) Quotient(f, g Func) Func  { return b.binary(zopQuot, f, g) }
func (b *ZDD) Remainder(f, g Func) Func { return b.binary(zopRem, f, g) }

@* 삼항 연산.
BDD 때와 같은 셋이 있고, ZDD에만 있는 것이 둘 더 있다.
@<자료 구조@>=
const (
	zternMux   = int32(0) // $f{?}\,g{:}\,h$
	zternMed   = int32(1) // $\langle fgh\rangle$
	zternAnd3  = int32(2) // $f\cap g\cap h$
	zternBuild = int32(3) // 노드 하나를 손수 짓는다
	zternSym   = int32(4) // 대칭 함수
)

@ |mux|의 특별한 경우 $h=\epsilon$이 ``$f$이면 $g$''를 준다. 이것은 정상
연산자가 아니어서 이항으로는 다룰 수 없는데, 삼항 |mux|가 정상이라 여기
얹혀 간다.

준위를 맞추는 고리가 둘이다. 족 |g|가 가장 위면 |g|를 내리고, |f|가 가장 위면
|f|를 내린다. 내릴 때마다 쉬운 경우가 새로 생길 수 있으므로 그 자리에서
다시 살핀다.
@<함수들@>=
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
	@<셋의 준위를 맞춘다@>@;
	@<맞춘 뒤의 |mux|@>@;
}

@ @<셋의 준위를 맞춘다@>=
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

@ @<맞춘 뒤의 |mux|@>=
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
	@<|f|가 꼭대기일 때의 두 갈래@>@;
}
return b.memo(f, g, key, b.uniqueFind(v, r0, r1))

@ |g|나 |h|가 |v|보다 아래에서 갈라진다면, 그 족에는 $e_v$를 품은 집합이
하나도 없다. 그러니 1쪽 갈래에서 그것들은 |botsink|가 된다.
@<|f|가 꼭대기일 때의 두 갈래@>=
g0, g1, h0, h1 := g, botsink, h, botsink
if vg == v {
	g0, g1 = b.mem[g].lo, b.mem[g].hi
}
if vh == v {
	h0, h1 = b.mem[h].lo, b.mem[h].hi
}
r0 = b.muxRec(b.mem[f].lo, g0, h0)
r1 = b.muxRec(b.mem[f].hi, g1, h1)

@ 중앙값 $\langle fgh\rangle$. 셋을 준위 차례로, 준위가 같으면 첨자 차례로
늘어놓는다. 늘어놓고 나서도 |f|가 |g|보다 위에 있으면 |f|를 내리고 처음부터
다시 늘어놓는다---|f|만 갖는 원소는 다수결에서 질 수밖에 없기 때문이다.
@<함수들@>=
func (b *ZDD) medRec(f, g, h int32) int32 {
	vf, vg, vh := b.mem[f].lvl, b.mem[g].lvl, b.mem[h].lvl
	for {
		@<셋을 준위와 첨자 차례로 늘어놓는다@>@;
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
	@<중앙값을 재귀로 구한다@>@;
}

@ @<셋을 준위와 첨자 차례로 늘어놓는다@>=
if vg < vf || (vg == vf && g < f) {
	f, g, vf, vg = g, f, vg, vf
}
if vh < vg || (vh == vg && h < g) {
	g, h, vg, vh = h, g, vh, vg
}
if vg < vf || (vg == vf && g < f) {
	f, g, vf, vg = g, f, vg, vf
}

@ @<중앙값을 재귀로 구한다@>=
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

@ 세 족의 교집합. 준위를 맞추는 고리가 둘인데, |f|를 내릴 때는 |g|도 함께
내려야 하므로 처음부터 다시 맞춘다.
@<함수들@>=
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
	@<|h|의 준위까지 맞춘다@>@;
	@<맞춘 뒤의 세 겹 교집합@>@;
}

@ @<|h|의 준위까지 맞춘다@>=
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

@ @<맞춘 뒤의 세 겹 교집합@>=
@<셋을 첨자 차례로 놓는다@>@;
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

@ @<셋을 첨자 차례로 놓는다@>=
if f > g {
	f, g = g, f
}
if g > h {
	g, h = h, g
}
if f > g {
	f, g = g, f
}

@ 마지막은 좀 투박한 연산이다. ZDD를 밑에서부터 손수 쌓아 올릴 때 쓴다.
$f=e_i$이고 |g|와 |h|의 뿌리가 $x_i$보다 아래에 있으면,
$f{!}\ g{:}\ h$는 $x_i$에서 갈라지며 |g|와 |h|를 두 갈래로 삼는 노드를 준다.
(다른 값이 들어오면 탈 없이 끝나기는 하되 뜻은 없다.)
@<함수들@>=
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

@ 삼항의 문들. 갈래 $(f{?}\,g{:}\,h)$, 다수결, 세 겹 교집합, 그리고
$e_i$와 두 갈래를 받아 노드 하나를 손수 짓는 |Build|.
@<함수들@>=
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

func (b *ZDD) Ite(f, g, h Func) Func    { return b.ternary(zternMux, f, g, h) }
func (b *ZDD) Median(f, g, h Func) Func { return b.ternary(zternMed, f, g, h) }
func (b *ZDD) And3(f, g, h Func) Func   { return b.ternary(zternAnd3, f, g, h) }

func (b *ZDD) Build(e, lo, hi Func) Func {
	return b.ternary(zternBuild, e, lo, hi)
}

@* 대칭 함수.
남은 하나는 결이 아주 다른 삼항 연산이다. 첫째 인자는 노드, 둘째는 변수,
셋째는 정수다.

첫째 인자 |p|는 원소들의 목록인데 $e_{i_1}\lor\cdots\lor e_{i_t}$ 꼴이면 이상적이다.
(꼴을 확인하지는 않는다. 0쪽 |lo| 포인터를 따라가며 만나는 준위들이 곧 목록이다.) 둘째 인자
|v|는 변수이고 |k|는 정수다. 돌려주는 것은, {\it 목록에 든 변수 가운데
$v$ 이상인 것이 정확히 $k$개 참이고 $v$보다 작은 것은 모두 거짓\/}인 함수다.
예컨대 $|symfunc|(e_1\lor e_4\lor e_6,\,2,\,2)$는
$\bar x_0\land\bar x_1\land S_2(x_4,x_6)$의 ZDD다.
@^대칭 함수@>
@<함수들@>=
func (b *ZDD) symfunc(p, v, k int32) int32 {
	vp := b.mem[p].lvl
	for vp < v {
		p = b.mem[p].lo
		vp = b.mem[p].lvl
	}
	if vp == b.n {
		@<목록이 비었다@>@;
	}
	key := ternKey(b.taut(k), zternSym)
	if r := b.cacheLookup(p, b.taut(v), key); r != null {
		return r
	}
	@<대칭 함수를 재귀로 구한다@>@;
}

@ 목록이 비었으면 답이 뻔하다. 아직 $k$개를 더 켜야 하는데 켤 것이 없으면
빈 족이고, 다 켰으면 남은 변수들은 무엇이든 좋다.
@<목록이 비었다@>=
if k > 0 {
	return botsink
}
q := b.taut(v)
b.ref(q)
return q

@ 목록의 첫 변수 $x_{vp}$를 켤 것인가 말 것인가. 켜지 않으면 나머지에서
$k$개를 켜야 하고, 켜면 $k-1$개를 켜야 한다. 그 둘이 노드 하나의 두 갈래가
된다. 그러고 나서 $v$와 $vp$ 사이의 변수들---목록에 없으니 무엇이든 좋은
것들---을 두 갈래가 같은 노드로 얹는다. BDD였다면 사라졌을 그 노드들이
ZDD에서는 ``있어도 되고 없어도 된다''를 말한다.
@<대칭 함수를 재귀로 구한다@>=
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

@ 투영 함수 $x_v$가 여기서 나온다. ``목록 $\{e_v\}$ 가운데 정확히 하나가
참''인 함수이니 곧 $e_v$를 품은 부분집합이 모두 든 족이다. BDD에서는 노드
하나로 끝나던 것이 ZDD에서는 이렇게 한 겹 돌아간다. ZDD가 다른 것을 간단히
여기기 때문이다. 바깥으로 내는 |Sym|은 준위 0에서 시작해, |p|에 열거된 원소
가운데 정확히 $k$개가 든 부분집합의 족을 준다.
@<함수들@>=
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

@* 세기와 열거.
족에 든 집합이 몇 개인지 세는 일은 BDD 때보다 오히려 쉽다. 건너뛴 준위를
2의 거듭제곱으로 갚아 줄 일이 없기 때문이다. ZDD에서 건너뛴다는 것은
``그 원소는 없다''는 한 가지 뜻뿐이니, 두 갈래의 셈을 그냥 더하면 된다.
바로 이것이 ZDD가 세는 일에 강한 까닭이다.
@<함수들@>=
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

@ 크기와 옆모습과 버팀대. BDD 때와 같은 것들이다. 노드 수, 준위마다 쓰는
노드 수, 그리고 그 족이 실제로 갈라 보는 원소들의 이름.
@<함수들@>=
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

@ @<함수들@>=
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

@ 어떤 집합이 족에 드는지 묻는 일. 준위를 따라 내려가되, 물어보려는 집합의
원소를 하나도 빠뜨리지 않고 다 지나야 한다. 건너뛴 준위에 그 원소가 있었다면
그 집합은 족에 없는 것이다.
@<함수들@>=
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

@ 하나씩 내놓는 열거. 족에 든 집합을 원소 이름의 오름차순 목록으로 준다. 참 싱크
|topsink|에 이를 때마다 집합 하나가 완성된다. 넘겨받은 쪽이 그 목록을
마음대로 간직해도 된다.
@<함수들@>=
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

@ 무작위 추출. 준위를 내려가며 두 갈래에 달린 집합의 수를 견주어 동전을
던진다. 족이 비었으면 둘째 값이 거짓이고, 난수원을 |nil|로 넘기면 전역
난수원을 쓴다.
@<함수들@>=
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

@* 최적화.
족을 손에 쥐고 나면 세는 것 말고도 할 일이 있다. 원소마다 무게를 주고
무게 합이 가장 큰 집합을 찾는 것이다. 조합론에서 자주 나오는 꼴인데---
최대 가중 독립집합, 가장 긴 단순 경로, 가장 비싼 타일링---어느 것이나
원래 문제로는 NP-어려운 것들이다. 그런데 답의 족을 ZDD로 지어 놓고 나면
마디 수에 정비례하는 시간에 풀린다. 값은 ZDD를 짓는 데 이미 다 치렀다.
@^최대 가중 독립집합@>

마디 $p$에 달린 부분족에서 가장 무거운 집합의 무게를 $B(p)$라 하면
$$B(p)=\max\bigl(B(\hbox{lo}),\ w_{e(p)}+B(\hbox{hi})\bigr),\qquad B(\top)=0$$
이다. ZDD에서는 마디를 건너뛰는 것이 곧 ``그 원소는 없다''는 뜻이므로
무관한 원소를 따로 챙길 일이 없다. BDD였다면 건너뛴 준위마다 무게가
양수인지 따져 보아야 했을 것이다.

@ 밑싹이 $\bot$인 갈래에는 집합이 하나도 없으니 견줄 것이 없다. 축약
규칙 덕에 |hi| 쪽은 결코 $\bot$이 아니므로, 마디 하나에서 견줄 것은 늘
하나 아니면 둘이다. 무게 표에 없는 원소는 무게가 0이라고 친다.
@<함수들@>=
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

@ 바깥으로 내는 문이다. 족이 비었으면 셋째 값이 거짓이다. 가장
{\it 가벼운\/} 집합을 찾고 싶으면 무게의 부호를 뒤집어 넘기고 답의
부호를 도로 뒤집으면 된다.
@<함수들@>=
func (b *ZDD) MaxWeight(f Func, w []int) ([]int, int, bool) {
	p := b.node(f)
	b.drain()
	if p == botsink {
		return nil, 0, false
	}
	best := map[int32]int{}
	total := b.bestRec(p, w, best)
	@<가장 무거운 집합을 되짚는다@>@;
}

@ 값을 다 구해 두었으니 되짚기는 뿌리에서 한 번 내려가면 끝난다. 마디마다
|hi| 쪽 값이 그 마디의 값과 같으면 그 원소를 골랐던 것이다. 여기서 부르는
|bestRec|은 이미 적어 둔 값을 꺼내 올 뿐이다.
@<가장 무거운 집합을 되짚는다@>=
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

@* 시험.
ZDD의 시험은 족을 통째로 비트마스크로 적어 놓고 맞대어 보는 것이다.
원소가 다섯이면 부분집합이 서른둘이니, 족 하나가 |uint32| 한 개에 들어간다.
그 서른두 비트를 가지고 온갖 연산을 손으로 셈해 두고 ZDD가 낸 답과 견준다.
@(zdd_test.go@>=
package bdd

import (
	"math/big"
	"math/rand/v2"
	"testing"
)

const zn = 5 // 원소의 수; 부분집합은 서른둘

type fam uint32 // 비트 $s$가 서면 부분집합 $s$가 족에 든다

func famOf(z *ZDD, f Func) fam {
	var m fam
	for s := range z.Subsets(f) {
		bits := 0
		for _, e := range s {
			bits |= 1 << e
		}
		m |= 1 << uint(bits)
	}
	return m
}

@ 거꾸로 비트마스크에서 ZDD를 짓는 손. 부분집합 하나하나를 원소들의 결합으로
짓고---$\epsilon$에서 시작해 $e_k$를 차례로 결합한다---그것들을 다 합집합한다.
이 짓는 방식 자체가 |Join|과 |Union|을 쓰므로, 지어 놓고 다시 읽어 보는
것만으로도 두 연산이 시험된다.
@(zdd_test.go@>=
func mk(z *ZDD, m fam) Func {
	f := z.Empty()
	for s := 0; s < 1<<zn; s++ {
		if m>>uint(s)&1 == 0 {
			continue
		}
		set := z.Unit()
		for e := 0; e < zn; e++ {
			if s>>e&1 == 1 {
				set = z.Join(set, z.Elt(e))
			}
		}
		f = z.Union(f, set)
	}
	return f
}

@ 족의 대수는 죄다 ``$f$에서 하나, $g$에서 하나 골라 무언가를 짓는다''는
꼴이므로, 그 짝짓기를 한 번만 적어 두고 짓는 방식만 갈아 끼운다.
나눗셈만은 정의를 그대로 옮겨 적는다.
@(zdd_test.go@>=
func pairOp(m, n fam, op func(a, b int) (int, bool)) fam {
	var r fam
	for a := 0; a < 1<<zn; a++ {
		for b := 0; b < 1<<zn; b++ {
			if m>>uint(a)&1 == 1 && n>>uint(b)&1 == 1 {
				if c, ok := op(a, b); ok {
					r |= 1 << uint(c)
				}
			}
		}
	}
	return r
}

@ 몫 $f/g$는 이런 족이다. 집합 $\alpha$가 드는 것은 $g$에 든 모든 $\beta$에
대해 $\alpha\cap\beta=\emptyset$이고 $\alpha\cup\beta\in f$일 때다.
@(zdd_test.go@>=
func bruteQuot(m, n fam) fam {
	if n == 0 {
		return ^fam(0) // $f/\emptyset=\wp$
	}
	var r fam
	for a := 0; a < 1<<zn; a++ {
		ok := true
		for b := 0; b < 1<<zn && ok; b++ {
			if n>>uint(b)&1 == 1 && (a&b != 0 || m>>uint(a|b)&1 == 0) {
				ok = false
			}
		}
		if ok {
			r |= 1 << uint(a)
		}
	}
	return r
}

@ 이제 열 가지 연산을 한자리에서 맞대어 본다. 무작위 족 둘을 지어 놓고
합집합·교집합·차집합·대칭차, 결합·서로소 결합·만남·델타, 몫·나머지를
모두 검사한다.
@(zdd_test.go@>=
func TestZDDAlgebra(t *testing.T) {
	z := NewZDD(zn)
	rnd := rand.New(rand.NewPCG(5, 6))
	for it := 0; it < 300; it++ {
		mm, nn := fam(rnd.Uint32()), fam(rnd.Uint32())
		f, g := mk(z, mm), mk(z, nn)
		if got := famOf(z, f); got != mm {
			t.Fatalf("%d번째: 지은 족이 %x여야 하는데 %x", it, mm, got)
		}
		check := func(name string, got Func, want fam) {
			if g := famOf(z, got); g != want {
				t.Fatalf("%d번째: %s가 %x여야 하는데 %x", it, name, want, g)
			}
		}
		@<열 가지 연산을 맞댄다@>@;
		if it%37 == 0 {
			if err := z.Check(); err != nil {
				t.Fatalf("%d번째: %v", it, err)
			}
		}
	}
	if err := z.Check(); err != nil {
		t.Fatal(err)
	}
}

@ @<열 가지 연산을 맞댄다@>=
union := func(a, b int) (int, bool) { return a | b, true }
check("Union", z.Union(f, g), mm|nn)
check("Intersect", z.Intersect(f, g), mm&nn)
check("Diff", z.Diff(f, g), mm&^nn)
check("Xor", z.Xor(f, g), mm^nn)
check("Join", z.Join(f, g), pairOp(mm, nn, union))
check("DisjointJoin", z.DisjointJoin(f, g),
	pairOp(mm, nn, func(a, b int) (int, bool) { return a | b, a&b == 0 }))
check("Meet", z.Meet(f, g),
	pairOp(mm, nn, func(a, b int) (int, bool) { return a & b, true }))
check("Delta", z.Delta(f, g),
	pairOp(mm, nn, func(a, b int) (int, bool) { return a ^ b, true }))
q := bruteQuot(mm, nn)
check("Quotient", z.Quotient(f, g), q)
check("Remainder", z.Remainder(f, g), mm&^pairOp(q, nn, union))

@ 삼항 연산과 대칭 함수. 그 가운데 |Sym|은 목록에 든 원소 가운데 정확히 $k$개를 품은
부분집합의 족이어야 한다. 목록으로 삼을 수 있는 서른한 가지를 모두, $k$는
0부터 5까지 모두 훑으니 백여든여섯 가지를 다 확인하는 셈이다.
@(zdd_test.go@>=
func TestZDDTernaryAndSym(t *testing.T) {
	z := NewZDD(zn)
	rnd := rand.New(rand.NewPCG(15, 16))
	for it := 0; it < 300; it++ {
		mm, nn, oo := fam(rnd.Uint32()), fam(rnd.Uint32()), fam(rnd.Uint32())
		f, g, h := mk(z, mm), mk(z, nn), mk(z, oo)
		if got := famOf(z, z.Ite(f, g, h)); got != (mm&nn)|(^mm&oo) {
			t.Fatalf("%d번째: Ite 틀림", it)
		}
		if got := famOf(z, z.Median(f, g, h)); got != (mm&nn)|(mm&oo)|(nn&oo) {
			t.Fatalf("%d번째: Median 틀림", it)
		}
		if got := famOf(z, z.And3(f, g, h)); got != mm&nn&oo {
			t.Fatalf("%d번째: And3 틀림", it)
		}
	}
	@<대칭 함수를 모조리 훑는다@>@;
	@<투영 함수와 온 족을 확인한다@>@;
	if err := z.Check(); err != nil {
		t.Fatal(err)
	}
}

@ @<대칭 함수를 모조리 훑는다@>=
for list := 1; list < 1<<zn; list++ {
	p := z.Empty()
	for e := 0; e < zn; e++ {
		if list>>e&1 == 1 {
			p = z.Union(p, z.Elt(e))
		}
	}
	for k := 0; k <= zn; k++ {
		var want fam
		for s := 0; s < 1<<zn; s++ {
			cnt := 0
			for e := 0; e < zn; e++ {
				if s>>e&1 == 1 && list>>e&1 == 1 {
					cnt++
				}
			}
			if cnt == k {
				want |= 1 << uint(s)
			}
		}
		if got := famOf(z, z.Sym(p, k)); got != want {
			t.Fatalf("Sym(%b,%d)이 %x여야 하는데 %x", list, k, want, got)
		}
	}
}

@ @<투영 함수와 온 족을 확인한다@>=
for e := 0; e < zn; e++ {
	var want fam
	for s := 0; s < 1<<zn; s++ {
		if s>>e&1 == 1 {
			want |= 1 << uint(s)
		}
	}
	if got := famOf(z, z.Var(e)); got != want {
		t.Fatalf("Var(%d)가 %x여야 하는데 %x", e, want, got)
	}
}
if got := famOf(z, z.Universe()); got != ^fam(0) {
	t.Fatalf("Universe가 온 족이 아니다: %x", got)
}

@ 세기와 물음과 뽑기. 물음을 맡은 |Contains|는 부분집합 서른두 가지를 모두 물어보고,
|Random|은 삼백 번 뽑아 본다.
@(zdd_test.go@>=
func TestZDDCountContainsRandom(t *testing.T) {
	z := NewZDD(zn)
	rnd := rand.New(rand.NewPCG(25, 26))
	for it := 0; it < 200; it++ {
		mm := fam(rnd.Uint32())
		f, n := mk(z, mm), 0
		for s := 0; s < 1<<zn; s++ {
			if mm>>uint(s)&1 == 1 {
				n++
			}
		}
		if got := z.Count(f); got.Cmp(big.NewInt(int64(n))) != 0 {
			t.Fatalf("%d번째: %d개여야 하는데 %v개", it, n, got)
		}
		@<모든 부분집합에 대해 |Contains|를 묻는다@>@;
		@<족에서 무작위로 뽑아 본다@>@;
	}
	if err := z.Check(); err != nil {
		t.Fatal(err)
	}
}

@ @<모든 부분집합에 대해 |Contains|를 묻는다@>=
for s := 0; s < 1<<zn; s++ {
	var set []int
	for e := 0; e < zn; e++ {
		if s>>e&1 == 1 {
			set = append(set, e)
		}
	}
	if z.Contains(f, set) != (mm>>uint(s)&1 == 1) {
		t.Fatalf("%d번째: Contains(%v) 틀림", it, set)
	}
}

@ @<족에서 무작위로 뽑아 본다@>=
if n == 0 {
	if _, ok := z.Random(f, rnd); ok {
		t.Fatalf("%d번째: 빈 족에서 뽑혔다", it)
	}
	continue
}
hits := map[int]int{}
for i := 0; i < 300; i++ {
	s, ok := z.Random(f, rnd)
	if !ok {
		t.Fatalf("%d번째: 뽑히지 않았다", it)
	}
	bits := 0
	for _, e := range s {
		bits |= 1 << e
	}
	if mm>>uint(bits)&1 == 0 {
		t.Fatalf("%d번째: 뽑힌 %v가 족에 없다", it, s)
	}
	hits[bits]++
}
if n <= 3 && len(hits) != n {
	t.Fatalf("%d번째: %d개 가운데 %d개만 뽑혔다", it, n, len(hits))
}

@ 최적화의 시험은 무식하게 다 견주는 것이다. 무작위 족과 무작위 무게를
놓고 서른두 부분집합을 손으로 훑어 가장 무거운 것을 찾는다. 무게가 같은
집합이 여럿일 수 있으니 집합 자체를 견주지는 않고, 무게와 소속을 따로 본다.
@(zdd_test.go@>=
func TestMaxWeight(t *testing.T) {
	rnd := rand.New(rand.NewPCG(31, 41))
	for trial := 0; trial < 500; trial++ {
		z := NewZDD(zn)
		m := fam(rnd.Uint32())
		w := make([]int, zn)
		for i := range w {
			w[i] = rnd.IntN(21) - 10
		}
		f := mk(z, m)
		got, weight, ok := z.MaxWeight(f, w)
		@<가장 무거운 집합을 손으로 찾는다@>@;
		@<낸 답을 셋으로 따진다@>@;
	}
}

@ 서른두 부분집합 가운데 족에 든 것만 훑어 무게를 더해 본다.
@<가장 무거운 집합을 손으로 찾는다@>=
want, found := 0, false
		for s := 0; s < 1<<zn; s++ {
			if m>>uint(s)&1 == 0 {
				continue
			}
			sum := 0
			for e := 0; e < zn; e++ {
				if s>>e&1 == 1 {
					sum += w[e]
				}
			}
			if !found || sum > want {
				want, found = sum, true
			}
		}

@ 무게가 맞는가, 낸 집합이 정말 족에 들어 있는가, 그 집합의 무게를 다시
더하면 낸 무게가 나오는가.
@<낸 답을 셋으로 따진다@>=
if ok != found {
	t.Fatalf("족 %#x: 답이 있느냐를 %v라 했는데 %v다", m, found, ok)
}
if !ok {
	continue
}
if weight != want {
	t.Fatalf("족 %#x, 무게 %v: 가장 무거운 것이 %d인데 %d라 한다",
		m, w, want, weight)
}
if !z.Contains(f, got) {
	t.Fatalf("족 %#x: 내놓은 %v가 족에 없다", m, got)
}
sum := 0
for _, e := range got {
	sum += w[e]
}
if sum != weight {
	t.Fatalf("집합 %v의 무게는 %d인데 %d라 한다", got, sum, weight)
}

@* 색인.
