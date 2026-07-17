/**
 * Native hardened auth verifier — authorized security research reference.
 * Wire contract matches research/verification HardenedAuth (Swift) + reference_server_mint.py.
 */

#include "ocrstudiosdk/hardened_auth.h"

#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <string>
#include <unordered_set>
#include <vector>

#include "ed25519_verify.h" /* backend-agnostic: portable default or -DUSE_LIBSODIUM */

struct OCRNonceLRU {
  size_t capacity;
  std::vector<std::string> order;
  std::unordered_set<std::string> set;
};

static int hex_nibble(char c) {
  if (c >= '0' && c <= '9') return c - '0';
  if (c >= 'a' && c <= 'f') return c - 'a' + 10;
  if (c >= 'A' && c <= 'F') return c - 'A' + 10;
  return -1;
}

static int streq(const char* a, const char* b) {
  if (!a || !b) return 0;
  return strcmp(a, b) == 0;
}

static int strieq_hex(const char* a, const char* b) {
  if (!a || !b) return 0;
  while (*a && *b) {
    char ca = (char)tolower((unsigned char)*a++);
    char cb = (char)tolower((unsigned char)*b++);
    if (ca != cb) return 0;
  }
  return *a == 0 && *b == 0;
}

/* base64url → bytes. returns 0 on success. */
static int b64url_decode(const char* in, size_t in_len, std::vector<uint8_t>* out) {
  static const char* tbl =
      "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
  std::string s(in, in_len);
  for (char& c : s) {
    if (c == '-') c = '+';
    else if (c == '_') c = '/';
  }
  while (s.size() % 4) s.push_back('=');

  out->clear();
  out->reserve((s.size() / 4) * 3);
  int val = 0, valb = -8;
  for (unsigned char c : s) {
    if (c == '=') break;
    const char* p = strchr(tbl, c);
    if (!p) return -1;
    val = (val << 6) + (int)(p - tbl);
    valb += 6;
    if (valb >= 0) {
      out->push_back((uint8_t)((val >> valb) & 0xFF));
      valb -= 8;
    }
  }
  return 0;
}

/* Minimal JSON string/int field extractors (payload is flat object). */
static int json_get_string(const char* json, const char* key, std::string* out) {
  std::string pat = std::string("\"") + key + "\":\"";
  const char* p = strstr(json, pat.c_str());
  if (!p) return -1;
  p += pat.size();
  const char* e = strchr(p, '"');
  if (!e) return -1;
  out->assign(p, e - p);
  return 0;
}

static int json_get_int64(const char* json, const char* key, int64_t* out) {
  std::string pat = std::string("\"") + key + "\":";
  const char* p = strstr(json, pat.c_str());
  if (!p) return -1;
  p += pat.size();
  char* end = nullptr;
  long long v = strtoll(p, &end, 10);
  if (end == p) return -1;
  *out = (int64_t)v;
  return 0;
}

OCRNonceLRU* ocr_nonce_lru_create(size_t capacity) {
  auto* l = new OCRNonceLRU();
  l->capacity = capacity ? capacity : 1;
  return l;
}

void ocr_nonce_lru_destroy(OCRNonceLRU* lru) { delete lru; }

static int nonce_admit(OCRNonceLRU* lru, const std::string& nonce) {
  if (!lru) return 1;
  if (lru->set.count(nonce)) return 0;
  lru->set.insert(nonce);
  lru->order.push_back(nonce);
  if (lru->order.size() > lru->capacity) {
    lru->set.erase(lru->order.front());
    lru->order.erase(lru->order.begin());
  }
  return 1;
}

int ocr_legacy_sig_well_formed(const char* hex256) {
  if (!hex256) return 0;
  size_t n = strlen(hex256);
  if (n != 256) return 0;
  for (size_t i = 0; i < n; ++i) {
    if (hex_nibble(hex256[i]) < 0) return 0;
  }
  return 1;
}

OCRAuthGateStatus ocr_hardened_auth_verify(
    const OCRHardenedAuthPolicy* policy,
    OCRNonceLRU* nonces,
    const OCRHardenedIntegrityHooks* integrity,
    const char* jwt,
    const char* config_sha256_hex,
    int64_t now_sec) {
  if (!policy || !jwt || !config_sha256_hex || !policy->server_pubkey) {
    return OCRAuthGateStatusJWTSignatureBad;
  }

  /* Split jwt into 3 parts */
  const char* p1 = strchr(jwt, '.');
  if (!p1) return OCRAuthGateStatusJWTSignatureBad;
  const char* p2 = strchr(p1 + 1, '.');
  if (!p2) return OCRAuthGateStatusJWTSignatureBad;
  if (strchr(p2 + 1, '.')) return OCRAuthGateStatusJWTSignatureBad;

  size_t hlen = (size_t)(p1 - jwt);
  size_t plen = (size_t)(p2 - (p1 + 1));
  const char* sig_b64 = p2 + 1;
  size_t slen = strlen(sig_b64);

  std::string signing_input(jwt, (size_t)(p2 - jwt)); /* header.payload */

  std::vector<uint8_t> sig;
  if (b64url_decode(sig_b64, slen, &sig) != 0 || sig.size() != 64) {
    return OCRAuthGateStatusJWTSignatureBad;
  }

  if (hardened_ed25519_verify(sig.data(),
                              (const unsigned char*)signing_input.data(),
                              (unsigned long long)signing_input.size(),
                              policy->server_pubkey) != 1) {
    return OCRAuthGateStatusJWTSignatureBad;
  }

  std::vector<uint8_t> payload_raw;
  if (b64url_decode(p1 + 1, plen, &payload_raw) != 0) {
    return OCRAuthGateStatusJWTSignatureBad;
  }
  payload_raw.push_back(0);
  const char* payload = (const char*)payload_raw.data();

  std::string sub, build, platform, cfg, nonce, aud;
  int64_t iat = 0, exp = 0;
  if (json_get_string(payload, "sub", &sub) ||
      json_get_string(payload, "lib_build_id", &build) ||
      json_get_string(payload, "platform", &platform) ||
      json_get_string(payload, "config_sha256", &cfg) ||
      json_get_string(payload, "nonce", &nonce) ||
      json_get_string(payload, "aud", &aud) ||
      json_get_int64(payload, "iat", &iat) ||
      json_get_int64(payload, "exp", &exp)) {
    return OCRAuthGateStatusJWTSignatureBad;
  }

  int64_t skew = policy->clock_skew_sec;
  if (iat < policy->iat_floor) return OCRAuthGateStatusJWTExpired;
  if (iat - skew > now_sec) return OCRAuthGateStatusJWTExpired;
  if (exp <= now_sec - skew) return OCRAuthGateStatusJWTExpired;
  if ((exp - iat) > policy->max_token_lifetime_sec) return OCRAuthGateStatusJWTExpired;

  if (!streq(aud.c_str(), policy->audience)) return OCRAuthGateStatusJWTSignatureBad;
  if (!streq(sub.c_str(), policy->client_id)) return OCRAuthGateStatusBuildMismatch;
  if (!streq(platform.c_str(), policy->platform)) return OCRAuthGateStatusBuildMismatch;
  if (!streq(build.c_str(), policy->lib_build_id)) return OCRAuthGateStatusBuildMismatch;
  if (!strieq_hex(cfg.c_str(), config_sha256_hex)) return OCRAuthGateStatusConfigMismatch;

  if (!nonce_admit(nonces, nonce)) return OCRAuthGateStatusNonceReused;

  if (integrity) {
    if (integrity->code_region_hash_ok && !integrity->code_region_hash_ok(integrity->ctx)) {
      return OCRAuthGateStatusCodeHashBad;
    }
    if (integrity->vcih_ok && !integrity->vcih_ok(integrity->ctx)) {
      return OCRAuthGateStatusVCIHFail;
    }
  }

  return OCRAuthGateStatusOK;
}

OCRAuthGateStatus ocr_create_session_hardened_check(
    const OCRHardenedAuthPolicy* policy,
    OCRNonceLRU* nonces,
    const OCRHardenedIntegrityHooks* integrity,
    const char* legacy_sig_hex,
    const char* attestation_jwt,
    const char* config_sha256_hex,
    int64_t now_sec) {
  if (!ocr_legacy_sig_well_formed(legacy_sig_hex)) {
    return OCRAuthGateStatusLegacyFail;
  }
  if (!attestation_jwt || attestation_jwt[0] == '\0') {
    if (policy && policy->offline_sku) {
      return OCRAuthGateStatusOK;
    }
    return OCRAuthGateStatusJWTSignatureBad;
  }
  return ocr_hardened_auth_verify(policy, nonces, integrity, attestation_jwt,
                                  config_sha256_hex, now_sec);
}
