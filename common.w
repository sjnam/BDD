\input kotexgweb

\def\title{공통의 땅}

@s Cleanup int
@s Mutex int
@s big.Int int
@s Rand int

@* 들어가며.
크누스는 {\sl The Art of Computer Programming\/} 7.1.4절 ``이진 결정 다이어그램''을
준비하면서 습작을 열다섯 편 남겼다. 이름에 \.{BDD1}에서 \.{BDD15}까지 번호가 붙은 그
프로그램들은 하나같이 ``큰 BDD 꾸러미에 필요한 기본 루틴들의 간략한 판''을
직접 겪어 보려는 시도다. 이 글이 밑감으로 삼은 것은 그 가운데 마지막 둘이다. 그 가운데
\.{BDD14}는 변수 순서를 바꾸고 ``체질''(sifting)하는 방법까지 갖춘 BDD 꾸러미이고,
\.{BDD15}는 같은 뼈대를 ZDD로 다시 지은 것이다.
@^Knuth, Donald Ervin@>
@^BDD14@>
@^BDD15@>

두 프로그램을 나란히 놓고 읽으면 재미있는 것이 보인다. 3000줄이 넘는 두 글이
거의 한 글자씩 같다. 노드를 담는 배열도, 변수마다 두는 유일 테이블도, 계산해
둔 결과를 기억하는 캐시도, 참조 계수와 쓰레기 수거도 모두 같다. 정말로 다른
곳은 딱 한 줄, 가지를 만들 자리에서 무엇을 축약하느냐다. BDD는 |lo|와 |hi|가
같으면 가지가 필요 없다고 보고, ZDD는 |hi|가 |botsink|이면 필요 없다고 본다.
그 한 줄에서 불 함수의 세계와 집합족의 세계가 갈린다.

@ 그래서 이 꾸러미는 두 엔진을 한 지붕 아래 둔다. 이 글은 그 공통의 땅이다:
노드 배열, 변수와 유일 테이블, 캐시, 참조 계수, 쓰레기 수거. 엔진들은 옆집에
산다---BDD는 \.{bdd.w}에, ZDD는 \.{zdd.w}에 있고, 변수 재정렬은 둘이 나눠 쓰므로
\.{reorder.w}에 따로 두었다. 크누스의 \.{DLX1}, \.{DLX2}, \.{DLX3}이 그랬듯
어느 것이나 처음부터 끝까지 혼자 읽을 수 있게 썼다.% 이 짜임새는 앞서 쓴
%{\it 춤추는 칸\/}(\.{github.com/sjnam/dancing-cells})을 그대로 본떴다.

@ \GO/로 옮기면서 버린 것이 하나 있는데, 버린 자리가 꽤 크다. 크누스는 메모리를
손수 관리한다. 이름이 |mem|인 거대한 배열을 잡아 놓고 아래쪽에는 노드를, 위쪽에는
4096바이트짜리 페이지를 쌓는다. 유일 테이블과 캐시는 그 페이지들에 흩어져 살고,
$k$번째 바이트를 찾으려면 |mem[b[k>>12]+(k&0xfff)]|처럼 두 번 걸러 가야 한다.
포인터는 32비트 |addr|로 눌러 담는다. 그가 쓰던 컴파일러가 포인터를 64비트로
고집해서, 그냥 두면 메모리와 하드웨어 캐시를 절반씩 버리는 셈이었기 때문이다.

이 모든 것이 \GO/에서는 필요 없다. 슬라이스가 있으니 페이지를 손수 나눌 까닭이
없고, 노드를 첨자로 가리키니 주소를 눌러 담을 까닭도 없다. 그런데 정작 크게
줄어든 곳은 따로 있다. 크누스의 |mem|은 크기가 정해져 있어서 노드가 모자랄 수
있고, 그래서 그의 재귀 루틴들은 하나같이 이런 모양을 하고 있다.
$$\vbox{\halign{\.{#}\hfil\cr
r0=and\_rec(...);\cr
if (!r0) return NULL; /* oops, trouble */\cr
r1=and\_rec(...);\cr
if (!r1) \{ deref(r0); return NULL; \} /* abort in midstream */\cr}}$$
재귀 루틴마다 절반가량이 ``자리가 모자라 도중에 손을 떼는'' 이야기이고,
그 위에는 쓰레기를 긁어모아 다시 해 보는 |attempt_repairs|가 얹혀 있다.
슬라이스는 모자라면 늘어나므로 그 절반이 통째로 사라진다. 남은 절반은 놀랄
만큼 짧고, 알고리즘의 뼈대가 훨씬 잘 보인다.

@ 버리지 않은 것은 참조 계수다. \GO/에는 쓰레기 수거기가 있으니 그것도 버릴 수
있지 않을까 싶지만, 그럴 수 없다. 노드들은 유일 테이블이 붙들고 있어서 \GO/가
보기에는 언제나 살아 있다. 어떤 노드를 더는 아무도 쓰지 않는다는 것은 BDD
꾸러미만 아는 사실이고, 그 사실을 세어 두는 것이 |xref| 필드다.

그래서 이 꾸러미는 크누스의 참조 계수를 그대로 쓰되, 그것을 세는 일을 사용자
대신 \GO/의 쓰레기 수거기에게 시킨다. 사용자가 손에 쥐는 |Func|은 손잡이 하나를
싼 값이고, 그 손잡이에 |runtime.AddCleanup|으로 정리 훅을 걸어 둔다. 손잡이가
닿지 않는 곳으로 가면 훅이 울리고, 훅은 ``이 노드를 놓아도 된다''는 쪽지를
대기표에 얹어 둔다. 쪽지를 실제로 처리하는 것은 다음 연산이 시작될 때다.
이 한 박자 늦춤이 중요하다. 연산이 도는 동안에는 어떤 노드도 죽지 않으므로,
재귀 한복판에서 발밑이 꺼질 걱정을 하지 않아도 된다.
@^AddCleanup@>

@ 그러니 이 꾸러미의 얼개는 이렇게 된다. {\it 밑준위\/}(|base|) 하나가 노드
배열과 유일 테이블과 캐시를 지니고, 그 위에서 BDD 엔진은 불 함수를, ZDD
엔진은 집합족을 다룬다. 함수 하나는 |Func| 손잡이로 주고받으며, 손잡이를
그냥 버리면 노드도 따라서 풀린다.

한 가지는 못 박아 두어야겠다. 밑준위 하나를 여러 고루틴에서 동시에 쓸 수는
없다. 정리 훅이 다른 고루틴에서 울리기는 하지만 그것이 손대는 것은 대기표
하나뿐이고, 그 대기표만 자물쇠로 지킨다.

뼈대는 이렇다. 이름 있는 절 둘이 차례로 이어진다.
@c
package bdd

import (
	"fmt"
	"math/big"
	"math/rand/v2"
	"runtime"
	"sync"
)

@<자료 구조@>

@<함수들@>

@* 노드.
BDD 꾸러미의 노드는 넷을 담는다. 변수를 가리키는 준위 |lvl|, 그 변수가 0일
때와 1일 때로 갈라지는 |lo|와 |hi|, 그리고 참조 계수 |xref|. 크누스의 노드와
크기가 같은 16바이트인데, 담는 것은 조금 다르다.

그의 |index| 필드는 위 10비트에 준위를 담고 나머지 22비트를 난수로 채웠다.
노드를 만들 때 난수를 하나 뽑아 박아 두면 해시 코드가 공짜로 생기기 때문이다.
값은 싸지만 값을 치른다. 준위에 10비트밖에 못 주니 변수가 1024개를 넘을 수
없고, 해시가 쓸 수 있는 비트도 22개뿐이다. 우리는 해시를 곱셈으로 만들기로
했다. 곱셈 한 번이면 난수를 미리 뽑아 두는 것만큼 싸고, 그 덕에 네 바이트가
통째로 준위 차지가 되어 변수 수의 천장이 사라진다.

@ 싱크는 둘이다. 항상 거짓인 |botsink|와 항상 참인 |topsink|. 첨자 0은 ``없음''을
뜻하는 |null|로 비워 두었다. 유일 테이블의 빈 칸과 캐시의 빈 자리를 0으로
알아보기 위해서다. 싱크의 준위는 어떤 변수보다도 아래인 |maxLvl|로 두었다.
그러면 ``|f|와 |g|의 준위 가운데 위엣것''을 고르는 자리마다 싱크를 따로
가려낼 일이 없어진다.
@<자료 구조@>=
const (
	null    = int32(0)      // 노드가 아님
	botsink = int32(1)      // 항상 0인 함수
	topsink = int32(2)      // 항상 1인 함수
	maxLvl  = int32(1) << 30 // 싱크의 준위: 어떤 변수보다도 아래
)

type node struct {
	lo, hi int32 // $x_v=0$일 때와 $x_v=1$일 때 갈 곳
	xref   int32 // 참조 계수 빼기 1; 음수면 죽은 노드
	lvl    int32 // 이 노드가 갈라 보는 변수의 준위
}

@ 크누스의 싱크는 제 자신을 가리키고 참조 계수도 함께 센다. 우리는 싱크를
{\it 불사\/}로 두기로 했다. 참조 계수를 올리고 내리는 자리마다 싱크면 그냥
지나친다. 싱크는 유일 테이블에 들어가지도 않고 쓰레기 수거의 눈에 띄지도
않으므로 계수를 세어 둘 까닭이 없고, 세지 않으면 ``싱크가 죽었다''는 괴상한
상태가 아예 생기지 않는다.
@<자료 구조@>=
type base struct {
	mem   []node // 노드들이 사는 곳; |mem[0]|은 쓰지 않는다
	avail int32  // 되쓸 수 있는 노드들의 목록 머리
	total int    // 지금 쓰이는 노드 수 (싱크 둘을 포함)
	dead  int    // 그 가운데 죽은 것의 수
	@<밑준위의 나머지 필드들@>@;
}

@ 노드를 새로 얻는 일과 되돌려 주는 일은 짧다. 자유 목록은 |xref| 필드를
링크로 삼아 이어 놓았다---어차피 죽은 노드의 참조 계수는 뜻이 없으므로,
크누스가 그랬듯 그 자리를 빌려 쓴다.
@<함수들@>=
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

@ 밑준위를 처음 세우는 자리. 싱크 둘을 놓고 캐시를 잡으면 끝이다. 그러고서
|zdd| 깃발 하나가 이 꾸러미의 두 세계를 가른다.
@<함수들@>=
func (b *base) init(zdd bool) {
	b.zdd = zdd
	b.mem = make([]node, 3, 64)
	b.mem[botsink] = node{lo: botsink, hi: botsink, lvl: maxLvl}
	b.mem[topsink] = node{lo: topsink, hi: topsink, lvl: maxLvl}
	b.total = 2
	b.ext = make(map[int32]int32)
	b.cacheInit()
}

@* 변수와 유일 테이블.
BDD 밑준위는 변수 $x_0$, $x_1$, \dots\ 위의 함수들을 나타낸다. 어떤 변수가 처음
불리면 그 변수를 위한 기록을 하나 만드는데, 거기에 딸린 가장 중요한 물건이
{\it 유일 테이블\/}이다. $x_v$에서 갈라지는 노드는 모두 그 표에 들어 있고,
표는 짝 $(l,h)$를 열쇠로 삼는다. BDD의 근본 성질---같은 $(v,l,h)$를 가진 노드가
둘일 수 없다---이 이 표 하나로 지켜진다. 그래서 이름이 유일 테이블이다.

표는 선형 조사(linear probing)로 훑는다. 크누스가 노드마다 3바이트쯤을 더 쓰면서도
선형 조사를 고른 까닭은 ``메모리를 차례로 훑는 것이 좋아서''다. 우리도 따른다.
표의 크기 $m$은 2의 거듭제곱이고, 그 안에 든 노드 수 $n$은 언제나 $m/8\le n\le 3m/4$
사이에 있다. 여덟 칸에 적어도 하나는 차 있고, 네 칸에 적어도 하나는 비어 있다.
@^Rudell, Richard Lyle@>

@ 변수 기록에는 표 말고도 몇 가지가 붙는다. 그 가운데 |proj|는 투영 함수 $x_v$이고,
|repl|은 합성에 쓰는 치환 함수 $y_v$이며(BDD 전용), |taut|과 |elt|는 ZDD가
쓰는 두 가지 특별한 노드다. 그리고 |name|은 사용자가 부르는 이름이다.

이름과 준위를 갈라 둔 것이 요긴하다. 변수 순서가 바뀌어도 사용자가 부르는
이름은 그대로여야 하기 때문이다. 사용자의 \.{x5}가 준위 13에 가 있으면
|vmap[5]=13|이고 |vars[13].name=5|다.
@<자료 구조@>=
type variable struct {
	proj int32   // 투영 함수 $x_v$
	repl int32   // 치환 함수 $y_v$ (BDD 전용)
	taut int32   // 여기서부터 항진인 노드 (ZDD 전용)
	elt  int32   // 원소 함수 $e_v$ (ZDD 전용)
	tab  []int32 // 유일 테이블; 길이는 2의 거듭제곱
	free int     // 그 가운데 빈 칸의 수
	name int32   // 사용자가 부르는 이름
	stamp uint32 // 합성에 쓰는 시각 도장
	aux   int32  // 체질 알고리즘이 쓰는 표식
	up, down int32 // 재정렬 때 이웃한 활성 준위
}

@ @<밑준위의 나머지 필드들@>=
vars []variable // 준위마다 하나씩
vmap []int32    // 이름을 준위로 옮기는 표

@ 준위 |v|에 아직 변수 기록이 없으면 하나 마련한다. 표는 두 칸으로 시작한다.
작게 시작해서 필요한 만큼만 자라는 편이, 쓰지도 않을 변수에 큰 표를 떼어 주는
것보다 낫다. 곁들여 |level|은 이름이 주어졌을 때 그 변수가 사는 준위를
알려 준다---둘을 가른 보람이 여기서 난다.
@<함수들@>=
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

@ 해시 코드는 곱셈으로 만든다. 크누스는 노드마다 난수를 박아 두고
|(l->index<<3)^(h->index<<2)|로 섞었지만, 우리 노드 첨자는 차례로 붙은 정수라
그대로 섞으면 무리를 짓는다. 황금비에서 온 상수를 곱하고 위 비트를 아래로
접어 주면 그 무리가 흩어진다. 곱셈 한 번이니 값도 싸다.
@^해시 코드@>
@<함수들@>=
const (
	mulA = 0x9E3779B1 // $2^{32}/\phi$, 황금비에서 온 승수
	mulB = 0x85EBCA77
	mulC = 0xC2B2AE35
)

func hash2(l, h int32) uint32 {
	x := uint32(l)*mulA + uint32(h)*mulB
	return x ^ (x >> 16)
}

@ 이제 이 프로그램에서 가장 중요한 루틴에 손을 댈 차례다. 준위 |v|와 노드
|l|, |h|가 주어지면, $x_v$에서 갈라져 0쪽으로 |l|, 1쪽으로 |h|를 가리키는 노드가
밑준위에 있는지 본다. 없으면 만든다. 어느 쪽이든 그 (유일한) 노드를 돌려준다.

참조 계수 규약은 크누스의 것을 그대로 따른다. 부르는 쪽은 |l|과 |h|에 대한
참조를 하나씩 얹어서 넘겨주고, 돌려받는 노드에 대한 참조를 하나 얻는다.
노드를 새로 만들면 |l|과 |h|에 얹혀 온 그 참조가 그대로 새 노드의 두 화살표가
된다. 이미 있는 노드를 찾으면 얹혀 온 참조 둘을 도로 내려놓고 찾은 노드의
계수를 하나 올린다.

그리고 여기가 BDD와 ZDD가 갈리는 바로 그 한 줄이다. BDD는 |l|과 |h|가 같으면
그 변수를 물어볼 까닭이 없으니 가지를 만들지 않는다. ZDD는 |h|가 |botsink|이면
---그 변수를 넣은 집합이 하나도 없으니---가지를 만들지 않는다.
@<함수들@>=
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
		@<빈 칸이 나올 때까지 선형 조사한다@>@;
		@<자리가 좁으면 넓히고, 아니면 새 노드를 만든다@>@;
	}
}

@ 조사하다가 찾던 노드를 만나면 거기서 돌아간다. 죽어 있던 노드를 만나는
운 좋은 경우도 있다. 그때는 계수를 0으로 되돌리기만 하면 되고 자식들은
건드리지 않는다. 자식들에게 얹혀 온 참조 둘이, 이 노드가 되살아나며 자식들에게
다시 걸어야 할 참조 둘과 정확히 맞아떨어지기 때문이다.
@<빈 칸이 나올 때까지 선형 조사한다@>=
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

@ 새 노드를 만들려는 참에 두 가지를 살핀다. 하나는 죽은 노드가 너무 많이
쌓이지 않았는가다. 작은 시계가 이 자리를 지날 때마다 똑딱이고, |timerInterval|
번마다 한 번씩 멈춰 서서 살림을 본다. 죽은 노드가 전체의 8분의 1을 넘으면
쓸어 담는다. 다른 하나는 표가 너무 빽빽하지 않은가다. 빈 칸이 4분의 1 아래로
내려가면 표를 두 배로 넓힌다. 어느 쪽이든 표가 달라지므로 처음부터 다시
찾아야 한다.
@<자리가 좁으면 넓히고, 아니면 새 노드를 만든다@>=
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

@ @^손볼 수 있는 값들@>
@<자료 구조@>=
const (
	timerInterval = 1024 // 이만큼마다 한 번씩 살림을 본다
	deadFraction  = 8    // 죽은 노드가 이 분의 일을 넘으면 쓸어 담는다
)

@ @<밑준위의 나머지 필드들@>=
timer uint64 // |uniqueFind|가 새 노드를 만들려 한 횟수
zdd   bool   // ZDD 축약 규칙을 쓰는가

@ 표를 새로 짓는 일은 넓힐 때나 줄일 때나 같다. 크누스는 표를 제자리에서 다시
해싱하는 Rudell의 재주를 부린다---위쪽 절반을 새로 잡을 수 없으니 아래쪽 절반을
두 번 훑어 밀어 올려야 했다. 슬라이스를 새로 잡을 수 있는 우리에게는 그럴
까닭이 없다. 새 표를 잡고 살아 있는 것들을 도로 꽂으면 그만이다.
@^Rudell, Richard Lyle@>
@<함수들@>=
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

@ 쓰레기를 수거할 때는 준위마다 이 루틴을 부른다. 죽은 노드를 표에서 지우고
자유 목록에 얹은 다음, 남은 것이 적으면 표를 줄인다.

선형 조사에서 항목을 지우는 것은 만만한 일이 아니다. 지운 자리가 조사의 사슬을
끊어 놓기 때문이다. 크누스는 {\sl TAOCP\/} 알고리즘 6.4R을 다듬어, 지울 것을
지나칠 때마다 뒤엣것을 앞으로 끌어당기는 영리한 되풀이를 쓴다. 우리는 그러지
않는다. 어차피 표 전체를 한 번 훑어야 하는데, 그 값이면 표를 통째로 다시 짓고도
남는다. 크누스의 프로그램에서 가장 까다로운 대목 하나가 이렇게 사라진다.
@<함수들@>=
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

@* 캐시.
밑준위 자체 말고 하나가 더 필요하다. 이미 해 본 계산을 다시 하지 않도록
기억해 두는 소프트웨어 캐시다. $f\land g=h$를 한 번 구했으면 그 사실을
적어 두었다가 다음에 그대로 꺼내 쓴다.

다만 ``적어 둔다''는 말이 곧이곧대로는 아니다. 모든 결과를 빠짐없이 기억하는
멋진 자료 구조를 짓는 값이, 몇 개쯤 잊고 다시 계산하는 값보다 비싸기 때문이다.
그래서 캐시는 해시 코드가 가리키는 {\it 한\/} 자리만 본다. 두 결과가 같은
자리로 가면 나중 것만 남는다. 대개 맞고 가끔 틀리는, 값싼 기억이다.

@ 항목 하나는 넷으로 이루어진다. $f$, $g$, $h$, 그리고 결과 $r$. 결과가
|null|이 아닐 때만 그 항목이 뜻을 가진다. 앞의 셋이 연산을 적어 두는 방식은
세 갈래다.

\smallskip\textindent{$\bullet$} $h$가 0이면 $g$는 {\it 시각 도장\/}이고 $f$가
노드다. 함수 합성이 이 꼴을 쓴다. 바깥의 도장을 하나 올리는 것만으로 관련된
항목 전부를 한꺼번에 무효로 만들 수 있다---도장이 지난 항목은 어떤 조회와도
맞지 않는다.

\smallskip\textindent{$\bullet$} $0<h\le|maxBinop|$이면 $h$는 노드 $f$와 $g$에
대한 이항 연산의 번호다.

\smallskip\textindent{$\bullet$} 그 밖이면 $(f,g,h)$는 세 노드 $f$, $g$,
$h\gg4$에 대한 삼항 연산이고, $h$의 아래 네 비트가 연산 번호다.
@<자료 구조@>=
type memo struct {
	f, g, h int32 // 피연산자와 연산 번호
	r       int32 // 결과; |null|이면 빈 자리
}

const maxBinop = 15 // 이 아래는 이항 연산 번호

@ @<밑준위의 나머지 필드들@>=
cache   []memo // 계산해 둔 결과들
cmask   int32  // |len(cache)-1|
inserts int    // 넣은 횟수
thresh  int    // 이만큼 넣으면 캐시를 두 배로

@ 캐시 크기는 언제나 2의 거듭제곱이다. 마음대로 고를 수 있을 때는, 들어 있는
항목 수 $m$의 네 배와 살아 있는 노드 수 $n$의 4분의 1 가운데 큰 쪽을 담을 만한
가장 작은 크기를 고른다.

두 배로 늘리는 문턱을 전체 칸수의 절반으로 둔 데에는 까닭이 있다. 무작위로
그만큼 집어넣으면 칸의 $e^{-1/2}\approx61$\%가 덮이지 않고 남는다. 그 확률을
$p$라 할 때 잃어버린 결과 하나를 다시 구하는 데 드는 걸음수 $E$는
$E=p\cdot1+(1-p)(1+2E)$를 만족하므로, 터지지 않으려면 $p>1/2$여야 하고
그때 $E=1/(2p-1)$이다.
@<함수들@>=
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

@ @^손볼 수 있는 값들@>
@<자료 구조@>=
const (
	minCacheSlots = 1 << 8
	maxCacheSlots = 1 << 24
)

@ 크기를 갈아 끼울 때는 새 슬라이스를 잡고 살아 있는 항목을 도로 꽂는다.
꽂다가 부딪혀 잃는 것이 있어도 그만이다---어차피 잊어도 되는 기억이니까.

자리를 고르는 |cacheSlot|은 유일 테이블의 해시보다 헐거워도 된다. 선형
조사가 아니라 한 자리만 보므로 무리를 지을 일이 없기 때문이다.
@<함수들@>=
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

@ 조회는 짧다. 자리 하나를 보고, 세 열쇠가 다 맞으면 결과를 돌려준다.
결과가 죽어 있으면 되살린다---캐시는 죽은 노드도 가리킬 수 있다. 아직
치워지지 않았을 뿐이지 자리는 그대로 있기 때문이다.
@<함수들@>=
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

@ 유일 테이블에서 죽은 노드를 걷어내기 전에, 캐시에 남은 그것들에 대한 참조를
먼저 지워야 한다. 지나간 도장을 단 항목도 이참에 함께 버린다.
@<함수들@>=
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

@ 항목 하나가 지났는지 보는 눈. 결과나 피연산자가 죽었으면 지났고, 합성
항목이면 도장이 바뀌었을 때 지났다. 그 곁의 |clearCache|는 훑을 것도 없이
캐시를 통째로 비운다. 변수 순서를 바꾸기 직전처럼, 적힌 것이 죄다 뜻을 잃는
자리에서 그렇게 부른다.
@<함수들@>=
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

@ 구한 것을 캐시에 적고 그대로 돌려주는 짧은 시늉. 두 엔진의 재귀마다
끝자락이 이 모양이므로 이름을 하나 붙여 두면 읽기 좋다.
@<함수들@>=
func (b *base) memo(f, g, h, r int32) int32 {
	b.cacheInsert(f, g, h, r)
	return r
}

@ 삼항 연산의 열쇠는 셋째 피연산자를 네 비트 왼쪽으로 밀고 그 자리에 연산
번호를 넣어 짓는다. 그러면 열쇠가 |maxBinop|보다 반드시 커지므로 이항 연산의
번호와 뒤섞이지 않는다. 크누스는 포인터가 16바이트 경계에 놓인다는 사실을
이용해 같은 일을 했다. 노드 첨자가 네 비트 밀려도 넘치지 않아야 하니, 이
꾸러미가 다룰 수 있는 노드는 $2^{27}$개까지다.
@<함수들@>=
func ternKey(h, op int32) int32 { return h<<4 | op }

@* 참조 계수.
노드 |p|의 |xref| 필드는 |p|를 가리키는 것들의 수에서 1을 뺀 값이다. 가리키는
것에는 위쪽 가지 노드들의 화살표, 바깥에서 붙든 손잡이, 투영 함수와 치환 함수가
모두 들어간다. 그러니 |xref==0|은 ``딱 하나가 붙들고 있다''는 뜻이고,
|xref<0|은 아무도 붙들지 않는다는 뜻---곧 죽었다는 뜻이다.

죽은 노드를 그 자리에서 치우지는 않는다. 자리는 그대로 두고 표시만 해 둔다.
쓸 만한 까닭이 둘 있다. 하나는 캐시가 아직 그 노드를 가리키고 있을 수 있고,
가리킨 채로도 아무 탈이 없다는 것. 다른 하나는 되살아날 수 있다는 것이다.
같은 $(v,l,h)$를 다시 물어보는 일은 생각보다 흔하다.
@<함수들@>=
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

@ 노드 하나가 죽으면 그 자식들도 참조를 하나씩 잃고, 그러다 따라 죽기도 한다.
아래로 내려가는 이 장례 행렬이 |kill|이다. 0쪽 갈래는 재귀로 가고 1쪽 갈래는
반복으로 간다---꼬리 재귀이므로 되돌아올 일이 없기 때문이다. 크누스가
|goto restart|로 적은 것을 우리는 |for| 고리로 적는다.
@<함수들@>=
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

@ 거꾸로 가는 길도 있다. 죽었던 노드를 되살릴 때는 자식들의 계수를 도로
올려 주어야 하고, 자식이 죽어 있었다면 그것도 함께 일으켜 세운다.
@<함수들@>=
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

@* 손잡이.
바깥세상이 이 꾸러미의 함수를 붙드는 방법이 |Func|이다. 안을 들여다보면
손잡이 하나를 싼 값일 뿐이다. 값으로 주고받아도 되고, 복사해도 되고, 슬라이스나
맵에 담아도 된다. 복사본들은 같은 손잡이를 나눠 쥐므로 노드는 하나만 붙든다.

손잡이가 닿지 않는 곳으로 가면 \GO/의 쓰레기 수거기가 정리 훅을 울린다. 훅은
``이 노드를 놓아도 된다''는 쪽지를 대기표에 얹을 뿐, 아무것도 건드리지 않는다.
훅이 다른 고루틴에서 울리기 때문이기도 하고, 연산 한복판에서 노드가 죽으면
곤란하기 때문이기도 하다. 쪽지를 실제로 처리하는 것은 다음 연산이 시작될 때다.
@^AddCleanup@>
@<자료 구조@>=
type Func struct{ h *handle }

type handle struct {
	b  *base
	p  int32
	cl runtime.Cleanup
}

@ @<밑준위의 나머지 필드들@>=
ext     map[int32]int32 // 노드마다 바깥에서 붙든 손잡이의 수
mu      sync.Mutex      // 아래 대기표를 지킨다
pending []int32         // 정리 훅이 얹어 둔 쪽지들

@ 노드 하나를 손잡이로 싸는 일과, 손잡이가 사라졌을 때 쪽지를 얹는 일. 싸는 쪽
|wrap|은 넘겨받은 노드의 참조를 그대로 물려받는다---그러니 |wrap|을 부르는
쪽은 참조를 하나 얹어 둔 노드를 넘겨야 한다.
@<함수들@>=
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

@ 모든 공개 연산은 |drain|으로 시작한다. 밀린 쪽지를 여기서 다 처리하고 나면,
그 뒤로 연산이 끝날 때까지는 어떤 노드도 죽지 않는다.
@<함수들@>=
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

@ 손잡이에서 노드를 꺼내는 자리에서 두 가지를 막는다. 이미 놓아 버린 손잡이와,
다른 밑준위에서 온 손잡이. 둘 다 조용히 틀린 답을 내는 대신 요란하게 죽는
편이 낫다.

그 곁에 |Equal|을 둔다. BDD는 유일하므로 두 함수가 같은지 묻는 일이 노드
첨자 둘을 견주는 일로 끝난다---이것이 BDD의 가장 값진 성질이다.
@<함수들@>=
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

@ 손잡이를 기다리지 않고 곧바로 놓고 싶을 때도 있다. 큰 계산 중간에 나온
함수라면 쓰레기 수거기를 기다리는 사이에 노드가 잔뜩 쌓일 수 있으니까. 그때
|Free|를 부르면 정리 훅을 떼어 내고 그 자리에서 놓는다. 두 번 불러도 탈이 없다.
@<함수들@>=
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

@* 쓰레기 수거.
죽은 노드를 실제로 치우는 일이다. 치우기 전에 그것들을 가리키는 것이 하나도
없어야 하므로, 캐시를 먼저 훑고 그다음에 유일 테이블들을 훑는다.

인자 |all|이 참이면 캐시를 통째로 비운다. 변수 순서를 바꾸기 직전처럼, 캐시에
적힌 것이 죄다 뜻을 잃는 자리에서 그렇게 부른다.
@<함수들@>=
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

@ @<밑준위의 나머지 필드들@>=
gcs int // 쓰레기를 쓸어 담은 횟수

@ 변수 재정렬(옆집 \.{reorder.w})이 쓰는 두 가지도 여기 자리를 잡아 둔다.
@<밑준위의 나머지 필드들@>=
totalvars int32 // 지금 쓰이는 변수의 수
first     int32 // 그 가운데 가장 위에 있는 것의 준위

@ 캐시를 통째로 비우면 합성에 쓰는 시각 도장도 함께 맞춰 두어야 한다.
도장이 0이라는 것은 ``이 준위 아래로는 치환 함수가 하나도 없다''는 뜻이므로,
0이 아닌 것들만 1로 눌러 놓으면 된다.
@<함수들@>=
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

@ @<밑준위의 나머지 필드들@>=
stamp    uint32 // 지금까지 준비하거나 마친 합성의 수
stampChg bool   // 마지막 합성 뒤에 도장이 바뀌었는가

@* 살림살이.
계산이 얼마나 커졌는지 들여다보는 창 하나. 크누스는 |mems|---8바이트 낱말을
몇 번이나 건드렸는가---를 세었다. 그것이 그가 알고 싶던 것이었기 때문이다.
우리가 세는 것은 더 수수하다. 노드가 몇이고 그중 죽은 것이 몇인지, 캐시가
얼마나 큰지, 쓰레기를 몇 번이나 쓸어 담았는지.
@<자료 구조@>=
type Stats struct {
	Nodes       int // 쓰이는 노드 수 (싱크 둘을 포함)
	Dead        int // 그 가운데 죽은 것
	Vars        int // 만들어진 변수의 수
	CacheSlots  int // 캐시의 칸수
	Collections int // 쓰레기를 쓸어 담은 횟수
}

@ @<함수들@>=
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

@* 훑기 채비.
두 엔진이 함수 하나를 훑을 때 함께 쓰는 자잘한 연장들을 여기 모아 둔다.

첫째는 준위의 {\it 차례\/}다. 준위 번호는 촘촘하지 않다. 사용자가 \.{x0}과
\.{x100}만 만들었으면 준위 0과 100만 살아 있다. 그러니 살아 있는 준위들에
0부터 차례로 번호를 다시 매겨 두어야, 화살표 하나가 변수를 몇 개나
건너뛰었는지 잴 수 있다. 그 다시 매긴 번호를 |levels|와 |ranks|가 나눠
맡는다. 앞엣것은 변수가 앉아 있는 준위들을 위에서 아래 차례로 늘어놓는다.
@<함수들@>=
func (b *base) levels() []int32 {
	out := make([]int32, 0, len(b.vars))
	for v := range b.vars {
		if b.vars[v].tab != nil {
			out = append(out, int32(v))
		}
	}
	return out
}

@ |ranks| 표의 |v|번 칸에는 준위 |v|보다 위에 있는 활성 준위의 수가 들어
있다. 맨 끝 칸에는 활성 준위의 총수가 들어 있어, 싱크의 자리 노릇을 한다.
@<함수들@>=
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

@ 둘째는 함수 하나에 딸린 노드들을 죄다 모으는 일이다. 같은 노드를 여러 번
만나므로 지나온 자리를 적어 둔다---BDD가 나무가 아니라 {\it 방향 비순환
그래프\/}라는 사실이 여기서 값을 한다.
@<함수들@>=
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

@ 셋째는 무작위 추출이다. 해가 $2^{80}$개인 함수에서 하나를 고르게 뽑으려면
큰 수를 다뤄야 하는데, |big.Int|에는 |math/rand/v2|와 맞물리는 추출이 없어서
손수 짓는다. $n$보다 작은 수를 고르게 뽑는 흔한 방법을 쓴다. $n$의 비트 수만큼
무작위 비트를 뽑고, $n$ 이상이 나오면 버리고 다시 뽑는다. 버릴 확률이 절반을
넘지 않으므로 평균 두 번이면 끝난다.
@<함수들@>=
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

@* 온전성 검사.
BDD 꾸러미는 겹겹이 남아도는 자료 구조 위에 서 있다. 유일 테이블도 캐시도
참조 계수도 모두 ``없어도 답은 나오는'' 것들이다. 그래서 어딘가 어긋나도
당장은 표가 나지 않는다. 명령 수백만 개를 더 실행한 뒤에야 엉뚱한 자리에서
탈이 난다.

크누스가 |sanity_check|를 쓴 까닭이 그것이다. 그는 이렇게 적었다---``이걸
써 보고 나서 구조 자체와 훨씬 친해졌다. 나머지 코드를 쓸 때 이 다져진 앎이
분명 값질 것이다.'' 나도 같은 것을 겪었다. 아래 검사가 확인하는 목록이 곧
이 자료 구조가 지켜야 할 것들의 목록이다.

값이 싼 검사는 아니다. 노드 수에 비례하는 시간과 자리를 쓰므로 시험과
디버깅에만 쓴다.
@^Knuth, Donald Ervin@>
@<함수들@>=
func (b *base) Check() error {
	b.drain()
	want := make(map[int32]int32)
	@<바깥과 특별 노드가 붙든 몫을 센다@>@;
	@<유일 테이블을 훑으며 노드마다 살핀다@>@;
	@<참조 계수와 총계를 맞춰 본다@>@;
	return nil
}

@ 참조는 네 군데서 온다. 바깥에서 붙든 손잡이, 위쪽 가지 노드의 화살표,
그리고 변수 기록이 붙든 특별한 노드들(투영·치환·원소·항진). 첫째와 셋째를
여기서 세고, 둘째는 표를 훑으며 센다.

항진 노드만 셈이 다르다. 바깥에서 붙드는 것은 맨 위의 것뿐이고 나머지는 바로
위 항진 노드가 붙든다---그래야 준위를 맞바꿀 때 아래쪽 항진 노드가 숨은 노드가
되어 제때 사라진다.
@<바깥과 특별 노드가 붙든 몫을 센다@>=
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

@ 표를 훑으며 노드마다 묻는다. 제 준위에 있는가? 같은 $(v,l,h)$를 가진
쌍둥이가 있지는 않은가? 축약 규칙과 준위 차례를 지키는가? 그리고 죽지 않았다면
제 자식들에게 참조를 하나씩 걸고 있는가?
@<유일 테이블을 훑으며 노드마다 살핀다@>=
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
			@<자식들에게 건 참조를 센다@>@;
		}
	}
}

@ @<자식들에게 건 참조를 센다@>=
if nd.lo > topsink {
	want[nd.lo]++
}
if nd.hi > topsink {
	want[nd.hi]++
}

@ 노드 하나의 생김새. 축약 규칙이 여기서 두 세계를 다시 한번 가른다.
그리고 어느 노드든 제 유일 테이블에서 찾아낼 수 있어야 한다---찾을 수 없다면
그 노드는 있으나 마나이고, 머잖아 쌍둥이가 생긴다. 그 물음에는 찾기만 하고
만들지는 않는 |find|를 쓴다.
@<함수들@>=
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

@ 마지막으로 셈을 맞춰 본다. 살아 있는 노드의 |xref|는 세어 본 참조 수에서
1을 뺀 값이어야 하고, 죽은 노드는 아무도 가리키지 않아야 한다. 그리고 쓰이는
노드와 자유 목록에 든 노드를 합하면 |mem|에 자리 잡은 노드 전부여야 한다.
하나라도 어긋나면 어딘가에서 노드가 새어 나간 것이다.
@<참조 계수와 총계를 맞춰 본다@>=
for p := range seen {
	q := b.find(p[0], p[1], p[2])
	if n := want[q]; b.mem[q].xref < 0 && n != 0 {
		return fmt.Errorf("죽은 노드 %d를 %d군데서 가리킨다", q, n)
	} else if b.mem[q].xref >= 0 && b.mem[q].xref != n-1 {
		return fmt.Errorf("노드 %d의 참조 계수는 %d여야 하는데 %d다",
			q, n-1, b.mem[q].xref)
	}
}
@<자유 목록을 훑는다@>@;
if total != b.total || dead != b.dead {
	return fmt.Errorf("노드는 %d(죽은 것 %d)여야 하는데 %d(죽은 것 %d)로 세고 있다",
		total, dead, b.total, b.dead)
}

@ @<자유 목록을 훑는다@>=
nfree := 0
for p := b.avail; p != null; p = b.mem[p].xref {
	if nfree++; nfree >= len(b.mem) {
		return fmt.Errorf("자유 목록이 고리를 이룬다")
	}
}
if b.total+nfree != len(b.mem)-1 {
	return fmt.Errorf("노드 %d개가 새어 나갔다", len(b.mem)-1-b.total-nfree)
}

@* 시험.
밑준위의 시험은 알고리즘이 아니라 {\it 살림\/}을 겨눈다. 손잡이가 제때
풀리는가, 죽은 노드가 제대로 치워지는가, 그러고도 셈이 맞는가. 밑준위만으로는
시험할 수 없으니 BDD 엔진을 하나 빌려 쓴다.
@(common_test.go@>=
package bdd

import (
	"runtime"
	"testing"
)

@ 첫째 시험은 쓰레기를 잔뜩 만들어 놓고 치우는 것이다. 함수를 지어서는
곧바로 버리기를 사만 번 되풀이하고, 그때마다 온전성 검사를 통과해야 한다. 여기서
|runtime.GC|를 불러 \GO/의 수거기가 정리 훅을 울리게 하고, |drain|으로 밀린
쪽지를 비운 다음 |collectGarbage|로 실제로 걷어낸다.
@(common_test.go@>=
func TestGarbageCollection(t *testing.T) {
	b := New()
	vars := make([]Func, 10)
	for k := range vars {
		vars[k] = b.Var(k)
	}
	for round := 0; round < 5; round++ {
		@<함수를 지었다 버리기를 되풀이한다@>@;
		runtime.GC()
		b.drain()
		b.collectGarbage(false)
		if err := b.Check(); err != nil {
			t.Fatalf("%d바퀴째: %v", round, err)
		}
	}
	if s := b.Stats(); s.Collections == 0 {
		t.Log("쓰레기 수거가 한 번도 저절로 일어나지 않았다")
	}
}

@ 여기서 |Free|를 부르는 것이 요점이다. 손잡이를 그냥 버려도 언젠가는
풀리지만, 그 ``언젠가''는 \GO/의 수거기가 정한다. 큰 계산 중간이라면 그때까지
노드가 잔뜩 쌓일 수 있으니 손수 놓는 길도 있어야 한다.
@<함수를 지었다 버리기를 되풀이한다@>=
for i := 0; i < 4000; i++ {
	f := vars[i%len(vars)]
	for j := 0; j < 4; j++ {
		g := vars[(i*7+j*3)%len(vars)]
		switch j % 3 {
		case 0:
			f = b.And(f, g)
		case 1:
			f = b.Or(f, g)
		case 2:
			f = b.Xor(f, g)
		}
	}
	f.Free()
}

@ 손잡이 자체의 됨됨이도 살핀다. 같은 함수를 두 번 지으면 같은 노드가
나와야 하고(BDD가 유일하다는 바로 그 성질이다), |Free|는 두 번 불러도 탈이
없어야 하며, 놓아 버린 손잡이나 남의 밑준위에서 온 손잡이를 쓰면 요란하게
죽어야 한다.
@(common_test.go@>=
func TestHandles(t *testing.T) {
	b, c := New(), New()
	x, y := b.Var(0), b.Var(1)
	if !b.And(x, y).Equal(b.And(y, x)) {
		t.Error("같은 함수인데 다른 노드가 나왔다")
	}
	if b.And(x, y).Equal(b.Or(x, y)) {
		t.Error("다른 함수인데 같은 노드가 나왔다")
	}
	f := b.And(x, y)
	f.Free()
	f.Free() // 두 번 불러도 탈이 없어야 한다
	@<놓아 버린 손잡이와 남의 손잡이를 써 본다@>@;
	if err := b.Check(); err != nil {
		t.Fatal(err)
	}
}

@ @<놓아 버린 손잡이와 남의 손잡이를 써 본다@>=
mustPanic := func(name string, fn func()) {
	defer func() {
		if recover() == nil {
			t.Errorf("%s: 죽었어야 하는데 멀쩡하다", name)
		}
	}()
	fn()
}
mustPanic("놓아 버린 손잡이", func() { b.And(f, x) })
mustPanic("남의 밑준위", func() { b.And(c.Var(0), x) })

@* 색인.
