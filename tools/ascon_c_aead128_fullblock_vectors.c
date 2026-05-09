// SPDX-License-Identifier: Apache-2.0
//
// Generates Phase 2.1 AEAD128 no-AD/full-block encryption vectors using the
// upstream ascon/ascon-c permutation as the golden primitive.
//
// This deliberately mirrors crypto_aead/asconaead128/ref/aead.c for the subset:
//   - encryption
//   - adlen = 0
//   - mlen = 16 * msg_blocks

#include <stdint.h>
#include <stdio.h>

#include "ascon.h"
#include "permutations.h"

#define LOCAL_ASCON_128A_RATE 16

#define SETBYTE(b, i) ((uint64_t)(b) << (8 * (i)))
#define PAD(i) SETBYTE(0x01, i)
#define DSEP() SETBYTE(0x80, 7)

static uint64_t loadbytes(const uint8_t* bytes, int n) {
  uint64_t x = 0;
  for (int i = 0; i < n; i++) x |= SETBYTE(bytes[i], i);
  return x;
}

static void storebytes(uint8_t* bytes, uint64_t x, int n) {
  for (int i = 0; i < n; i++) bytes[i] = (uint8_t)(x >> (8 * i));
}

static void print128(const char* name, uint64_t hi, uint64_t lo) {
  printf("localparam [127:0] %-24s = 128'h%016llx%016llx;\n",
         name, (unsigned long long)hi, (unsigned long long)lo);
}

static void print_block_bytes_as_words(const char* name, const uint8_t* b) {
  print128(name, loadbytes(b, 8), loadbytes(b + 8, 8));
}

static void encrypt_noad_fullblocks(const uint8_t key[16], const uint8_t nonce[16],
                                    const uint8_t* msg, uint32_t blocks,
                                    uint8_t* ciphertext, uint8_t tag[16]) {
  const uint64_t K0 = loadbytes(key, 8);
  const uint64_t K1 = loadbytes(key + 8, 8);
  const uint64_t N0 = loadbytes(nonce, 8);
  const uint64_t N1 = loadbytes(nonce + 8, 8);

  ascon_state_t s;
  s.x[0] = ASCON_128A_IV;
  s.x[1] = K0;
  s.x[2] = K1;
  s.x[3] = N0;
  s.x[4] = N1;

  P(&s, 12);
  s.x[3] ^= K0;
  s.x[4] ^= K1;

  // adlen == 0: skip AD absorption, still apply domain separation.
  s.x[4] ^= DSEP();

  for (uint32_t i = 0; i < blocks; i++) {
    const uint8_t* m = msg + (i * LOCAL_ASCON_128A_RATE);
    uint8_t* c = ciphertext + (i * LOCAL_ASCON_128A_RATE);
    s.x[0] ^= loadbytes(m, 8);
    s.x[1] ^= loadbytes(m + 8, 8);
    storebytes(c, s.x[0], 8);
    storebytes(c + 8, s.x[1], 8);
    P(&s, 8);
  }

  // Final plaintext block for mlen % 16 == 0.
  s.x[0] ^= PAD(0);

  s.x[2] ^= K0;
  s.x[3] ^= K1;
  P(&s, 12);
  s.x[3] ^= K0;
  s.x[4] ^= K1;

  storebytes(tag, s.x[3], 8);
  storebytes(tag + 8, s.x[4], 8);
}

int main(void) {
  uint8_t key[16];
  uint8_t nonce[16];
  uint8_t msg[32];
  uint8_t ct[32];
  uint8_t tag[16];

  for (int i = 0; i < 16; i++) {
    key[i] = (uint8_t)i;
    nonce[i] = (uint8_t)(0xa0 + i);
  }
  for (int i = 0; i < 32; i++) msg[i] = (uint8_t)(0x30 + i);

  printf("// SPDX-License-Identifier: Apache-2.0\n");
  printf("// Auto-generated from upstream ascon/ascon-c via tools/ascon_c_aead128_fullblock_vectors.c.\n\n");

  print_block_bytes_as_words("VEC_AEAD_KEY", key);
  print_block_bytes_as_words("VEC_AEAD_NONCE", nonce);
  printf("\n");

  encrypt_noad_fullblocks(key, nonce, msg, 0, ct, tag);
  print128("VEC_AEAD_EMPTY_TAG", loadbytes(tag, 8), loadbytes(tag + 8, 8));
  printf("\n");

  encrypt_noad_fullblocks(key, nonce, msg, 1, ct, tag);
  print_block_bytes_as_words("VEC_AEAD_1BLK_PT0", msg);
  print_block_bytes_as_words("VEC_AEAD_1BLK_CT0", ct);
  print128("VEC_AEAD_1BLK_TAG", loadbytes(tag, 8), loadbytes(tag + 8, 8));
  printf("\n");

  encrypt_noad_fullblocks(key, nonce, msg, 2, ct, tag);
  print_block_bytes_as_words("VEC_AEAD_2BLK_PT0", msg);
  print_block_bytes_as_words("VEC_AEAD_2BLK_PT1", msg + 16);
  print_block_bytes_as_words("VEC_AEAD_2BLK_CT0", ct);
  print_block_bytes_as_words("VEC_AEAD_2BLK_CT1", ct + 16);
  print128("VEC_AEAD_2BLK_TAG", loadbytes(tag, 8), loadbytes(tag + 8, 8));

  return 0;
}
