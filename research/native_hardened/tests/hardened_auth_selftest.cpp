/**
 * Codemagic / local self-test for native hardened_auth.
 * Token minted with PyNaCl (same seed as research/verification tests).
 */

#include "ocrstudiosdk/hardened_auth.h"

#include <cstdio>
#include <cstring>
#include <string>

#include <sodium.h>

static int failures = 0;

static void expect(bool ok, const char* name) {
  if (!ok) {
    std::fprintf(stderr, "FAIL: %s\n", name);
    ++failures;
  } else {
    std::printf("PASS: %s\n", name);
  }
}

/* seed 001122...ccddeeff → pubkey */
static const uint8_t kPub[32] = {
    0x3c, 0xcd, 0x24, 0x1c, 0xff, 0xc9, 0xb3, 0x61, 0x80, 0x44, 0xb9, 0x7d,
    0x03, 0x6d, 0x86, 0x14, 0x59, 0x3d, 0x8b, 0x01, 0x7c, 0x34, 0x0f, 0x1d,
    0xee, 0x87, 0x73, 0x38, 0x55, 0x17, 0x65, 0x4b};

static const char* kCfg =
    "2daa12d34c0f3d4e19aaef99ea99e3e7ca43d11dccffa09ca5751c9b292b6fdd";

static const char* kJwt =
    "eyJhbGciOiJFZERTQSIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJvY3JzdHVkaW9fYXJhZmF0Z3JvdXBfdHJp"
    "YWwiLCJsaWJfYnVpbGRfaWQiOiIxLjMuMS1pb3MtYXJtNjQtdHJpYWwtMjAyNlEzIiwicGxhdGZvcm0i"
    "OiJpb3MiLCJjb25maWdfc2hhMjU2IjoiMmRhYTEyZDM0YzBmM2Q0ZTE5YWFlZjk5ZWE5OWUzZTdjYTQz"
    "ZDExZGNjZmZhMDljYTU3NTFjOWIyOTJiNmZkZCIsImlhdCI6MTc4NDMzMjgwMCwiZXhwIjoxNzg0NDE5"
    "MjAwLCJub25jZSI6ImEzZjFiYzllLTAwMDAtNDAwMC04MDAwLTAwMDAwMDAwMDAwMSIsImF1ZCI6Im9j"
    "cnN0dWRpby1zZGsifQ.X7GUaaOU-Oczx9tVKT8a8ODFOwywM6e0kq7MBNYXqsQ0-rI-0L3vmDGf3BL4_"
    "MqXj1PtEipaIJWvs_LVZ7D0AQ";

static const int64_t kNow = 1784332800;

/* 256 hex of 'a' — well-formed legacy smoke only */
static std::string FakeLegacySig() { return std::string(256, 'a'); }

static OCRHardenedAuthPolicy Policy(const char* build = "1.3.1-ios-arm64-trial-2026Q3") {
  OCRHardenedAuthPolicy p{};
  p.client_id = "ocrstudio_arafatgroup_trial";
  p.lib_build_id = build;
  p.platform = "ios";
  p.audience = "ocrstudio-sdk";
  p.server_pubkey = kPub;
  p.max_token_lifetime_sec = 48 * 60 * 60;
  p.clock_skew_sec = 300;
  p.iat_floor = 1767225600;
  p.offline_sku = 0;
  return p;
}

int main() {
  if (sodium_init() < 0) {
    std::fprintf(stderr, "sodium_init failed\n");
    return 2;
  }

  OCRNonceLRU* lru = ocr_nonce_lru_create(1024);
  auto p = Policy();
  std::string legacy = FakeLegacySig();

  expect(ocr_create_session_hardened_check(&p, lru, nullptr, legacy.c_str(), "", kCfg, kNow) ==
             OCRAuthGateStatusJWTSignatureBad,
         "fully_patched_rejects_empty_jwt");

  expect(ocr_create_session_hardened_check(&p, lru, nullptr, "short", kJwt, kCfg, kNow) ==
             OCRAuthGateStatusLegacyFail,
         "malformed_legacy_rejected");

  expect(ocr_create_session_hardened_check(&p, lru, nullptr, legacy.c_str(), kJwt, kCfg, kNow) ==
             OCRAuthGateStatusOK,
         "valid_jwt_accepted");

  expect(ocr_create_session_hardened_check(&p, lru, nullptr, legacy.c_str(), kJwt, kCfg, kNow) ==
             OCRAuthGateStatusNonceReused,
         "nonce_replay_rejected");

  OCRNonceLRU* lru2 = ocr_nonce_lru_create(1024);
  auto wrong_build = Policy("9.9.9-ios-arm64-attacker-build");
  expect(ocr_create_session_hardened_check(&wrong_build, lru2, nullptr, legacy.c_str(), kJwt, kCfg,
                                           kNow) == OCRAuthGateStatusBuildMismatch,
         "build_mismatch_rejected");

  OCRNonceLRU* lru3 = ocr_nonce_lru_create(1024);
  expect(ocr_create_session_hardened_check(&p, lru3, nullptr, legacy.c_str(), kJwt,
                                           "00" /* wrong */, kNow) ==
             OCRAuthGateStatusConfigMismatch,
         "config_mismatch_rejected");

  ocr_nonce_lru_destroy(lru);
  ocr_nonce_lru_destroy(lru2);
  ocr_nonce_lru_destroy(lru3);

  if (failures) {
    std::fprintf(stderr, "\n%d failure(s)\n", failures);
    return 1;
  }
  std::printf("\nNATIVE HARDENED SELFTEST: ALL PASS\n");
  return 0;
}
