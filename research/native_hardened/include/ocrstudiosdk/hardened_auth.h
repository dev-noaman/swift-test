/**
 * OCRStudioSDK — native hardened auth (authorized security research)
 *
 * Drop-in C API for CreateSessionHardened gate verification.
 * Gate order MUST match CLAUDE.md / HardenedAuthVerifier.swift.
 *
 * Vendor: implement Ed25519 via libsodium (reference) or BearSSL/HACL* in-tree.
 */

#ifndef OCRSTUDIOSDK_HARDENED_AUTH_H_INCLUDED
#define OCRSTUDIOSDK_HARDENED_AUTH_H_INCLUDED

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef enum OCRAuthGateStatus {
  OCRAuthGateStatusOK = 0,
  OCRAuthGateStatusLegacyFail = 1,
  OCRAuthGateStatusJWTSignatureBad = 2,
  OCRAuthGateStatusJWTExpired = 3,
  OCRAuthGateStatusBuildMismatch = 4,
  OCRAuthGateStatusConfigMismatch = 5,
  OCRAuthGateStatusNonceReused = 6,
  OCRAuthGateStatusCodeHashBad = 7,
  OCRAuthGateStatusVCIHFail = 8
} OCRAuthGateStatus;

/** Baked policy constants for one library build (vendor embeds per SKU). */
typedef struct OCRHardenedAuthPolicy {
  const char* client_id;          /* claims.sub */
  const char* lib_build_id;       /* claims.lib_build_id */
  const char* platform;           /* claims.platform */
  const char* audience;           /* claims.aud */
  const uint8_t* server_pubkey;   /* 32-byte Ed25519 public key */
  int64_t max_token_lifetime_sec; /* 48h hard cap */
  int64_t clock_skew_sec;         /* ±300s */
  int64_t iat_floor;              /* reject iat < this (2026-01-01Z) */
  int offline_sku;                /* non-zero: empty JWT allowed */
} OCRHardenedAuthPolicy;

/** Optional anti-patch hooks (P3). NULL → treated as pass (reference default). */
typedef struct OCRHardenedIntegrityHooks {
  int (*code_region_hash_ok)(void* ctx);
  int (*vcih_ok)(void* ctx);
  void* ctx;
} OCRHardenedIntegrityHooks;

/** Opaque nonce LRU (process-lifetime replay cache). */
typedef struct OCRNonceLRU OCRNonceLRU;

OCRNonceLRU* ocr_nonce_lru_create(size_t capacity);
void ocr_nonce_lru_destroy(OCRNonceLRU* lru);

/**
 * Verify compact EdDSA JWT. Returns OCRAuthGateStatusOK only if all gates pass.
 * @param config_sha256_hex  lowercase/uppercase hex SHA-256 of on-disk config
 * @param now_sec            unix epoch (injectable for tests)
 */
OCRAuthGateStatus ocr_hardened_auth_verify(
    const OCRHardenedAuthPolicy* policy,
    OCRNonceLRU* nonces,
    const OCRHardenedIntegrityHooks* integrity, /* nullable */
    const char* jwt,
    const char* config_sha256_hex,
    int64_t now_sec);

/** True if signature is exactly 256 hex characters. */
int ocr_legacy_sig_well_formed(const char* hex256);

/**
 * Phase-3 native entry helper:
 *  1) legacy smoke (256-hex)
 *  2) JWT gates (unless offline_sku && jwt empty)
 * Does NOT create an OCRStudioSDKSession — ObjC++ wrapper does that after OK.
 */
OCRAuthGateStatus ocr_create_session_hardened_check(
    const OCRHardenedAuthPolicy* policy,
    OCRNonceLRU* nonces,
    const OCRHardenedIntegrityHooks* integrity,
    const char* legacy_sig_hex,
    const char* attestation_jwt,
    const char* config_sha256_hex,
    int64_t now_sec);

#ifdef __cplusplus
}
#endif

#endif /* OCRSTUDIOSDK_HARDENED_AUTH_H_INCLUDED */
