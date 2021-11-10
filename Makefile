
QUASI=libexec/quasi/_bin/quasi
CC=cc

all: quasi _bin/ixc

quasi: $(QUASI)
	mkdir -p _gen
	$(QUASI) -f _gen source/mt/*.txt

_bin/ixc:
	mkdir -p _bin
	$(CC) -o _bin/ixc -I_gen/include _gen/c/*.c

clean:
	make -C libexec/quasi clean
	rm -rf _gen _bin


$(QUASI):
	make -C libexec/quasi
