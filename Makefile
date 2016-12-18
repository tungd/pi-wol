PULP := pulp
CLOSURE := closure-compiler

GO_SRC := $(wildcard *.go)

ASSETS := assets
JS_SRC := $(wildcard src/*.js)
PURS_SRC := $(wildcard src/*.purs)


build: pi-wol $(ASSETS)/app.min.js

%.min.js: %.js
	$(CLOSURE) --js $< > $@

pi-wol: $(GO_SRC)
	go build

$(ASSETS)/app.js: $(PURS_SRC) $(JS_SRC)
	$(PULP) build --to $@

clean: pi-wol $(ASSETS)/app.js
	rm $^

watch:
	@fswatch -e pi-wol -e .git/ -ro . | xargs -n1 -I{} make

.PHONY: build deploy clean
