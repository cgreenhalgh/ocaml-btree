default: build

config:
	ocaml setup.ml -configure --disable-tests

config-test: 
	ocaml setup.ml -configure --enable-tests

build:
	ocaml setup.ml -build

install:
	ocaml setup.ml -install

clean:
	ocaml setup.ml -clean
	${RM} testfile

test: config-test build
	${RM} testfile
	touch testfile 
	./btree_test.native

xen_testfile:
	${RM} xen_testfile
	dd bs=4096 count=256 if=/dev/zero of=xen_testfile

xen_test: xen_testfile
	cd xen_test && mirari configure --xen
	cd xen_text && mirari build --xen
	cd xen_test && sudo xl create -c btree_test.myxl

