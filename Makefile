# BDD·ZDD 꾸러미는 문학적 프로그램이다. .w 파일만이 원본이고 .go와 .pdf는
# 모두 생성물이다. `make`는 .w를 Go로 짜내어 빌드하고, `make pdf`는 조판한다.
#
# 다만 라이브러리 API의 .go 넷은 저장소에 넣어 두고 clean에서도 빼 둔다.
# `go get`으로 이 꾸러미를 가져다 쓰는 쪽에 GWEB을 깔라고 할 수는 없다.
#
#   common.w   공통의 땅: 노드 배열, 유일 테이블, 캐시, 참조 계수, 쓰레기 수거
#   bdd.w      BDD 엔진 (이항·삼항 연산, 한정사, 합성, 세기와 열거)
#   zdd.w      ZDD 엔진 (족의 대수, 나눗셈, 대칭 함수, 세기와 열거)
#   reorder.w  변수 재정렬 (제자리 맞바꿈과 Rudell의 체질)
#
# examples 아래 아홉도 모두 문학적 프로그램이다.
#
#   queens.w     n-퀸을 BDD로
#   indep.w      독립집합을 ZDD로
#   simpath.w    격자의 단순 경로를 프런티어 법으로
#   bddl.w       크누스의 BDDL/ZDDL 문법을 쓰는 계산기
#   solitaire.w  페그 솔리테어를 상징적 도달 가능성으로
#   order.w      변수 차례가 BDD 크기를 어떻게 좌우하는가
#   circuit.w    가산기 둘의 등가성 증명, 그리고 곱셈기라는 천장
#   factor.w     곱의 합 인수분해 (미나토의 나눗셈)
#   pentomino.w  펜토미노 타일링, 정확 피복을 ZDD로
#
# 한글 .w는 kotexgweb을 쓰므로 luatex으로만 조판된다.
#
# GTANGLE/GWEAVE라는 이름을 쓰는 것은 GNU Make에 붙박이로 있는 TANGLE/WEAVE
# 변수(CWEB 연장을 가리킨다)와 부딪히지 않기 위해서다.

GO      ?= go
GTANGLE ?= gtangle
GWEAVE  ?= gweave
LUATEX  ?= luatex -interaction=nonstopmode

LIB      := common bdd zdd reorder
EXAMPLES := queens indep bddl simpath solitaire order circuit factor pentomino
EXGO     := $(foreach e,$(EXAMPLES),examples/$(e)/$(e).go)
EXPDF    := $(foreach e,$(EXAMPLES),examples/$(e)/$(e).pdf)
JUNK     := tex pdf idx scn log toc dvi

.PHONY: all build test vet tangle pdf clean

all: build

# .w가 바뀌면 Go 원본을 다시 짜낸다. 엔진마다 시험 파일도 함께 나온다.
common.go common_test.go: common.w
	$(GTANGLE) $<
	gofmt -w common.go common_test.go

bdd.go bdd_test.go: bdd.w
	$(GTANGLE) $<
	gofmt -w bdd.go bdd_test.go

zdd.go zdd_test.go: zdd.w
	$(GTANGLE) $<
	gofmt -w zdd.go zdd_test.go

reorder.go reorder_test.go: reorder.w
	$(GTANGLE) $<
	gofmt -w reorder.go reorder_test.go

# 예제는 제 디렉터리에서 짜낸다. 정적 패턴 규칙이라 아래의 %-규칙보다 앞선다.
$(EXGO): examples/%.go: examples/%.w
	cd $(dir $@) && $(GTANGLE) $(notdir $<)
	gofmt -w $@

tangle: $(addsuffix .go,$(LIB)) $(EXGO)

build: tangle
	$(GO) build ./...

test: tangle $(addsuffix _test.go,$(LIB))
	$(GO) test ./...

vet: tangle
	$(GO) vet ./...

# 조판은 두 번 돌린다. 상호 참조가 두 번째 판에서 맞춰진다.
pdf: $(addsuffix .pdf,$(LIB)) $(EXPDF)

%.pdf: %.w
	$(GWEAVE) $<
	$(LUATEX) $*.tex
	$(LUATEX) $*.tex

$(EXPDF): examples/%.pdf: examples/%.w
	cd $(dir $@) && $(GWEAVE) $(notdir $<)
	cd $(dir $@) && $(LUATEX) $(notdir $*).tex
	cd $(dir $@) && $(LUATEX) $(notdir $*).tex

# clean은 .w가 만들어 낸 것을 지운다. 라이브러리 API의 .go 넷만은 남긴다 ---
# 그것은 저장소에 든 것이고, GWEB이 없는 이도 `go build`는 할 수 있어야 한다.
# 나머지는 `make`(또는 `make tangle`)를 다시 돌리면 도로 생긴다.
clean:
	rm -f $(addsuffix _test.go,$(LIB))
	rm -f $(foreach x,$(JUNK),$(addsuffix .$(x),$(LIB)))
	rm -f $(EXGO)
	rm -f $(foreach e,$(EXAMPLES),$(foreach x,$(JUNK),examples/$(e)/$(e).$(x)))
	rm -f $(foreach e,$(EXAMPLES),examples/$(e)/$(e))
