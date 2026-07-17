/**
  Copyright (c) 2024-2026, OCR Studio
  All rights reserved.
*/

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

#import <objcocrstudiosdk/ocr_studio_result.h>
#import <objcocrstudiosdk/ocr_studio_instance.h>
#import <objcocrstudiosdk/ocr_studio_image.h>

@protocol OCRStudioSDKDelegate <NSObject>
@optional
- (void) OCRStudioSDKObtainedResult:(nonnull OBJCOCRStudioSDKResult *)result
            fromFrameWithBuffer:(nonnull CMSampleBufferRef)buffer;
- (void) OCRStudioSDKObtainedMessage:(nonnull NSString *)json_message;
- (void) OCRStudioSDKObtainedSingleImageResult:(nonnull OBJCOCRStudioSDKResult *)result;
- (void) OCRStudioSDKSessionEnded;
@end

@protocol OCRStudioSDKInitializationDelegate <NSObject>
@optional
- (void) OCRStudioSDKInitialized;
- (void) OCRStudioSDKVideoSessionStarted;
- (void) OCRStudioSDKVideoSessionDismissed;
@end

@interface OCRStudioSDKSessionParameters : NSObject

@property (nonatomic, readonly, strong, nullable) NSString *session_type;
@property (nonatomic, readonly, strong, nullable) NSString *target_group_type;
@property (nonatomic, readonly, strong, nullable) NSArray<NSString *> *target_masks;
@property (nonatomic, readonly, strong, nullable) NSString *output_modes;
@property (nonatomic, readonly, strong, nullable) NSMutableDictionary *options;

- (nonnull NSString *)jsonString;

- (void)setSessionType:(nonnull NSString *)session_type;

- (void)setTargetGroupType:(nonnull NSString *)target_group_type;
- (void)setTargetMasks:(nonnull NSArray<NSString *>*)target_masks;
- (void)addTargetMask:(nonnull NSString *)target_mask;
- (void)clearTargetMasks;

- (nonnull NSString *)getSessionType;
- (nonnull NSString *)getTargetGroupType;
- (nonnull NSArray<NSString *>*)getTargetMasks;

- (void)setOptionWithName:(nonnull NSString *)name
                        to:(nonnull NSString *)value;
- (void)removeOptionWithName:(nonnull NSString *)name;
- (void)clearOptions;

@end

@interface OCRStudioSDKInstance : NSObject

@property (weak, nonatomic, nullable, readonly) id<OCRStudioSDKDelegate> engineDelegate;
@property (weak, nonatomic, nullable, readonly) id<OCRStudioSDKInitializationDelegate> initializationDelegate;

@property (strong, nullable, readonly) OBJCOCRStudioSDKInstance* engine; // main configuration of OCRStudioSDK Engine
@property (strong, nullable, readonly) OBJCOCRStudioSDKSession* session; // current video recognition session
@property (strong, nullable)  OCRStudioSDKSessionParameters* session_params; // current session params

@property BOOL engineInitialized;
@property BOOL videoSessionRunning;
@property BOOL sessionEnded;
@property (nonatomic, strong, nullable) NSString * currentInstruction;
@property (nonatomic, readonly, strong, nullable) NSDictionary *instructions;

/// When YES (default), initVideoSession runs CreateSessionHardened gates (JWT) before legacy createSession.
@property (nonatomic, assign) BOOL hardenedAuthEnabled;
/// Optional override JWT from vendor Auth Server; if nil, trial auto-mint is used when hardenedAuthEnabled.
@property (nonatomic, copy, nullable) NSString *attestationJWT;
/// Baked library build id for JWT binding (default trial build id).
@property (nonatomic, copy, nonnull) NSString *libBuildId;

- (nonnull instancetype) initWithSignature:(nonnull NSString *)signature;
- (void) setEngineDelegate:(nullable __weak id<OCRStudioSDKDelegate>)delegate;
- (void) setInitializationDelegate:(nullable __weak id<OCRStudioSDKInitializationDelegate>)delegate;

- (void) initializeEngine:(nonnull NSString *)configPath;

- (void) initVideoSession;

- (void) dismissVideoSession;
- (void) dismissVideoSessionRunning;

- (void) suspendSession;
- (void) resumeSession;

- (void) processFrame:(nonnull CMSampleBufferRef)sampleBuffer
      withOrientation:(UIDeviceOrientation)deviceOrientation;

- (void) processFrame:(nonnull CMSampleBufferRef)sampleBuffer
      withOrientation:(UIDeviceOrientation)deviceOrientation
               andRoi:(CGRect)roi;

- (nonnull OBJCOCRStudioSDKResult*) processSingleImage:(nonnull OBJCOCRStudioSDKImageRef *)image;
- (nonnull OBJCOCRStudioSDKResult*) processSingleImageFromFile:(nonnull NSString *)filePath;
- (nonnull OBJCOCRStudioSDKResult*) processSingleImageFromUIImage:(nonnull UIImage *)image;

- (nonnull OBJCOCRStudioSDKResult*) processData:(nonnull NSString *)data;
- (nonnull OBJCOCRStudioSDKResult*) processSelfie:(nonnull UIImage *)image;

- (nonnull OBJCOCRStudioSDKResult *) compareFacesFromDocument:(nonnull OBJCOCRStudioSDKImageRef *)photo
                                                    andSelfie:(nonnull OBJCOCRStudioSDKImageRef *)image;

@end

