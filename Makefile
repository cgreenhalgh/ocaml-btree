default: build

config:
	ocaml setup.ml -configure --enable-tests

build:
	ocaml setup.ml -build

install:
	ocaml setup.ml -install

clean:
	ocaml setup.ml -clean
	${RM} testfile

test: build
	${RM} testfile
	touch testfile 
	./btree_test.native

