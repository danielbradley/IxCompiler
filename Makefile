
VERSION=015

PLATFORM=posix
CC=cc
MAX2MARKDOWN=libexec/Max2Markdown/bin/max2markdown.sh
QUASI=libexec/quasi/_bin/quasi
#TESTFILES=testdata/ix.base/StringBuffer.ix
TESTFILES=testdata/Test.ix

default: quasi ixc doco

all: default test show

quasi: $(QUASI)
	mkdir -p _gen
	$(QUASI) -f _gen source/mt/*.txt

ixc:
	mkdir -p _bin
	$(CC) -o _bin/ixc -g -I_gen/include _gen/c/*.c _gen/c/$(PLATFORM)/*.c

doco: $(MAX2MARKDOWN)
	mkdir -p documentation/$(VERSION)
	$(MAX2MARKDOWN) source/mt/*.txt > documentation/$(VERSION)/README.md
	$(MAX2MARKDOWN) source/mt/*.txt > README.md

test:
	mkdir -p _output
	_bin/ixc --output-dir _output --target-language C $(TESTFILES)

show: showh showc

showh:
	cat _output/include/ix.base.h

showc:
	cat _output/c/ix.base.c

testcompile:
	mkdir -p _output/bin
	gcc -c -o _output/bin/ix.base.o -I _output/include _output/c/ix.base.c

debug:
	mkdir -p _output
#	gdb --args _bin/ixc --output-dir _output --target-language C testdata/ix.base/*.ix
	gdb --args _bin/ixc --output-dir _output --target-language C $(TESTFILES)

clean:
	make -C libexec/quasi clean
	rm -rf _gen _bin


$(QUASI):
	make -C libexec/quasi

$(MAX2MARKDOWN):
	cd libexec; git clone https://github.com/danielbradley/Max2Markdown.git
