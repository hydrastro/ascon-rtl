#include <stdint.h>
#include <stddef.h>
#include "ascon_accel.h"

#ifndef ASCON_ACCEL_ENC_BASE
#define ASCON_ACCEL_ENC_BASE 0xF0000000u
#endif

#ifndef ASCON_ACCEL_DEC_BASE
#define ASCON_ACCEL_DEC_BASE 0xF0000000u
#endif

static const uint8_t demo_key[16] = {
  0x00,0x01,0x02,0x03,0x04,0x05,0x06,0x07,
  0x08,0x09,0x0a,0x0b,0x0c,0x0d,0x0e,0x0f
};

static const uint8_t demo_nonce[16] = {
  0x10,0x11,0x12,0x13,0x14,0x15,0x16,0x17,
  0x18,0x19,0x1a,0x1b,0x1c,0x1d,0x1e,0x1f
};

static const uint8_t demo_ad[17] = {
  0xa0,0xa1,0xa2,0xa3,0xa4,0xa5,0xa6,0xa7,
  0xa8,0xa9,0xaa,0xab,0xac,0xad,0xae,0xaf,0xb0
};

static const uint8_t demo_pt[31] = {
  0x00,0x11,0x22,0x33,0x44,0x55,0x66,0x77,
  0x88,0x99,0xaa,0xbb,0xcc,0xdd,0xee,0xff,
  0x10,0x21,0x32,0x43,0x54,0x65,0x76,0x87,
  0x98,0xa9,0xba,0xcb,0xdc,0xed,0xfe
};

int main(void) {
  ascon_accel_t enc;
  ascon_accel_init(&enc, (uintptr_t)ASCON_ACCEL_ENC_BASE);

  uint8_t ct[sizeof(demo_pt)] = {0};
  uint8_t tag[16] = {0};

  int rc = ascon_accel_encrypt(&enc,
                               demo_key,
                               demo_nonce,
                               demo_ad,
                               sizeof(demo_ad),
                               demo_pt,
                               ct,
                               sizeof(demo_pt),
                               tag);
  if (rc != ASCON_ACCEL_OK) {
    return 1;
  }

#if ASCON_ACCEL_DEC_BASE != ASCON_ACCEL_ENC_BASE
  ascon_accel_t dec;
  ascon_accel_init(&dec, (uintptr_t)ASCON_ACCEL_DEC_BASE);

  uint8_t recovered[sizeof(demo_pt)] = {0};
  rc = ascon_accel_decrypt(&dec,
                           demo_key,
                           demo_nonce,
                           demo_ad,
                           sizeof(demo_ad),
                           ct,
                           recovered,
                           sizeof(ct),
                           tag);
  if (rc != ASCON_ACCEL_OK) {
    return 2;
  }

  for (size_t i = 0; i < sizeof(demo_pt); i++) {
    if (recovered[i] != demo_pt[i]) {
      return 3;
    }
  }
#endif

  return 0;
}
