// SPDX-License-Identifier: Apache-2.0
//
// Generates Phase 1 permutation vectors from the upstream ascon/ascon-c source.
//
// Build example:
//   cc -std=c99 -O2 \
//      -I$ASCON_C_DIR/src \
//      -I$ASCON_C_DIR/src/opt64 \
//      -I$ASCON_C_DIR/crypto_aead/asconaead128/ref \
//      tools/ascon_c_perm_vectors.c -o build/ascon_c_perm_vectors

#include <stdint.h>
#include <stdio.h>

#include "ascon.h"
#include "permutations.h"

static void load_state(ascon_state_t* s, const uint64_t w[5]) {
  for (int i = 0; i < 5; i++) {
    s->x[i] = w[i];
  }
}

static void print_state_param(const char* name, const ascon_state_t* s) {
  printf("localparam [319:0] %-19s = 320'h%016llx%016llx%016llx%016llx%016llx;\n",
         name,
         (unsigned long long)s->x[0],
         (unsigned long long)s->x[1],
         (unsigned long long)s->x[2],
         (unsigned long long)s->x[3],
         (unsigned long long)s->x[4]);
}

static void emit_family(const char* prefix, const uint64_t w[5]) {
  ascon_state_t s;
  char name[64];

  load_state(&s, w);
  snprintf(name, sizeof(name), "%s_STATE", prefix);
  print_state_param(name, &s);

  load_state(&s, w);
  P(&s, 12);
  snprintf(name, sizeof(name), "%s_P12", prefix);
  print_state_param(name, &s);

  load_state(&s, w);
  P(&s, 8);
  snprintf(name, sizeof(name), "%s_P8", prefix);
  print_state_param(name, &s);

  load_state(&s, w);
  P(&s, 6);
  snprintf(name, sizeof(name), "%s_P6", prefix);
  print_state_param(name, &s);
}

int main(void) {
  const uint64_t zero[5] = {
      0x0000000000000000ull, 0x0000000000000000ull, 0x0000000000000000ull,
      0x0000000000000000ull, 0x0000000000000000ull};

  const uint64_t sample[5] = {
      0x0123456789abcdefull, 0xfedcba9876543210ull, 0x0011223344556677ull,
      0x8899aabbccddeeffull, 0x0f1e2d3c4b5a6978ull};

  printf("// SPDX-License-Identifier: Apache-2.0\n");
  printf("// Auto-generated from upstream ascon/ascon-c via tools/ascon_c_perm_vectors.c.\n\n");
  emit_family("VEC_ZERO", zero);
  printf("\n");
  emit_family("VEC_SAMPLE", sample);
  printf("\n");
  return 0;
}
