/* Standalone repro (no CREST code) of the leak that chez-release-escaped-frames.patch removes.
 *
 * A Scheme error escapes through a C function that had called into Scheme. Each such error should
 * leave nothing behind; stock Chez (d533f2e, and upstream main) leaves about 208 bytes.
 *
 * Build (Linux), with B = <chez build dir>/ta6le:
 *   cc -O1 -m64 -msse2 -D_REENTRANT -pthread -I$B/boot/ta6le -o repro repro.c \
 *      $B/boot/ta6le/libkernel.a $B/zlib/libz.a $B/lz4/lib/liblz4.a -rdynamic -lm -ldl -lncurses -lrt -lpthread
 * Run:
 *   ./repro $B/boot/ta6le/petite.boot $B/boot/ta6le/scheme.boot repro.ss
 * Result on 2026-11-12: stock Chez "heap grew 20800000 bytes over 100000 errors (208.0 per error)";
 * with the patch "heap grew 0 bytes over 100000 errors (0.0 per error)".
 */
#include "scheme.h"
#include <malloc.h>
#include <stdio.h>

static ptr top(const char* name) { return Stop_level_value(Sstring_to_symbol(name)); }

/* The C function in the middle: Scheme calls it (repro.ss: call-c), and it calls Scheme again. */
static void call_scheme(void) {
  Scall0(top("raise-it")); /* Scheme code that raises an error */
}

int main(int argc, char** argv) {
  (void)argc;
  Sscheme_init(NULL);
  Sregister_boot_file(argv[1]); /* petite.boot */
  Sregister_boot_file(argv[2]); /* scheme.boot */
  Sbuild_heap(argv[0], NULL);
  Sforeign_symbol("call_scheme", (void*)call_scheme); /* the name that repro.ss looks up */
  Scall1(top("load"), Sstring(argv[3]));              /* repro.ss */
  for (int i = 0; i < 1000; i++) {
    Scall0(top("try")); /* warm up */
  }
  Scall0(top("collect"));
  size_t before = mallinfo().uordblks;
  const int n = 100000;
  for (int i = 0; i < n; i++) {
    Scall0(top("try")); /* a call from C into Scheme: the outer frame. Inside it, one error escapes. */
  }
  Scall0(top("collect"));
  long grew = (long)(mallinfo().uordblks - before);
  printf("heap grew %ld bytes over %d errors (%.1f per error)\n", grew, n, (double)grew / n);
  return 0;
}
