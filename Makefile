
build:
	@dune build @all

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
