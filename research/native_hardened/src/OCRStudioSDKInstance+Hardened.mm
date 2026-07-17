/**
 * ObjC++ CreateSessionHardened — vendor merge target.
 *
 * Compile only when linking against the real OBJCOCRStudioSDKInstance + libsodium
 * + hardened_auth.cpp. Codemagic CI builds the C++ selftest separately.
 */

#import "objcocrstudiosdk/OCRStudioSDKInstance+Hardened.h"

#include "ocrstudiosdk/hardened_auth.h"

#include <mutex>
#include <string>

/* Vendor replaces these baked constants per SKU / build. */
static const char* kClientId = "ocrstudio_arafatgroup_trial";
static const char* kBuildId = "1.3.1-ios-arm64-trial-2026Q3";
static const char* kPlatform = "ios";
static const char* kAudience = "ocrstudio-sdk";
/* Placeholder — vendor must bake the real Ed25519 public key for their mint server. */
static const uint8_t kServerPubKey[32] = {0};

static OCRNonceLRU* SharedNonces() {
  static OCRNonceLRU* lru = ocr_nonce_lru_create(1000000);
  return lru;
}

static OCRHardenedAuthPolicy MakePolicy() {
  OCRHardenedAuthPolicy p{};
  p.client_id = kClientId;
  p.lib_build_id = kBuildId;
  p.platform = kPlatform;
  p.audience = kAudience;
  p.server_pubkey = kServerPubKey;
  p.max_token_lifetime_sec = 48 * 60 * 60;
  p.clock_skew_sec = 300;
  p.iat_floor = 1767225600; /* 2026-01-01Z */
  p.offline_sku = 0;
  return p;
}

@implementation OBJCOCRStudioSDKInstance (Hardened)

- (OBJCOCRStudioSDKSession *)createSessionHardenedWithSignature:(NSString *)legacySig
                                                    attestation:(NSString *)jwt
                                         withJsonSessionParams:(NSString *)paramsJSON
                                                configSHA256Hex:(NSString *)configSHA256Hex
                                                     gateStatus:(OCRAuthGateStatus *)outStatus
                                                          error:(NSError **)error
                                                       delegate:(id<OBJCOCRStudioSDKDelegate>)delegate {
  OCRHardenedAuthPolicy policy = MakePolicy();
  OCRAuthGateStatus st = (OCRAuthGateStatus)ocr_create_session_hardened_check(
      &policy,
      SharedNonces(),
      nullptr,
      legacySig.UTF8String,
      jwt.UTF8String ?: "",
      configSHA256Hex.UTF8String,
      (int64_t)[[NSDate date] timeIntervalSince1970]);

  if (outStatus) *outStatus = st;
  if (st != OCRAuthGateStatusOK) {
    if (error) {
      *error = [NSError errorWithDomain:@"ai.ocrstudio.sdk.auth"
                                   code:(NSInteger)st
                               userInfo:@{NSLocalizedDescriptionKey:
                                            [NSString stringWithFormat:@"hardened gate failed: %ld", (long)st]}];
    }
    return nil;
  }

  /* Gates passed — create the real session (legacy VSA still runs inside the closed binary). */
  return [self createSession:legacySig
       withJsonSessionParams:paramsJSON
                withDelegate:delegate];
}

@end
