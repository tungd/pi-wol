PULP := pulp
CLOSURE := closure-compiler

GO_SRC := $(wildcard *.go)

ASSETS := assets
JS_SRC := $(wildcard src/*.js)
PURS_SRC := $(wildcard src/*.purs)


build: pi-wol $(ASSETS)/app.min.js

%.min.js: %.js
	cp $< $@
#	$(CLOSURE) --js $< > $@

pi-wol: $(GO_SRC)
	go build
	rice append --exec $@

$(ASSETS)/app.js: $(PURS_SRC) $(JS_SRC)
	$(PULP) build --to $@

clean: pi-wol $(ASSETS)/app.js
	rm $^

watch:
	@fswatch -ro src | xargs -n1 -I{} make

.PHONY: build deploy clean
