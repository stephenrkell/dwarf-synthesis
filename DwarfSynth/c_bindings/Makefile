LIBDWARFW_DIR=$(shell readlink -f ../../libdwarfw/build)

CFLAGS += -Wall -Wextra -std=c11 -O2 -g $(CDEFINE) -I$(OPAM_SWITCH_PREFIX)/lib/ocaml
LDFLAGS += -L$(LIBDWARFW_DIR) -Wl,-rpath,$(LIBDWARFW_DIR)
# keep dependencies in topsorted order
LDLIBS += -ldwarfw -ldwarf -lelf -lz

all: test_dw.bin ml_dwarf_write.bin

test_%.bin: test_%.o dwarf_write.o
	gcc $(CFLAGS) $^ $(LDFLAGS) $(LDLIBS) -o $@

%.o: %.c
	gcc $(CFLAGS) -c $< -o $@

ml_dwarf_write.bin: ml_dwarf_write.ml dwarf_write_stubs.c dwarf_write.o
	ocamlopt $(patsubst %,-ccopt %,$(CFLAGS)) -c dwarf_write_stubs.c
	ocamlopt -o $@ $< -ccopt dwarf_write_stubs.o -ccopt dwarf_write.o $(patsubst %,-ccopt %,$(LDFLAGS) $(LDLIBS))

clean:
	rm -f *.o *.bin

.PRECIOUS: %.o
