\input kotexgweb
\input luamplib.sty

\def\title{회로 등가성 검사}

@s Func int
@s BDD int

@* 들어가며.
회로를 두 벌 만들었다고 하자. 하나는 읽기 쉽게 짠 것이고 하나는 빠르게
고쳐 짠 것이다. 둘이 정말로 같은 함수를 계산하는가? 이 물음에 답하는
일을 {\it 등가성 검사\/}라 하고, 반도체를 만드는 사람들이 BDD를 쓰는
첫째 이유가 바로 이것이다.

곧이곧대로 하자면 입력을 다 넣어 보면 된다. 입력이 예순네 개인 회로라면
경우가 $2^{64}$가지다. 1초에 10억 가지씩 넣어 보아도 오백 년이 걸린다.
@^등가성 검사@>

@ BDD는 이 물음을 우스울 만큼 싸게 만든다. 변수 차례를 정해 놓으면
불 함수 하나에 다이어그램이 {\it 딱 하나\/} 대응하기 때문이다. 두 회로의
BDD를 짓고 나면 ``같은가''는 ``뿌리가 같은 노드인가''가 된다. 이 꾸러미의
|Equal|이 하는 일도 그것뿐이다---노드 첨자 둘을 견준다. 회로가 아무리
커도 이 마지막 걸음은 한 걸음이다.

값은 BDD를 짓는 데 다 치른다. 그러니 물음은 하나로 좁혀진다. {\it 이
회로의 BDD가 감당할 만한 크기인가.\/} 가산기는 그렇고 곱셈기는 그렇지
않다. 이 프로그램은 그 둘을 나란히 보여 준다.

@ 자리올림을 어떻게 나르느냐로 가산기가 갈린다. 물결 자리올림은 한 칸씩
손에서 손으로 넘기고, Kogge와 Stone이 1973년에 내놓은 접두 가산기는
거리를 두 배씩 늘려 가며 건너뛴다. 깊이가 $n$과 $\lceil\lg n\rceil$로
다르니 회로로서는 아주 다른 물건인데, 계산하는 함수는 똑같다.
@^Kogge, Peter Michael@>
@^Stone, Harold Stuart@>

$$\mplibcode
beginfig(1);
numeric u, v, r, y, d; u := 7.6mm; v := 5.4mm; r := 1.9mm;
for j=0 upto 7:
  fill fullcircle scaled r shifted (j*u, 0) withcolor .42white;
endfor
for j=0 upto 6:
  drawarrow (j*u+.62r, 0) -- ((j+1)*u-.62r, 0);
endfor
label.rt(btex 물결 자리올림 etex, (7u+5mm, 0));
y := -13mm;
for j=0 upto 7:
  fill fullcircle scaled r shifted (j*u, y) withcolor .42white;
endfor
d := 1;
for k=1 upto 3:
  for j=0 upto 7:
    fill fullcircle scaled r shifted (j*u, y-k*v) withcolor .42white;
    draw (j*u, y-(k-1)*v-.62r) -- (j*u, y-k*v+.62r) withcolor .5white;
    if j>=d:
      draw ((j-d)*u+.5r, y-(k-1)*v-.5r) -- (j*u-.5r, y-k*v+.5r);
    fi
  endfor
  d := 2d;
endfor
label.rt(btex Kogge--Stone 접두 etex, (7u+5mm, y-1.5v));
endfig;
\endmplibcode$$

@ 부르는 법은 이렇다.
$$\vbox{\halign{\.{#}\hfil\cr
go run .\cr
go run . -mul 14\cr
go run . -bits 12\cr}}$$
곱셈기는 기본값인 12까지 1초 남짓이고, 14로 올리면 20초, 16이면 3분이
걸린다. 노드가 왜 그렇게 되는지는 마지막 절에서 이야기한다.
@c
package main

import (
	"flag"
	"fmt"
	"math/rand/v2"

	"github.com/sjnam/bdd"
)

@<함수들@>

func main() {
	@<명령줄을 읽는다@>@;
	@<두 가산기를 맞대어 본다@>@;
	@<틀린 회로를 잡아낸다@>@;
	@<곱셈기를 재어 본다@>@;
}

@ @<명령줄을 읽는다@>=
bits := flag.Int("bits", 8, "반례를 찾을 가산기의 폭")
mul := flag.Int("mul", 12, "곱셈기를 이 크기까지")
flag.Parse()

@* 입력과 변수 차례.
피연산자 두 개의 비트를 어떤 차례로 물어보느냐가 크기를 좌우한다. $a$를
다 물어본 뒤에 $b$를 물어보면 안 된다. 자리올림을 알려면 두 피연산자의
같은 자리를 견주어야 하는데, 멀리 떨어뜨려 놓으면 앞의 $n$비트를 통째로
기억한 채 내려가야 하기 때문이다. 짝지어 놓고, 자리올림이 흐르는 반대
방향인 {\it 최상위부터\/} 물어보면 기억할 것이 자리올림 한 비트로 줄어든다.

배열은 최하위 비트를 0번으로 두는 편이 셈하기에 낫다. 그래서 이름을
줄 때 뒤집는다.
@^변수 차례@>
@<함수들@>=
func inputs(b *bdd.BDD, n int) (x, y []bdd.Func) {
	x, y = make([]bdd.Func, n), make([]bdd.Func, n)
	for j := 0; j < n; j++ {
		x[j] = b.Var(2 * (n - 1 - j))
		y[j] = b.Var(2*(n-1-j) + 1)
	}
	return
}

@* 가산기 둘.
물결 자리올림은 정의 그대로다. 자리마다 합은 세 비트의 배타적 논리합이고,
다음 자리올림은 세 비트의 {\it 다수결\/}이다. 다수결은 이 꾸러미에
$\langle fgh\rangle$로 이미 들어 있으므로 |Median| 한 번이면 된다.
@<함수들@>=
func ripple(b *bdd.BDD, x, y []bdd.Func) []bdd.Func {
	n := len(x)
	s := make([]bdd.Func, n+1)
	c := b.Zero()
	for j := 0; j < n; j++ {
		s[j] = b.Xor(b.Xor(x[j], y[j]), c)
		c = b.Median(x[j], y[j], c)
	}
	s[n] = c
	return s
}

@ 접두 가산기는 생각이 한 겹 더 있다. 자리 $j$에서 자리올림이
{\it 생기는\/} 조건 $g_j=a_jb_j$와 아래에서 온 자리올림을 그대로
{\it 넘기는\/} 조건 $p_j=a_j\oplus b_j$를 두면, 두 구간을 이어 붙이는
일이 결합법칙을 만족하는 연산 하나가 된다.
$$(G,P)\circ(G',P')=(G\lor PG',\ PP')$$
결합법칙이 성립하니 접두곱을 나무 모양으로 계산할 수 있고, 그것이
Kogge--Stone이다. 거리를 $1,2,4,\ldots$로 늘려 가며 $\lceil\lg n\rceil$
바퀴만 돌면 모든 자리의 접두곱이 한꺼번에 구해진다.
@^접두곱@>
@<함수들@>=
func kogge(b *bdd.BDD, x, y []bdd.Func, bug bool) []bdd.Func {
	n := len(x)
	g, p, q := make([]bdd.Func, n), make([]bdd.Func, n), make([]bdd.Func, n)
	for j := 0; j < n; j++ {
		g[j] = b.And(x[j], y[j])
		p[j] = b.Xor(x[j], y[j])
		q[j] = p[j]
		if bug {
			q[j] = b.Or(x[j], y[j])
		}
	}
	@<접두곱을 거리 두 배씩 늘려 가며 구한다@>@;
	@<접두곱에서 합 비트를 뽑는다@>@;
}

@ 한 바퀴에서 $j$번 자리는 자기 자신과 $d$칸 아래의 접두곱을 잇는다.
그 바퀴의 결과를 같은 배열에 덮어쓰면 안 되므로 새 배열에 담는다.
@<접두곱을 거리 두 배씩 늘려 가며 구한다@>=
for d := 1; d < n; d *= 2 {
	ng, np := make([]bdd.Func, n), make([]bdd.Func, n)
	copy(ng, g)
	copy(np, p)
	for j := d; j < n; j++ {
		ng[j] = b.Or(g[j], b.And(p[j], g[j-d]))
		np[j] = b.And(p[j], p[j-d])
	}
	g, p = ng, np
}

@ 다 돌고 나면 $g_j$가 자리 $j$까지의 자리올림, 곧 자리 $j+1$로 들어가는
자리올림이다. 합은 전달 신호와 아래 자리올림의 배타적 논리합이다.
@<접두곱에서 합 비트를 뽑는다@>=
s := make([]bdd.Func, n+1)
c := b.Zero()
for j := 0; j < n; j++ {
	s[j] = b.Xor(q[j], c)
	c = g[j]
}
s[n] = c
return s

@ 맞대어 보는 일은 |Equal| 한 줄이다. 어긋나는 첫 비트를 돌려주고,
다 같으면 $-1$을 돌려준다.
@<함수들@>=
func firstDiff(u, v []bdd.Func) int {
	for j := range u {
		if !u[j].Equal(v[j]) {
			return j
		}
	}
	return -1
}

@ 재어 보면 가산기의 BDD가 작다는 것이 눈에 들어온다. 자리올림 비트는
노드 $3n+1$개, 가장 큰 합 비트는 $6n-3$개로 둘 다 $n$에 정비례한다.
그래서 64비트 가산기 둘이 같음을 증명하는 데 10밀리초도 안 걸린다.
$2^{64}$가지를 넣어 보는 대신에 말이다.
@<두 가산기를 맞대어 본다@>=
fmt.Println("== 가산기 둘은 같은가 ==")
for _, n := range []int{8, 16, 32, 64} {
	b := bdd.New()
	x, y := inputs(b, n)
	u, v := ripple(b, x, y), kogge(b, x, y, false)
	big := 0
	for _, f := range u {
		big = max(big, b.Size(f))
	}
	fmt.Printf("n=%2d  같은가 %5v  자리올림 %4d개(3n+1=%d)  가장 큰 합 비트 %4d개(6n-3=%d)\n",
		n, firstDiff(u, v) < 0, b.Size(u[n]), 3*n+1, big, 6*n-3)
}

@* 틀린 회로를 잡아낸다.
회로를 한 글자 틀리게 짜 보자. 합을 구할 때 쓰는 전달 신호로
$a_j\oplus b_j$ 대신 $a_j\lor b_j$를 쓰는 것이다. 얼핏 그럴듯하다.
자리올림을 나르는 데는 $\lor$를 써도 아무 탈이 없기 때문이다---$g_j$가
참이면 어차피 자리올림이 나므로 $p_j$가 어느 쪽이든 결과가 같다. 그러나
{\it 합\/}에서는 다르다. 두 비트가 모두 1인 자리에서 답이 뒤집힌다.

이런 버그가 무서운 것은 대부분의 입력에서 멀쩡히 돌기 때문이다. 그래서
1994년 펜티엄의 나눗셈 사건 뒤로 이 분야에서는 ``넣어 보는 것''이 아니라
``증명하는 것''이 표준이 되었다.
@^펜티엄 FDIV@>
@<틀린 회로를 잡아낸다@>=
fmt.Println("== 한 글자 틀린 회로 ==")
n := *bits
b := bdd.New()
x, y := inputs(b, n)
u, v := ripple(b, x, y), kogge(b, x, y, true)
if j := firstDiff(u, v); j < 0 {
	fmt.Println("어긋나는 데가 없다")
} else {
	@<반례를 하나 뽑는다@>@;
}

@ ``같지 않다''는 답을 듣고 나면 다음 질문은 언제나 ``어디가''다. 두
비트의 배타적 논리합이 곧 어긋나는 입력들의 집합이니, 거기서 하나를
무작위로 뽑으면 반례가 된다. |Random|이 그 일을 한다.
@<반례를 하나 뽑는다@>=
d := b.Xor(u[j], v[j])
fmt.Printf("%d번 비트가 어긋난다. 어긋나는 입력이 %v가지\n", j, b.Count(d))
if w, ok := b.Random(d, rand.New(rand.NewPCG(20260907, 2))); ok {
	@<반례를 읽어서 찍는다@>@;
}

@ 배정은 변수 이름으로 첨자를 매긴 배열이다. 이름을 줄 때 뒤집었으니
읽을 때도 뒤집는다. 틀린 회로가 실제로 무엇을 내놓는지는 |Eval|로
비트마다 물어본다.
@<반례를 읽어서 찍는다@>=
av, bv, got := 0, 0, 0
for k := 0; k < n; k++ {
	if w[2*(n-1-k)] {
		av |= 1 << k
	}
	if w[2*(n-1-k)+1] {
		bv |= 1 << k
	}
}
for k := 0; k <= n; k++ {
	if b.Eval(v[k], w) {
		got |= 1 << k
	}
}
fmt.Printf("반례: %d + %d 은 %d인데 틀린 회로는 %d를 내놓는다\n", av, bv, av+bv, got)

@* 곱셈기.
가산기가 이렇게 순한데 곱셈기도 그러리라 기대하면 어긋난다. Bryant는
1991년에 $n$비트 곱셈기의 {\it 가운데\/} 출력 비트가 어떤 변수 차례에
대해서도 $\Omega(2^{n/8})$개의 노드를 필요로 한다는 것을 증명했다. 이것은
좋은 차례를 못 찾아서 생기는 일이 아니라 함수 자체의 성질이다.
@^Bryant, Randal Everitt@>
@^곱셈기@>
@<곱셈기를 재어 본다@>=
fmt.Println("== 곱셈기의 가운데 비트 ==")
for n := 4; n <= *mul; n += 2 {
	b := bdd.New()
	x, y := inputs(b, n)
	@<자리별로 더해 곱을 짓는다@>@;
	fmt.Printf("n=%2d  가운데 비트 %9d개  맨 위 비트 %7d개\n",
		n, b.Size(acc[n-1]), b.Size(acc[2*n-2]))
}

@ 곱셈기는 초등학교에서 배운 그대로 짓는다. $b_j$가 1인 자리마다
$a$를 $j$칸 밀어 더한다. 더하는 일은 앞의 물결 자리올림과 같은 셈인데,
자리마다 결과를 제자리에 쌓아 나가므로 배열 하나로 족하다.
@<자리별로 더해 곱을 짓는다@>=
acc := make([]bdd.Func, 2*n)
for k := range acc {
	acc[k] = b.Zero()
}
for j := 0; j < n; j++ {
	c := b.Zero()
	for i := 0; i < n; i++ {
		pp := b.And(x[i], y[j])
		s := b.Xor(b.Xor(acc[i+j], pp), c)
		c = b.Median(acc[i+j], pp, c)
		acc[i+j] = s
	}
	@<남은 자리올림을 위로 흘려보낸다@>@;
}

@ @<남은 자리올림을 위로 흘려보낸다@>=
for k := n + j; k < 2*n; k++ {
	s := b.Xor(acc[k], c)
	c = b.And(acc[k], c)
	acc[k] = s
}

@ 재어 보면 이렇게 나온다.
$$\vbox{\halign{\hfil$n=#$\quad&\hfil#\hfil\quad&\hfil#\hfil\cr
\omit\hfil$n$\hfil&가운데 비트&맨 위 비트\cr
\noalign{\smallskip\hrule\smallskip}
4&71&35\cr
6&571&130\cr
8&5{,}271&383\cr
10&48{,}679&1{,}220\cr
12&447{,}683&3{,}663\cr
14&4{,}125{,}443&10{,}983\cr
16&38{,}174{,}143&32{,}963\cr}}$$
$n$이 둘 늘 때마다 가운데 비트가 아홉 배가 된다. 16비트에서 이미 노드가
3800만 개이고, 32비트 곱셈기라면 우주의 원자 수를 넘긴다. 맨 위 비트는
훨씬 순한데, 그것도 지수이기는 마찬가지다.

이것이 BDD의 천장이다. 정직하게 적어 둘 일이다. 실무에서 곱셈기를
검사할 때 BDD를 쓰지 않고 다른 연장을 꺼내는 까닭이 여기 있다.

@* 색인.
