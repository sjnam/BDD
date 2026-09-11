\input kotexgweb

\def\title{BDD 엔진}

@s Func int
@s Int int
@s Seq int
@s Rand int
@s base int

@* BDD 엔진.
{\it 이진 결정 다이어그램\/}(binary decision diagram)은 불 함수를 그림 하나로
적는 방법이다. 노드마다 변수를 하나씩 물어보고, 답에 따라 두 갈래 가운데
하나로 내려간다. 아래로 갈수록 변수의 번호가 커지고, 맨 아래에는 참과 거짓
두 싱크가 있다. 이것이 {\it 순서 있는\/} 결정 다이어그램(OBDD)이고, 여기에
축약 규칙 둘을 더하면 놀라운 성질이 하나 나온다.

첫째 규칙: 두 갈래가 같은 곳으로 가면 그 노드는 필요 없다. 둘째 규칙:
똑같이 생긴 노드가 둘 있으면 하나면 된다. 이 둘을 끝까지 밀고 나가면,
변수 순서를 정해 놓았을 때 {\it 불 함수 하나에 다이어그램이 딱 하나\/}
대응한다. 두 함수가 같은지 묻는 일이 노드 첨자 둘을 견주는 일로 줄어든다.
1986년에 Randal Bryant가 이 사실과 그 위에서 도는 알고리즘들을 정리한 뒤로
BDD는 검증과 조합론의 연장이 되었다.
@^Bryant, Randal Everitt@>
@^Akers, Sheldon Buckingham@>

@ 이 글은 그 위에서 도는 연산들을 담는다. 밑바탕---노드 배열, 유일 테이블,
캐시, 참조 계수---은 옆집 \.{common.w}에 있고, 여기서는 그것들이 이미 있다고
치고 시작한다.

연산은 하나같이 같은 모양을 하고 있다. 겉껍질 하나와 재귀 하나. 겉껍질은
밀린 정리표를 비우고 재귀를 부른 다음 결과를 손잡이에 싸서 돌려준다.
재귀는 쉬운 경우면 곧바로 답하고, 아니면 캐시를 뒤지고, 그래도 없으면
꼭대기 변수를 하나 골라 두 갈래로 나뉘어 제 자신을 부른다. 크누스의 말대로
``재귀 루틴을 먼저 쓴다. 계산의 알맹이가 거기 있으니까.''
@c
package bdd

import (
	"iter"
	"math/big"
	"math/rand/v2"
)

@<자료 구조@>

@<함수들@>

@ 밑준위 하나에 이름을 붙인다. 타입 |BDD|는 |base|가 가진 모든 것을 물려받고,
거기에 불 함수를 다루는 연산들을 얹는다.
@<자료 구조@>=
type BDD struct{ base }

@ 빈 밑준위를 하나 지어 내는 문. 변수는 미리 만들어 두지 않는다. BDD에서는
어떤 변수를 쓰는지가 미리 정해져 있을 까닭이 없으므로, 부를 때 생긴다.
@<함수들@>=
func New() *BDD {
	b := new(BDD)
	b.init(false)
	return b
}

@ 가장 단순한 상수 아닌 함수가 투영 함수 $x_v$다. ``변수 $x_v$ 그 자체''인
함수이고, BDD로는 노드 하나---0쪽으로 |botsink|, 1쪽으로 |topsink|---다.
없으면 만들고, 있으면 그대로 쓴다.

여기서 이름과 준위가 처음 갈린다. 사용자가 부르는 |k|는 이름이고, 그 변수가
실제로 앉은 자리가 준위다. 처음에는 둘이 같지만 변수 순서를 바꾸면 달라진다.
@<함수들@>=
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

@ 바깥에서 쓰는 문을 셋 낸다. 늘 거짓인 함수와 늘 참인 함수, 그리고 변수
$x_k$ 그 자체인 함수.
@<함수들@>=
func (b *BDD) Zero() Func { return b.wrap(botsink) }
func (b *BDD) One() Func  { return b.wrap(topsink) }

func (b *BDD) Var(k int) Func {
	b.drain()
	return b.wrap(b.projection(int32(k)))
}

@* 이항 연산.
이항 연산은 열한 가지인데 재귀 루틴은 넷뿐이다. 나머지는 그 넷과 삼항
|mux|를 조금씩 돌려 쓴다. 크누스가 캐시에 적어 두려고 붙인 번호를 그대로
쓴다---번호가 곧 캐시의 열쇠이기 때문이다.

번호에는 뜻이 있다. $f$와 $g$의 진리표 네 칸 $(00,01,10,11)$ 가운데 결과가
참인 칸에 $1,2,4,8$을 매겨 더한 값이다. 그래서 |opAnd|는 $11$ 칸 하나이니 1,
|opOr|는 $01,10,11$이니 7, |opXor|는 $01,10$이니 6이다. 한정사들은
그 자리를 비켜 9, 10, 12, 14, 15를 쓴다.
@<자료 구조@>=
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

@ 겉껍질은 하나로 족하다. 크누스의 |binary_top|이 그랬듯, 번호를 보고
알맞은 재귀로 넘긴다.
@<함수들@>=
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

@ 그러면 바깥으로 내는 문들은 한 줄씩이다. 논리곱 $f\land g$, 논리합
$f\lor g$, 배타합 $f\oplus g$, 그리고 $f\land\bar g$와 $\bar f\land g$.
@<함수들@>=
func (b *BDD) And(f, g Func) Func { return b.binary(opAnd, f, g) }
func (b *BDD) Or(f, g Func) Func  { return b.binary(opOr, f, g) }
func (b *BDD) Xor(f, g Func) Func { return b.binary(opXor, f, g) }

func (b *BDD) Butnot(f, g Func) Func { return b.binary(opButnot, f, g) }
func (b *BDD) Notbut(f, g Func) Func { return b.binary(opNotbut, f, g) }

@ 부정만은 문이 따로다. 이항 연산 번호를 하나 얻어 쓰는 대신 $1\oplus f$로
셈한다.
@<함수들@>=
func (b *BDD) Not(f Func) Func {
	p := b.node(f)
	b.drain()
	return b.wrap(b.xorRec(topsink, p))
}

@ 이제 알맹이다. $f\land g$부터.

쉬운 경우를 먼저 턴다. 두 피연산자가 같으면 답도 그것이고, 하나가 상수면
답이 뻔하다. $\land$는 대칭이므로 언제나 |f<g|가 되도록 맞바꿔 두는데,
그러면 캐시에 같은 짝이 두 모양으로 들어가는 일이 없어진다. 상수를 가려낼 때
|f<=topsink|만 보면 되는 것도 그 맞바꿈 덕이다.
@<함수들@>=
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
	@<$f\land g$를 재귀로 구한다@>@;
}

@ 두 함수의 꼭대기 변수 가운데 위엣것을 |v|라 하자. 그 준위에서 갈라 보면
$f=(x_v{?}\ f_1{:}\ f_0)$이고 $g=(x_v{?}\ g_1{:}\ g_0)$이니
$f\land g=(x_v{?}\ f_1\land g_1{:}\ f_0\land g_0)$이다. 아래 절이 그
가름을 맡는다---|v|보다 아래에서 갈라지는 쪽은 통째로 내려간다.
@<$f\land g$를 재귀로 구한다@>=
@<|f|와 |g|를 준위 |v|에서 가른다@>@;
r0 := b.andRec(f0, g0)
r1 := b.andRec(f1, g1)
r := b.uniqueFind(v, r0, r1)
b.cacheInsert(f, g, opAnd, r)
return r

@ 싱크의 준위를 |maxLvl|로 둔 보람이 여기서 난다. 상수는 어떤 변수보다도
아래에 있으니, ``|v|에서 갈라지는가''를 묻는 것만으로 상수가 저절로 걸러진다.
@<|f|와 |g|를 준위 |v|에서 가른다@>=
v := min(b.mem[f].lvl, b.mem[g].lvl)
f0, f1, g0, g1 := f, f, g, g
if b.mem[f].lvl == v {
	f0, f1 = b.mem[f].lo, b.mem[f].hi
}
if b.mem[g].lvl == v {
	g0, g1 = b.mem[g].lo, b.mem[g].hi
}

@ $f\lor g$는 $f\land g$의 쌍대다. 크누스는 ``둘을 한 루틴으로 합칠 수도
있었지만, 뭐 어때, 프로그램은 길수록 그럴듯해 보이니까''라고 적었다.
@<함수들@>=
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
	@<$f\lor g$를 재귀로 구한다@>@;
}

@ @<$f\lor g$를 재귀로 구한다@>=
@<|f|와 |g|를 준위 |v|에서 가른다@>@;
r0 := b.orRec(f0, g0)
r1 := b.orRec(f1, g1)
r := b.uniqueFind(v, r0, r1)
b.cacheInsert(f, g, opOr, r)
return r

@ 배타적 논리합도 매한가지다. $f\oplus f=0$이라는 것과, 상수 가운데 |botsink|만
쉬운 경우를 준다는 것---$1\oplus g=\bar g$는 여전히 일거리다---이 다르다.

크누스는 여기에 짧은 실험 기록을 남겼다. $f\oplus g=r$를 알아낸 김에
$f\oplus r=g$와 $g\oplus r=f$도 캐시에 적어 두면 어떨까 싶어 초고에서 해
보았는데, 얻는 것보다 드는 것이 많았다고 한다.
@<함수들@>=
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
	@<$f\oplus g$를 재귀로 구한다@>@;
}

@ @<$f\oplus g$를 재귀로 구한다@>=
@<|f|와 |g|를 준위 |v|에서 가른다@>@;
r0 := b.xorRec(f0, g0)
r1 := b.xorRec(f1, g1)
r := b.uniqueFind(v, r0, r1)
b.cacheInsert(f, g, opXor, r)
return r

@ 변화를 주는 뜻에서 Coudert와 Madre의 {\it 제약\/}(constrain) 연산도
옮겨 둔다. $f\downarrow g$는 변수 순서에 기대는 연산이다. $g$가 항등적으로
0이면 답도 0이고, 아니면 $(f\downarrow g)(x)=f(y)$인데 여기서 $y$는
$x$, $x\oplus1$, $x\oplus2$, \dots\ 가운데 $g(y)=1$인 첫째 것이다.
($x=(x_0\ldots x_n)_2$와 $y=(y_0\ldots y_n)_2$를 이진수로 본다.)
@^Coudert, Olivier@>
@^Madre, Jean Christophe@>
@<함수들@>=
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
	@<$f\downarrow g$를 재귀로 구한다@>@;
}

@ $g$의 꼭대기 변수가 |v|일 때, $g$의 한쪽 가지가 0이면 그쪽은 볼 것도 없다.
$x_v$의 값이 그 반대쪽으로 정해져 버리기 때문이다. 그 지름길이 이 연산의
힘이다.
@<$f\downarrow g$를 재귀로 구한다@>=
@<|f|와 |g|를 준위 |v|에서 가른다@>@;
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

@* 한정사.
재미가 붙었으니 한정사로 간다. 아래 루틴들에서 둘째 피연산자 |g|는
$x_2\land x_4\land x_5$처럼 {\it 양의 리터럴들의 논리곱\/}이어야 한다.
그러면 예컨대 $f\mathbin{\rm E}g$는
$\exists x_2\,\exists x_4\,\exists x_5\,f(x_1,\ldots,x_n)$을 뜻한다.
@^한정사@>

프로그램은 |g|가 정말 그런 꼴인지 굳이 확인하지 않는다. 다만 |g|가 아무
함수나 되면 그 뜻이 변수 순서에 기대게 된다---$g=\bar x_1\lor x_2$ 같은 것을
생각해 보라. 아무거나 넣어 보려는 사람은 그 점을 알고(또는 겁내고) 있어야 한다.

값은 어떨까. $g$가 리터럴 $k$개의 논리곱이고 그것들이 죄다 BDD의 밑바닥에
있으면, 한정은 |f|의 크기에 비례하는 시간에 끝난다. 하지만 그것들이 꼭대기
가까이 있으면 그 크기의 $2^k$제곱까지 갈 수도 있다.

@ 존재 한정 $f\mathbin{\rm E}g$가 본보기다. 함수 |f|가 |g|의 꼭대기 변수에 기대지
않으면 그 변수는 볼 것도 없으니 |g|를 한 칸 내린다---|g|가 논리곱이므로
언제나 |hi|쪽으로 간다. 크누스의 |goto restart|를 |for| 고리로 적었다.
@<함수들@>=
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
		@<$f\mathbin{\rm E}g$를 재귀로 구한다@>@;
	}
}

@ |g|의 꼭대기 변수가 |f|의 것과 같으면, 그 변수는 한정되어 사라진다.
두 가지에서 얻은 답을 $\lor$로 합치는 자리가 바로 존재 한정이 일어나는
곳이다. 다르면 그 변수는 살아남으므로 여느 때처럼 노드를 하나 만든다.

$r_0$이 벌써 1이면 합집합도 1이니 $r_1$은 구할 것도 없다. 이 짧은 가지치기가
꽤 값지다.
@<$f\mathbin{\rm E}g$를 재귀로 구한다@>=
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

@ 전칭 한정 $\forall$은 존재 한정과 줄 하나하나가 같다. 0과 1이 자리를
바꾸고 $\lor$가 $\land$로 바뀔 뿐이다.
@<함수들@>=
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
		@<$f\mathbin{\rm A}g$를 재귀로 구한다@>@;
	}
}

@ @<$f\mathbin{\rm A}g$를 재귀로 구한다@>=
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

@ 불 미분 $f\mathbin{\rm D}g$는 더 쉽다. $f\oplus f=0$ 덕에 지름길이 하나 더
생긴다. 함수 |f|가 |g|의 변수에 기대지 않으면 미분은 그냥 0이다.
@<함수들@>=
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
	@<$f\mathbin{\rm D}g$를 재귀로 구한다@>@;
}

@ @<$f\mathbin{\rm D}g$를 재귀로 구한다@>=
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

@ 남은 두 한정사는 좀 별나다. 크누스도 ``어느 책에서도 본 적이 없다---하기야
세상 책을 다 읽어 본 것은 아니지만''이라고 적었다. 그래도 |g|가 변수
$x_v$ {\it 하나\/}일 때는 뜻이 자연스럽다. $f\mathbin{\rm Y}x_v$는 남은
변수들의 함수로서 $f(x_1,\ldots,x_n)=x_v$가 되는 곳이고,
$f\mathbin{\rm N}x_v$는 $f(x_1,\ldots,x_n)=\bar x_v$가 되는 곳이다.

이를테면 $f$가 단조인 것은 모든 $v$에 대해 $f\mathbin{\rm N}x_v=0$인 것과
같다. 리터럴이 둘 이상일 때는 결과가 변수 순서에 기대므로, 그 경우는
잊는 편이 낫다. 아예 생각하지 말자. 되는 경우만 즐기자.
@<함수들@>=
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
	@<$f\mathbin{\rm Y}g$ 또는 $f\mathbin{\rm N}g$를 재귀로 구한다@>@;
}

@ 아래쪽 가지에서 얻은 답이 이미 상수인데 그것이 찾던 쪽과 어긋나면,
위쪽은 볼 것도 없이 0이다.
@<$f\mathbin{\rm Y}g$ 또는 $f\mathbin{\rm N}g$를 재귀로 구한다@>=
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

@ 바깥으로 내는 문들. 앞의 둘은 |g|에 나오는 변수들을 존재 한정하거나 전칭
한정하고, 가운데 셋은 불 미분과 두 별난 한정사이며, 마지막은 제약이다.
둘째 인자 |g|가 양의 리터럴들의 논리곱이어야 한다는 것을 잊지 말자.
@<함수들@>=
func (b *BDD) Exists(f, g Func) Func { return b.binary(opExist, f, g) }
func (b *BDD) Forall(f, g Func) Func { return b.binary(opAll, f, g) }

func (b *BDD) Diff(f, g Func) Func { return b.binary(opDiff, f, g) }
func (b *BDD) Yes(f, g Func) Func  { return b.binary(opYes, f, g) }
func (b *BDD) No(f, g Func) Func   { return b.binary(opNo, f, g) }

func (b *BDD) Constrain(f, g Func) Func { return b.binary(opConstrain, f, g) }

@* 삼항 연산.
모든 연산은 이항 연산으로 쪼갤 수 있다. 그래도 셋을 한꺼번에 다루면 빨라지는지
보는 것은 재미있는 일이다.

삼항 연산의 캐시 열쇠는 조금 다르게 짓는다. 셋째 피연산자를 네 비트 왼쪽으로
밀고 그 자리에 연산 번호를 넣는다. 그러면 열쇠가 |maxBinop|보다 반드시 커지므로
이항 연산의 번호와 뒤섞이지 않는다. 크누스는 포인터가 16바이트 경계에 놓인다는
사실을 이용해 같은 일을 했다.
@<자료 구조@>=
const (
	ternMux      = int32(0) // $f{?}\,g{:}\,h$
	ternMed      = int32(1) // $\langle fgh\rangle$
	ternAndAnd   = int32(2) // $f\land g\land h$
	ternAndExist = int32(3) // $(f\land g)\mathbin{\rm E}h$
)

@ 첫째는 |mux|다. 많은 이가 ``ite''(if-then-else)라 부르지만 크누스는
발음할 수가 없다며 오래 써 온 이 이름을 고집했다. 나도 따른다.

특별한 경우 둘을 눈여겨보자. $h=1$이면 ``$f$이면 $g$''이고, $g=0$이면
``$f$가 아니고 $g$''다. 이항 연산으로 따로 둘 수도 있었지만 조금 느린
삼항 길로 보냈다.
@<함수들@>=
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
	@<$(f{?}\,g{:}\,h)$를 재귀로 구한다@>@;
}

@ @<$(f{?}\,g{:}\,h)$를 재귀로 구한다@>=
@<|f|, |g|, |h|를 준위 |v|에서 가른다@>@;
r0 := b.muxRec(f0, g0, h0)
r1 := b.muxRec(f1, g1, h1)
r := b.uniqueFind(v, r0, r1)
return b.memo(f, g, ternKey(h, ternMux), r)

@ 셋을 가르는 절. 둘을 가르는 절과 하는 일이 같다.
@<|f|, |g|, |h|를 준위 |v|에서 가른다@>=
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

@ 중앙값(또는 다수결) 연산 $\langle fgh\rangle$은 대칭이 아주 곱다.
셋을 크기순으로 늘어놓고 나면 쉬운 경우들이 한눈에 든다. 크누스는 이 정렬을
맞바꿈 여섯 갈래로 적었지만, 세 개를 늘어놓는 데는 견줌 셋이면 넉넉하다.
@<함수들@>=
func (b *BDD) medRec(f, g, h int32) int32 {
	@<|f|, |g|, |h|를 크기순으로 놓는다@>@;
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
	@<$\langle fgh\rangle$을 재귀로 구한다@>@;
}

@ @<|f|, |g|, |h|를 크기순으로 놓는다@>=
if f > g {
	f, g = g, f
}
if g > h {
	g, h = h, g
}
if f > g {
	f, g = g, f
}

@ @<$\langle fgh\rangle$을 재귀로 구한다@>=
@<|f|, |g|, |h|를 준위 |v|에서 가른다@>@;
r0 := b.medRec(f0, g0, h0)
r1 := b.medRec(f1, g1, h1)
r := b.uniqueFind(v, r0, r1)
return b.memo(f, g, ternKey(h, ternMed), r)

@ $f\land g\land h$도 대칭을 누린다. (시간이 넉넉하면 $f\lor g\lor h$와
$f\oplus g\oplus h$로도 같은 놀이를 할 수 있겠다.)
@<함수들@>=
func (b *BDD) andAndRec(f, g, h int32) int32 {
	@<|f|, |g|, |h|를 크기순으로 놓는다@>@;
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
	@<$f\land g\land h$를 재귀로 구한다@>@;
}

@ @<$f\land g\land h$를 재귀로 구한다@>=
@<|f|, |g|, |h|를 준위 |v|에서 가른다@>@;
r0 := b.andAndRec(f0, g0, h0)
r1 := b.andAndRec(f1, g1, h1)
r := b.uniqueFind(v, r0, r1)
return b.memo(f, g, ternKey(h, ternAndAnd), r)

@ 마지막 삼항 연산은 $(f\land g)\mathbin{\rm E}h$다. Ken McMillan이 알아챈
것인데, $f\land g$를 먼저 만들지 않고 곧바로 재귀로 내려가면 시간이 많이
절약될 때가 있다. 두 재귀 |andRec|과 |existRec|의 생각을 한자리에 포갠 셈이다.
@^McMillan, Kenneth Lauchlin@>
@<함수들@>=
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
		@<$(f\land g)\mathbin{\rm E}h$를 재귀로 구한다@>@;
	}
}

@ @<$(f\land g)\mathbin{\rm E}h$를 재귀로 구한다@>=
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

@ 삼항 연산의 겉껍질도 하나로 족하다. 바깥으로는 넷을 낸다. 갈래
$(f{?}\,g{:}\,h)$, 다수결 $\langle fgh\rangle$, 세 겹 논리곱, 그리고
McMillan의 $(f\land g)\mathbin{\rm E}h$.
@<함수들@>=
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

func (b *BDD) Ite(f, g, h Func) Func    { return b.ternary(ternMux, f, g, h) }
func (b *BDD) Median(f, g, h Func) Func { return b.ternary(ternMed, f, g, h) }
func (b *BDD) And3(f, g, h Func) Func   { return b.ternary(ternAndAnd, f, g, h) }
func (b *BDD) AndExists(f, g, h Func) Func {
	return b.ternary(ternAndExist, f, g, h)
}

@* 함수 합성.
이제 우리 무기고에서 가장 힘센 것 차례다. 으뜸 함수 $f(x_0,\ldots,x_n)$과
치환 함수 $y_0(x_0,\ldots,x_n)$, \dots, $y_n(x_0,\ldots,x_n)$의 BDD가 주어졌을 때
$$F(x_0,\ldots,x_n)=f\bigl(y_0(x_0,\ldots,x_n),\ldots,y_n(x_0,\ldots,x_n)\bigr)$$
의 BDD를 짓는 일이다. 만만찮아 보이는 이 일이 놀랍도록 짧은 재귀로 끝난다.

물론 결과가 어마어마하게 클 수 있으니 나쁜 경우의 값도 어마어마하다.
하지만 그리 나쁘지 않은 경우에는 값도 그리 나쁘지 않다. 낙천적으로 가자.

@ 값을 아끼는 밑천은 여느 때처럼 캐시다. 밑준위의 노드 하나는 어떤 준위~$v$에
대해 변수 $(x_v,x_{v+1},\ldots)$의 함수를 나타내므로, ``이 함수를
$(y_v,y_{v+1},\ldots)$로 이미 합성해 보았는가''를 캐시가 기억해 두면 된다.

그런데 사용자가 $y_k$를 바꾸면 준위 $v\le k$인 함수들의 결과가 모두 못 쓰게
된다. $v>k$인 것들은 여전히 쓸 만한데도 말이다. 그래서 변수마다 {\it 시각
도장\/}을 둔다. $y_k$가 바뀌면 $x_0$부터 $x_k$까지의 도장을 올린다. 그러면
그 함수들에 대한 캐시 항목은 조회에서 저절로 어긋나고, 아래쪽 항목들은
그대로 살아남는다. 도장이 0이라는 것은 ``이 준위부터 아래로는 치환이 하나도
없다''는 뜻이다.
@^시각 도장@>

@ 사용자가 $y_k$를 새로 정할 때 도장이 어떻게 움직이는지 보자.
치환을 {\it 거두는\/} 경우가 조금 까다롭다. 아래쪽에 아직 치환이 남아 있으면
도장은 그대로 두어야 하고, 남아 있지 않으면 위로 거슬러 올라가며 0으로
되돌려야 하며, 그러다 꼭대기까지 다 비면 도장 자체를 물린다.
@<함수들@>=
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
		@<도장을 새로 찍는다@>@;
		return
	}
	@<치환을 거두고 도장을 매만진다@>@;
}

@ @<치환을 거두고 도장을 매만진다@>=
if v+1 < int32(len(b.vars)) && b.vars[v+1].stamp != 0 {
	@<도장을 새로 찍는다@>@;
	return
}
for v >= 0 && b.vars[v].repl == null {
	b.vars[v].stamp = 0
	v--
}
if v >= 0 {
	@<도장을 새로 찍는다@>@;
	return
}
if b.stampChg {
	b.stamp--
}
b.stampChg = false

@ 도장을 새로 찍을 때는, 아직 이번 합성을 하지 않았으면 도장을 하나 올리고,
준위 |v|에서 꼭대기까지 거슬러 올라가며 그 도장을 찍는다. 이미 찍힌 것을
만나면 그 위는 볼 것도 없다.
@<도장을 새로 찍는다@>=
if !b.stampChg {
	b.stampChg = true
	b.stamp++
}
for v >= 0 && b.vars[v].stamp != b.stamp {
	b.vars[v].stamp = b.stamp
	v--
}

@ 으뜸 재귀. 짧다.
@<함수들@>=
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
	@<$f(y_0,\ldots)$을 재귀로 구한다@>@;
}

@ 셈하는 모양은 앞의 재귀들과 판박이처럼 보인다. 그런데 속은 아주 다르다. 두 결과
|r0|과 |r1|은 이제 밑바닥 가까운 변수들만이 아니라 {\it 모든\/} 변수를
품을 수 있다. 치환이 일어나는 자리는 |mux| 한 줄이다.
@<$f(y_0,\ldots)$을 재귀로 구한다@>=
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

@ 바깥으로 내는 문. 크누스의 \.{BDDL}에서는 \.{y3=f7} 같은 명령으로 치환을
하나씩 걸어 두고 \.{f1=f2[y]}로 합성했다. \GO/에서는 한 번에 넘기는 편이
자연스러우므로 맵으로 받는다. 맵에 없는 변수는 그대로 둔다. 합성이 끝나면
걸어 둔 치환을 도로 거둔다.
@<함수들@>=
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

@* 세기와 열거.
크누스의 \.{BDD14}는 여기서 멈춘다. 해를 세는 일은 \.{BDDREAD-COUNT}라는
딴 프로그램이 맡았기 때문이다. 그가 BDD를 파일로 뱉고 다른 프로그램이
받아 세는 식으로 나눈 것은 습작의 사정이고, 라이브러리로 쓰려면 여기 있어야
한다. BDD가 값진 까닭의 태반이 ``세는 일이 거저''라는 데 있으니까.

$2^{100}$쯤은 예사로 나오므로 셈은 |big.Int|로 한다.

@ 이제 세는 일 자체는 짧다. 노드마다 두 가지의 셈을 더하되, 건너뛴 변수
수만큼 밀어 올린다. 같은 노드를 여러 번 만나므로 적어 둔다---BDD가 그림이
아니라 {\it 방향 비순환 그래프\/}라는 사실이 여기서 값을 한다. 세는 것은
지금 밑준위에 있는 변수 전부에 대해서다.
@<함수들@>=
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

@ 크기와 옆모습. 크기를 재는 |Size|는 함수 하나를 그리는 데 드는 노드 수이고
(싱크 둘을 포함한다), |Profile|은 준위마다 몇 개씩인지를 위에서 아래로
늘어놓은 것이다. 크누스의 \.{pp3} 명령이 찍던 것이 이 옆모습이다.
@<함수들@>=
func (b *BDD) Size(f Func) int {
	seen := map[int32]bool{}
	b.reach(b.node(f), seen)
	return len(seen)
}

@ 옆모습은 활성 준위마다 몇 개씩인지를 위에서 아래로 늘어놓은 것이고,
버팀대는 그 함수가 실제로 기대는 변수들의 이름이다. 둘 다 노드를 한 번
훑으면 나온다.
@<함수들@>=
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

@ 값을 매겨 보는 일도 있어야겠다. 배정 |x|는 변수 이름으로 첨자를 매긴
배열이고, 거기 없는 변수는 거짓으로 친다.
@<함수들@>=
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

@ 하나씩 내놓는 열거. \GO/ 1.23이 준 반복자 덕에 모양이 곱다. 부르는 쪽이
도중에 그만두면 훑기도 거기서 멈춘다---해가 $2^{80}$개인 함수를 만나도
앞의 열 개만 보고 나올 수 있다.

건너뛴 변수는 두 값 모두로 펼친다. 그러니 여기서 나오는 것은 BDD의 경로가
아니라 배정 하나하나다. 배정은 변수 이름으로 첨자를 매긴 배열이고, 넘겨받은
쪽이 마음대로 간직해도 된다.
@<함수들@>=
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

@ 훑기 자체는 예사로운 되돌이 훑기다. 거짓 싱크에 이르면 그 아래로는 해가
없으니 곧바로 돌아 나오고, 준위를 다 내려왔으면 배정 하나가 완성된 것이다.
@<함수들@>=
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

@ 마지막으로 무작위 추출. 해가 $2^{80}$개일 때 그중 하나를 {\it 고르게\/}
뽑으려면 세어 놓은 것이 있어야 한다. 준위를 내려가며 두 가지의 무게를 견주어
동전을 던지되, 그 무게가 곧 그 아래에 달린 해의 수다. 해가 없으면 둘째
값이 거짓이고, 난수원을 |nil|로 넘기면 전역 난수원을 쓴다.
@<함수들@>=
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
	@<준위를 내려가며 배정을 뽑는다@>@;
}

@ @<준위를 내려가며 배정을 뽑는다@>=
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

@* 시험.
문학적 프로그램은 제가 살아 있다는 증거를 스스로 지녀야 한다. 이 마지막
부분은 같은 원본에서 짜여 나오되 {\it 다른\/} 파일로 흘러 들어간다. 이름이
\.{bdd\_test.go}인 파일로 가는 것인데, \.{GWEB}의 파일 출력 제어 코드---으뜸 출력
말고 곁 출력에 이름을 주는 그것---덕이다.

시험의 뼈대는 하나다. {\it 진리표와 맞대어 본다\/}. 변수 여섯 개면 배정이
64가지뿐이니 |uint64| 하나에 진리표가 통째로 들어간다. BDD가 내놓은 답을
그 64비트와 맞대어 한 비트라도 어긋나면 잡아낸다. 배정 $a$의 비트 $nv-1-k$가
변수 $k$의 값이라는 약속을 쓴다. BDD 꾸러미의 버그는 대개
드물고 조용해서, 이렇게 무식하게 전수로 견주는 것이 가장 든든하다.
@(bdd_test.go@>=
package bdd

import (
	"math/big"
	"math/rand/v2"
	"testing"
)

const nv = 6 // 변수의 수; 배정은 64가지

type tt uint64 // 비트 $a$가 서면 배정 $a$에서 참이다

func ttOf(b *BDD, f Func) tt {
	var m tt
	x := make([]bool, nv)
	for a := 0; a < 1<<nv; a++ {
		for k := 0; k < nv; k++ {
			x[k] = a>>(nv-1-k)&1 == 1
		}
		if b.Eval(f, x) {
			m |= 1 << uint(a)
		}
	}
	return m
}

@ 무작위 함수를 하나 짓는 손. 변수 몇 개를 아무렇게나 골라 세 번쯤 엮는다.
진리표도 함께 지어 돌려주므로, 부르는 쪽은 언제나 정답을 손에 쥔 채로
시험할 수 있다.
@(bdd_test.go@>=
func randFunc(b *BDD, rnd *rand.Rand, vars []Func) (Func, tt) {
	f := vars[rnd.IntN(len(vars))]
	m := ttOf(b, f)
	for i := 0; i < 3; i++ {
		g := vars[rnd.IntN(len(vars))]
		n := ttOf(b, g)
		switch rnd.IntN(3) {
		case 0:
			f, m = b.And(f, g), m&n
		case 1:
			f, m = b.Or(f, g), m|n
		case 2:
			f, m = b.Xor(f, g), m^n
		}
	}
	return f, m
}

@ 첫째 시험은 이 꾸러미 전체를 한 번에 훑는다. 함수 마흔 개를 손에 쥐고
있다가 둘을 골라 엮기를 이천 번 되풀이하되, 그때마다 진리표와 맞대고 해의
개수도 세어 본다. 백 번에 한 번쯤은 밑준위의 온전성까지 검사한다.
@(bdd_test.go@>=
func TestAgainstTruthTable(t *testing.T) {
	b := New()
	rnd := rand.New(rand.NewPCG(1, 2))
	full := ^tt(0)
	var fs []Func
	var ts []tt
	@<변수와 상수를 밑천으로 깔아 둔다@>@;
	for it := 0; it < 2000; it++ {
		@<둘을 골라 엮고 진리표와 맞댄다@>@;
	}
	if err := b.Check(); err != nil {
		t.Fatal(err)
	}
}

@ @<변수와 상수를 밑천으로 깔아 둔다@>=
for k := 0; k < nv; k++ {
	fs = append(fs, b.Var(k))
	var m tt
	for a := 0; a < 1<<nv; a++ {
		if a>>(nv-1-k)&1 == 1 {
			m |= 1 << uint(a)
		}
	}
	ts = append(ts, m)
}
fs = append(fs, b.Zero(), b.One())
ts = append(ts, 0, full)

@ @<둘을 골라 엮고 진리표와 맞댄다@>=
i, j := rnd.IntN(len(fs)), rnd.IntN(len(fs))
var f Func
var m tt
switch rnd.IntN(6) {
case 0:
	f, m = b.And(fs[i], fs[j]), ts[i]&ts[j]
case 1:
	f, m = b.Or(fs[i], fs[j]), ts[i]|ts[j]
case 2:
	f, m = b.Xor(fs[i], fs[j]), ts[i]^ts[j]
case 3:
	f, m = b.Not(fs[i]), full&^ts[i]
case 4:
	f, m = b.Butnot(fs[i], fs[j]), ts[i]&^ts[j]
case 5:
	k := rnd.IntN(len(fs))
	f, m = b.Ite(fs[i], fs[j], fs[k]), (ts[i]&ts[j])|(^ts[i]&ts[k])
}
@<맞대어 보고 밑천에 넣는다@>@;

@ @<맞대어 보고 밑천에 넣는다@>=
if got := ttOf(b, f); got != m {
	t.Fatalf("%d번째: 진리표가 %x여야 하는데 %x", it, m, got)
}
want := big.NewInt(0)
for a := 0; a < 1<<nv; a++ {
	if m>>uint(a)&1 == 1 {
		want.Add(want, big.NewInt(1))
	}
}
if got := b.Count(f); got.Cmp(want) != 0 {
	t.Fatalf("%d번째: 해가 %v개여야 하는데 %v개", it, want, got)
}
fs, ts = append(fs, f), append(ts, m)
if len(fs) > 40 {
	fs, ts = fs[len(fs)-40:], ts[len(ts)-40:]
}
if it%97 == 0 {
	if err := b.Check(); err != nil {
		t.Fatalf("%d번째: %v", it, err)
	}
}

@ 한정사는 정의를 그대로 옮겨 힘으로 센다. 둘째 인자 |g|가 리터럴들의 논리곱이므로
그것이 가리키는 변수 집합 |set|을 훑으며, 그 변수들을 온갖 값으로 바꿔 본
결과를 모두 $\lor$하면 $\exists$이고 모두 $\land$하면 $\forall$이다.
@(bdd_test.go@>=
func TestQuantifiers(t *testing.T) {
	b := New()
	rnd := rand.New(rand.NewPCG(7, 9))
	vars := make([]Func, nv)
	for k := range vars {
		vars[k] = b.Var(k)
	}
	for it := 0; it < 300; it++ {
		f, mf := randFunc(b, rnd, vars)
		set := rnd.IntN(1<<nv-1) + 1
		@<변수 집합 |set|의 논리곱 |g|를 짓는다@>@;
		@<힘으로 센 한정과 맞댄다@>@;
	}
	if err := b.Check(); err != nil {
		t.Fatal(err)
	}
}

@ @<변수 집합 |set|의 논리곱 |g|를 짓는다@>=
g := b.One()
for k := 0; k < nv; k++ {
	if set>>(nv-1-k)&1 == 1 {
		g = b.And(g, vars[k])
	}
}

@ @<힘으로 센 한정과 맞댄다@>=
var wantE, wantA tt
for a := 0; a < 1<<nv; a++ {
	e, u := false, true
	for s := 0; s < 1<<nv; s++ {
		if s&set != s {
			continue
		}
		if mf>>uint(a&^set|s)&1 == 1 {
			e = true
		} else {
			u = false
		}
	}
	if e {
		wantE |= 1 << uint(a)
	}
	if u {
		wantA |= 1 << uint(a)
	}
}
if got := ttOf(b, b.Exists(f, g)); got != wantE {
	t.Fatalf("%d번째: Exists가 %x여야 하는데 %x", it, wantE, got)
}
if got := ttOf(b, b.Forall(f, g)); got != wantA {
	t.Fatalf("%d번째: Forall이 %x여야 하는데 %x", it, wantA, got)
}

@ 삼항 연산 셋. 그 가운데 |AndExists|는 정의대로 $f\land g$를 먼저 만들고 한정한 것과
같아야 한다---빠른 길과 느린 길이 같은 곳에 이르는지 보는 셈이다.
@(bdd_test.go@>=
func TestTernary(t *testing.T) {
	b := New()
	rnd := rand.New(rand.NewPCG(17, 19))
	vars := make([]Func, nv)
	for k := range vars {
		vars[k] = b.Var(k)
	}
	for it := 0; it < 300; it++ {
		f, mf := randFunc(b, rnd, vars)
		g, mg := randFunc(b, rnd, vars)
		h, mh := randFunc(b, rnd, vars)
		if got := ttOf(b, b.Median(f, g, h)); got != (mf&mg)|(mf&mh)|(mg&mh) {
			t.Fatalf("%d번째: Median 틀림", it)
		}
		if got := ttOf(b, b.And3(f, g, h)); got != mf&mg&mh {
			t.Fatalf("%d번째: And3 틀림", it)
		}
		e := b.And(vars[rnd.IntN(nv)], vars[rnd.IntN(nv)])
		if ttOf(b, b.AndExists(f, g, e)) != ttOf(b, b.Exists(b.And(f, g), e)) {
			t.Fatalf("%d번째: AndExists 틀림", it)
		}
	}
	if err := b.Check(); err != nil {
		t.Fatal(err)
	}
}

@ 제약 연산은 정의가 유별나니 정의 그대로 흉내 낸다. 배정 $x$에 대해
$x$, $x\oplus1$, $x\oplus2$, \dots\ 를 차례로 훑어 $g$가 참인 첫째 $y$를
찾고, 거기서 $f$의 값을 읽는다.
@(bdd_test.go@>=
func TestConstrain(t *testing.T) {
	b := New()
	rnd := rand.New(rand.NewPCG(3, 4))
	vars := make([]Func, nv)
	for k := range vars {
		vars[k] = b.Var(k)
	}
	for it := 0; it < 200; it++ {
		f, mf := randFunc(b, rnd, vars)
		g, mg := randFunc(b, rnd, vars)
		var want tt
		if mg != 0 {
			@<제약의 정의를 그대로 흉내 낸다@>@;
		}
		if got := ttOf(b, b.Constrain(f, g)); got != want {
			t.Fatalf("%d번째: Constrain이 %x여야 하는데 %x", it, want, got)
		}
	}
	if err := b.Check(); err != nil {
		t.Fatal(err)
	}
}

@ @<제약의 정의를 그대로 흉내 낸다@>=
for x := 0; x < 1<<nv; x++ {
	for d := 0; ; d++ {
		y := x ^ d
		if y < 1<<nv && mg>>uint(y)&1 == 1 {
			if mf>>uint(y)&1 == 1 {
				want |= 1 << uint(x)
			}
			break
		}
	}
}

@ 합성도 정의대로 흉내 낸다. 배정 $a$에서 치환 함수들의 값을 먼저 재어
새 배정 $z$를 만들고, 거기서 으뜸 함수의 값을 읽는다.
@(bdd_test.go@>=
func TestCompose(t *testing.T) {
	b := New()
	rnd := rand.New(rand.NewPCG(21, 22))
	vars := make([]Func, nv)
	for k := range vars {
		vars[k] = b.Var(k)
	}
	for it := 0; it < 200; it++ {
		f, mf := randFunc(b, rnd, vars)
		y, my := map[int]Func{}, map[int]tt{}
		for k := 0; k < nv; k++ {
			if rnd.IntN(2) == 1 {
				y[k], my[k] = randFunc(b, rnd, vars)
			}
		}
		@<합성의 정의를 그대로 흉내 낸다@>@;
	}
	if err := b.Check(); err != nil {
		t.Fatal(err)
	}
}

@ @<합성의 정의를 그대로 흉내 낸다@>=
var want tt
for a := 0; a < 1<<nv; a++ {
	z := 0
	for k := 0; k < nv; k++ {
		bit := a >> (nv - 1 - k) & 1
		if m, ok := my[k]; ok {
			bit = int(m >> uint(a) & 1)
		}
		z |= bit << (nv - 1 - k)
	}
	if mf>>uint(z)&1 == 1 {
		want |= 1 << uint(a)
	}
}
if got := ttOf(b, b.Compose(f, y)); got != want {
	t.Fatalf("%d번째: Compose가 %x여야 하는데 %x", it, want, got)
}

@ 열거와 무작위 추출. 나오는 배정이 죄다 해여야 하고, 겹치는 것이 없어야
하고, 개수가 |Count|와 맞아야 한다. 도중에 그만두는 것도 해 본다. 그리고
해가 서넛뿐인 함수에서 삼백 번 뽑으면 모든 해가 적어도 한 번은 나와야
한다---고르게 뽑는다면 그렇다.
@(bdd_test.go@>=
func TestAllAndRandom(t *testing.T) {
	b := New()
	rnd := rand.New(rand.NewPCG(31, 32))
	vars := make([]Func, nv)
	for k := range vars {
		vars[k] = b.Var(k)
	}
	for it := 0; it < 100; it++ {
		f, mf := randFunc(b, rnd, vars)
		n := @<열거를 맞대어 보고 개수를 돌려준다@>@;
		@<중간에 그만두어 본다@>@;
		@<무작위로 뽑아 본다@>@;
	}
	if err := b.Check(); err != nil {
		t.Fatal(err)
	}
}

@ @<열거를 맞대어 보고 개수를 돌려준다@>=
func() int {
	seen, n := map[int]bool{}, 0
	for x := range b.All(f) {
		a := 0
		for k := 0; k < nv; k++ {
			if x[k] {
				a |= 1 << (nv - 1 - k)
			}
		}
		if mf>>uint(a)&1 != 1 || seen[a] {
			t.Fatalf("%d번째: %v가 해가 아니거나 두 번 나왔다", it, x)
		}
		seen[a], n = true, n+1
	}
	if want := b.Count(f); want.Cmp(big.NewInt(int64(n))) != 0 {
		t.Fatalf("%d번째: %v개 나와야 하는데 %d개", it, want, n)
	}
	return n
}()

@ @<중간에 그만두어 본다@>=
cnt := 0
for range b.All(f) {
	if cnt++; cnt == 2 {
		break
	}
}

@ @<무작위로 뽑아 본다@>=
if n == 0 {
	if _, ok := b.Random(f, rnd); ok {
		t.Fatalf("%d번째: 해가 없는데 뽑혔다", it)
	}
	continue
}
hits := map[int]int{}
for i := 0; i < 300; i++ {
	x, ok := b.Random(f, rnd)
	if !ok {
		t.Fatalf("%d번째: 뽑히지 않았다", it)
	}
	a := 0
	for k := 0; k < nv; k++ {
		if x[k] {
			a |= 1 << (nv - 1 - k)
		}
	}
	if mf>>uint(a)&1 != 1 {
		t.Fatalf("%d번째: 뽑힌 %v가 해가 아니다", it, x)
	}
	hits[a]++
}
if n <= 4 && len(hits) != n {
	t.Fatalf("%d번째: 해 %d개 가운데 %d개만 뽑혔다", it, n, len(hits))
}

@* 색인.
