/**
  Copyright (c) 2024-2026, OCR Studio
  All rights reserved.
*/

#import "OCRStudioSDKVideoPreviewView.h"

@implementation OCRStudioSDKVideoPreviewView

+ (Class) layerClass {
  return [AVCaptureVideoPreviewLayer class];
}

- (AVCaptureVideoPreviewLayer *) videoPreviewLayer {
  return (AVCaptureVideoPreviewLayer *)self.layer;
}

- (AVCaptureSession *) session {
  return self.videoPreviewLayer.session;
}

- (void) setSession:(AVCaptureSession *)session {
  self.videoPreviewLayer.session = session;
}

@end
