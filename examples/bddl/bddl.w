\input kotexgweb

\def\title{BDDL 계산기}

% 크누스가 BDD14 림보에 두었던 것들. \<...>는 문법 표기이고, \ttv는 세로줄
% --- TeX 파트의 맨 세로줄은 GWEB이 코드 모드로 넘어가는 글자라 쓸 수 없다.
\def\<#1>{\hbox{$\langle\,$#1$\,\rangle$}}
\chardef\ttv='174

@s Func int
@s BDD int
@s ZDD int
@s Scanner int
@s File int

@* 들어가며.
크누스의 \.{BDD14}와 \.{BDD15}는 라이브러리가 아니라 {\it 대화식 프로그램\/}
이었다. 명령을 한 줄씩 읽어 BDD를 짓고, 물어보면 답한다. 그 명령 언어에
그는 \.{BDDL}과 \.{ZDDL}이라는 이름을 붙였다.
@^BDDL@>
@^ZDDL@>

문법은 단출하다. \<number>를 음이 아닌 십진수라 할 때
$$\eqalign{
&\<const>\gets\.{c0}\mid\.{c1}\mid\.{c2}\cr
&\<atom>\gets\<const>\mid\.x\<number>\mid\.e\<number>\mid\.f\<number>\cr
&\<expr>\gets\<atom>\mid\.\~\<atom>\mid
   \<atom>\<binop>\<atom>\mid
   \<atom>\<ternop>\<atom>\<ternop>\<atom>\cr
&\<command>\gets\<special>\mid\.f\<number>\.=\<expr>\mid\.f\<number>\.{=.}\cr}$$
이다. 이를테면 \.{f1=x1\^{}x2} 다음에 \.{f2=x3{\ttv}x4}, 그다음에 \.{f1=f1\&f2}라
하면 $f_1$은 $(x_1\oplus x_2)\land(x_3\lor x_4)$가 된다.

@ 우리가 옮기면서 한 가지를 바꿨다. 크누스의 프로그램은 물어보면 노드 번호를
16진수로 찍어 준다. 그의 관심사가 자료 구조 그 자체였기 때문이다. 우리는
라이브러리가 아는 것---크기, 옆모습, 해의 개수, 해 목록---을 찍는다. 노드
번호는 라이브러리가 감춘 것이고, 감춘 데는 까닭이 있으니 굳이 들추지 않는다.

그러니 이것은 \.{BDDL} 해석기라기보다 \.{BDDL} 문법을 쓰는 {\it 계산기\/}다.
@c
package main

import (
	"bufio"
	"flag"
	"fmt"
	"os"
	"strconv"
	"strings"

	"github.com/sjnam/bdd"
)

@<자료 구조@>

@<함수들@>

func main() {
	@<밑준위를 세운다@>@;
	@<입력을 고른다@>@;
	@<명령을 하나씩 읽어 따른다@>@;
}

@ 계산기가 지니고 다니는 것은 넷이다. 두 엔진 가운데 하나(다른 하나는
|nil|이다), 이름 붙은 함수들, 그리고 BDD 합성에 쓸 치환 함수들.
@<자료 구조@>=
type calc struct {
	b *bdd.BDD
	z *bdd.ZDD
	f map[int]bdd.Func // \.{f0}, \.{f1}, \dots
	y map[int]bdd.Func // \.{y0}, \.{y1}, \dots (BDD 전용)
}

@ 어느 세계에서 놀 것인지는 명령줄이 정한다. \.{-z}에 원소 수를 주면 ZDD
모드다. ZDD는 원소 수를 미리 알아야 하므로 어쩔 수 없다.
@<밑준위를 세운다@>=
zn := flag.Int("z", -1, "ZDD 모드로 시작하며 원소 수를 정한다")
flag.Parse()
c := &calc{f: map[int]bdd.Func{}, y: map[int]bdd.Func{}}
if *zn >= 0 {
	c.z = bdd.NewZDD(*zn)
} else {
	c.b = bdd.New()
}

@* 명령 읽기.
명령은 파일에서 오거나 표준 입력에서 온다. 파일 이름을 주면 그것을 읽고,
안 주면 표준 입력을 읽는다.

말을 거는 것(``\.{> }'' 표시)은 사람이 앉아 있을 때뿐이다. 파이프로 들어오는
것이면 표시를 내지 않는다. 표준 입력이 문자 장치인지 물어보면 그것을 알 수 있다.
@<입력을 고른다@>=
in, prompt := os.Stdin, true
if a := flag.Args(); len(a) > 0 {
	fh, err := os.Open(a[0])
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	defer fh.Close()
	in = fh
}
if fi, err := in.Stat(); err == nil && fi.Mode()&os.ModeCharDevice == 0 {
	prompt = false
}
sc := bufio.NewScanner(in)

@ 읽기 고리. 끝내는 명령만 여기서 가려낸다. 나머지는 아래 절이 맡는다.
@<명령을 하나씩 읽어 따른다@>=
for {
	if prompt {
		fmt.Print("> ")
	}
	if !sc.Scan() {
		return
	}
	line := strings.TrimSpace(sc.Text())
	if line == "q" || line == "quit" {
		return
	}
	@<한 줄을 따르되 잘못은 그 줄에서 그친다@>@;
}

@ 잘못된 명령을 만나면 그 줄에서 손을 떼고 다음 줄로 넘어가야 한다. 아래
절들은 잘못을 만나면 |panic|을 던지도록 썼으므로, 그것을 받아 낼 자리가
줄마다 하나씩 필요하다. 익명 함수를 그 자리에 세운다---|defer|는 함수가
끝날 때 도는 것이라, 고리 안에 그냥 두면 프로그램이 끝날 때까지 기다린다.
@<한 줄을 따르되 잘못은 그 줄에서 그친다@>=
func() {
	defer func() {
		if e := recover(); e != nil {
			fmt.Println("!", e)
		}
	}()
	@<명령을 갈라 따른다@>@;
}()

@ 명령을 가르는 자리. 크누스의 명령표를 거의 그대로 옮겼다. 첫 글자가
명령을 정하고, 뒤에 붙은 것이 인자다.
@<명령을 갈라 따른다@>=
switch {
case line == "" || strings.HasPrefix(line, "#"):
case strings.HasPrefix(line, "!"):
	fmt.Println(line[1:]) // 그대로 되뇐다
case line == "help" || line == "?":
	@<도움말을 찍는다@>@;
case line == "O":
	fmt.Println(c.order())
case line == "$":
	@<통계를 찍는다@>@;
case line == "b":
	@<자연 차례로 되돌린다@>@;
default:
	@<나머지 명령을 갈라 따른다@>@;
}

@ @<나머지 명령을 갈라 따른다@>=
switch {
case strings.HasPrefix(line, "pp"):
	@<옆모습을 찍는다@>@;
case strings.HasPrefix(line, "p"):
	@<크기와 개수를 찍는다@>@;
case strings.HasPrefix(line, "c"):
	fmt.Println(c.count(c.get(num(argsOf(line, 1)[0]))))
case strings.HasPrefix(line, "l"):
	@<해를 늘어놓는다@>@;
case strings.HasPrefix(line, "r"):
	@<무작위로 하나 뽑는다@>@;
case strings.HasPrefix(line, "S"):
	@<체질한다@>@;
case strings.HasPrefix(line, "s"):
	@<변수를 위 이웃과 맞바꾼다@>@;
case strings.HasPrefix(line, "y"):
	@<치환 함수를 정한다@>@;
case strings.HasPrefix(line, "f"):
	@<함수에 값을 매긴다@>@;
default:
	fmt.Println("! 모르는 명령:", line)
}

@ 인자를 떼어 내는 손. 크누스는 \.{p3}처럼 붙여 썼고 우리는 \.{p 3}도
받는다. 명령 글자 뒤를 통째로 낱말로 쪼개면 둘 다 걸린다.
@<함수들@>=
func argsOf(line string, n int) []string {
	return strings.Fields(line[n:])
}

func num(s string) int {
	k, err := strconv.Atoi(strings.TrimSpace(s))
	if err != nil {
		panic("숫자가 아니다: " + s)
	}
	return k
}

@ 이름으로 함수를 찾는 손. 없는 것을 부르면 그 자리에서 죽는다.
@<함수들@>=
func (c *calc) get(k int) bdd.Func {
	f, ok := c.f[k]
	if !ok {
		panic(fmt.Sprintf("f%d이 없다", k))
	}
	return f
}

@* 함수에 값 매기기.
\.{f3=\dots}가 이 프로그램의 알맹이다. 등호를 찾아 왼쪽에서 이름을, 오른쪽에서
식을 얻는다. 오른쪽이 점 하나면 그 함수를 지운다.
@<함수에 값을 매긴다@>=
i := strings.Index(line, "=")
if i < 0 {
	panic("`=`가 없다: " + line)
}
k, rhs := num(line[1:i]), strings.TrimSpace(line[i+1:])
if rhs == "." {
	delete(c.f, k)
} else {
	@<오른쪽 항을 잰다@>@;
	c.f[k] = val
}

@ 오른쪽 항을 재는 자리. 여섯 갈래다. 여집합, 합성, 대칭 함수, 그리고
원자 하나거나 이항이거나 삼항이거나.

가르는 일은 |cut|이 한다. 맨 앞 원자와 그 뒤에 붙은 연산자 한 글자를 떼어
내는 것인데, 두 번 부르면 삼항까지 갈린다.
@<오른쪽 항을 잰다@>=
var val bdd.Func
first, op, tail := cut(rhs)
second, op2, third := cut(tail)
sym := strings.IndexByte(rhs, 'S')
switch {
case strings.HasPrefix(rhs, "~"):
	@<여집합을 잰다@>@;
case strings.HasSuffix(rhs, "[y]"):
	@<합성을 잰다@>@;
case c.z != nil && sym > 0:
	val = c.z.Sym(c.atom(rhs[:sym]), num(rhs[sym+1:]))
case op == 0:
	val = c.atom(rhs)
case op2 == 0:
	@<이항 연산을 잰다@>@;
default:
	@<삼항 연산을 잰다@>@;
}

@ @<함수들@>=
func cut(s string) (string, byte, string) {
	for i := 1; i < len(s); i++ {
		if strings.IndexByte("&>|^*+\"/%_?:.!ANYDE<", s[i]) >= 0 {
			return strings.TrimSpace(s[:i]), s[i], strings.TrimSpace(s[i+1:])
		}
	}
	return s, 0, ""
}

@ 부정과 여집합은 같은 글자 \.\~를 쓴다. BDD에서는 $\bar f$이고 ZDD에서는
$\wp\setminus f$인데, 크누스가 \.{ZDDL}에서 \.{c1\^{}f}로 적던 바로 그것이다.
@<여집합을 잰다@>=
if c.z != nil {
	val = c.z.Diff(c.z.Universe(), c.atom(rhs[1:]))
} else {
	val = c.b.Not(c.atom(rhs[1:]))
}

@ 합성은 \.{f2[y]}라고 적는다. 미리 \.{y3=x1}처럼 걸어 둔 치환들을 한꺼번에
넘긴다. ZDD에는 합성이 없다.
@<합성을 잰다@>=
if c.z != nil {
	panic("ZDD에는 합성이 없다")
}
val = c.b.Compose(c.atom(strings.TrimSuffix(rhs, "[y]")), c.y)

@* 연산자 표.
크누스는 연산자를 번호로 다루고 이름표 배열 하나를 곁에 두었다.
$$\hbox{\.{char *binopname[]=\{"","\&",">","!","<",\dots\};}}$$
우리는 거꾸로 간다. 글자에서 곧바로 연산으로 가는 표를 만든다. \GO/의
{\it 메서드 표현식\/}(method expression)을 쓰면 메서드를 값으로 적을 수
있으므로, 표가 곧 이름표 배열 노릇을 한다.
@^메서드 표현식@>
@<자료 구조@>=
var bddBin = map[byte]func(*bdd.BDD, bdd.Func, bdd.Func) bdd.Func{
	'&': (*bdd.BDD).And, '|': (*bdd.BDD).Or, '^': (*bdd.BDD).Xor,
	'>': (*bdd.BDD).Butnot, '<': (*bdd.BDD).Notbut,
	'_': (*bdd.BDD).Constrain,
	'A': (*bdd.BDD).Forall, 'E': (*bdd.BDD).Exists,
	'D': (*bdd.BDD).Diff, 'Y': (*bdd.BDD).Yes, 'N': (*bdd.BDD).No,
}

@ ZDD 쪽은 글자가 사뭇 다르다. \.*는 미나토의 결합이고, \.{\char'42}는 만남,
\.{\char'137}는 델타, \./와 \.\%는 몫과 나머지다. 크누스가 고른 글자를
그대로 따랐다.
@^Minato, Shin-ichi@>
@<자료 구조@>=
var zddBin = map[byte]func(*bdd.ZDD, bdd.Func, bdd.Func) bdd.Func{
	'&': (*bdd.ZDD).Intersect, '|': (*bdd.ZDD).Union,
	'^': (*bdd.ZDD).Xor, '>': (*bdd.ZDD).Diff,
	'*': (*bdd.ZDD).Join, '+': (*bdd.ZDD).DisjointJoin,
	'"': (*bdd.ZDD).Meet, '_': (*bdd.ZDD).Delta,
	'/': (*bdd.ZDD).Quotient, '%': (*bdd.ZDD).Remainder,
}

@ 삼항은 글자 둘이 열쇠다. \.{f?g:h}, \.{f.g.h}, \.{f\&g\&h}처럼. 마지막
하나씩만 두 세계가 다르다. BDD에는 \.{f\&g\,E\,h}가 있고, ZDD에는 노드를
손수 짓는 \.{e!lo:hi}가 있다.
@<자료 구조@>=
var bddTern = map[[2]byte]func(*bdd.BDD, bdd.Func, bdd.Func, bdd.Func) bdd.Func{
	{'?', ':'}: (*bdd.BDD).Ite, {'.', '.'}: (*bdd.BDD).Median,
	{'&', '&'}: (*bdd.BDD).And3, {'&', 'E'}: (*bdd.BDD).AndExists,
}

var zddTern = map[[2]byte]func(*bdd.ZDD, bdd.Func, bdd.Func, bdd.Func) bdd.Func{
	{'?', ':'}: (*bdd.ZDD).Ite, {'.', '.'}: (*bdd.ZDD).Median,
	{'&', '&'}: (*bdd.ZDD).And3, {'!', ':'}: (*bdd.ZDD).Build,
}

@ 표가 있으니 재는 일은 두 줄이다. 표에 없는 글자면 그 자리에서 죽는다.
@<이항 연산을 잰다@>=
x, y := c.atom(first), c.atom(tail)
if c.z != nil {
	g, ok := zddBin[op]
	if !ok {
		panic(fmt.Sprintf("모르는 연산자 '%c'", op))
	}
	val = g(c.z, x, y)
} else {
	g, ok := bddBin[op]
	if !ok {
		panic(fmt.Sprintf("모르는 연산자 '%c'", op))
	}
	val = g(c.b, x, y)
}

@ @<삼항 연산을 잰다@>=
x, y, w := c.atom(first), c.atom(second), c.atom(third)
key := [2]byte{op, op2}
if c.z != nil {
	g, ok := zddTern[key]
	if !ok {
		panic(fmt.Sprintf("모르는 삼항 연산 '%c%c'", op, op2))
	}
	val = g(c.z, x, y, w)
} else {
	g, ok := bddTern[key]
	if !ok {
		panic(fmt.Sprintf("모르는 삼항 연산 '%c%c'", op, op2))
	}
	val = g(c.b, x, y, w)
}

@* 원자.
원자는 네 가지다. 상수 \.{cK}, 변수 \.{xK}, 원소 \.{eK}(ZDD 전용),
그리고 이름 붙은 함수 \.{fK}.

변수와 원소를 갈라 둔 것을 눈여겨보자. ZDD에서 \.{e3}은 집합 $\{e_3\}$
{\it 하나만\/} 든 족이고 \.{x3}은 $e_3$을 품은 부분집합이 {\it 모두\/} 든
족이다. 아주 다른 것이다.
@<함수들@>=
func (c *calc) atom(s string) bdd.Func {
	s = strings.TrimSpace(s)
	if s == "" {
		panic("빈 원자")
	}
	k := 0
	if len(s) > 1 {
		k = num(s[1:])
	}
	@<첫 글자를 보고 원자를 만든다@>@;
}

@ @<첫 글자를 보고 원자를 만든다@>=
switch s[0] {
case 'c':
	@<상수를 만든다@>@;
case 'x':
	if c.z != nil {
		return c.z.Var(k)
	}
	return c.b.Var(k)
case 'e':
	if c.z == nil {
		panic("BDD에는 원소 함수가 없다")
	}
	return c.z.Elt(k)
case 'f':
	return c.get(k)
}
panic("모르는 원자: " + s)

@ 상수는 두 세계에서 수가 다르다. BDD에는 거짓과 참 둘뿐이지만 ZDD에는
셋이다---빈 족 $\emptyset$, 온 족 $\wp$, 그리고 공집합 하나만 든 족
$\epsilon$. 크누스가 \.{c0}, \.{c1}, \.{c2}라 부르던 것들이다.
@<상수를 만든다@>=
if c.z != nil {
	switch k {
	case 0:
		return c.z.Empty()
	case 1:
		return c.z.Universe()
	case 2:
		return c.z.Unit()
	}
	panic("ZDD의 상수는 c0, c1, c2뿐이다")
}
switch k {
case 0:
	return c.b.Zero()
case 1:
	return c.b.One()
}
panic("BDD의 상수는 c0, c1뿐이다")

@ 치환 함수는 원자 하나만 받는다. \.{y3=.}이라 하면 걸어 둔 것을 거둔다.
@<치환 함수를 정한다@>=
if c.z != nil {
	panic("ZDD 모드에는 합성이 없다")
}
i := strings.Index(line, "=")
if i < 0 {
	panic("`=`가 없다: " + line)
}
k := num(line[1:i])
if rhs := strings.TrimSpace(line[i+1:]); rhs == "." {
	delete(c.y, k)
} else {
	c.y[k] = c.atom(rhs)
}

@* 찍어 보기.
지은 것을 들여다보는 명령 넷이다. \.{p3}은 노드 수와 개수, \.{pp3}은
옆모습, \.{c3}은 개수만, \.{l3 5}는 해를 다섯 개까지 늘어놓는다.

두 엔진이 같은 이름의 메서드를 가지고 있지만 되돌려 주는 것이 달라서
(BDD는 배정을, ZDD는 집합을 준다) 매번 갈라 적어야 한다. 이것이 두 세계를
한 계산기에 담은 값이다.
@<크기와 개수를 찍는다@>=
k := argNum(line, 1)
f, n := c.get(k), 0
if c.z != nil {
	n = c.z.Size(f)
} else {
	n = c.b.Size(f)
}
fmt.Printf("f%d: 노드 %d개, %s개\n", k, n, c.count(f))

@ @<옆모습을 찍는다@>=
f := c.get(argNum(line, 2))
if c.z != nil {
	fmt.Println(c.z.Profile(f))
} else {
	fmt.Println(c.b.Profile(f))
}

@ 늘어놓기는 스무 개에서 그친다. 뒤에 수를 붙이면 그만큼 본다. 해가
$2^{80}$개인 함수라도 앞의 몇 개만 보고 빠져나올 수 있는 것은 열거가
반복자로 나오기 때문이다.
@<해를 늘어놓는다@>=
a := argsOf(line, 1)
if len(a) == 0 {
	panic("번호가 빠졌다: " + line)
}
f, n, i := c.get(num(a[0])), 20, 0
if len(a) > 1 {
	n = num(a[1])
}
@<해를 |n|개까지 찍는다@>@;

@ @<해를 |n|개까지 찍는다@>=
if c.z != nil {
	for s := range c.z.Subsets(f) {
		if i++; i > n {
			break
		}
		fmt.Println(" ", s)
	}
} else {
	for x := range c.b.All(f) {
		if i++; i > n {
			break
		}
		fmt.Println(" ", bits(x))
	}
}

@ @<무작위로 하나 뽑는다@>=
f := c.get(argNum(line, 1))
if c.z != nil {
	if s, ok := c.z.Random(f, nil); ok {
		fmt.Println(" ", s)
	} else {
		fmt.Println("  (빈 족)")
	}
} else if x, ok := c.b.Random(f, nil); ok {
	fmt.Println(" ", bits(x))
} else {
	fmt.Println("  (해가 없다)")
}

@ BDD의 배정은 참거짓의 배열로 나오는데, 그대로 찍으면 눈에 안 들어온다.
0과 1을 이어 붙인 글자열이 낫다.
@<함수들@>=
func bits(x []bool) string {
	var sb strings.Builder
	for _, v := range x {
		if v {
			sb.WriteByte('1')
		} else {
			sb.WriteByte('0')
		}
	}
	return sb.String()
}

@ 번호 하나를 떼어 내는 손. 빠뜨렸으면 그 자리에서 죽는다.
@<함수들@>=
func argNum(line string, n int) int {
	a := argsOf(line, n)
	if len(a) == 0 {
		panic("번호가 빠졌다: " + line)
	}
	return num(a[0])
}

@ 개수와 차례는 두 엔진에서 같은 모양으로 나오므로 한 번만 갈라 적어 둔다.
@<함수들@>=
func (c *calc) count(f bdd.Func) string {
	if c.z != nil {
		return c.z.Count(f).String()
	}
	return c.b.Count(f).String()
}

func (c *calc) order() []int {
	if c.z != nil {
		return c.z.Order()
	}
	return c.b.Order()
}

@* 차례 만지기.
변수 차례를 손으로 만져 보는 명령 셋이다. \.{s3}은 변수 3을 바로 위
이웃과 맞바꾸고, \.S는 모두 체질하며 \.{S3}은 변수 3만 체질한다.
\.b는 자연 차례로 되돌린다.

\.O로 차례를 찍어 보면서 \.S를 되풀이해 보는 것이 재미있다. 체질은 어림법
이라 한 바퀴로는 최적에 못 미치는데, 몇 바퀴 돌리면 자리를 잡는 것이 눈에
보인다.
@<변수를 위 이웃과 맞바꾼다@>=
k := argNum(line, 1)
if c.z != nil {
	c.z.Swap(k)
} else {
	c.b.Swap(k)
}

@ @<체질한다@>=
a := argsOf(line, 1)
switch {
case len(a) == 0 && c.z != nil:
	c.z.SiftAll()
case len(a) == 0:
	c.b.SiftAll()
case c.z != nil:
	c.z.Sift(num(a[0]))
default:
	c.b.Sift(num(a[0]))
}

@ 자연 차례로 되돌리는 데는 따로 손이 없어도 된다. 지금 차례가 몇 개인지만
알면, 그 자리에 $0,1,2,\dots$를 채워 넣고 |Reorder|에 넘기면 그만이다.
@<자연 차례로 되돌린다@>=
ord := c.order()
for i := range ord {
	ord[i] = i
}
if c.z != nil {
	c.z.Reorder(ord)
} else {
	c.b.Reorder(ord)
}

@ @<통계를 찍는다@>=
if c.z != nil {
	fmt.Println(c.z.Stats())
} else {
	fmt.Println(c.b.Stats())
}

@* 도움말.
마지막으로 \.{help}. 두 모드의 명령이 대부분 같으므로 같은 것을 먼저 적고
다른 것을 뒤에 붙인다.
@<도움말을 찍는다@>=
fmt.Print(`  fK=<식>    함수를 정한다      fK=.   지운다
  p K        노드 수와 개수     pp K   옆모습
  c K        개수만             l K n  해를 n개까지 늘어놓는다
  r K        무작위로 하나 뽑는다
  O          변수 차례          s K    변수 K를 위 이웃과 맞바꾼다
  S [K]      체질 (K를 주면 그 변수만)   b   자연 차례로 되돌린다
  $          통계               q      끝낸다
`)
@<모드마다 다른 도움말을 찍는다@>@;

@ @<모드마다 다른 도움말을 찍는다@>=
if c.z != nil {
	fmt.Print(`  원자: c0(빈 족) c1(온 족) c2(공집합만) eK(원소) xK(K를 품은 것) fK
  단항: ~f (여집합)
  이항: & 교집합  | 합집합  ^ 대칭차  > 차집합  * 결합  + 서로소결합
        " 만남  / 몫  % 나머지  _ 델타
  삼항: f?g:h  f.g.h  f&g&h  e!lo:hi (노드 짓기)
  그 밖: fK=fJ S n  (목록에서 정확히 n개)
`)
	return
}
fmt.Print(`  원자: c0 c1 xK fK          단항: ~f
  이항: & 논리곱  | 논리합  ^ 배타합  > f∧¬g  < ¬f∧g  _ 제약
        A 전칭  E 존재  D 미분  Y 예  N 아니오
  삼항: f?g:h  f.g.h  f&g&h  f&g E h
  합성: yK=<원자> 로 치환을 걸고  fJ=fI[y]
`)

@* 색인.
