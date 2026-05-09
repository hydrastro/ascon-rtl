// SPDX-License-Identifier: Apache-2.0
//
// Generates Phase 2.3 AEAD128 encryption vectors with associated data using
// the upstream ascon/ascon-c permutation as the golden primitive.

#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include "ascon.h"
#include "permutations.h"

#define LOCAL_ASCON_128A_RATE 16

#define SETBYTE(b, i) ((uint64_t)(b) << (8 * (i)))
#define PAD(i) SETBYTE(0x01, i)
#define DSEP() SETBYTE(0x80, 7)

struct test_case {
  unsigned adlen;
  unsigned mlen;
};

static uint64_t loadbytes(const uint8_t* bytes, int n) {
  uint64_t x = 0;
  for (int i = 0; i < n; i++) x |= SETBYTE(bytes[i], i);
  return x;
}

static void storebytes(uint8_t* bytes, uint64_t x, int n) {
  for (int i = 0; i < n; i++) bytes[i] = (uint8_t)(x >> (8 * i));
}

static void print128(const char* name, uint64_t hi, uint64_t lo) {
  printf("localparam [127:0] %-32s = 128'h%016llx%016llx;\n",
         name, (unsigned long long)hi, (unsigned long long)lo);
}

static void print_block_bytes_as_words(const char* name, const uint8_t* b, int n) {
  uint8_t tmp[16];
  memset(tmp, 0, sizeof(tmp));
  if (n > 16) n = 16;
  if (n > 0) memcpy(tmp, b, (size_t)n);
  print128(name, loadbytes(tmp, 8), loadbytes(tmp + 8, 8));
}

static void absorb_ad(ascon_state_t* s, const uint8_t* ad, uint32_t adlen) {
  if (adlen != 0) {
    while (adlen >= LOCAL_ASCON_128A_RATE) {
      s->x[0] ^= loadbytes(ad, 8);
      s->x[1] ^= loadbytes(ad + 8, 8);
      P(s, 8);
      ad += LOCAL_ASCON_128A_RATE;
      adlen -= LOCAL_ASCON_128A_RATE;
    }

    if (adlen >= 8) {
      s->x[0] ^= loadbytes(ad, 8);
      s->x[1] ^= loadbytes(ad + 8, (int)(adlen - 8));
      s->x[1] ^= PAD(adlen - 8);
    } else {
      s->x[0] ^= loadbytes(ad, (int)adlen);
      s->x[0] ^= PAD(adlen);
    }
    P(s, 8);
  }

  s->x[4] ^= DSEP();
}

static void encrypt_with_ad(const uint8_t key[16], const uint8_t nonce[16],
                            const uint8_t* ad, uint32_t adlen,
                            const uint8_t* msg, uint32_t mlen,
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

  absorb_ad(&s, ad, adlen);

  while (mlen >= LOCAL_ASCON_128A_RATE) {
    s.x[0] ^= loadbytes(msg, 8);
    s.x[1] ^= loadbytes(msg + 8, 8);
    storebytes(ciphertext, s.x[0], 8);
    storebytes(ciphertext + 8, s.x[1], 8);
    P(&s, 8);
    msg += LOCAL_ASCON_128A_RATE;
    ciphertext += LOCAL_ASCON_128A_RATE;
    mlen -= LOCAL_ASCON_128A_RATE;
  }

  if (mlen >= 8) {
    s.x[0] ^= loadbytes(msg, 8);
    s.x[1] ^= loadbytes(msg + 8, (int)(mlen - 8));
    storebytes(ciphertext, s.x[0], 8);
    storebytes(ciphertext + 8, s.x[1], (int)(mlen - 8));
    s.x[1] ^= PAD(mlen - 8);
  } else {
    s.x[0] ^= loadbytes(msg, (int)mlen);
    storebytes(ciphertext, s.x[0], (int)mlen);
    s.x[0] ^= PAD(mlen);
  }

  s.x[2] ^= K0;
  s.x[3] ^= K1;
  P(&s, 12);
  s.x[3] ^= K0;
  s.x[4] ^= K1;

  storebytes(tag, s.x[3], 8);
  storebytes(tag + 8, s.x[4], 8);
}

static void print_case(unsigned idx, const struct test_case* tc,
                       const uint8_t* ad, const uint8_t* msg,
                       const uint8_t* ct, const uint8_t tag[16]) {
  char name[80];
  const unsigned ad_blocks = (tc->adlen + 15u) / 16u;
  const unsigned msg_blocks = (tc->mlen + 15u) / 16u;

  printf("localparam [31:0] VEC_AEAD_AD_C%u_AD_BYTES     = 32'd%u;\n", idx, tc->adlen);
  printf("localparam [31:0] VEC_AEAD_AD_C%u_MSG_BYTES    = 32'd%u;\n", idx, tc->mlen);

  snprintf(name, sizeof(name), "VEC_AEAD_AD_C%u_TAG", idx);
  print128(name, loadbytes(tag, 8), loadbytes(tag + 8, 8));

  for (unsigned i = 0; i < ad_blocks; i++) {
    unsigned block_len = tc->adlen - (i * 16u);
    if (block_len > 16u) block_len = 16u;
    snprintf(name, sizeof(name), "VEC_AEAD_AD_C%u_AD%u", idx, i);
    print_block_bytes_as_words(name, ad + (i * 16u), (int)block_len);
  }

  for (unsigned i = 0; i < msg_blocks; i++) {
    unsigned block_len = tc->mlen - (i * 16u);
    if (block_len > 16u) block_len = 16u;

    snprintf(name, sizeof(name), "VEC_AEAD_AD_C%u_PT%u", idx, i);
    print_block_bytes_as_words(name, msg + (i * 16u), (int)block_len);

    snprintf(name, sizeof(name), "VEC_AEAD_AD_C%u_CT%u", idx, i);
    print_block_bytes_as_words(name, ct + (i * 16u), (int)block_len);
  }
  printf("\n");
}

int main(void) {
  uint8_t key[16];
  uint8_t nonce[16];
  uint8_t ad[64];
  uint8_t msg[64];
  uint8_t ct[64];
  uint8_t tag[16];
  const struct test_case cases[] = {
    {0, 0},
    {1, 0},
    {7, 1},
    {8, 8},
    {9, 15},
    {15, 16},
    {16, 16},
    {17, 17},
    {31, 32},
    {32, 31}
  };

  for (int i = 0; i < 16; i++) {
    key[i] = (uint8_t)i;
    nonce[i] = (uint8_t)(0xa0 + i);
  }
  for (int i = 0; i < 64; i++) {
    ad[i] = (uint8_t)(0x80 + i);
    msg[i] = (uint8_t)(0x30 + i);
  }

  printf("// SPDX-License-Identifier: Apache-2.0\n");
  printf("// Auto-generated from upstream ascon/ascon-c via tools/ascon_c_aead128_ad_vectors.c.\n\n");

  print_block_bytes_as_words("VEC_AEAD_AD_KEY", key, 16);
  print_block_bytes_as_words("VEC_AEAD_AD_NONCE", nonce, 16);
  printf("\n");

  for (unsigned i = 0; i < sizeof(cases) / sizeof(cases[0]); i++) {
    memset(ct, 0, sizeof(ct));
    memset(tag, 0, sizeof(tag));
    encrypt_with_ad(key, nonce, ad, cases[i].adlen, msg, cases[i].mlen, ct, tag);
    print_case(i, &cases[i], ad, msg, ct, tag);
  }

  return 0;
}
