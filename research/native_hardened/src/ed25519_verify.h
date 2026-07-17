/*
 * ed25519_verify.h -- backend-agnostic Ed25519 verify entry.
 * Implemented by ed25519_verify_portable.c (portable default or -DUSE_LIBSODIUM).
 */
#ifndef HARDENED_ED25519_VERIFY_H
#define HARDENED_ED25519_VERIFY_H

#ifdef __cplusplus
extern "C" {
#endif

/* Returns 1 iff `sig` (64 bytes) is a valid Ed25519 signature by `pk`
 * (32 bytes) over msg[0..mlen). Returns 0 on any failure. */
int hardened_ed25519_verify(const unsigned char sig[64],
                            const unsigned char *msg, unsigned long long mlen,
                            const unsigned char pk[32]);

#ifdef __cplusplus
}
#endif
#endif
