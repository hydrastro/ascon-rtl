#ifndef ASCON_ACCEL_H
#define ASCON_ACCEL_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#ifndef ASCON_ACCEL_DEFAULT_TIMEOUT
#define ASCON_ACCEL_DEFAULT_TIMEOUT (1000000u)
#endif

/* Register offsets, byte-addressed. */
#define ASCON_ACCEL_REG_CTRL       0x00u
#define ASCON_ACCEL_REG_STATUS     0x04u
#define ASCON_ACCEL_REG_AD_BYTES   0x08u
#define ASCON_ACCEL_REG_MSG_BYTES  0x0cu
#define ASCON_ACCEL_REG_KEY0       0x10u
#define ASCON_ACCEL_REG_KEY1       0x14u
#define ASCON_ACCEL_REG_KEY2       0x18u
#define ASCON_ACCEL_REG_KEY3       0x1cu
#define ASCON_ACCEL_REG_NONCE0     0x20u
#define ASCON_ACCEL_REG_NONCE1     0x24u
#define ASCON_ACCEL_REG_NONCE2     0x28u
#define ASCON_ACCEL_REG_NONCE3     0x2cu
#define ASCON_ACCEL_REG_TAG0       0x30u
#define ASCON_ACCEL_REG_TAG1       0x34u
#define ASCON_ACCEL_REG_TAG2       0x38u
#define ASCON_ACCEL_REG_TAG3       0x3cu
#define ASCON_ACCEL_REG_AD_IN      0x40u
#define ASCON_ACCEL_REG_DATA_IN    0x44u
#define ASCON_ACCEL_REG_DATA_OUT   0x48u
#define ASCON_ACCEL_REG_DOUT_META  0x4cu
#define ASCON_ACCEL_REG_RESULT0    0x50u
#define ASCON_ACCEL_REG_RESULT1    0x54u
#define ASCON_ACCEL_REG_RESULT2    0x58u
#define ASCON_ACCEL_REG_RESULT3    0x5cu
#define ASCON_ACCEL_REG_LEVELS     0x60u

/* CTRL write bits. */
#define ASCON_ACCEL_CTRL_START      (1u << 0)
#define ASCON_ACCEL_CTRL_CLEAR      (1u << 1)
#define ASCON_ACCEL_CTRL_RESULT_ACK (1u << 2)

/* STATUS read bits. */
#define ASCON_ACCEL_STATUS_START_READY     (1u << 0)
#define ASCON_ACCEL_STATUS_BUSY            (1u << 1)
#define ASCON_ACCEL_STATUS_DONE            (1u << 2)
#define ASCON_ACCEL_STATUS_DOUT_VALID      (1u << 3)
#define ASCON_ACCEL_STATUS_RESULT_PENDING  (1u << 4)
#define ASCON_ACCEL_STATUS_AUTH_OK         (1u << 5)
#define ASCON_ACCEL_STATUS_AD_READY        (1u << 6)
#define ASCON_ACCEL_STATUS_DATA_READY      (1u << 7)
#define ASCON_ACCEL_STATUS_IRQ             (1u << 8)
#define ASCON_ACCEL_STATUS_DOUT_BYTES_MASK (7u << 9)
#define ASCON_ACCEL_STATUS_DOUT_LAST       (1u << 12)

/* DOUT_META read fields. */
#define ASCON_ACCEL_DOUT_META_BYTES_MASK   0x7u
#define ASCON_ACCEL_DOUT_META_LAST         (1u << 8)
#define ASCON_ACCEL_DOUT_META_VALID        (1u << 16)

typedef enum ascon_accel_status_e {
  ASCON_ACCEL_OK = 0,
  ASCON_ACCEL_ERR_TIMEOUT = -1,
  ASCON_ACCEL_ERR_BAD_ARG = -2,
  ASCON_ACCEL_ERR_AUTH = -3
} ascon_accel_status_t;

typedef struct ascon_accel_s {
  uintptr_t base;
  uint32_t timeout;
} ascon_accel_t;

void ascon_accel_init(ascon_accel_t *dev, uintptr_t base);
void ascon_accel_set_timeout(ascon_accel_t *dev, uint32_t timeout);
void ascon_accel_clear(const ascon_accel_t *dev);
uint32_t ascon_accel_status(const ascon_accel_t *dev);

int ascon_accel_encrypt(const ascon_accel_t *dev,
                        const uint8_t key[16],
                        const uint8_t nonce[16],
                        const uint8_t *ad,
                        size_t ad_len,
                        const uint8_t *plaintext,
                        uint8_t *ciphertext,
                        size_t msg_len,
                        uint8_t tag[16]);

int ascon_accel_decrypt(const ascon_accel_t *dev,
                        const uint8_t key[16],
                        const uint8_t nonce[16],
                        const uint8_t *ad,
                        size_t ad_len,
                        const uint8_t *ciphertext,
                        uint8_t *plaintext,
                        size_t msg_len,
                        const uint8_t tag[16]);

#ifdef __cplusplus
}
#endif

#endif /* ASCON_ACCEL_H */
