# Go를 위한 BDD·ZDD 꾸러미

크누스가 『The Art of Computer Programming』 7.1.4절을 준비하며 쓴 두 습작
[**BDD14**](https://www-cs-faculty.stanford.edu/~knuth/programs/bdd14.w)와
[**BDD15**](https://www-cs-faculty.stanford.edu/~knuth/programs/bdd15.w)를
Go로 옮긴 것이다. 앞의 것은 변수 재정렬까지 갖춘 BDD 꾸러미이고, 뒤의 것은
같은 뼈대를 ZDD로 다시 지은 것이다.

두 프로그램을 나란히 놓고 읽으면 재미있는 것이 보인다. 3000줄이 넘는 두 글이
거의 한 글자씩 같다. 노드를 담는 배열도, 변수마다 두는 유일 테이블도, 계산해
둔 결과를 기억하는 캐시도, 참조 계수와 쓰레기 수거도 모두 같다. 정말로 다른
곳은 딱 한 줄, 가지를 만들 자리에서 무엇을 축약하느냐다.

- **BDD**는 두 갈래가 같은 곳으로 가면 가지를 만들지 않는다.
- **ZDD**는 1쪽 갈래가 거짓 싱크로 가면 가지를 만들지 않는다.

그 한 줄에서 불 함수의 세계와 집합족의 세계가 갈린다. 그래서 이 꾸러미는
두 엔진을 한 지붕 아래 둔다.

## 설치

```sh
go get github.com/sjnam/bdd
```

`.w`를 손보려면 [GWEB](https://github.com/sjnam/gweb)이 필요하다. 조판은
한글이므로 luatex으로만 된다.

```sh
make          # .w를 Go로 짜내고 빌드한다
make test     # 시험을 돌린다
make pdf      # 문학적 문서를 조판한다
```

## 맛보기

```go
b := bdd.New()
x1, x2, x3, x4 := b.Var(1), b.Var(2), b.Var(3), b.Var(4)

f := b.And(b.Xor(x1, x2), b.Or(x3, x4))   // (x1⊕x2) ∧ (x3∨x4)
fmt.Println(b.Count(f))                    // 6
fmt.Println(b.Size(f))                     // 7 (노드 수)

for sol := range b.All(f) {                // 해를 하나씩
    fmt.Println(sol)
}
```

집합족이라면 ZDD 쪽이다.

```go
z := bdd.NewZDD(10)                        // 원소 e0..e9
f := z.Universe()                          // 부분집합 전부
for _, e := range edges {                  // 간선마다 걸러 낸다
    both := z.Join(z.Elt(e.u), z.Elt(e.v))
    f = z.Diff(f, z.Join(both, z.Universe()))
}
fmt.Println(z.Count(f))                    // 독립집합의 수
```

## 함수 손잡이와 수명

함수 하나는 `Func` 손잡이로 주고받는다. 값 타입이라 복사해도 되고 슬라이스나
맵에 담아도 되며, 복사본들은 같은 노드를 나눠 쥔다.

크누스의 프로그램은 노드마다 참조 계수를 두고 손으로 세었다. 이 꾸러미도
그 계수를 그대로 쓰되, 세는 일은 Go의 쓰레기 수거기에게 맡긴다. 손잡이가
닿지 않는 곳으로 가면 `runtime.AddCleanup`이 걸어 둔 훅이 울리고, 그 훅은
“이 노드를 놓아도 된다”는 쪽지를 대기표에 얹는다. 쪽지를 실제로 처리하는
것은 다음 연산이 시작될 때다. 이 한 박자 늦춤 덕에 연산이 도는 동안에는
어떤 노드도 죽지 않는다.

```go
f := b.And(x, y)   // 그냥 버리면 나중에 저절로 풀린다
f.Free()           // 큰 계산 중간이라면 손수 놓아도 된다 (두 번 불러도 탈 없다)
```

밑준위 하나를 여러 고루틴에서 동시에 쓸 수는 없다.

## BDD API

밑준위는 `bdd.New()`로 만든다. 변수는 부를 때 생긴다.

| 하는 일 | 메서드 |
| --- | --- |
| 상수와 변수 | `Zero() One() Var(k)` |
| 이항 | `And Or Xor Not Butnot Notbut Constrain` |
| 한정사 | `Exists(f,g) Forall(f,g) Diff(f,g) Yes(f,g) No(f,g)` |
| 삼항 | `Ite(f,g,h) Median(f,g,h) And3(f,g,h) AndExists(f,g,h)` |
| 합성 | `Compose(f, map[int]Func)` |
| 세기 | `Count(f) *big.Int`, `Size(f)`, `Profile(f)`, `Support(f)` |
| 값 재기 | `Eval(f, []bool)` |
| 열거 | `All(f) iter.Seq[[]bool]`, `Random(f, *rand.Rand)` |

한정사의 둘째 인자 `g`는 양의 리터럴들의 논리곱이어야 한다. `f Exists g`는
`g`에 나오는 변수들을 존재 한정한다는 뜻이다.

제약 연산 `Constrain`은 Coudert와 Madre의 $f\downarrow g$이고, `Yes`와 `No`는 크누스가
BDD14에 넣은 별난 한정사다. `f Yes x`는 $f=x$가 되는 곳, `f No x`는
$f=\bar x$가 되는 곳이다. 함수 $f$가 단조인 것은 모든 $v$에 대해
`f No x_v`가 0인 것과 같다.

세는 메서드 `Count`는 지금 밑준위에 있는 모든 변수에 대해 센다. 화살표가 건너뛴 변수는
값이 무엇이든 상관없다는 뜻이므로 2의 거듭제곱으로 갚는다.

## ZDD API

밑준위는 `bdd.NewZDD(n)`으로 만든다. 원소 수를 미리 정해야 한다 — ZDD에서
“건너뛴다”는 것이 “그 원소는 없다”는 뜻이므로, 어디까지가 원소인지를
모르면 족 자체가 정해지지 않는다.

| 하는 일 | 메서드 |
| --- | --- |
| 상수 | `Empty()` ∅, `Unit()` {∅}, `Universe()` ℘ |
| 원소 | `Elt(k)` {{e_k}}, `Var(k)` e_k를 품은 것 전부 |
| 집합 연산 | `Union Intersect Diff Xor` |
| 족의 대수 | `Join` ⊔, `DisjointJoin`, `Meet` ⊓, `Delta` Δ |
| 나눗셈 | `Quotient(f,g)` f/g, `Remainder(f,g)` f mod g |
| 삼항 | `Ite Median And3`, `Build(e,lo,hi)` |
| 대칭 함수 | `Sym(p, k)` — p에 열거된 원소 가운데 정확히 k개 |
| 세기 | `Count(f) *big.Int`, `Size(f)`, `Profile(f)`, `Support(f)` |
| 물음 | `Contains(f, []int)` |
| 열거 | `Subsets(f) iter.Seq[[]int]`, `Random(f, *rand.Rand)` |
| 최적화 | `MaxWeight(f, w []int) ([]int, int, bool)` — 무게 합이 가장 큰 집합 |

결합 `Join`은 미나토의 곱이다. `f ⊔ g = {α∪β : α∈f, β∈g}`. 집합 하나를 짓는 가장
자연스러운 길이 이것이다 — `Elt(1) ⊔ Elt(2) ⊔ Elt(3)`이 `{{e1,e2,e3}}`이다.

노드 짓기 `Build(e, lo, hi)`는 노드 하나를 손수 짓는다. `e`가 `Elt(i)`이고 `lo`와 `hi`의
뿌리가 준위 `i`보다 아래에 있어야 한다. ZDD를 밑에서부터 쌓아 올리는
알고리즘 — 이를테면 `examples/simpath`의 프런티어 법 — 이 이것을 쓴다.

## 변수 재정렬

BDD의 크기는 변수 차례에 목을 맨다. 같은 함수라도 어떤 차례에서는 노드가
$n$개면 되고 다른 차례에서는 $2^n$개가 든다. Rudell의 **체질**(sifting)은
변수 하나를 위에서 아래까지 죽 밀어 보고 노드가 가장 적었던 자리에 놓는
어림법이다. 단순한 생각인데 놀랄 만큼 잘 듣는다.

```go
b.Order()          // 지금 차례 (위에서 아래로)
b.Swap(k)          // 변수 k를 바로 위 이웃과 맞바꾼다
b.Sift(k)          // 변수 k의 가장 좋은 자리를 찾는다
b.SiftAll()        // 모든 변수를 차례로 체질한다
b.Reorder(order)   // 차례를 통째로 정해 준다
```

재정렬은 BDD와 ZDD가 함께 쓴다. 차례가 바뀌어도 손에 쥔 `Func`이 나타내는
함수는 그대로다 — 나타내는 *방식*만 달라진다.

이를테면 `x0∧x7 ∨ x1∧x8 ∨ ⋯ ∨ x6∧x13`을 짝을 갈라놓는 최악의 차례로 지으면
노드가 256개인데, 체질을 몇 바퀴 돌리면 이론값인 16개에 이른다.

## 예제

```sh
go run ./examples/queens -n 8              # n-퀸을 BDD로
go run ./examples/indep -g petersen        # 독립집합을 ZDD로
go run ./examples/simpath -m 8 -n 8        # 격자의 단순 경로를 세기
go run ./examples/bddl                     # 크누스의 BDDL/ZDDL 계산기
go run ./examples/solitaire -b plus        # 페그 솔리테어의 도달 가능한 자리
go run ./examples/order                    # 변수 차례가 크기를 어떻게 좌우하는가
go run ./examples/circuit                  # 가산기 둘의 등가성, 그리고 곱셈기
go run ./examples/factor                   # 곱의 합 인수분해
go run ./examples/pentomino -m 6 -n 10     # 펜토미노 타일링을 ZDD로
```

- **queens** — 칸마다 변수를 하나 두고 조건을 BDD로 엮는다. 8-퀸의 해는 92개.
  조건을 다 엮고 나면 해를 하나도 늘어놓지 않고 개수를 알 수 있다.
- **indep** — 그래프의 독립집합을 ZDD로 모은다. 페테르센 그래프는 76개,
  $6\times6$ 격자는 5,598,861개. 가장 큰 독립집합은 대칭 함수 `Sym`으로 찾고,
  정점에 무게를 얹은 최대 가중 독립집합은 `MaxWeight`로 찾는다 — 무게를 모두 1로
  두면 두 길의 답이 같아야 하므로 그 자체로 검사가 된다.
- **simpath** — 크누스의 SIMPATH를 옮겼다. $8\times8$ 격자의
  모퉁이에서 모퉁이까지 가는 단순 경로가 789,360,053,252가지인데, 0.1초 남짓에
  센다. `Build`로 ZDD를 밑에서부터 손수 쌓아 올리는 본보기이기도 하다.
  `-long`을 주면 `MaxWeight`가 가장 긴 경로(길이 62)를 찾아 준다 — 그래프
  일반에서는 NP-어려운 문제인데, 족을 쥐고 있으면 마디 수에 정비례한다.
- **solitaire** — 페그 솔리테어의 판 하나를 33비트 불 벡터로 적으면 판의 집합이
  불 함수 하나가 된다. 한 수를 관계 $T(x,x')$로 적어 놓고
  $(\exists x)[R(x)\land T(x,x')]$를 되풀이하면, 자리를 하나도 그리지 않고
  닿을 수 있는 자리를 모두 센다. 십자판의 답은 187,636,299가지.
  BDD가 세상에 쓸모를 증명한 그 계산(상징적 모형 검사)의 축소판이다.
- **order** — 변수 차례의 세 얼굴. 쌍의 논리합은 짝을 붙이면 노드 22개, 갈라
  놓으면 2048개이고 `SiftAll`이 도로 22개로 되찾는다. 대칭 함수는 어떤 차례로도
  크기가 같아 체질이 할 일이 없다. 숨은 가중 비트는 어떤 차례로도 지수적이어서,
  체질이 82만 개를 2만 8천 개로 줄여도 지수는 지수로 남는다.
- **circuit** — BDD가 반도체 업계의 연장이 된 까닭. 물결 자리올림 가산기와
  Kogge–Stone 접두 가산기가 같은 함수임을 64비트에서 10밀리초에 증명한다
  (`Func.Equal`은 노드 첨자를 견줄 뿐이다). 한 글자 틀린 회로에는 `Random`으로
  반례를 내놓고, 곱셈기의 가운데 비트는 $n$이 2 늘 때마다 아홉 배로 터져
  BDD의 천장을 보여 준다.
- **factor** — ZDD가 태어난 자리. 미나토의 나눗셈 $f/g$와 $f \bmod g$로 곱의 합을
  인수분해한다. `ae+af+ag+bce+bcf+bcg+bd`(리터럴 17개)가 `(a+bc)(e+f+g)+bd`(8개)가
  되고, 결과를 도로 펼쳐 `Func.Equal`로 확인한다. 같은 큐브 족을 BDD에 담으면
  우주 크기에 정비례해 자라는데 ZDD는 열두 마디에 머문다는 것도 재어 본다.
- **pentomino** — 정확 피복을 ZDD로. 프런티어로 답 전체를 한 덩어리로 쌓는다.
  $6\times10$ 판의 답 9,356가지가 ZDD 26,984마디에 들어가고, 그 뒤로는 세기도
  균등 추출(`Random`)도 거저다. 되짚기가 답을 하나씩 뱉는 것과 대비된다.
- **bddl** — BDD14와 BDD15의 명령 언어를 흉내 낸 계산기. 노드 번호를 찍는 대신
  크기·옆모습·해의 개수·해 목록을 찍는다. `help`를 치면 문법이 나온다.

```text
$ go run ./examples/bddl
> f1=x1^x2
> f2=x3|x4
> f1=f1&f2
> p 1
f1: 노드 7개, 6개
> S
> O
[1 2 4 3]
```

## 문학적 프로그램

`.w` 파일만이 원본이다. `gtangle`이 Go를 짜내고 `gweave`가 조판할 TeX을
짜낸다. 각 문서는 처음부터 끝까지 혼자 읽을 수 있게 썼다.

예제 아홉도 모두 문학적 프로그램이다. `make pdf`를 돌리면 열세 편이 함께
조판된다.

생성물은 저장소에 넣지 않는 것이 원칙인데, 라이브러리 API의 `.go` 넷만은
예외로 넣어 두었다. `go get`으로 이 꾸러미를 가져다 쓰는 쪽에 GWEB을 깔라고
할 수는 없기 때문이다. 시험 파일과 예제의 `.go`, 조판 결과는 넣지 않으므로
저장소를 받아 예제까지 돌려 보려면 `make`를 한 번 돌려야 한다.

| 파일 | 담은 것 |
| --- | --- |
| `common.w` | 공통의 땅: 노드 배열, 변수와 유일 테이블, 캐시, 참조 계수, 손잡이, 쓰레기 수거, 온전성 검사 |
| `bdd.w` | BDD 엔진: 이항·삼항 연산, 한정사, 함수 합성, 세기와 열거 |
| `zdd.w` | ZDD 엔진: 족의 대수, 나눗셈, 대칭 함수, 세기와 열거, 최적화 |
| `reorder.w` | 제자리 맞바꿈과 Rudell의 체질 |
| `examples/queens/queens.w` | n-퀸을 BDD로 |
| `examples/indep/indep.w` | 독립집합을 ZDD로 |
| `examples/simpath/simpath.w` | 프런티어 법으로 단순 경로 세기 |
| `examples/bddl/bddl.w` | 크누스의 명령 언어를 쓰는 계산기 |
| `examples/solitaire/solitaire.w` | 페그 솔리테어를 상징적 도달 가능성으로 |
| `examples/order/order.w` | 변수 차례가 BDD 크기를 어떻게 좌우하는가 |
| `examples/circuit/circuit.w` | 회로 등가성 검사와 곱셈기의 폭발 |
| `examples/factor/factor.w` | 곱의 합 인수분해, 미나토의 나눗셈 |
| `examples/pentomino/pentomino.w` | 펜토미노 타일링, 정확 피복을 ZDD로 |

시험도 같은 원본에서 짜여 나온다. `gtangle bdd.w`는 `bdd.go`와 `bdd_test.go`를
함께 내놓는다.

## Go로 옮기며 달라진 것

크누스는 메모리를 손수 관리한다. `mem`이라는 거대한 배열을 잡아 아래쪽에는
노드를, 위쪽에는 4096바이트짜리 페이지를 쌓고, 유일 테이블과 캐시는 그
페이지들에 흩어 놓는다. 포인터는 32비트로 눌러 담는다. 이 모든 것이
Go에서는 필요 없다.

정작 크게 줄어든 곳은 따로 있다. 크누스의 `mem`은 크기가 정해져 있어 노드가
모자랄 수 있고, 그래서 재귀 루틴마다 절반가량이 “자리가 모자라 도중에 손을
떼는” 이야기다. 슬라이스는 모자라면 늘어나므로 그 절반이 통째로 사라진다.
남은 절반은 놀랄 만큼 짧고 알고리즘의 뼈대가 훨씬 잘 보인다.

그 밖에 달라진 것들:

- **해시 코드를 곱셈으로 만든다.** 크누스는 노드마다 난수 22비트를 박아 두어
  해시를 공짜로 얻었다. 그 대가로 변수가 1024개를 넘을 수 없었다. 곱셈 한 번이면
  난수를 미리 뽑아 두는 것만큼 싸고, 그 덕에 네 바이트가 통째로 준위 차지가
  되어 변수 수의 천장이 사라진다.
- **표를 제자리에서 다시 해싱하지 않는다.** 크누스는 페이지를 새로 잡을 수
  없어 Rudell의 재주를 부려야 했다. 슬라이스를 새로 잡으면 그만이다. 선형
  조사에서 항목을 지우는 가장 까다로운 대목(TAOCP 알고리즘 6.4R의 변형)도
  같은 까닭으로 사라진다.
- **싱크는 불사다.** 참조 계수를 세지 않으므로 “싱크가 죽었다”는 괴상한
  상태가 아예 생기지 않는다.
- **삼항 연산의 캐시 열쇠**는 셋째 피연산자를 네 비트 밀어 짓는다. 크누스는
  포인터가 16바이트 경계에 놓인다는 사실로 같은 일을 했다. 그래서 이 꾸러미가
  다룰 수 있는 노드는 $2^{27}$개까지다.
- **해를 세고 열거하는 일이 들어왔다.** 크누스의 습작에는 없고 딴 프로그램이
  맡았지만, 라이브러리로 쓰려면 여기 있어야 한다.

## 온전성 검사

BDD 꾸러미는 겹겹이 남아도는 자료 구조 위에 서 있다. 유일 테이블도 캐시도
참조 계수도 모두 “없어도 답은 나오는” 것들이라, 어딘가 어긋나도 당장은
표가 나지 않는다. 그래서 크누스를 따라 `Check()`를 두었다.

```go
if err := b.Check(); err != nil {
    log.Fatal(err)
}
```

참조 계수를 죄다 다시 세어 보고, 유일 테이블에서 모든 노드를 찾을 수 있는지
보고, 축약 규칙과 준위 차례를 확인하고, 새어 나간 노드가 없는지 센다. 값이
싸지 않으니 시험과 디버깅에만 쓴다. 이 꾸러미의 시험은 무작위 연산 수천 번을
돌리는 사이사이에 이것을 부른다.

## 참고

- D. E. Knuth, *The Art of Computer Programming*, Volume 4A, 7.1.4절 (BDD)
- R. E. Bryant, "Graph-based algorithms for Boolean function manipulation,"
  *IEEE Trans. Computers* **C-35** (1986), 677–691
- S. Minato, "Zero-suppressed BDDs for set manipulation in combinatorial
  problems," *DAC* (1993), 272–277
- R. Rudell, "Dynamic variable ordering for ordered binary decision diagrams,"
  *ICCAD* (1993), 42–47
- [dancing-cells](https://github.com/sjnam/dancing-cells) — 이 저장소의 모델
