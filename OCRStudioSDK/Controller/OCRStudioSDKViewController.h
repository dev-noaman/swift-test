/**
  Copyright (c) 2024-2026, OCR Studio
  All rights reserved.
*/

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

#import "OCRStudioSDKInstance.h"
#import "OCRStudioSDKCaptureButton.h"

@protocol OCRStudioSDKViewControllerDelegate <NSObject>

@optional

- (void) ocrViewControllerDidRecognize:(nonnull OBJCOCRStudioSDKResult *)result
                            fromBuffer:(nullable CMSampleBufferRef)buffer;

- (void) ocrViewControllerDidRecognizeSingleImage:(nonnull OBJCOCRStudioSDKResult *)result;

- (void) ocrViewControllerDidCancel;

- (void) ocrViewControllerDidStop:(nonnull OBJCOCRStudioSDKResult *)result;

- (void) ocrViewControllerDidGalleryPick;

- (void) ocrViewControllerReadyCheckSelfie:(nonnull OBJCOCRStudioSDKResult *)result;

@end

@class DocTypeLabel;

@interface OCRStudioSDKViewController : UIViewController <OCRStudioSDKDelegate,
OCRStudioSDKCameraButtonDelegate>

@property (weak, nullable) id<OCRStudioSDKViewControllerDelegate> ocrDelegate;

@property (nonatomic, assign) BOOL displayDocumentQuadrangle;
@property (nonatomic, assign) BOOL displayZonesQuadrangles;
@property (nonatomic, assign) BOOL displayProcessingFeedback;
@property (nonatomic, assign) BOOL enableOnTapFocus;
@property (nonatomic, assign) BOOL shouldDisplayRoi;
@property (nonatomic, assign) BOOL bestCameraDevice;
@property (nonatomic, assign) float quadranglesAlpha;
@property (nonatomic, assign) float quadranglesWidth;
@property (nonatomic, strong, nonnull) UIColor* quadranglesColor;
@property (nonatomic, strong, nonnull) UIColor* roiQuadranglesColor;
@property (nonatomic, strong, nonnull) UILabel* docTypeLabel;
@property (nonatomic, strong, nonnull) UILabel* instructionLabel;
@property (nonatomic, strong, nonnull) OCRStudioSDKCaptureButton* captureButton;
@property (nonatomic, weak, nullable) id<OCRStudioSDKCameraButtonDelegate> captureButtonDelegate;

@property (nonatomic, nonnull) UIButton* cancelButton;
@property (nonatomic, nonnull) UIButton* torchButton;
@property (nonatomic, nonnull) UIButton* switchCameraButton;

// optional elements
@property (nonatomic, strong, nullable) UIButton* galleryButton;
@property (nonatomic, strong, nullable) UIButton* photoButton;
@property (nonatomic, strong, nonnull) UIImageView* livenessMask;

- (nonnull instancetype) init;

- (nonnull instancetype) initWithLockedOrientation:(BOOL)lockOrientation;

- (nonnull instancetype) initWithLockedOrientation:(BOOL)lockOrientation WithTorch:(BOOL)torchOnByDefault;

- (nonnull instancetype) initWithLockedOrientation:(BOOL)lockOrientation
                                         WithTorch:(BOOL)torchOnByDefault
                                    WithBestDevice:(BOOL)bestDevice;

- (void) attachEngineInstance:(nonnull __weak OCRStudioSDKInstance *)instance;

- (void) setDefaultOrientation:(UIDeviceOrientation)orientation; // if orientation lock enabled

- (void) startRecognition;

- (void) stopRecognition;

- (CGSize) cameraSize;

- (CGRect) getCurrentRoi;

- (void) configureDocumentTypeLabel:(nonnull NSString *) label;

- (void) setRoiWithOffsetX:(CGFloat)offsetX
                      andY:(CGFloat)offsetY
               orientation:(UIDeviceOrientation)orientation
                displayRoi:(BOOL)displayroi;

- (void) processImageFile:(nonnull NSString *)filePath;
- (void) processUIImage:(nonnull UIImage *)image;

- (nonnull OCRStudioSDKSessionParameters *) sessionParams;

- (void) setStartMask;

@end



