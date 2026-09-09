\input kotexgweb

\def\title{곱의 합 인수분해}

@s Func int
@s ZDD int

@* 들어가며.
불 함수를 적는 가장 흔한 꼴은 {\it 곱의 합\/}이다. 리터럴을 곱해 항을
만들고 항을 더한다. 예를 들어
$$f=ae+af+ag+bce+bcf+bcg+bd$$
는 항이 일곱이고 리터럴이 열일곱이다. 그런데 같은 함수를
$$f=(a+bc)(e+f+g)+bd$$
로 적으면 리터럴이 여덟이다. 회로로 만들면 트랜지스터 수가 리터럴 수에
거의 비례하므로, 이 다시 적기가 곧 돈이다. 이 일을 {\it 인수분해\/}라
한다.
@^인수분해@>

@ 인수분해기가 하루 종일 하는 일은 큐브의 {\it 집합\/}을 주무르는
것이다. 더하고, 빼고, 나누고, 곱한다. 그래서 미나토는 1993년에 그
집합을 담을 자료 구조로 ZDD를 내놓았고, 이듬해에 그 위에서 바로 도는
인수분해 알고리즘을 내놓았다. 이 프로그램은 그 둘째 논문을 옮긴 것이다.
@^Minato, Shin-ichi@>

여기서 쓰는 연산이 몫 $f/g$와 나머지 $f\bmod g$다. 앞의 예제들이 한
번도 부르지 않은 것들인데, 그럴 만도 하다---이 둘은 애초에 이 일을
하라고 만들어진 연산이기 때문이다.

@ 부르는 법은 이렇다.
$$\vbox{\halign{\.{#}\hfil\cr
go run .\cr
go run . -e ab+ac+ad+bc+bd+cd\cr
go run . -k 11\cr}}$$
모두 눈 깜짝할 사이에 끝난다.
@c
package main

import (
	"flag"
	"fmt"
	"sort"
	"strings"

	"github.com/sjnam/bdd"
)

@<자료 구조@>

@<함수들@>

func main() {
	@<명령줄을 읽는다@>@;
	@<우주를 넓혀 가며 재어 본다@>@;
	@<보기들을 인수분해한다@>@;
	@<펼쳤다 도로 접는다@>@;
}

@ @<명령줄을 읽는다@>=
e := flag.String("e", "", "인수분해할 곱의 합 (비우면 보기들을 쓴다)")
k := flag.Int("k", 8, "이 크기로 펼쳤다 도로 접어 본다")
flag.Parse()

@* 왜 ZDD인가.
큐브의 집합이 왜 하필 ZDD인지부터 보고 가자. 변수가 여럿인 회로에서
큐브 하나에 드는 리터럴은 대개 몇 개뿐이다. 나머지 리터럴은 그 큐브에
{\it 없다\/}. 이런 성긴 족을 담을 때 두 자료 구조의 처지가 갈린다.

BDD는 특성 함수를 담는다. ``이 배정이 족에 드는가''를 묻는 함수이므로,
큐브에 나오지 않는 리터럴마다 ``그것은 0이어야 한다''고 못박는 마디가
하나씩 필요하다. ZDD의 축약 규칙은 바로 그 마디를 없앤다. 그래서 족이
그대로여도 우주를 넓히면 BDD만 자라고 ZDD는 꿈쩍하지 않는다.
@^성긴 족@>
@<우주를 넓혀 가며 재어 본다@>=
fmt.Println("== 같은 족을 두 자료 구조에 담으면 ==")
for _, u := range []int{34, 68, 136, 272, 544} {
	z := bdd.NewZDD(u)
	f := parse(z, spread(5))
	@<같은 족을 BDD로도 담아 |g|를 얻는다@>@;
	fmt.Printf("리터럴 자리 %3d개, 큐브 %d개:  ZDD %3d마디,  BDD %4d마디\n",
		u, cubes(z, f), z.Size(f), b.Size(g))
}

@ BDD 쪽은 정의를 그대로 옮긴다. 큐브 하나가 배정 하나이므로, 그
큐브에 드는 리터럴은 1이고 나머지는 모두 0이라고 적은 다음, 큐브들을
논리합으로 잇는다.
@<같은 족을 BDD로도 담아 |g|를 얻는다@>=
b := bdd.New()
x := make([]bdd.Func, u)
for i := range x {
	x[i] = b.Var(i)
}
g := b.Zero()
for c := range z.Subsets(f) {
	in := make([]bool, u)
	for _, v := range c {
		in[v] = true
	}
	t := b.One()
	for i := 0; i < u; i++ {
		if in[i] {
			t = b.And(t, x[i])
		} else {
			t = b.And(t, b.Not(x[i]))
		}
	}
	g = b.Or(g, t)
}

@ 재어 보면 이렇게 나온다.
$$\vbox{\halign{\hfil#\quad&\hfil#\quad&\hfil#\quad&\hfil#\quad&\hfil#\quad&\hfil#\cr
리터럴 자리&34&68&136&272&544\cr
\noalign{\smallskip\hrule\smallskip}
ZDD&12&12&12&12&12\cr
BDD&52&86&154&290&562\cr}}$$
BDD는 우주 크기에 정확히 정비례해 자라고 ZDD는 열두 마디에 머문다.
큐브 스물다섯 개짜리 족 하나에서 이 정도니, 실제 인수분해기가 다루는
수만 개짜리 족에서는 견줄 것이 못 된다.

@* 리터럴과 큐브.
변수 하나에 리터럴이 둘 있으므로 원소를 둘씩 준다. 변수 $i$의 긍정
리터럴은 $2i$, 부정 리터럴은 $2i+1$이다. 짝을 붙여 두면 같은 변수의
두 리터럴이 ZDD에서 이웃하게 되어, 한 큐브에 둘 다 들 수 없다는
사정이 위아래로 멀리 퍼지지 않는다.

식은 소문자 한 글자를 변수로 삼아 적는다. 따옴표가 붙으면 부정이고,
붙여 쓰면 곱, \.{+}로 이으면 합이다.
@^리터럴@>
@<함수들@>=
func parse(z *bdd.ZDD, s string) bdd.Func {
	f := z.Empty()
	for _, term := range strings.Split(s, "+") {
		c := z.Unit()
		rs := []rune(term)
		for i := 0; i < len(rs); i++ {
			if rs[i] < 'a' || rs[i] > 'z' {
				continue
			}
			v := 2 * int(rs[i]-'a')
			if i+1 < len(rs) && rs[i+1] == '\'' {
				v, i = v+1, i+1
			}
			c = z.Join(c, z.Elt(v))
		}
		f = z.Union(f, c)
	}
	return f
}

@ 항의 수와 리터럴의 수는 자주 물어본다. 항의 수는 족의 크기이고,
리터럴의 수는 큐브들의 크기를 다 더한 것이다. 이 프로그램이 다루는
식은 항이 int에 넉넉히 들어간다.
@<함수들@>=
func cubes(z *bdd.ZDD, f bdd.Func) int {
	return int(z.Count(f).Int64())
}

func rawLits(z *bdd.ZDD, f bdd.Func) int {
	n := 0
	for c := range z.Subsets(f) {
		n += len(c)
	}
	return n
}

@* 인수분해한 식.
인수분해의 결과는 족이 아니라 {\it 나무\/}다. 잎은 리터럴이고 가지는
합이거나 곱이다. 여기에 상수 둘이 더 필요하다. 빈 족 0과, 빈 큐브
하나만 든 단위 족 1이다. 1을 적을 자리를 마련해 두지 않으면
$(1+a)(b+c)(d+e)$ 같은 답을 적을 수 없다---실제로 처음에 그것을
빠뜨렸다가 되펼침 검사에 걸렸다.
@<자료 구조@>=
type form struct {
	lit  int // 0 이상이면 리터럴, $-1$이면 가지, $-2$면 상수 1
	prod bool
	kids []*form
}

@ 나무를 지을 때 잔가지를 정리해 둔다. 합에서는 0인 가지를 버리고,
곱에서는 0이 하나라도 있으면 통째로 0이며 1인 가지는 버린다. 가지가
하나만 남으면 마디를 두지 않는다. 나무를 작게 유지해야 찍었을 때
읽을 만한 식이 된다.
@<함수들@>=
func lit(v int) *form { return &form{lit: v} }

func one() *form { return &form{lit: -2} }

func sum(ks ...*form) *form {
	var out []*form
	for _, k := range ks {
		if k != nil {
			out = append(out, k)
		}
	}
	@<가지가 하나뿐이거나 없으면 마디를 두지 않는다@>@;
	return &form{lit: -1, kids: out}
}

@ @<가지가 하나뿐이거나 없으면 마디를 두지 않는다@>=
switch len(out) {
case 0:
	return nil
case 1:
	return out[0]
}

@ @<함수들@>=
func prod(ks ...*form) *form {
	var out []*form
	for _, k := range ks {
		if k == nil {
			return nil
		}
		if k.lit != -2 {
			out = append(out, k)
		}
	}
	if len(out) == 0 {
		return one()
	}
	if len(out) == 1 {
		return out[0]
	}
	return &form{lit: -1, prod: true, kids: out}
}

@ 찍을 때 괄호는 곱 안에 든 합에만 친다. 그 밖에는 필요 없다.
@<함수들@>=
func (f *form) String() string {
	switch {
	case f == nil:
		return "0"
	case f.lit == -2:
		return "1"
	case f.lit >= 0:
		s := string(rune('a' + f.lit/2))
		if f.lit%2 == 1 {
			s += "'"
		}
		return s
	}
	var parts []string
	for _, k := range f.kids {
		s := k.String()
		if f.prod && k.lit < 0 && !k.prod {
			s = "(" + s + ")"
		}
		parts = append(parts, s)
	}
	if f.prod {
		return strings.Join(parts, "")
	}
	return strings.Join(parts, "+")
}

@ 문학적 프로그램은 제가 옳다는 증거를 스스로 지녀야 한다. 여기서는
그 증거를 얻기가 쉽다. {\it 인수분해한 식을 도로 펼쳐서 원래 족과
같은지 보면 된다.\/} 합은 합집합이고 곱은 결합 $\sqcup$이므로, 나무를
훑으며 두 연산으로 되짚어 올라간 다음 |Equal|로 견준다. 그 판정은
마디 첨자 둘을 견주는 일이라 거저다.
@<함수들@>=
func (f *form) eval(z *bdd.ZDD) bdd.Func {
	switch {
	case f == nil:
		return z.Empty()
	case f.lit == -2:
		return z.Unit()
	case f.lit >= 0:
		return z.Elt(f.lit)
	}
	r := f.kids[0].eval(z)
	for _, k := range f.kids[1:] {
		if f.prod {
			r = z.Join(r, k.eval(z))
		} else {
			r = z.Union(r, k.eval(z))
		}
	}
	return r
}

@ 잎의 수가 곧 인수분해한 식의 리터럴 수다. 이것이 줄어들라고 하는
일이다.
@<함수들@>=
func (f *form) lits() int {
	switch {
	case f == nil || f.lit == -2:
		return 0
	case f.lit >= 0:
		return 1
	}
	n := 0
	for _, k := range f.kids {
		n += k.lits()
	}
	return n
}

@* 나눗셈이 하는 일.
큐브 족을 다루는 데 몫이 얼마나 요긴한지 보자. 원소 하나짜리 족
$\{\{v\}\}$로 나눈 몫 $f/\{v\}$는 ``$v$가 든 큐브들에서 $v$를 뺀 것''이다.
그러니 $f/\{v\}$의 항 수가 곧 $v$를 품은 큐브의 수다. 그 수가 $f$의 항
수와 같다면 $v$는 {\it 모든\/} 큐브에 들어 있다는 뜻이다.

모든 큐브에 드는 리터럴을 다 모은 것을 {\it 공통 큐브\/}라 한다. 공통
큐브가 비어 있지 않으면 그것을 통째로 밖으로 빼낼 수 있다.
@^공통 큐브@>
@<함수들@>=
func commonCube(z *bdd.ZDD, f bdd.Func) bdd.Func {
	c, n := z.Unit(), cubes(z, f)
	if n == 0 {
		return c
	}
	for _, v := range z.Support(f) {
		if cubes(z, z.Quotient(f, z.Elt(v))) == n {
			c = z.Join(c, z.Elt(v))
		}
	}
	return c
}

@ 공통 큐브로 나누어 버리면 남는 것은 {\it 큐브 자유\/}(cube-free)한
족이다. 어떤 리터럴도 모든 큐브에 들어 있지 않다는 뜻이고, 대수적
인수분해는 이 성질을 발판으로 삼는다. 공통 큐브가 비었으면 단위 족으로
나누는 셈이라 아무 일도 일어나지 않는다.
@<함수들@>=
func cubeFree(z *bdd.ZDD, f bdd.Func) bdd.Func {
	return z.Quotient(f, commonCube(z, f))
}

@ 더 나눌 수 없는 족은 곱의 합 그대로 적는다. 항은 짧은 것부터, 같은
길이면 사전 차례로 늘어놓는다. 그래야 찍힌 식이 눈에 익는다.
@<함수들@>=
func flat(z *bdd.ZDD, f bdd.Func) *form {
	var terms []*form
	for c := range z.Subsets(f) {
		var ls []*form
		for _, v := range c {
			ls = append(ls, lit(v))
		}
		terms = append(terms, prod(ls...))
	}
	sort.Slice(terms, func(i, j int) bool {
		a, b := terms[i].String(), terms[j].String()
		if len(a) != len(b) {
			return len(a) < len(b)
		}
		return a < b
	})
	return sum(terms...)
}

@* 나눌 것 고르기.
인수분해의 알맹이는 ``무엇으로 나눌까''다. Brayton과 McMullen이 1982년에
답을 내놓았다. $f$를 어떤 큐브로 나눈 뒤 큐브 자유하게 만든 것을
$f$의 {\it 커널\/}이라 하는데, 두 식에 공통 인수가 있다면 그 인수는
반드시 두 식의 커널들과 관계가 있다. 그러니 커널을 하나 찾아 나누면 된다.
@^Brayton, Robert King@>
@^McMullen, Curtis Tracy@>
@^커널@>

가장 싸게 얻는 것이 준위 0 커널이다. 큐브 자유하게 만든 다음, 두 개
이상의 큐브에 나오는 리터럴이 있으면 그것으로 나누고 다시 큐브 자유하게
만들기를 되풀이한다. 나눌 때마다 족이 작아지므로 반드시 멈춘다.
@<나눌 것 |d|를 고른다@>=
d := cubeFree(z, f)
for {
	pick := -1
	for _, v := range z.Support(d) {
		if cubes(z, z.Quotient(d, z.Elt(v))) >= 2 {
			pick = v
			break
		}
	}
	if pick < 0 {
		break
	}
	d = cubeFree(z, z.Quotient(d, z.Elt(pick)))
}

@* 인수분해.
Brayton의 일반 인수분해를 그대로 옮긴다. 나눌 것을 고르고, 나누고,
몫과 나누는 것과 나머지를 각각 다시 인수분해해서 이어 붙인다. 중간에
몫이 한 항뿐이거나 나누는 것이 큐브 자유하지 않으면, 그때는 리터럴
하나를 밖으로 빼내는 쪽으로 방향을 튼다.
@<함수들@>=
func factor(z *bdd.ZDD, f bdd.Func) *form {
	if cubes(z, f) <= 1 {
		return flat(z, f)
	}
	@<나눌 것 |d|를 고른다@>@;
	if cubes(z, d) <= 1 {
		return flat(z, f)
	}
	@<나누어 보고 식을 짓는다@>@;
}

@ 몫이 한 항뿐이면 그 항의 리터럴 하나를 빼내는 편이 낫다. 그렇지
않으면 몫을 큐브 자유하게 만들어 그것으로 다시 나눈다. 이번에는 몫과
나누는 것의 자리가 바뀌었으므로, 나누는 쪽이 큐브 자유하면 세 조각을
그대로 이어 붙이면 된다.
@<나누어 보고 식을 짓는다@>=
q := z.Quotient(f, d)
if cubes(z, q) == 1 {
	return literalFactor(z, f, q)
}
q = cubeFree(z, q)
d, r := z.Quotient(f, q), z.Remainder(f, q)
if commonCube(z, d).Equal(z.Unit()) {
	return sum(prod(factor(z, q), factor(z, d)), factor(z, r))
}
return literalFactor(z, f, commonCube(z, d))

@ 리터럴 하나를 빼내는 쪽은 이렇다. 주어진 큐브에 든 리터럴 가운데
가장 많은 큐브에 나오는 것을 골라 밖으로 빼내고, 몫과 나머지를 각각
다시 인수분해한다.
@<함수들@>=
func literalFactor(z *bdd.ZDD, f, c bdd.Func) *form {
	best, bn := -1, -1
	for _, v := range z.Support(c) {
		if k := cubes(z, z.Quotient(f, z.Elt(v))); k > bn {
			best, bn = v, k
		}
	}
	if best < 0 {
		return flat(z, f)
	}
	q, r := z.Quotient(f, z.Elt(best)), z.Remainder(f, z.Elt(best))
	return sum(prod(lit(best), factor(z, q)), factor(z, r))
}

@* 돌려 보기.
보기 아홉 개를 늘어놓는다. 마지막 둘은 눈여겨볼 만하다. 완전 그래프의
간선을 죄다 적은 식은 인수분해해도 별로 줄지 않고, 반대로
$(a+b+c)(e+f+g)$를 펼친 식은 원래대로 고스란히 접힌다.
@<보기들을 인수분해한다@>=
fmt.Println("== 인수분해 ==")
tests := []string{
	"ae+af+ag+bce+bcf+bcg+bd", "ab+ac+ad", "abc+abd+aef+aeg",
	"ab+a'b'", "ac+ad+bc+bd+e", "abc+abd+abe+acd+ace+ade",
	"abd+abe+acd+ace+bd+be+cd+ce",
	"ab+ac+ad+ae+bc+bd+be+cd+ce+de",
	"ae+be+ce+af+bf+cf+ag+bg+cg",
}
if *e != "" {
	tests = []string{*e}
}
for _, s := range tests {
	@<식 |s| 하나를 인수분해해 찍는다@>@;
}

@ 우주는 소문자 스물여섯 자에 리터럴 둘씩, 쉰두 자리면 넉넉하다.
@<식 |s| 하나를 인수분해해 찍는다@>=
z := bdd.NewZDD(52)
f := parse(z, s)
g := factor(z, f)
fmt.Printf("%-30s -> %-27s  리터럴 %2d -> %2d  되펼침 %v\n",
	s, g.String(), rawLits(z, f), g.lits(), g.eval(z).Equal(f))

@ 마지막으로 펼쳤다 도로 접어 본다. $(a+b+\cdots)(m+n+\cdots)$을
곱해 놓으면 항이 $k^2$개, 리터럴이 $2k^2$개가 되는데, 인수분해하면
리터럴 $2k$개로 돌아와야 한다.
@<함수들@>=
func spread(k int) string {
	var terms []string
	for i := 0; i < k; i++ {
		for j := 0; j < k; j++ {
			terms = append(terms, string(rune('a'+i))+string(rune('m'+j)))
		}
	}
	return strings.Join(terms, "+")
}

@ @<펼쳤다 도로 접는다@>=
fmt.Println("== 펼쳤다 도로 접기 ==")
z := bdd.NewZDD(52)
f := parse(z, spread(*k))
g := factor(z, f)
fmt.Printf("k=%d: 항 %d개, 리터럴 %d개  ->  리터럴 %d개, 되펼침 %v\n",
	*k, cubes(z, f), rawLits(z, f), g.lits(), g.eval(z).Equal(f))
fmt.Println(g.String())

@* 색인.
