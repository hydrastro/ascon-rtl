#include "ascon_accel.h"

static volatile uint32_t *reg_ptr(const ascon_accel_t *dev, uint32_t offset) {
  return (volatile uint32_t *)(dev->base + (uintptr_t)offset);
}

static void reg_write(const ascon_accel_t *dev, uint32_t offset, uint32_t value) {
  *reg_ptr(dev, offset) = value;
}

static uint32_t reg_read(const ascon_accel_t *dev, uint32_t offset) {
  return *reg_ptr(dev, offset);
}

static uint32_t load_le32_partial(const uint8_t *src, size_t remaining) {
  uint32_t value = 0;
  if (remaining > 0) value |= ((uint32_t)src[0]) << 0;
  if (remaining > 1) value |= ((uint32_t)src[1]) << 8;
  if (remaining > 2) value |= ((uint32_t)src[2]) << 16;
  if (remaining > 3) value |= ((uint32_t)src[3]) << 24;
  return value;
}

static void store_le32_partial(uint8_t *dst, uint32_t value, size_t remaining) {
  if (remaining > 0) dst[0] = (uint8_t)(value >> 0);
  if (remaining > 1) dst[1] = (uint8_t)(value >> 8);
  if (remaining > 2) dst[2] = (uint8_t)(value >> 16);
  if (remaining > 3) dst[3] = (uint8_t)(value >> 24);
}

static uint32_t timeout_limit(const ascon_accel_t *dev) {
  return dev->timeout ? dev->timeout : ASCON_ACCEL_DEFAULT_TIMEOUT;
}

static int wait_status_set(const ascon_accel_t *dev, uint32_t mask) {
  uint32_t guard = timeout_limit(dev);
  while (guard--) {
    if (reg_read(dev, ASCON_ACCEL_REG_STATUS) & mask) {
      return ASCON_ACCEL_OK;
    }
  }
  return ASCON_ACCEL_ERR_TIMEOUT;
}

static int wait_ad_ready(const ascon_accel_t *dev) {
  return wait_status_set(dev, ASCON_ACCEL_STATUS_AD_READY);
}

static int wait_data_ready(const ascon_accel_t *dev) {
  return wait_status_set(dev, ASCON_ACCEL_STATUS_DATA_READY);
}

static int wait_dout_valid(const ascon_accel_t *dev, uint32_t *meta) {
  uint32_t guard = timeout_limit(dev);
  while (guard--) {
    uint32_t m = reg_read(dev, ASCON_ACCEL_REG_DOUT_META);
    if (m & ASCON_ACCEL_DOUT_META_VALID) {
      *meta = m;
      return ASCON_ACCEL_OK;
    }
  }
  return ASCON_ACCEL_ERR_TIMEOUT;
}

static int wait_result(const ascon_accel_t *dev, uint32_t *status) {
  uint32_t guard = timeout_limit(dev);
  while (guard--) {
    uint32_t s = reg_read(dev, ASCON_ACCEL_REG_STATUS);
    if (s & ASCON_ACCEL_STATUS_RESULT_PENDING) {
      *status = s;
      return ASCON_ACCEL_OK;
    }
  }
  return ASCON_ACCEL_ERR_TIMEOUT;
}

/*
 * KEY/NONCE/TAG registers expose the internal 128-bit Ascon layout:
 *   raw[127:64] = LOADBYTES(bytes[0..7])
 *   raw[63:0]   = LOADBYTES(bytes[8..15])
 * with word0 at raw[31:0]. Therefore byte-array order maps to registers as
 *   reg0 = bytes[8..11],  reg1 = bytes[12..15],
 *   reg2 = bytes[0..3],   reg3 = bytes[4..7].
 */
static void write_ascon128_bytes(const ascon_accel_t *dev, uint32_t base, const uint8_t x[16]) {
  reg_write(dev, base + 0x00u, load_le32_partial(x + 8, 4));
  reg_write(dev, base + 0x04u, load_le32_partial(x + 12, 4));
  reg_write(dev, base + 0x08u, load_le32_partial(x + 0, 4));
  reg_write(dev, base + 0x0cu, load_le32_partial(x + 4, 4));
}

static void read_ascon128_bytes(const ascon_accel_t *dev, uint32_t base, uint8_t x[16]) {
  uint32_t w0 = reg_read(dev, base + 0x00u);
  uint32_t w1 = reg_read(dev, base + 0x04u);
  uint32_t w2 = reg_read(dev, base + 0x08u);
  uint32_t w3 = reg_read(dev, base + 0x0cu);
  store_le32_partial(x + 8,  w0, 4);
  store_le32_partial(x + 12, w1, 4);
  store_le32_partial(x + 0,  w2, 4);
  store_le32_partial(x + 4,  w3, 4);
}

static int write_stream_words(const ascon_accel_t *dev, uint32_t offset,
                              const uint8_t *src, size_t len,
                              uint32_t ready_mask) {
  size_t pos = 0;
  while (pos < len) {
    int rc;
    if (ready_mask == ASCON_ACCEL_STATUS_AD_READY) {
      rc = wait_ad_ready(dev);
    } else {
      rc = wait_data_ready(dev);
    }
    if (rc != ASCON_ACCEL_OK) {
      return rc;
    }
    size_t remaining = len - pos;
    reg_write(dev, offset, load_le32_partial(src + pos, remaining));
    pos += (remaining >= 4u) ? 4u : remaining;
  }
  return ASCON_ACCEL_OK;
}

static int read_stream_words(const ascon_accel_t *dev, uint8_t *dst, size_t len) {
  size_t pos = 0;
  while (pos < len) {
    uint32_t meta;
    int rc = wait_dout_valid(dev, &meta);
    if (rc != ASCON_ACCEL_OK) {
      return rc;
    }

    uint32_t word = reg_read(dev, ASCON_ACCEL_REG_DATA_OUT);
    size_t bytes = (size_t)(meta & ASCON_ACCEL_DOUT_META_BYTES_MASK);
    size_t remaining = len - pos;
    if (bytes == 0u || bytes > 4u || bytes > remaining) {
      return ASCON_ACCEL_ERR_BAD_ARG;
    }

    store_le32_partial(dst + pos, word, bytes);
    pos += bytes;
  }
  return ASCON_ACCEL_OK;
}

void ascon_accel_init(ascon_accel_t *dev, uintptr_t base) {
  if (!dev) {
    return;
  }
  dev->base = base;
  dev->timeout = ASCON_ACCEL_DEFAULT_TIMEOUT;
}

void ascon_accel_set_timeout(ascon_accel_t *dev, uint32_t timeout) {
  if (!dev) {
    return;
  }
  dev->timeout = timeout;
}

void ascon_accel_clear(const ascon_accel_t *dev) {
  reg_write(dev, ASCON_ACCEL_REG_CTRL, ASCON_ACCEL_CTRL_CLEAR);
}

uint32_t ascon_accel_status(const ascon_accel_t *dev) {
  return reg_read(dev, ASCON_ACCEL_REG_STATUS);
}

static int configure_job(const ascon_accel_t *dev,
                         const uint8_t key[16],
                         const uint8_t nonce[16],
                         const uint8_t tag_or_null[16],
                         size_t ad_len,
                         size_t msg_len) {
  if (!dev || !key || !nonce) {
    return ASCON_ACCEL_ERR_BAD_ARG;
  }
  if ((ad_len > UINT32_MAX) || (msg_len > UINT32_MAX)) {
    return ASCON_ACCEL_ERR_BAD_ARG;
  }

  ascon_accel_clear(dev);
  write_ascon128_bytes(dev, ASCON_ACCEL_REG_KEY0, key);
  write_ascon128_bytes(dev, ASCON_ACCEL_REG_NONCE0, nonce);
  if (tag_or_null) {
    write_ascon128_bytes(dev, ASCON_ACCEL_REG_TAG0, tag_or_null);
  }
  reg_write(dev, ASCON_ACCEL_REG_AD_BYTES, (uint32_t)ad_len);
  reg_write(dev, ASCON_ACCEL_REG_MSG_BYTES, (uint32_t)msg_len);
  return ASCON_ACCEL_OK;
}

int ascon_accel_encrypt(const ascon_accel_t *dev,
                        const uint8_t key[16],
                        const uint8_t nonce[16],
                        const uint8_t *ad,
                        size_t ad_len,
                        const uint8_t *plaintext,
                        uint8_t *ciphertext,
                        size_t msg_len,
                        uint8_t tag[16]) {
  if ((ad_len && !ad) || (msg_len && (!plaintext || !ciphertext)) || !tag) {
    return ASCON_ACCEL_ERR_BAD_ARG;
  }

  int rc = configure_job(dev, key, nonce, NULL, ad_len, msg_len);
  if (rc != ASCON_ACCEL_OK) return rc;

  rc = write_stream_words(dev, ASCON_ACCEL_REG_AD_IN, ad, ad_len, ASCON_ACCEL_STATUS_AD_READY);
  if (rc != ASCON_ACCEL_OK) return rc;
  rc = write_stream_words(dev, ASCON_ACCEL_REG_DATA_IN, plaintext, msg_len, ASCON_ACCEL_STATUS_DATA_READY);
  if (rc != ASCON_ACCEL_OK) return rc;

  if (wait_status_set(dev, ASCON_ACCEL_STATUS_START_READY) != ASCON_ACCEL_OK) {
    return ASCON_ACCEL_ERR_TIMEOUT;
  }
  reg_write(dev, ASCON_ACCEL_REG_CTRL, ASCON_ACCEL_CTRL_START);

  rc = read_stream_words(dev, ciphertext, msg_len);
  if (rc != ASCON_ACCEL_OK) return rc;

  uint32_t status = 0;
  rc = wait_result(dev, &status);
  if (rc != ASCON_ACCEL_OK) return rc;
  read_ascon128_bytes(dev, ASCON_ACCEL_REG_RESULT0, tag);
  reg_write(dev, ASCON_ACCEL_REG_CTRL, ASCON_ACCEL_CTRL_RESULT_ACK);

  return (status & ASCON_ACCEL_STATUS_AUTH_OK) ? ASCON_ACCEL_OK : ASCON_ACCEL_ERR_AUTH;
}

int ascon_accel_decrypt(const ascon_accel_t *dev,
                        const uint8_t key[16],
                        const uint8_t nonce[16],
                        const uint8_t *ad,
                        size_t ad_len,
                        const uint8_t *ciphertext,
                        uint8_t *plaintext,
                        size_t msg_len,
                        const uint8_t tag[16]) {
  if ((ad_len && !ad) || (msg_len && (!ciphertext || !plaintext)) || !tag) {
    return ASCON_ACCEL_ERR_BAD_ARG;
  }

  int rc = configure_job(dev, key, nonce, tag, ad_len, msg_len);
  if (rc != ASCON_ACCEL_OK) return rc;

  rc = write_stream_words(dev, ASCON_ACCEL_REG_AD_IN, ad, ad_len, ASCON_ACCEL_STATUS_AD_READY);
  if (rc != ASCON_ACCEL_OK) return rc;
  rc = write_stream_words(dev, ASCON_ACCEL_REG_DATA_IN, ciphertext, msg_len, ASCON_ACCEL_STATUS_DATA_READY);
  if (rc != ASCON_ACCEL_OK) return rc;

  if (wait_status_set(dev, ASCON_ACCEL_STATUS_START_READY) != ASCON_ACCEL_OK) {
    return ASCON_ACCEL_ERR_TIMEOUT;
  }
  reg_write(dev, ASCON_ACCEL_REG_CTRL, ASCON_ACCEL_CTRL_START);

  /* Plaintext is tentative until the final authentication result is checked. */
  rc = read_stream_words(dev, plaintext, msg_len);
  if (rc != ASCON_ACCEL_OK) return rc;

  uint32_t status = 0;
  rc = wait_result(dev, &status);
  if (rc != ASCON_ACCEL_OK) return rc;
  reg_write(dev, ASCON_ACCEL_REG_CTRL, ASCON_ACCEL_CTRL_RESULT_ACK);

  return (status & ASCON_ACCEL_STATUS_AUTH_OK) ? ASCON_ACCEL_OK : ASCON_ACCEL_ERR_AUTH;
}
