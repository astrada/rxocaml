
all:
	@dune build @all

build:
	@dune build @install

install: build
	@dune install

uninstall: build
	@dune uninstall

clean:
	@dune clean

test:
	@dune runtest --force --no-buffer

doc:
	@dune build @doc

watch:
	@dune build @all -w

example-hello:
	dune exec examples/hello/hello.exe

.PHONY: build install clean test doc watch example-hello

