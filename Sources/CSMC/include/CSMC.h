#ifndef MACPULSE_CSMC_H
#define MACPULSE_CSMC_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Opens a connection to AppleSMCKeysEndpoint. Returns 0 on success.
int macpulse_smc_open(void);

/// Closes the current SMC connection. Safe to call when not open.
void macpulse_smc_close(void);

/// Returns the number of SMC keys exposed by this machine. Returns 0 on failure.
uint32_t macpulse_smc_key_count(void);

/// Copies a four-byte key name by index into out_key (must hold at least 5 bytes).
/// Returns 0 on success, -1 on failure.
int macpulse_smc_key_by_index(uint32_t index, char out_key[5]);

/// Reads a four-byte SMC key.
/// Returns 0 on success, -1 on transport failure, -2 when the key is missing,
/// -3 when the caller buffer is too small.
int macpulse_smc_read_key(const char *key,
                          uint32_t *out_data_size,
                          uint32_t *out_data_type,
                          uint8_t *out_bytes,
                          size_t out_capacity);

#ifdef __cplusplus
}
#endif

#endif
