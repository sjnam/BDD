\input kotexgweb

\def\title{독립집합}

@s Func int
@s ZDD int
@s Int int

@* 들어가며.
그래프의 {\it 독립집합\/}은 서로 이웃하지 않은 정점들의 모임이다. 간선
하나를 통째로 품은 부분집합은 독립집합이 아니고, 그렇지 않은 것은 모두
독립집합이다. 정의가 이렇게 짧으니 프로그램도 짧아야 마땅하다.

BDD로 풀자면 정점마다 변수를 두고 간선마다 $\lnot(x_u\land x_v)$를 엮으면
된다. 그런데 우리가 세려는 것은 불 함수가 아니라 {\it 집합족\/}이다.
그렇다면 ZDD의 일감이다. 온 족 $\wp$에서 시작해서 못 쓸 것들을 걷어내는
체 하나면 끝난다.
@^독립집합@>

@ 체는 이렇게 생겼다. 간선 $(u,v)$에 대해
$$\{\{e_u,e_v\}\}\sqcup\wp$$
는 $e_u$와 $e_v$를 모두 품은 부분집합 전부다. 결합 $\sqcup$이 ``$\{e_u,e_v\}$에
아무것이나 갖다 붙인 것''을 뜻하기 때문이다. 그것을 빼면 된다. 간선마다
한 번씩, 모두 빼고 나면 남는 것이 독립집합의 족이다.

성긴 족일수록 ZDD가 이긴다고 했는데 독립집합은 그리 성기지 않다. 그래도
$6\times6$ 격자의 독립집합 5,598,861개가 노드 285개에 담긴다. 세는 것은
물론 거저다.
@c
package main

import (
	"flag"
	"fmt"
	"math/rand/v2"

	"github.com/sjnam/bdd"
)

@<자료 구조@>

func main() {
	@<명령줄을 읽는다@>@;
	@<그래프를 고른다@>@;
	@<체로 걸러 독립집합의 족을 짓는다@>@;
	@<세어 보고 가장 큰 것을 찾는다@>@;
	@<무게를 주고 가장 무거운 독립집합을 찾는다@>@;
}

@ @<명령줄을 읽는다@>=
name := flag.String("g", "petersen", "그래프: petersen, grid, cycle, complete")
rows := flag.Int("m", 4, "격자의 행 수")
cols := flag.Int("n", 4, "격자의 열 수 (또는 cycle·complete의 크기)")
show := flag.Int("show", 0, "독립집합을 이만큼 늘어놓는다")
flag.Parse()

@* 그래프.
그래프는 정점 수와 간선 목록으로 적는다. 정점에는 $0$부터 번호를 매기고,
그 번호가 곧 ZDD의 원소 번호가 된다.
@<자료 구조@>=
type edge struct{ u, v int }

@ 넷을 마련해 두었다. 페테르센 그래프는 정점 열 개에 간선 열다섯 개인
유명한 반례 제조기다. 격자는 $m\times n$이고, 사이클과 완전 그래프는
크기 하나만 받는다.
@^Petersen, Julius@>
@<그래프를 고른다@>=
var nv int
var edges []edge
switch *name {
case "petersen":
	@<페테르센 그래프@>@;
case "grid":
	@<격자 그래프@>@;
case "cycle":
	@<사이클@>@;
case "complete":
	@<완전 그래프@>@;
default:
	panic("모르는 그래프: " + *name)
}

@ 바깥 오각형과 안쪽 오각별을 살(spoke) 다섯으로 이은 것이 페테르센
그래프다. 안쪽이 오각형이 아니라 오각{\it 별\/}이라 정점 $5+k$가
$5+((k+2)\bmod5)$와 이어진다.
@<페테르센 그래프@>=
nv, edges = 10, []edge{
	{0, 1}, {1, 2}, {2, 3}, {3, 4}, {4, 0}, // 바깥 오각형
	{5, 7}, {7, 9}, {9, 6}, {6, 8}, {8, 5}, // 안쪽 오각별
	{0, 5}, {1, 6}, {2, 7}, {3, 8}, {4, 9}, // 살
}

@ 격자는 오른쪽 이웃과 아래쪽 이웃만 이어 주면 된다. 왼쪽과 위쪽은 그
이웃이 제 몫으로 이미 이어 놓았을 테니까.
@<격자 그래프@>=
id := func(i, j int) int { return i**cols + j }
nv = *rows * *cols
for i := 0; i < *rows; i++ {
	for j := 0; j < *cols; j++ {
		if j+1 < *cols {
			edges = append(edges, edge{id(i, j), id(i, j+1)})
		}
		if i+1 < *rows {
			edges = append(edges, edge{id(i, j), id(i+1, j)})
		}
	}
}

@ 사이클 $C_n$의 독립집합 수가 뤼카 수 $L_n$이라는 것은 잘 알려져 있다.
$L_{10}=123$이니 셈이 맞는지 여기서 손쉽게 확인할 수 있다.
@^뤼카 수@>
@<사이클@>=
nv = *cols
for i := 0; i < nv; i++ {
	edges = append(edges, edge{i, (i + 1) % nv})
}

@ 완전 그래프의 독립집합은 공집합과 한 점짜리들뿐이니 $n+1$개다. 이것도
셈을 재어 보는 잣대가 된다.
@<완전 그래프@>=
nv = *cols
for i := 0; i < nv; i++ {
	for j := i + 1; j < nv; j++ {
		edges = append(edges, edge{i, j})
	}
}

@* 족 짓기.
이제 세 줄이다. 온 족에서 시작해, 간선마다 그 두 끝을 모두 품은 것들을
빼 나간다.
@<체로 걸러 독립집합의 족을 짓는다@>=
z := bdd.NewZDD(nv)
f := z.Universe()
for _, e := range edges {
	both := z.Join(z.Elt(e.u), z.Elt(e.v)) // 집합 $\{e_u,e_v\}$ 하나만 든 족
	f = z.Diff(f, z.Join(both, z.Universe()))
}
fmt.Printf("%s: 정점 %d개, 간선 %d개\n", *name, nv, len(edges))
fmt.Printf("독립집합 %v개, ZDD 노드 %d개\n", z.Count(f), z.Size(f))

@* 가장 큰 것 찾기.
독립수(independence number)---가장 큰 독립집합의 크기---를 찾는 데 대칭
함수가 요긴하다. 정점을 모두 늘어놓은 목록 |all|을 만들어 두면
|z.Sym(all, k)|가 ``정확히 $k$개를 품은 부분집합''의 족이다. 그것과
독립집합의 족을 교집합해서 비지 않은 가장 큰 $k$를 찾으면 된다.

위에서부터 훑어 내려오는 것이 중요하다. 처음 비지 않은 곳이 곧 답이고,
거기서 멈추면 된다.
@<세어 보고 가장 큰 것을 찾는다@>=
all := z.Empty()
for v := 0; v < nv; v++ {
	all = z.Union(all, z.Elt(v))
}
for k := nv; k >= 0; k-- {
	g := z.Intersect(f, z.Sym(all, k))
	if z.Count(g).Sign() == 0 {
		continue
	}
	fmt.Printf("가장 큰 독립집합은 크기 %d, 그런 것이 %v개\n", k, z.Count(g))
	@<가장 큰 것 몇 가지를 늘어놓는다@>@;
	break
}

@ @<가장 큰 것 몇 가지를 늘어놓는다@>=
seen := 0
for s := range z.Subsets(g) {
	if seen++; seen > *show {
		break
	}
	fmt.Printf("  %d: %v\n", seen, s)
}

@* 무게를 얹으면.
정점마다 값이 다르다면 어떨까. ``서로 이웃하지 않게 고르되 값의 합을 가장
크게''는 최대 가중 독립집합 문제이고, 그래프 일반에서는 NP-어렵다. 그런데
독립집합의 족을 이미 ZDD로 지어 놓았으므로 여기서는 거저다. |MaxWeight|가
마디를 한 번 훑으며 각 마디에 달린 부분족의 최대 무게를 적어 두고, 뿌리에서
한 번 내려오며 답을 되짚는다. ZDD 마디 수에 정비례한다.

값은 이미 다 치렀다는 점이 요점이다. $6\times36$ 격자의 독립집합을 세는
것도, 그 가운데 가장 무거운 것을 찾는 것도, 같은 ZDD 하나를 놓고 하는
일이다.
@^최대 가중 독립집합@>
@<무게를 주고 가장 무거운 독립집합을 찾는다@>=
w := make([]int, nv)
rnd := rand.New(rand.NewPCG(20260907, uint64(nv)))
for v := range w {
	w[v] = 1 + rnd.IntN(20)
}
fmt.Printf("무게 %v\n", w)
if set, weight, ok := z.MaxWeight(f, w); ok {
	fmt.Printf("가장 무거운 독립집합은 %v, 무게 %d\n", set, weight)
}
@<무게를 모두 1로 두어 본다@>@;

@ 무게를 모두 1로 두면 가장 무거운 독립집합이 곧 가장 {\it 큰\/} 독립집합이
된다. 앞 절에서 대칭 함수로 찾아 놓은 크기와 같은 수가 나와야 한다. 한
답에 이르는 길이 둘이니 이것만으로도 쓸 만한 검사가 된다.
@<무게를 모두 1로 두어 본다@>=
ones := make([]int, nv)
for v := range ones {
	ones[v] = 1
}
if set, size, ok := z.MaxWeight(f, ones); ok {
	fmt.Printf("무게를 모두 1로 두면 크기 %d짜리 %v\n", size, set)
}

@* 색인.
