/**
  Copyright (c) 2024-2026, OCR Studio
  All rights reserved.
*/

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSUInteger, OCRStudioSDKCameraButtonMode) {
    OCRStudioSDKCameraButtonModePhoto,
    OCRStudioSDKCameraButtonModeVideo
};

typedef NS_ENUM(NSUInteger, OCRStudioSDKCameraButtonState) {
    OCRStudioSDKCameraButtonStateRecording,
    OCRStudioSDKCameraButtonStateWaiting
};

@class OCRStudioSDKCaptureButton;

@protocol OCRStudioSDKCameraButtonDelegate

- (void) OCRStudioSDKCameraButtonTapped:(nonnull OCRStudioSDKCaptureButton *)sender;

@end

@interface OCRStudioSDKCaptureButton : UIButton

@property (nonatomic, nullable, weak) id<OCRStudioSDKCameraButtonDelegate> delegate;

@property (nonatomic, assign) float animationDuration;
@property (nonatomic, nonnull, strong) UIColor* defaultColor;
@property (nonatomic, nonnull, strong) UIColor* videoProcColor;

- (nonnull instancetype) initWithFrame:(CGRect)frame
andMode:(OCRStudioSDKCameraButtonMode)mode;

- (void) restoreState;
- (OCRStudioSDKCameraButtonMode) mode;
- (OCRStudioSDKCameraButtonState) recordingState;

@end
