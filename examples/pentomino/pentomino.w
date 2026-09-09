\input kotexgweb
\input luamplib.sty

\def\title{펜토미노 타일링}

@s Func int
@s ZDD int

@* 들어가며.
정사각형 다섯 개를 변끼리 붙여 만들 수 있는 모양은 뒤집고 돌린 것을 같다고
치면 열두 가지다. 이것이 {\it 펜토미노\/}이고, 열두 조각을 모두 써서
$6\times10$ 직사각형을 덮는 방법은 2339가지다. 판을 돌리고 뒤집은 것까지
따로 세면 네 배인 9356가지가 된다. 1960년에 Solomon Golomb이 이 조각들에
이름을 붙였고, Dana Scott이 이듬해에 컴퓨터로 $8\times8$ 판의 답을 세었다.
@^Golomb, Solomon Wolf@>
@^Scott, Dana Stewart@>
@^펜토미노@>

$$\mplibcode
beginfig(1);
numeric u; u := 3.1mm;
numeric p[][];
def setp(expr k, a, b, c, d, e) =
  p[k][0] := a; p[k][1] := b; p[k][2] := c; p[k][3] := d; p[k][4] := e;
enddef;
setp(0, 1, 2, 10, 11, 21);
setp(1, 0, 10, 20, 30, 40);
setp(2, 0, 10, 20, 30, 31);
setp(3, 1, 11, 20, 21, 30);
setp(4, 0, 1, 10, 11, 20);
setp(5, 0, 1, 2, 11, 21);
setp(6, 0, 2, 10, 11, 12);
setp(7, 0, 10, 20, 21, 22);
setp(8, 0, 10, 11, 21, 22);
setp(9, 1, 10, 11, 12, 21);
setp(10, 1, 10, 11, 21, 31);
setp(11, 0, 1, 11, 21, 22);
picture lb[];
lb[0] := btex F etex; lb[1] := btex I etex; lb[2] := btex L etex;
lb[3] := btex N etex; lb[4] := btex P etex; lb[5] := btex T etex;
lb[6] := btex U etex; lb[7] := btex V etex; lb[8] := btex W etex;
lb[9] := btex X etex; lb[10] := btex Y etex; lb[11] := btex Z etex;
numeric ox, oy;
for k=0 upto 11:
  ox := (k mod 6)*4.6u; oy := -(k div 6)*7.6u;
  for j=0 upto 4:
    fill unitsquare shifted ((p[k][j] mod 10), -(p[k][j] div 10))
      scaled u shifted (ox, oy) withcolor .74white;
    draw unitsquare shifted ((p[k][j] mod 10), -(p[k][j] div 10))
      scaled u shifted (ox, oy) withpen pencircle scaled .3pt
      withcolor .45white;
  endfor
  label(lb[k], (ox + 1.4u, oy - 5.7u));
endfor
endfig;
\endmplibcode$$

@ 이런 문제를 {\it 정확 피복\/}이라 한다. 항목이 있고 선택지가 있는데,
선택지 몇 개를 골라 항목 하나하나를 {\it 꼭 한 번씩\/} 덮으라는 것이다.
여기서 항목은 판의 예순 칸과 열두 조각이고, 선택지는 조각 하나를 판 어딘가에
놓는 방법 하나다. 크누스는 이 문제를 푸는 데 평생 공을 들였고 춤추는 링크와
춤추는 칸이 거기서 나왔다.
@^정확 피복@>
@^Knuth, Donald Ervin@>

@ 되짚기로 푸는 것과 여기서 하는 일은 목표가 다르다. 되짚기는 답을 하나씩
뱉는다. 9356가지를 다 받으려면 9356번 받아야 하고, 받고 나면 손에 남는 것은
답 목록뿐이다. 여기서는 답을 하나도 그리지 않고 {\it 답 전체를 한 덩어리로\/}
짓는다. 그 덩어리가 ZDD 26984마디다. 손에 쥐고 나면 세는 것도, 균등하게 하나
뽑는 것도, 조건을 더 거는 것도 거저다. 특히 균등 추출은 되짚기로는 하기
어려운 일이다---미리 세어 두지 않으면 어느 답을 뽑아야 고른지 알 수 없기
때문이다.

부르는 법은 이렇다.
$$\vbox{\halign{\.{#}\hfil\cr
go run .\cr
go run . -m 6 -n 10\cr
go run . -m 6 -n 10 -random\cr
go run . -m 3 -n 20 -show 8\cr}}$$
기본값인 $5\times12$는 2초에 끝나고 메모리를 230메가바이트쯤 쓴다. 이름난
$6\times10$은 8초가 걸리고 1.7기가바이트를 쓴다---왜 그렇게 먹는지는
뒤에서 이야기한다.
@c
package main

import (
	"flag"
	"fmt"
	"math/rand/v2"
	"sort"

	"github.com/sjnam/bdd"
)

@<자료 구조@>

@<함수들@>

func main() {
	@<명령줄을 읽는다@>@;
	@<놓을 수 있는 자리를 모두 모은다@>@;
	@<프런티어로 덮기의 족을 짓는다@>@;
	@<조각마다 하나씩이라는 조건을 건다@>@;
	@<세고 뽑고 그린다@>@;
}

@ 조각이 열둘에 한 조각이 다섯 칸이니 판은 예순 칸이어야 한다. 짧은 쪽을
행으로 삼는 것이 중요한데, 그 까닭은 곧 나온다.
@<명령줄을 읽는다@>=
rows := flag.Int("m", 5, "판의 행 수")
cols := flag.Int("n", 12, "판의 열 수")
show := flag.Int("show", 0, "답을 이만큼 그려 본다")
pick := flag.Bool("random", false, "답 하나를 균등하게 뽑아 그린다")
flag.Parse()
m, n := *rows, *cols
if m > n {
	m, n = n, m
}
if m*n != 60 {
	fmt.Println("판이 예순 칸이 아니다:", m, "x", n)
	return
}

@* 열두 조각.
조각은 왼쪽 위를 원점으로 삼은 칸 다섯 개의 목록으로 적는다. 이름은
Golomb이 붙인 대로 알파벳 열두 자를 쓴다. 글자 모양이 조각 모양을
닮았다---\.I는 곧은 막대이고 \.X는 십자다.
@<자료 구조@>=
var shapes = map[byte][][2]int{
	'F': {{0, 1}, {0, 2}, {1, 0}, {1, 1}, {2, 1}},
	'I': {{0, 0}, {1, 0}, {2, 0}, {3, 0}, {4, 0}},
	'L': {{0, 0}, {1, 0}, {2, 0}, {3, 0}, {3, 1}},
	'N': {{0, 1}, {1, 1}, {2, 0}, {2, 1}, {3, 0}},
	'P': {{0, 0}, {0, 1}, {1, 0}, {1, 1}, {2, 0}},
	'T': {{0, 0}, {0, 1}, {0, 2}, {1, 1}, {2, 1}},
	'U': {{0, 0}, {0, 2}, {1, 0}, {1, 1}, {1, 2}},
	'V': {{0, 0}, {1, 0}, {2, 0}, {2, 1}, {2, 2}},
	'W': {{0, 0}, {1, 0}, {1, 1}, {2, 1}, {2, 2}},
	'X': {{0, 1}, {1, 0}, {1, 1}, {1, 2}, {2, 1}},
	'Y': {{0, 1}, {1, 0}, {1, 1}, {2, 1}, {3, 1}},
	'Z': {{0, 0}, {0, 1}, {1, 1}, {2, 1}, {2, 2}},
}

const names = "FILNPTUVWXYZ"

@ 조각마다 돌리고 뒤집어 방향을 만든다. 네 번 돌리고, 뒤집어서 또 네 번
돌리면 여덟이 나오는데 대칭인 조각은 그보다 적다. \.X는 하나뿐이고 \.I는
둘, \.F는 여덟이다. 중복을 걸러내려고 왼쪽 위로 당겨 놓고 열쇠를 만들어
견준다.
@<놓을 수 있는 자리를 모두 모은다@>=
var ps []placement
for pi := 0; pi < 12; pi++ {
	seen := map[string]bool{}
	cur := shapes[names[pi]]
	for t := 0; t < 8; t++ {
		@<|cur|를 당겨 |norm|과 열쇠 |key|를 얻는다@>@;
		if !seen[key] {
			seen[key] = true
			@<|norm|을 판 곳곳에 놓아 본다@>@;
		}
		@<|cur|를 돌리거나 뒤집는다@>@;
	}
}
@<자리를 첫 칸 차례로 늘어놓는다@>@;

@ @<|cur|를 당겨 |norm|과 열쇠 |key|를 얻는다@>=
mr, mc := 99, 99
for _, c := range cur {
	mr, mc = min(mr, c[0]), min(mc, c[1])
}
norm := make([][2]int, len(cur))
for i, c := range cur {
	norm[i] = [2]int{c[0] - mr, c[1] - mc}
}
sort.Slice(norm, func(i, j int) bool {
	if norm[i][0] != norm[j][0] {
		return norm[i][0] < norm[j][0]
	}
	return norm[i][1] < norm[j][1]
})
key := fmt.Sprint(norm)

@ 네 번째 걸음에서만 뒤집고 나머지는 돌린다. 돌리기는 $(r,c)\mapsto(c,-r)$,
뒤집기는 $(r,c)\mapsto(r,-c)$다. 어차피 다음 걸음에서 왼쪽 위로 당기므로
음수가 나와도 상관없다.
@<|cur|를 돌리거나 뒤집는다@>=
next := make([][2]int, len(cur))
for i, c := range cur {
	if t == 3 {
		next[i] = [2]int{c[0], -c[1]}
	} else {
		next[i] = [2]int{c[1], -c[0]}
	}
}
cur = next

@* 칸 번호와 프런티어.
여기가 이 프로그램에서 가장 중요한 대목이다. 칸에 번호를 매기는 차례가
프로그램이 도는지 안 도는지를 가른다.

행 우선으로 매기면 안 된다. $3\times20$ 판에서 세로로 선 조각 하나는
스무 칸씩 떨어진 칸 셋을 덮는다. 그러면 뒤에서 이야기할 ``상태''가
마흔 칸에 걸치게 되어 걷잡을 수 없이 불어난다. 처음에 그렇게 짰다가
$3\times20$---답이 여덟 가지뿐인 판---조차 5분 안에 끝나지 않았다.

짧은 쪽을 따라 매기면 된다. 열 우선으로, 곧 $(r,c)$를 $cm+r$번으로
매기면 조각 하나가 걸치는 칸이 다섯 열 안에 들어온다.
@^프런티어@>
@<|norm|을 판 곳곳에 놓아 본다@>=
h, w := 0, 0
for _, c := range norm {
	h, w = max(h, c[0]), max(w, c[1])
}
for r := 0; r+h < m; r++ {
	for c := 0; c+w < n; c++ {
		p := placement{piece: pi, cells: make([]int, 5)}
		for i, x := range norm {
			p.cells[i] = (c+x[1])*m + r + x[0]
		}
		sort.Ints(p.cells)
		for _, k := range p.cells {
			p.mask |= 1 << k
		}
		ps = append(ps, p)
	}
}

@ @<자료 구조@>=
type placement struct {
	piece int    // 어느 조각인가
	cells []int  // 덮는 칸들, 오름차순
	mask  uint64 // 같은 것을 비트로
}

@ 자리를 {\it 첫 칸\/} 차례로 늘어놓는 것이 다음 절의 발판이다. 그러면
답에 든 자리들이 늘 이 차례대로 나타나고, 각 자리는 그때까지 안 덮인 첫
칸을 덮는다.
@<자리를 첫 칸 차례로 늘어놓는다@>=
sort.Slice(ps, func(i, j int) bool {
	if ps[i].cells[0] != ps[j].cells[0] {
		return ps[i].cells[0] < ps[j].cells[0]
	}
	return ps[i].piece < ps[j].piece
})
start := make([]int, m*n+1)
for c, i := 0, 0; c <= m*n; c++ {
	for i < len(ps) && ps[i].cells[0] < c {
		i++
	}
	start[c] = i
}
fmt.Printf("%d×%d 판: 칸 %d개, 놓을 자리 %d가지\n", m, n, m*n, len(ps))

@* 프런티어로 쌓기.
ZDD의 원소는 ``자리''다. 답 하나는 자리 열두 개를 고른 것이고, 답 전체는
그런 모음들의 족이다. 그 족을 밑에서부터 손수 쌓는다.

첨자 $i$번 자리를 볼 차례이고 지금까지 덮인 칸이 |covered|라 하자. 안 덮인
첫 칸을 $c$라 하면, 첫 칸이 $c$보다 앞인 자리는 이제 와서 쓸 수 없다---그
자리의 첫 칸은 이미 덮여 있으니 겹친다. 그래서 첨자를 |start[c]|까지 건너뛴다.
거기서도 첫 칸이 $c$보다 뒤라면 칸 $c$를 덮을 자리가 남아 있지 않다는 뜻이니
죽은 길이다.
@<자료 구조@>=
type state struct {
	i       int
	covered uint64
}

type solver struct {
	z     *bdd.ZDD
	ps    []placement
	start []int
	full  uint64
	memo  map[state]bdd.Func
}

@ 재귀는 짧다. 자리 $i$를 안 쓰는 갈래와 쓰는 갈래를 각각 구해 |Build|로
마디 하나를 짓는다. 쓰는 갈래는 첫 칸이 딱 $c$이고 겹치지 않을 때만 열린다.
같은 상태를 여러 길로 만날 때마다 다시 세지 않도록 |memo|에 담아 둔다---
그 나눠 쓰기가 이 방법의 전부다.
@<함수들@>=
func (s *solver) node(st state) bdd.Func {
	if st.covered == s.full {
		return s.z.Unit()
	}
	c := 0
	for ; st.covered&(1<<c) != 0; c++ {
	}
	if st.i < s.start[c] {
		st.i = s.start[c]
	}
	if st.i == len(s.ps) || s.ps[st.i].cells[0] > c {
		return s.z.Empty()
	}
	if f, ok := s.memo[st]; ok {
		return f
	}
	@<두 갈래를 구해 마디를 짓는다@>@;
}

@ @<두 갈래를 구해 마디를 짓는다@>=
lo := s.node(state{st.i + 1, st.covered})
hi := s.z.Empty()
if p := s.ps[st.i]; p.cells[0] == c && st.covered&p.mask == 0 {
	hi = s.node(state{st.i + 1, st.covered | p.mask})
}
f := s.z.Build(s.z.Elt(st.i), lo, hi)
s.memo[st] = f
return f

@ 여기서 눈여겨볼 것이 있다. 이 재귀는 {\it 조각을 거듭 써도 좋다고\/}
치고 센다. \.X를 두 번 쓰고 \.T를 안 써도 칸만 정확히 덮으면 답으로
친다. 그런 덮기가 $6\times10$ 판에 78억 4588만 8732가지 있다.

조각 조건을 재귀에 넣으려면 ``어느 조각을 썼나''를 상태에 얹어야 하는데,
그러면 상태가 최대 $2^{12}$배로 불어난다. 실제로 그렇게 짜서 재어 보니
$5\times12$ 판에서 상태가 120만 개에서 3157만 개로, 스물여섯 배가 되었다.
$6\times10$은 4분을 기다려도 끝나지 않았다.

그러니 넣지 않는다. 나중에 ZDD 연산으로 걸러내는 편이 훨씬 싸다. 조건을
{\it 나중에\/} 걸 수 있다는 것이 답 전체를 손에 쥐고 있는 값어치다.
@<프런티어로 덮기의 족을 짓는다@>=
z := bdd.NewZDD(len(ps))
s := &solver{z: z, ps: ps, start: start, full: 1<<(m*n) - 1,
	memo: map[state]bdd.Func{}}
f := s.node(state{})
fmt.Printf("조각을 거듭 써도 되는 덮기: 상태 %d개, ZDD %d마디, %v가지\n",
	len(s.memo), z.Size(f), z.Count(f))

@* 조각마다 하나씩.
조각 하나에 대해 ``그 조각의 자리를 정확히 하나 골랐다''는 족은 사슬
하나로 지어진다. 원소를 아래에서 위로 훑으며 상태 둘을 나란히 끌고 가면
된다. 아직 하나도 못 골랐다는 상태와 하나 골랐다는 상태다. 못 고른 채로
끝나면 $\emptyset$이고 하나 고른 채로 끝나면 $\{\emptyset\}$이다.
@<조각마다 하나씩이라는 조건을 건다@>=
for pi := 0; pi < 12; pi++ {
	none, once := z.Empty(), z.Unit()
	for v := len(ps) - 1; v >= 0; v-- {
		e := z.Elt(v)
		if ps[v].piece == pi {
			none, once = z.Build(e, none, once), z.Build(e, once, z.Empty())
		} else {
			none, once = z.Build(e, none, none), z.Build(e, once, once)
		}
	}
	f = z.Intersect(f, none)
}
fmt.Printf("조각 조건까지: ZDD %d마디, 답 %v가지\n", z.Size(f), z.Count(f))

@ 조건 열두 개를 걸고 나면 $6\times10$ 판의 ZDD가 26984마디로 줄고 답이
9356가지로 줄어든다. 78억에서 9356으로 걸러 내는 데 든 시간은 전체의
절반쯤이다.

메모리를 많이 먹는 것은 ZDD가 아니라 |memo|다. $6\times10$에서 상태가
740만 개인데 그 하나하나가 손잡이를 붙들고 있으니 1.7기가바이트가 든다.
정작 결과물인 ZDD는 26984마디, 곧 반 메가바이트도 안 된다. 짓는 동안이
무겁고 짓고 나면 가벼운 것이 이 방법의 생김새다.

@* 세고 뽑고 그리기.
이제 족을 손에 쥐었으니 물어보는 일만 남았다. 답 하나를 균등하게 뽑는
것부터 해 보자. |Random|은 마디마다 두 갈래에 달린 답의 수를 견주어
가지를 고르므로, 9356가지 가운데 어느 것이나 똑같은 확률로 나온다.
되짚기로는 이렇게 못 한다.
@<세고 뽑고 그린다@>=
if *pick {
	if sol, ok := z.Random(f, rand.New(rand.NewPCG(20260907, 9))); ok {
		draw(m, n, ps, sol)
	}
}

@ 늘어놓기는 반복자로 나온다. 원하는 만큼만 받고 빠져나오면 훑기도 거기서
멈춘다.
@<세고 뽑고 그린다@>=
seen := 0
for sol := range z.Subsets(f) {
	if seen++; seen > *show {
		break
	}
	draw(m, n, ps, sol)
}

@ 그리는 일은 칸마다 어느 조각이 덮었는지 적는 것이다. 칸 번호를 열
우선으로 매겼으니 읽을 때도 그렇게 읽는다.
@<함수들@>=
func draw(m, n int, ps []placement, sol []int) {
	g := make([]byte, m*n)
	for _, i := range sol {
		for _, c := range ps[i].cells {
			g[c] = names[ps[i].piece]
		}
	}
	for r := 0; r < m; r++ {
		for c := 0; c < n; c++ {
			fmt.Printf(" %c", g[c*m+r])
		}
		fmt.Println()
	}
	fmt.Println()
}

@* 색인.
