\input kotexgweb
\input luamplib.sty

\def\title{단순 경로 세기}

@s Func int
@s ZDD int
@s big.Int int

@* 들어가며.
$8\times8$ 격자의 왼쪽 위 모퉁이에서 오른쪽 아래 모퉁이까지, 같은 칸을 두 번
밟지 않고 가는 길이 몇 가지나 될까. 답은
$$789{,}360{,}053{,}252$$
가지다. 칠천팔백억이 넘는다. 하나씩 세자면 컴퓨터로도 한나절이 걸릴 텐데,
ZDD로는 눈 깜짝할 사이다. 길을 하나도 그리지 않고 세기 때문이다.

이 프로그램은 크누스가 {\sl TAOCP\/} 7.1.4절에서 다룬 \.{SIMPATH} 알고리즘을
옆집 ZDD 꾸러미 위에 얹은 것이다. 방법의 이름은 {\it 프런티어\/}(frontier)
법이다.
@^SIMPATH@>
@^Knuth, Donald Ervin@>

@ 생각은 이렇다. 그래프의 간선에 $e_0$, $e_1$, \dots, $e_{m-1}$이라고 차례를
매긴다. 그러면 길 하나는 간선들의 부분집합이고, 단순 경로 전체는 부분집합의
{\it 족\/}이다. 족이라면 ZDD의 일감이다.

간선을 차례로 훑으며 ``이 간선을 넣을까 뺄까''를 정해 나간다고 하자.
$e_i$까지 정하고 났을 때 앞으로의 판단에 필요한 정보는 무엇일까. 놀랍게도
아주 적다. 이미 정한 간선들과 아직 정하지 않은 간선들 {\it 양쪽에 걸친\/}
정점들---이것을 프런티어라 한다---에 대해, 지금까지 그은 조각들이 어떻게
이어져 있는지만 알면 된다. 프런티어 바깥의 정점은 이미 운명이 정해졌거나
아직 손도 대지 않았으므로 잊어도 좋다.

$$\mplibcode
beginfig(1);
u := 13mm; r := 2.2mm;
pair p[];
for i=0 upto 3: for j=0 upto 3:
  p[4i+j] := (j*u, (3-i)*u);
endfor endfor
for i=0 upto 3: for j=0 upto 3:
  if j<3: draw p[4i+j]--p[4i+j+1] withcolor .75white; fi
  if i<3: draw p[4i+j]--p[4i+j+4] withcolor .75white; fi
endfor endfor
path pp; pp := p[0]--p[1]--p[5]--p[6]--p[10]--p[11]--p[15];
draw pp withpen pencircle scaled 1.6pt withcolor (.85,.2,.1);
for i=0 upto 3: for j=0 upto 3:
  fill fullcircle scaled 2.4mm shifted p[4i+j] withcolor .35white;
endfor endfor
draw (-.45u, .5u+2u)--(3.45u, .5u+2u) dashed evenly withcolor .45white;
for j=0 upto 3:
  draw fullcircle scaled (2r) shifted p[4+j] withpen pencircle scaled 1pt;
endfor
label.lft(btex $s$ etex, p[0] shifted (-3mm,2mm));
label.rt(btex $t$ etex, p[15] shifted (3mm,-2mm));
label.rt(btex 프런티어 etex, (3.55u, 2.5u));
endfig;
\endmplibcode$$

\noindent 점선 위쪽 간선은 이미 정했고 아래쪽은 아직 정하지 않았다. 동그라미
친 네 정점이 그때의 프런티어다. 격자의 폭이 $w$면 프런티어는 많아야 $w+1$개다.
그러니 상태의 가짓수가 간선 수에 비해 훨씬 적고, 같은 상태로 모이는 길들을
한 노드에 몰아 담을 수 있다. 그것이 ZDD가 하는 일이다.

@ 프런티어 위에서 무엇을 기억해야 하는가. {\it 짝\/}(mate) 배열 하나면 된다.
정점 $v$에 대해
$$\hbox{|mate[v]|}=\cases{v,&아직 손대지 않았다\cr
\hbox{|inside|},&길의 안쪽이다 (차수 2)\cr
w,&길 조각의 한쪽 끝이고 반대쪽 끝이 $w$다\cr}$$
로 적는다. 간선 $(u,v)$를 새로 그으면 두 조각이 하나로 이어지므로,
$a=|mate[u]|$, $b=|mate[v]|$라 할 때 $u$와 $v$는 안쪽이 되고 $a$와 $b$가
새 조각의 두 끝이 된다.

여기에 크누스의 재주 하나가 얹힌다. 우리가 찾는 것은 $s$에서 $t$까지 가는
길인데, 처음부터 |mate[s]=t|, |mate[t]=s|로 두면 마치 $s$와 $t$ 사이에
{\it 보이지 않는 간선\/} 하나가 이미 그어져 있는 셈이 된다. 그러면 찾는 것이
``$s$--$t$ 경로''가 아니라 ``그 보이지 않는 간선을 지나는 사이클 하나''가
되어, 판정이 한결 매끈해진다.
@^짝 배열@>

@ 뼈대는 짧다. 그래프를 만들고, 간선 차례를 정하고, ZDD를 밑에서부터 쌓고,
세어 본다. 부르는 법은 이렇다.
$$\vbox{\halign{\.{#}\hfil\cr
go run . -m 8 -n 8\cr
go run . -m 5 -n 5 -show 3 -bylen\cr}}$$
@c
package main

import (
	"flag"
	"fmt"
	"math/big"
	"slices"

	"github.com/sjnam/bdd"
)

@<자료 구조@>

@<함수들@>

func main() {
	@<명령줄을 읽는다@>@;
	@<격자 그래프를 만든다@>@;
	@<ZDD를 짓고 세어 본다@>@;
}

@* 그래프와 간선 차례.
정점은 $0$부터 $n-1$까지 번호를 매기고, 간선은 정점 쌍의 목록이다. 간선의
{\it 차례\/}가 이 방법의 목숨줄이다. 차례를 잘못 잡으면 프런티어가 커지고,
프런티어가 커지면 상태의 가짓수가 폭발한다.

격자라면 답이 뻔하다. 왼쪽 위에서 오른쪽 아래로, 행을 따라 쓸어 가며
오른쪽 간선과 아래쪽 간선을 차례로 내놓는다. 그러면 프런티어는 늘 한 행
언저리에 머문다.
@<자료 구조@>=
type graph struct {
	n     int      // 정점의 수
	edges [][2]int // 간선의 차례
	s, t  int      // 길의 두 끝
}

@ @<격자 그래프를 만든다@>=
g := &graph{n: *rows * *cols, s: 0, t: *rows**cols - 1}
id := func(i, j int) int { return i**cols + j }
for i := 0; i < *rows; i++ {
	for j := 0; j < *cols; j++ {
		if j+1 < *cols {
			g.edges = append(g.edges, [2]int{id(i, j), id(i, j+1)})
		}
		if i+1 < *rows {
			g.edges = append(g.edges, [2]int{id(i, j), id(i+1, j)})
		}
	}
}
if g.n > 254 {
	panic("정점이 너무 많다: 짝 배열이 int8에 담기지 않는다")
}

@ 간선 차례가 정해지면 프런티어도 정해진다. 정점 $v$가 프런티어에 드는 것은,
이미 지나온 간선 가운데 $v$에 닿는 것이 있고 앞으로 볼 간선 가운데도 $v$에
닿는 것이 있을 때다. $s$와 $t$는 보이지 않는 간선 덕에 처음부터 손댄 것으로
친다.
@<자료 구조@>=
type solver struct {
	g        *graph
	z        *bdd.ZDD
	last     []int   // 정점마다 마지막으로 닿는 간선의 번호
	frontier [][]int // 간선 i를 정하기 직전의 프런티어
	memo     map[string]bdd.Func
}

@ @<함수들@>=
func newSolver(g *graph) *solver {
	m := len(g.edges)
	s := &solver{g: g, z: bdd.NewZDD(m), last: make([]int, g.n),
		frontier: make([][]int, m+1), memo: map[string]bdd.Func{}}
	first := make([]int, g.n)
	for v := range first {
		first[v], s.last[v] = m, -1
	}
	for i, e := range g.edges {
		for _, v := range e {
			first[v], s.last[v] = min(first[v], i), i
		}
	}
	first[g.s], first[g.t] = -1, -1 // 보이지 않는 간선이 이미 닿았다
	@<준위마다 프런티어를 적어 둔다@>@;
	return s
}

@ @<준위마다 프런티어를 적어 둔다@>=
for i := 0; i <= m; i++ {
	for v := 0; v < g.n; v++ {
		if first[v] < i && s.last[v] >= i {
			s.frontier[i] = append(s.frontier[i], v)
		}
	}
}

@* 짝 배열.
짝 배열은 정점마다 한 바이트다. 값이 그 정점 자신이면 아직 손대지 않은
것이고, |inside|면 길의 안쪽이며, 그 밖이면 조각의 반대쪽 끝이다.
@<자료 구조@>=
const inside = int8(-1) // 길의 안쪽; 차수가 이미 2다

@ 간선 $(u,v)$를 긋는 일. 세 가지로 끝난다. 못 긋거나, 이어 붙이거나,
사이클이 닫히거나.

못 긋는 것은 둘 가운데 하나가 이미 안쪽일 때다. 차수가 3이 되어 버리니까.
사이클이 닫히는 것은 |mate[u]|가 바로 $v$일 때다---둘이 같은 조각의 두 끝이니
여기에 간선을 그으면 고리가 된다. 보이지 않는 간선 덕에 그 고리가 곧 우리가
찾던 $s$--$t$ 경로다.
@<함수들@>=
const (
	blocked = iota // 그을 수 없다
	linked         // 두 조각을 이었다
	closed         // 사이클이 닫혔다
)

func link(mate []int8, u, v int) int {
	a, b := mate[u], mate[v]
	switch {
	case a == inside || b == inside:
		return blocked
	case a == int8(v):
		return closed
	}
	mate[u], mate[v] = inside, inside
	mate[a], mate[b] = b, a
	return linked
}

@ 여기서 대입 차례가 묘하다. $u$가 아직 손대지 않은 정점이면 $a=u$이므로
|mate[u]|에 |inside|를 넣었다가 곧 |mate[a]=b|가 그것을 덮어쓴다. 결과는
``$u$는 새 조각의 한쪽 끝이고 반대쪽 끝은 $b$''---바로 우리가 바라던 것이다.
두 줄이 손대지 않은 정점과 이미 조각의 끝인 정점을 한꺼번에 옳게 다룬다.

@ 정점이 프런티어를 떠날 때는 매듭이 지어져 있어야 한다. 안쪽이거나(차수 2)
손대지 않았거나(차수 0) 둘 중 하나다. 짝이 남아 있으면 그 정점은 어디로도
이어지지 못한 길 끝이니, 그 갈래는 거기서 죽는다.
@<함수들@>=
func settled(mate []int8, v int) bool {
	return mate[v] == inside || mate[v] == int8(v)
}

@* 밑에서부터 짓기.
이제 ZDD를 짓는다. 재귀 |build(i, mate)|는 ``간선 $e_i$부터 $e_{m-1}$까지를 어떻게
고르면 길이 완성되는가''를 나타내는 족이다. 밑준위에서 |Build|를 부르면
준위 $i$에 노드 하나가 놓이는데, 두 갈래가 각각 $e_i$를 빼는 경우와 넣는
경우다. 재귀가 아래에서 위로 거슬러 올라오므로 노드도 밑에서부터 쌓인다.

같은 상태로 모이는 길들은 같은 노드를 나눠 쓴다. 그 몫을 |memo|가 맡는다.
이 한 줄이 칠천팔백억 가지를 몇만 개의 노드로 접는다.
@<함수들@>=
func (s *solver) build(i int, mate []int8) bdd.Func {
	if i == len(s.g.edges) {
		return s.z.Empty() // 끝까지 왔는데 고리가 닫히지 않았다
	}
	key := s.key(i, mate)
	if f, ok := s.memo[key]; ok {
		return f
	}
	f := s.z.Build(s.z.Elt(i), s.branch(i, mate, false), s.branch(i, mate, true))
	s.memo[key] = f
	return f
}

@ 상태의 이름표는 프런티어 위의 짝 값들을 그대로 이어 붙인 것이다. 프런티어
{\it 바깥\/}은 넣지 않는다---이미 떠난 정점의 짝 값은 남아 있어도 뜻이
없으므로, 넣었다가는 같은 상태를 여럿으로 갈라 놓게 된다.
@<함수들@>=
func (s *solver) key(i int, mate []int8) string {
	buf := make([]byte, 0, 2+len(s.frontier[i]))
	buf = append(buf, byte(i), byte(i>>8))
	for _, v := range s.frontier[i] {
		buf = append(buf, byte(mate[v]+1))
	}
	return string(buf)
}

@ 갈래 하나를 뻗는 일. 간선을 넣기로 했으면 이어 붙여 보고, 어느 쪽이든
이 준위에서 프런티어를 떠나는 정점들의 매듭을 검사한다.
@<함수들@>=
func (s *solver) branch(i int, mate []int8, take bool) bdd.Func {
	m := slices.Clone(mate)
	if take {
		switch u, v := s.g.edges[i][0], s.g.edges[i][1]; link(m, u, v) {
		case blocked:
			return s.z.Empty()
		case closed:
			@<고리가 닫혔다@>@;
		}
	}
	@<프런티어를 떠나는 정점을 검사한다@>@;
	return s.build(i+1, m)
}

@ 고리가 닫히면 길이 완성된 것이다. 다만 아무 데도 이어지지 못한 조각이
남아 있으면 안 된다. 프런티어에 아직 짝을 달고 있는 정점이 있다면 그것은
영영 이어질 데가 없으므로 그 갈래는 죽는다. 남은 간선은 모두 빼야 하니
답은 $\epsilon$, 곧 ``공집합 하나만 든 족''이다.
@<고리가 닫혔다@>=
for _, w := range s.frontier[i] {
	if w != u && w != v && !settled(m, w) {
		return s.z.Empty()
	}
}
return s.z.Unit()

@ @<프런티어를 떠나는 정점을 검사한다@>=
for _, w := range s.frontier[i] {
	if s.last[w] == i && !settled(m, w) {
		return s.z.Empty()
	}
}

@ 첫걸음은 짝 배열을 차려 놓는 일이다. 모두 제 자신을 가리키게 두고,
$s$와 $t$만 서로를 가리키게 한다. 보이지 않는 간선이 그것이다.
@<함수들@>=
func (s *solver) run() bdd.Func {
	mate := make([]int8, s.g.n)
	for v := range mate {
		mate[v] = int8(v)
	}
	mate[s.g.s], mate[s.g.t] = int8(s.g.t), int8(s.g.s)
	return s.build(0, mate)
}

@* 세어 보기.
다 짓고 나면 세는 일은 거저다. 노드마다 두 갈래의 셈을 더하기만 하면 된다.
길이별로 몇 개인지도 알고 싶다면 대칭 함수를 쓴다---``간선을 정확히 $k$개
고른 것''과 교집합을 취하면 길이가 $k$인 경로만 남는다.
@<ZDD를 짓고 세어 본다@>=
sv := newSolver(g)
f := sv.run()
fmt.Printf("%d×%d 격자: 정점 %d개, 간선 %d개\n", *rows, *cols, g.n, len(g.edges))
fmt.Printf("ZDD 노드 %d개, 상태 %d개\n", sv.z.Size(f), len(sv.memo))
fmt.Printf("단순 경로 %v가지\n", sv.z.Count(f))
@<몇 가지를 그려 본다@>@;
@<길이별로 세어 본다@>@;
@<가장 긴 경로를 찾는다@>@;

@ @<명령줄을 읽는다@>=
rows := flag.Int("m", 4, "격자의 행 수")
cols := flag.Int("n", 4, "격자의 열 수")
show := flag.Int("show", 0, "경로를 이만큼 그려 본다")
bylen := flag.Bool("bylen", false, "길이별로 세어 본다")
long := flag.Bool("long", false, "가장 긴 경로를 찾는다")
flag.Parse()

@ @<몇 가지를 그려 본다@>=
if *show > 0 {
	seen := 0
	for path := range sv.z.Subsets(f) {
		if seen++; seen > *show {
			break
		}
		fmt.Printf("  길이 %d: %v\n", len(path), path)
	}
	if p, ok := sv.z.Random(f, nil); ok {
		fmt.Printf("  무작위로 하나: 길이 %d\n", len(p))
	}
}

@ 길이별 셈은 대칭 함수의 좋은 쓸모다. 간선 전부를 늘어놓은 목록 |all|을
만들어 두고, 거기서 정확히 $k$개를 고른 족과 교집합을 취한다.
@<길이별로 세어 본다@>=
if *bylen {
	all := sv.z.Empty()
	for i := range g.edges {
		all = sv.z.Union(all, sv.z.Elt(i))
	}
	total := new(big.Int)
	for k := 1; k <= len(g.edges); k++ {
		c := sv.z.Count(sv.z.Intersect(f, sv.z.Sym(all, k)))
		if c.Sign() > 0 {
			fmt.Printf("  길이 %2d: %v가지\n", k, c)
			total.Add(total, c)
		}
	}
	fmt.Printf("  합계: %v가지\n", total)
}

@* 가장 긴 경로.
단순 경로 가운데 가장 {\it 긴\/} 것을 찾는 문제는 그래프 일반에서 NP-어렵다.
해밀턴 경로가 있느냐를 묻는 것이 이 문제의 특별한 경우이기 때문이다. 그런데
경로 전부를 ZDD로 지어 놓았으니 여기서는 거저다. 간선마다 무게를 1로 주고
|MaxWeight|를 부르면 간선 수가 가장 많은 경로가 나온다. ZDD 마디 수에
정비례하는 시간에.
@^해밀턴 경로@>

$8\times8$ 격자에서 답은 길이 62다. 예순네 칸을 모두 지나는 해밀턴 경로라면
63이어야 하니 한 칸이 모자란 셈인데, 여기에는 까닭이 있다. 격자를 장기판처럼
두 빛깔로 칠하면 간선은 언제나 다른 빛깔을 잇는다. 그러니 칸을 $k$개 지나는
경로의 두 끝은 $k$가 짝수일 때만 다른 빛깔이다. 그런데 $s$와 $t$는 두 모퉁이
$(0,0)$과 $(7,7)$이라 빛깔이 {\it 같다\/}. 예순네 칸을 다 지나면 두 끝의 빛깔이
달라야 하므로 그런 경로는 없다. 한 칸을 버리면 된다. 그래서 63이 아니라 62다.
$4\times4$에서 14가 나오는 것도 같은 까닭이다.
@^장기판 논법@>

길이별 셈으로도 가장 긴 길이는 알 수 있지만 그쪽은 간선 수만큼 |Sym|을
부르고 교집합을 취해야 한다. 이쪽은 한 번 훑고 끝이며, 무엇보다
{\it 그 경로를\/} 돌려준다. 무게를 간선의 실제 길이로 바꾸어 넘기면 가장
비싼 경로가 나오고, 부호를 뒤집으면 가장 싼 경로가 나온다.
@<가장 긴 경로를 찾는다@>=
if *long {
	w := make([]int, len(g.edges))
	for i := range w {
		w[i] = 1
	}
	if path, k, ok := sv.z.MaxWeight(f, w); ok {
		fmt.Printf("가장 긴 경로는 길이 %d\n", k)
		for _, e := range path {
			fmt.Printf(" %d--%d", g.edges[e][0], g.edges[e][1])
		}
		fmt.Println()
	}
}

@* 색인.
