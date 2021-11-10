
VERSION=001

CC=cc
MAX2MARKDOWN=libexec/Max2Markdown/bin/max2markdown.sh
QUASI=libexec/quasi/_bin/quasi
DOCUMENTATION=documentation/$(VERSION)/documentation.md

all: quasi _bin/ixc

quasi: $(QUASI)
	mkdir -p _gen
	$(QUASI) -f _gen source/mt/*.txt

_bin/ixc:
	mkdir -p _bin
	$(CC) -o _bin/ixc -I_gen/include _gen/c/*.c

doco: $(DOCUMENTATION)

$(DOCUMENTATION): $(MAX2MARKDOWN)
	mkdir -p documentation/$(VERSION)
	$(MAX2MARKDOWN) source/mt/*.txt > $(DOCUMENTATION)

clean:
	make -C libexec/quasi clean
	rm -rf _gen _bin


$(QUASI):
	make -C libexec/quasi

$(MAX2MARKDOWN):
	cd libexec; git clone https://github.com/danielbradley/Max2Markdown.git