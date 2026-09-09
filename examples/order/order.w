\input kotexgweb
\input luamplib.sty

\def\title{변수 차례}

@s Func int
@s BDD int

@* 들어가며.
BDD의 크기는 함수의 성질이 아니다. {\it 함수와 변수 차례, 그 둘의\/}
성질이다. 같은 불 함수를 놓고도 변수를 어떤 차례로 물어보느냐에 따라
노드가 스무 개일 수도 있고 백만 개일 수도 있다. Bryant는 1986년 논문에서
이미 이것을 지적했고, 그 뒤로 좋은 차례를 찾는 일이 BDD를 쓰는 사람의
가장 큰 숙제가 되었다. 주어진 함수의 최적 차례를 찾는 문제는 NP-난해라는
것도 밝혀져 있다.
@^Bryant, Randal Everitt@>
@^변수 차례@>
@^Bollig, Beate@>
@^Wegener, Ingo@>

@ 그렇다고 아무 함수나 다 그런 것은 아니다. 이 프로그램은 세 가지 얼굴을
나란히 놓고 재어 본다.

\medskip
\item{$\bullet$} {\bf 차례가 전부인 함수.} 쌍의 논리합
$x_1x_2\lor\cdots\lor x_{2m-1}x_{2m}$은 짝을 붙여 놓으면 노드가 $2m+2$개,
갈라 놓으면 $2^{m+1}$개다. 스무 개와 이천 개의 차이가 차례 하나에서 온다.

\item{$\bullet$} {\bf 차례가 상관없는 함수.} 대칭 함수는 어떤 차례로
물어보아도 BDD가 똑같다. 재정렬이 할 일이 없다.

\item{$\bullet$} {\bf 어떤 차례로도 안 되는 함수.} 숨은 가중 비트
$h_n$은 모든 차례에 대해 노드가 $n$의 지수로 자란다. 체질이 크게
줄여 주기는 하지만 지수는 지수로 남는다.
\medskip

\noindent 옆모습을 보면 첫째 얼굴이 한눈에 들어온다. $m=6$일 때 준위마다
노드가 몇 개인지 그린 것이다.

$$\mplibcode
beginfig(1);
numeric wu, hu; wu := 1.5mm; hu := 3.4mm;
numeric a[];
a1 := 1; a2 := 2; a3 := 4; a4 := 8; a5 := 16; a6 := 32;
a7 := 32; a8 := 16; a9 := 8; a10 := 4; a11 := 2; a12 := 1;
path box; box := (-.5,0)--(.5,0)--(.5,-1)--(-.5,-1)--cycle;
for i=1 upto 12:
  fill box xscaled wu yscaled hu shifted (0, -(i-1)*hu) withcolor .68white;
  fill box xscaled (a[i]*wu) yscaled hu shifted (58mm, -(i-1)*hu)
    withcolor .68white;
endfor
label.bot(btex 좋은 차례: 노드 14개 etex, (0, -12hu-1.5mm));
label.bot(btex 나쁜 차례: 노드 128개 etex, (58mm, -12hu-1.5mm));
endfig;
\endmplibcode$$

@ 재는 일은 늘 같은 모양이다. 함수를 짓고, 크기를 재고, 차례를 흐트러
뜨리고, 다시 재고, 체질하고, 또 재어 본다. 부르는 법은 이렇다.
$$\vbox{\halign{\.{#}\hfil\cr
go run .\cr
go run . -m 14\cr
go run . -n 40\cr}}$$
숨은 가중 비트는 $n=40$에서 체질에 15초쯤 걸린다. 기본값인 35까지는
전부 합쳐 2초 남짓이다.
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
	@<쌍의 논리합을 재어 본다@>@;
	@<대칭 함수를 재어 본다@>@;
	@<숨은 가중 비트를 재어 본다@>@;
}

@ @<명령줄을 읽는다@>=
maxm := flag.Int("m", 10, "쌍의 논리합을 이 크기까지")
maxn := flag.Int("n", 35, "숨은 가중 비트를 이 크기까지")
flag.Parse()

@* 체질을 멈출 때.
체질 한 바퀴로는 모자란다. 변수 하나를 옮기면 다른 변수들의 형편이
달라지므로, 아까 제자리를 찾았던 변수가 이제는 딴 데 있어야 좋을 수
있다. 그래서 크기가 더는 줄지 않을 때까지 돌린다. 마지막 한 바퀴는
아무것도 바꾸지 못하는데, 그것이 멈출 때가 되었다는 신호다.
@<함수들@>=
func settle(b *bdd.BDD, f bdd.Func) (int, int) {
	size, rounds := b.Size(f), 0
	for {
		b.SiftAll()
		rounds++
		if n := b.Size(f); n != size {
			size = n
		} else {
			return n, rounds
		}
	}
}

@* 쌍의 논리합.
$$f_m=x_1x_2\lor x_3x_4\lor\cdots\lor x_{2m-1}x_{2m}$$
짝을 붙여 물어보면 기억할 것이 한 비트뿐이다. ``지금까지 본 쌍 가운데
둘 다 1인 것이 있었나.'' 있었으면 답은 이미 1이고, 없었으면 남은 쌍만
보면 된다. 그래서 준위마다 노드가 하나씩, 모두 $2m+2$개다.

갈라 놓으면 사정이 달라진다. $x_1,x_3,\ldots,x_{2m-1}$을 먼저 다 물어본
뒤에야 $x_2,x_4,\ldots$를 묻는다면, 아래쪽에 내려갈 때 앞의 $m$개를
{\it 통째로\/} 기억하고 있어야 한다. 어느 것이 1이었는지에 따라 남은
질문이 다 다르기 때문이다. 그래서 너비가 $2^m$까지 부풀어 오른다.
@^쌍의 논리합@>
@<쌍의 논리합을 재어 본다@>=
fmt.Println("== 쌍의 논리합 ==")
for m := 4; m <= *maxm; m += 2 {
	b := bdd.New()
	x := make([]bdd.Func, 2*m)
	for i := range x {
		x[i] = b.Var(i)
	}
	f := b.Zero()
	for i := 0; i < m; i++ {
		f = b.Or(f, b.And(x[2*i], x[2*i+1]))
	}
	@<차례를 갈라 놓았다가 체질로 되찾는다@>@;
}

@ 갈라 놓는 데는 |Reorder|를 쓴다. 짝수 이름을 모두 위로 올리고 홀수
이름을 그 아래에 둔다. 그러고 나서 체질에 맡긴다.
@<차례를 갈라 놓았다가 체질로 되찾는다@>=
good := b.Size(f)
bad := make([]int, 0, 2*m)
for i := 0; i < m; i++ {
	bad = append(bad, 2*i)
}
for i := 0; i < m; i++ {
	bad = append(bad, 2*i+1)
}
b.Reorder(bad)
split, prof := b.Size(f), b.Profile(f)
sifted, rounds := settle(b, f)
fmt.Printf("m=%2d  짝지어 %4d (2m+2=%d)  갈라서 %6d (2^(m+1)=%d)"+
	"  체질 뒤 %4d (%d바퀴)\n",
	m, good, 2*m+2, split, 1<<(m+1), sifted, rounds)

@ 갈라 놓은 차례의 옆모습을 함께 찍는다. $1,2,4,\ldots,2^{m-1},2^{m-1},
\ldots,4,2,1$이라는 마름모가 그대로 나온다. 앞에 그린 그림이 바로
이 숫자들이다.
@<차례를 갈라 놓았다가 체질로 되찾는다@>=
fmt.Printf("      갈라서 옆모습 %v\n", prof)
fmt.Printf("      체질 뒤 차례 %v\n", b.Order())

@ 체질이 되찾아 온 차례를 보면 재미있다. 원래의 $0,1,2,\ldots$로
돌아가지는 않는다. 그럴 까닭이 없다---이 함수에서 중요한 것은 짝이
{\it 서로 붙어 있다\/}는 것뿐이고, 쌍끼리의 차례나 쌍 안에서의 앞뒤는
아무래도 좋기 때문이다. 그래서 \.{[6 7 4 5 0 1 2 3]} 같은 것이 나온다.
크기는 어김없이 $2m+2$다.

@* 대칭 함수.
대칭 함수는 변수를 아무렇게나 뒤섞어도 그대로인 함수다. 그러면 BDD도
그대로일 수밖에 없다. 차례를 $\pi$로 바꾼 뒤의 BDD는 원래 BDD와
{\it 동형\/}이므로 노드 수가 같다. 재정렬로 얻을 것이 하나도 없는
함수가 있다는 뜻이고, 체질을 돌려 보면 정말로 한 개도 줄지 않는다.
@^대칭 함수@>
@<대칭 함수를 재어 본다@>=
fmt.Println("== 대칭 함수: 정확히 n/2개가 1 ==")
rnd := rand.New(rand.NewPCG(20260907, 7))
for n := 12; n <= 24; n += 4 {
	b := bdd.New()
	x := make([]bdd.Func, n)
	for i := range x {
		x[i] = b.Var(i)
	}
	f := exactly(b, x)[n/2]
	plain := b.Size(f)
	@<차례를 마구 섞는다@>@;
	shuf := b.Size(f)
	sifted, rounds := settle(b, f)
	fmt.Printf("n=%2d  차례대로 %5d  마구 섞어 %5d  체질 뒤 %5d (%d바퀴)\n",
		n, plain, shuf, sifted, rounds)
}

@ @<차례를 마구 섞는다@>=
p := make([]int, n)
for i := range p {
	p[i] = i
}
rnd.Shuffle(n, func(i, j int) { p[i], p[j] = p[j], p[i] })
b.Reorder(p)

@ ``정확히 $j$개가 1''을 짓는 일은 파스칼 삼각형을 한 줄씩 미는 것과
같다. 변수를 하나 더 볼 때마다, 그것이 0이면 세던 수가 그대로이고
1이면 하나 늘어난다. 큰 $j$부터 갱신해야 방금 고친 값을 다시 쓰지
않는다. 이 표는 대칭 함수와 숨은 가중 비트 양쪽에서 쓴다.
@<함수들@>=
func exactly(b *bdd.BDD, x []bdd.Func) []bdd.Func {
	n := len(x)
	row := make([]bdd.Func, n+1)
	row[0] = b.One()
	for j := 1; j <= n; j++ {
		row[j] = b.Zero()
	}
	for i := 0; i < n; i++ {
		for j := i + 1; j >= 1; j-- {
			row[j] = b.Or(b.And(b.Not(x[i]), row[j]), b.And(x[i], row[j-1]))
		}
		row[0] = b.And(b.Not(x[i]), row[0])
	}
	return row
}

@* 숨은 가중 비트.
$\nu(x)$를 $x$에 든 1의 개수라 할 때
$$h_n(x)=\cases{x_{\nu(x)},&$\nu(x)>0$\cr 0,&$\nu(x)=0$\cr}$$
로 정의되는 함수다. 몇 번째 비트를 볼지를 비트들 자신이 정하는 셈이라
{\it 숨은 가중 비트\/}라는 이름이 붙었다. Bryant는 1991년에 이 함수의
BDD가 어떤 변수 차례에 대해서도 $\Omega(2^{n/5})$개의 노드를 가진다는
것을 증명했다. 좋은 차례를 아무리 찾아도 소용없는 함수가 실제로
있다는 첫 예다.
@^숨은 가중 비트@>
@^Bryant, Randal Everitt@>
@<숨은 가중 비트를 재어 본다@>=
fmt.Println("== 숨은 가중 비트 ==")
for n := 10; n <= *maxn; n += 5 {
	b := bdd.New()
	x := make([]bdd.Func, n)
	for i := range x {
		x[i] = b.Var(i)
	}
	@<|h|를 짓는다@>@;
	plain := b.Size(h)
	sifted, rounds := settle(b, h)
	fmt.Printf("n=%2d  차례대로 %7d  체질 뒤 %6d (%d바퀴)\n",
		n, plain, sifted, rounds)
}

@ 정의를 그대로 옮기면 된다. 1이 $k$개인 경우와 $x_k$가 1인 경우를
곱하고, $k$에 대해 모두 더한다. 첨자가 1부터 시작하므로 배열에서는
하나를 뺀다.
@<|h|를 짓는다@>=
ex := exactly(b, x)
h := b.Zero()
for k := 1; k <= n; k++ {
	h = b.Or(h, b.And(ex[k], x[k-1]))
}

@ 재어 보면 체질의 값어치와 한계가 한눈에 보인다. $n=40$에서 노드가
82만 개인데 체질이 2만 8천 개로 줄인다---스물아홉 배다. 그런데 줄어든
쪽의 수열을 늘어놓아 보면
$$109,\ 282,\ 796,\ 2090,\ 5230,\ 12381,\ 27978$$
로 $n$이 5 늘 때마다 두 배 반씩 커진다. 여전히 지수다. 체질은 상수를
깎을 뿐 지수를 깎지 못한다. Bryant의 하계가 말하는 그대로다.

@ 한 가지 일러둘 것이 있다. 노드 수는 돌릴 때마다 같은데 {\it 바퀴
수는\/} 한둘씩 오락가락한다. 손잡이가 풀리는 시점을 \GO/의 쓰레기 수거가
정하기 때문이다. 체질에 들어가기 전에 죽은 노드를 걷어내는데, 그때
마침 정리 훅이 돌았느냐에 따라 걷어낼 것이 조금씩 달라지고, 그러면
체질이 보는 표도 달라진다. 어느 쪽으로 가든 이르는 곳은 같다.

@* 색인.
