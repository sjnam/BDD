\input kotexgweb
\input luamplib.sty

\def\title{상징적 도달 가능성}

@s Func int
@s Int int
@s big int
@s bdd int
@s time int

@* 들어가며.
페그 솔리테어는 십자 모양 판에 파인 서른세 구멍과 말 서른두 개로 하는
혼자 놀이다. 말 하나가 이웃한 말을 뛰어넘어 그 너머 빈 구멍에 앉으면
넘긴 말은 판에서 빠진다. 가운데만 비워 놓고 시작해서 가운데 한 알만
남기고 끝내는 것이 이 놀이의 고전적인 목표다. 1697년 궁정 초상화에
이미 이 판이 그려져 있고, 라이프니츠는 1710년에 이 놀이를 두고 짧은
글을 하나 남겼다.
@^라이프니츠, 고트프리트 빌헬름@>
@^페그 솔리테어@>

$$\mplibcode
beginfig(1);
numeric u, d; u := 7.5mm; d := 4.2mm;
pair p[];
for r=0 upto 6: for c=0 upto 6:
  p[7r+c] := (c*u, -r*u);
endfor endfor
def cell(expr k) = fullcircle scaled d shifted p[k] enddef;
for r=0 upto 6: for c=0 upto 6:
  if ((r>=2) and (r<=4)) or ((c>=2) and (c<=4)):
    if (r=3) and (c=3):
      draw cell(7r+c) withpen pencircle scaled .7pt withcolor .55white;
    else:
      fill cell(7r+c) withcolor .38white;
    fi
  fi
endfor endfor
drawarrow p[22]{up} .. {down}p[24]
  withpen pencircle scaled 1pt withcolor (.85,.2,.1);
endfig;
\endmplibcode$$

\noindent 가운데 한 칸만 비워 놓고 시작한다. 화살표는 그 자리에서 둘 수
있는 네 수 가운데 하나다. 뛰어넘긴 말은 판에서 빠지므로 한 수마다 말이
하나씩 줄고, 서른두 수를 다 두면 한 알만 남는다.

@ 이 프로그램이 하는 일은 한 판을 푸는 것이 아니다. {\it 닿을 수 있는
자리를 모두 세는 것\/}이다. 가운데만 빈 그 자리에서 출발해 규칙대로만
움직여 이를 수 있는 판의 모양이 몇 가지나 되는지 묻는다. 답은 1억
8763만 6299가지다.

하나씩 훑어 세도 되기는 한다. 되짚기로 한나절쯤 돌리면 나온다. 여기서는
자리를 하나도 그리지 않고 센다. {\it 집합을 통째로 옮기는\/} 것이다.
말이 있는 칸을 1, 빈 칸을 0으로 적으면 판 하나가 33비트짜리 불 벡터가
되고, 그러면 판의 {\it 집합\/}은 33변수 불 함수 하나가 된다. 함수 하나를
BDD 하나로 적을 수 있으니, 자리 2900만 개를 노드 100만 개에 담아 놓고
한꺼번에 밀고 나갈 수 있다.
@^상징적 도달 가능성@>

@ 밀고 나가는 방법은 이렇다. 한 걸음을 {\it 관계\/}로 적는다. 지금의
판을 $x=(x_0,\ldots,x_{n-1})$, 한 수 둔 뒤의 판을 $x'$이라 하고,
``$x$에서 한 수로 $x'$에 갈 수 있다''를 $2n$변수 불 함수 $T(x,x')$로
적는 것이다. 그러면 자리의 집합 $R$이 한 걸음 뒤에 이르는 집합은
$$R'(x')=(\exists x)\,\bigl[R(x)\land T(x,x')\bigr]$$
이고, 여기서 $x'$을 도로 $x$라 부르면 다음 층이 된다. 이 두 줄이
프로그램의 전부다.

1990년에 Burch, Clarke, McMillan, Dill, Hwang이 ``상징적 모형 검사:
$10^{20}$개의 상태와 그 너머''라는 제목으로 이 방법을 내놓았다. 상태를
하나도 만들지 않고 상태 공간을 훑는다는 발상이 검증이라는 분야를 통째로
바꾸어 놓았고, BDD가 세상에 쓸모를 증명한 것도 그때다.
@^McMillan, Kenneth Lauchlin@>
@^Burch, Jerry Ross@>
@^Clarke, Edmund Melson@>
@^상징적 모형 검사@>

@ 우리 꾸러미에는 마침 저 두 줄에 딱 맞는 문이 나 있다. 삼항 연산
|AndExists|가 McMillan이 {\it 관계곱\/}(relational product)이라 부른
그것으로, $R\land T$를 먼저 만들고 나서 한정하는 대신 두 일을 한
재귀에서 해치운다. 중간에 생길 $R\land T$가 양쪽 어느 것보다도 클 수
있으니 이것이 요긴하다. 이름을 되돌리는 일은 합성 |Compose|가 맡는다.

부르는 법은 이렇다.
$$\vbox{\halign{\.{#}\hfil\cr
go run .\cr
go run . -b plus\cr
go run . -b english -show 5\cr}}$$
큰 판은 내 노트북에서 4분쯤 걸린다. 층마다 결과를 바로 찍으므로 어디까지
갔는지는 보면서 기다릴 수 있다. \.{-b plus}는 작은 판이라 눈 깜짝할
사이에 끝난다.
@c
package main

import (
	"flag"
	"fmt"
	"math/big"
	"time"

	"github.com/sjnam/bdd"
)

@<자료 구조@>

func main() {
	@<명령줄을 읽는다@>@;
	@<판에 번호를 매긴다@>@;
	@<둘 수 있는 수를 모은다@>@;
	@<변수 두 벌을 잡는다@>@;
	@<전이 관계를 엮는다@>@;
	@<층층이 훑는다@>@;
	@<끝자리를 그린다@>@;
}

@* 판과 수.
판은 직사각 격자에서 몇 칸을 도려낸 모양이다. 어느 칸이 살아 있는지를
술어 하나로 적으면 판이 정해진다. 여기 둘을 둔다. 서른세 칸짜리 십자판이
표준이고, 스물한 칸짜리 작은 십자판은 같은 프로그램을 순식간에 돌려
보고 싶을 때 쓴다. 작은 판은 가운데서 시작하면 말 넷이 남고 더는
움직일 수 없다---못 푸는 판이라는 것도 이 프로그램이 알려 준다.
@<자료 구조@>=
type board struct {
	rows, cols int                 // 격자의 크기
	cr, cc     int                 // 비워 놓고 시작할 칸
	ok         func(r, c int) bool // 살아 있는 칸인가
}

var boards = map[string]board{
	"english": {7, 7, 3, 3,
		func(r, c int) bool { return (r >= 2 && r <= 4) || (c >= 2 && c <= 4) }},
	"plus": {5, 5, 2, 2,
		func(r, c int) bool { return (r >= 1 && r <= 3) || (c >= 1 && c <= 3) }},
}

@ @<명령줄을 읽는다@>=
name := flag.String("b", "english", "판: english 또는 plus")
show := flag.Int("show", 5, "마지막 층의 자리를 이만큼 그린다")
flag.Parse()
bd, found := boards[*name]
if !found {
	fmt.Println("모르는 판:", *name)
	return
}

@ 칸에는 행 우선으로 번호를 매긴다. 이 차례가 그대로 BDD의 변수 차례가
되므로 아무렇게나 매길 일이 아니다. 한 수는 한 줄 위의 세 칸을 건드리니
행을 따라 번호를 매기면 서로 얽히는 변수들이 가까이 모인다. 대각선을
따라 매겨 보기도 하고 가운데서 바깥으로 매겨 보기도 했는데, 행 우선이
가장 좋았다---가운데서 바깥으로 매기면 노드가 두 배 넘게 불어난다.
@<판에 번호를 매긴다@>=
id := make([][]int, bd.rows)
n := 0
for r := range id {
	id[r] = make([]int, bd.cols)
	for c := range id[r] {
		id[r][c] = -1
		if bd.ok(r, c) {
			id[r][c] = n
			n++
		}
	}
}
at := func(r, c int) int {
	if r < 0 || r >= bd.rows || c < 0 || c >= bd.cols {
		return -1
	}
	return id[r][c]
}

@ 한 수는 칸 세 개로 적힌다. 뛰는 말이 있던 칸 $a$, 넘기는 말이 있던
칸 $b$, 그리고 비어 있다가 말을 받는 칸 $e$다. 네 방향으로 훑으면
십자판에서는 일흔여섯 가지가 나온다.
@<둘 수 있는 수를 모은다@>=
var moves [][3]int
for r := 0; r < bd.rows; r++ {
	for c := 0; c < bd.cols; c++ {
		for _, d := range [4][2]int{{0, 1}, {1, 0}, {0, -1}, {-1, 0}} {
			a, b, e := at(r, c), at(r+d[0], c+d[1]), at(r+2*d[0], c+2*d[1])
			if a >= 0 && b >= 0 && e >= 0 {
				moves = append(moves, [3]int{a, b, e})
			}
		}
	}
}
fmt.Printf("%s 판: 칸 %d개, 둘 수 있는 수 %d가지\n", *name, n, len(moves))

@* 두 벌의 변수.
관계를 적으려면 변수가 두 벌 있어야 한다. 지금의 판을 말하는 $x_i$와
한 수 뒤의 판을 말하는 $x'_i$다. 그 둘을 어떻게 늘어놓느냐가 BDD의
크기를 좌우한다.

$x$를 다 늘어놓고 그다음에 $x'$을 늘어놓으면 안 된다. 관계는 대부분의
칸에서 $x_i=x'_i$라고 말하는데, 두 변수가 멀리 떨어져 있으면 그 등식
하나를 기억하는 데 위에서 아래까지 길이 뻗어야 하고, 등식이 $n$개면
너비가 $2^n$이 된다. 짝끼리 붙여 놓으면 등식은 그 자리에서 판정되고
끝난다. 그래서 이름을 $2i$와 $2i+1$로 준다. 이 꾸러미는 처음에 이름이
곧 준위이므로 그것으로 교대 배치가 된다.
@^변수 차례@>
@<변수 두 벌을 잡는다@>=
b := bdd.New()
x := make([]bdd.Func, n)
y := make([]bdd.Func, n)
for i := 0; i < n; i++ {
	x[i], y[i] = b.Var(2*i), b.Var(2*i+1)
}
same := make([]bdd.Func, n)
for i := range same {
	same[i] = b.Not(b.Xor(x[i], y[i]))
}

@* 전이 관계.
수 하나가 말하는 것은 두 가지다. 둘 수 있으려면 $a$와 $b$에 말이 있고
$e$가 비어 있어야 하고, 두고 나면 $a$와 $b$가 비고 $e$에 말이 앉는다.
그런데 그것만 적어서는 안 된다. {\it 나머지 칸은 그대로\/}라는 말을
빠뜨리면, 관계는 손대지 않은 칸을 마음대로 바꿔도 좋다고 말하는 셈이
된다. 인공지능에서 프레임 문제라 부르는 그것인데, 여기서는 등식
$n-3$개를 곱해 두는 것으로 끝난다.
@^프레임 문제@>
@<전이 관계를 엮는다@>=
t0 := time.Now()
t := b.Zero()
for _, m := range moves {
	@<한 수의 관계 |u|를 짓는다@>@;
	t = b.Or(t, u)
}
fmt.Printf("전이 관계: 노드 %d개, %v\n", b.Size(t), time.Since(t0).Round(time.Millisecond))

@ @<한 수의 관계 |u|를 짓는다@>=
u := b.And(b.And3(x[m[0]], x[m[1]], b.Not(x[m[2]])),
	b.And3(b.Not(y[m[0]]), b.Not(y[m[1]]), y[m[2]]))
for i := 0; i < n; i++ {
	if i != m[0] && i != m[1] && i != m[2] {
		u = b.And(u, same[i])
	}
}

@ 일흔여섯 가지를 다 엮어도 노드가 1405개밖에 안 된다. 관계가 이렇게
작다는 것이 이 방법의 밑천이다. 수의 가짓수만큼 경우를 나누는 대신,
그 모두를 한 함수에 담아 놓고 집합에 한 번 적용한다.

@* 상을 구한다.
한정할 변수들은 논리곱 하나로 적어 넘긴다. 이 꾸러미의 한정사는 둘째
인자를 ``양의 리터럴들의 논리곱''으로 받는다. 이름을 되돌리는 일은
사전 하나로 적는다. 두 벌이 붙어 있으니 $x'_i$ 자리에 $x_i$를 넣으면
된다.
@<층층이 훑는다@>=
cube := b.One()
back := map[int]bdd.Func{}
for i := 0; i < n; i++ {
	cube = b.And(cube, x[i])
	back[2*i+1] = x[i]
}

@ 출발 자리는 가운데 한 칸만 비어 있는 판이다. 자리 {\it 하나\/}도
집합이니 함수로 적힌다.
@<층층이 훑는다@>=
f := b.One()
for i := 0; i < n; i++ {
	if i == at(bd.cr, bd.cc) {
		f = b.And(f, b.Not(x[i]))
	} else {
		f = b.And(f, x[i])
	}
}

@ 한 수를 둘 때마다 말이 정확히 하나씩 줄어든다. 그러니 $k$번째 층은
말이 $n-1-k$개인 자리들이고, 층끼리 겹칠 수가 없다. 이미 본 자리를
빼는 일도, 더 볼 것이 있는지 따로 살피는 일도 필요 없다. 층이 비면
끝이고, 층별 개수를 그냥 더하면 그것이 전체다.
@<층층이 훑는다@>=
t0 = time.Now()
total, last := new(big.Int), f
for k := 0; ; k++ {
	c := new(big.Int).Rsh(b.Count(f), uint(n))
	if c.Sign() == 0 {
		break
	}
	total.Add(total, c)
	fmt.Printf("%2d수  말 %2d개  자리 %14s  노드 %8d\n", k, n-1-k, c, b.Size(f))
	last = f
	f = b.Compose(b.AndExists(f, t, cube), back)
}
fmt.Printf("닿을 수 있는 자리 %s가지, %v\n", total, time.Since(t0).Round(time.Millisecond))

@ 세는 대목에 손질이 하나 붙어 있다. 이 꾸러미의 |Count|는 그때까지
만들어진 변수 {\it 전부\/}를 셈에 넣는다. 우리 함수는 $x$에만 기대고
$x'$에는 기대지 않으므로, 기대지 않는 변수 $n$개가 자유로이 0과 1을
오가며 답을 $2^n$배로 부풀린다. 그래서 $n$비트 오른쪽으로 밀어 준다.

@* 끝자리.
십자판에서 마지막 층에 남는 자리는 다섯 가지다. 가운데 하나와, 십자의
네 끝. 가운데 비우고 시작해 가운데 하나로 끝내는 그 고전적인 마무리가
저기 들어 있고, 그것 말고는 십자의 팔 끝에서만 끝날 수 있다는 것도
함께 나온다.
@<끝자리를 그린다@>=
end := last
for i := 0; i < n; i++ {
	end = b.And(end, b.Not(y[i]))
}

@ 프라임 변수를 0으로 못박고 나서 늘어놓는 까닭도 |Count|의 사정과
같다. 훑개 |All|은 살아 있는 변수를 모두 지나가므로, 못박아 두지
않으면 자리 하나마다 $2^n$가지를 늘어놓는다.
@<끝자리를 그린다@>=
seen := 0
for sol := range b.All(end) {
	if seen++; seen > *show {
		break
	}
	@<자리 하나를 그린다@>@;
}

@ 배정은 변수 이름으로 첨자를 매긴 배열이니, 칸 $(r,c)$의 말을 보려면
그 칸 번호의 두 배를 보면 된다.
@<자리 하나를 그린다@>=
for r := 0; r < bd.rows; r++ {
	for c := 0; c < bd.cols; c++ {
		switch {
		case at(r, c) < 0:
			fmt.Print("  ")
		case sol[2*at(r, c)]:
			fmt.Print(" o")
		default:
			fmt.Print(" .")
		}
	}
	fmt.Println()
}
fmt.Println()

@* 색인.
