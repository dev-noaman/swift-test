/**
 * OCRStudioSDK — ObjC++ CreateSessionHardened (authorized security research)
 *
 * Drop-in category matching VALIDATION_PACKAGE.md §6.6.
 * Vendor: add this header to the public wrap surface and link hardened_auth.cpp.
 */

#ifndef OBJCOCRSTUDIOSDK_INSTANCE_HARDENED_H_INCLUDED
#define OBJCOCRSTUDIOSDK_INSTANCE_HARDENED_H_INCLUDED

#import <Foundation/Foundation.h>
#import <objcocrstudiosdk/ocr_studio_instance.h>
#import <objcocrstudiosdk/ocr_studio_delegate.h>

typedef NS_ENUM(NSInteger, OCRAuthGateStatus) {
  OCRAuthGateStatusOK = 0,
  OCRAuthGateStatusLegacyFail = 1,
  OCRAuthGateStatusJWTSignatureBad = 2,
  OCRAuthGateStatusJWTExpired = 3,
  OCRAuthGateStatusBuildMismatch = 4,
  OCRAuthGateStatusConfigMismatch = 5,
  OCRAuthGateStatusNonceReused = 6,
  OCRAuthGateStatusCodeHashBad = 7,
  OCRAuthGateStatusVCIHFail = 8,
};

NS_ASSUME_NONNULL_BEGIN

@interface OBJCOCRStudioSDKInstance (Hardened)

/**
 * Phase-3 entry: verify attestation JWT, then create a session via legacy
 * createSession only if all hardened gates pass.
 *
 * @param configSHA256Hex  SHA-256 (hex) of the loaded .ocr config bytes
 * @param outStatus        optional; set to gate result (0 = OK)
 */
- (nullable OBJCOCRStudioSDKSession *)createSessionHardenedWithSignature:(NSString *)legacySig
                                                             attestation:(NSString *)jwt
                                                  withJsonSessionParams:(NSString *)paramsJSON
                                                         configSHA256Hex:(NSString *)configSHA256Hex
                                                              gateStatus:(nullable OCRAuthGateStatus *)outStatus
                                                                   error:(NSError * _Nullable * _Nullable)error
                                                                delegate:(nullable id<OBJCOCRStudioSDKDelegate>)delegate;

@end

NS_ASSUME_NONNULL_END

#endif /* OBJCOCRSTUDIOSDK_INSTANCE_HARDENED_H_INCLUDED */
