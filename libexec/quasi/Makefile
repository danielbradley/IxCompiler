
CC=cc

all: _bin/quasi

_bin/quasi: _src/quasi.c
	mkdir -p _bin
	$(CC) -o _bin/quasi _src/quasi.c

_src/quasi.c:
	mkdir -p _src
	cd _src; wget https://quasi-literateprogramming.com/resources/downloads/2.0/quasi.c

clean:
	rm -rf _bin _src
