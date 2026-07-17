/**
  Copyright (c) 2024-2026, OCR Studio
  All rights reserved.
*/

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@interface OCRStudioSDKVideoPreviewView : UIView

@property (nonatomic, readonly) AVCaptureVideoPreviewLayer* videoPreviewLayer;
@property (nonatomic) AVCaptureSession* session;

@end
