PULP := pulp
CLOSURE := closure-compiler

GO_SRC := $(wildcard *.go)

ASSETS := assets
JS_SRC := $(wildcard src/*.js)
PURS_SRC := $(wildcard src/*.purs)


build: pi-wol $(ASSETS)/app.min.js

%.min.js: %.js
	cp $< $@

pi-wol: $(GO_SRC)
	go build

$(ASSETS)/app.js: $(PURS_SRC) $(JS_SRC)
	$(PULP) build --to $@

clean: pi-wol $(ASSETS)/app.js $(ASSETS)/app.min.js
	rm $^

watch:
	@fswatch -ro src | xargs -n1 -I{} make

dist: build
	$(CLOSURE) --js assets/app.js > assets/app.min.js
	rice append --exec pi-wol

.PHONY: build clean watch dist
