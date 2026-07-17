/**
  Copyright (c) 2024-2026, OCR Studio
  All rights reserved.
*/

#import "OCRStudioSDKCameraManager.h"

#import <UIKit/UIKit.h>

@interface OCRStudioSDKCameraManager ()

@property (nonatomic) AVCaptureDevice* captureDevice;
@property (nonatomic) AVCaptureDeviceInput* captureDeviceInput;
@property (nonatomic) AVCaptureVideoDataOutput* captureVideoDataOutput;
@property (nonatomic) AVCaptureSession* captureSession;
@property (nonatomic) CGFloat zoomState;

@end

@implementation OCRStudioSDKCameraManager

- (instancetype) init {
  return [self initWithCaptureDevicePosition:AVCaptureDevicePositionBack
                              WithBestDevice:NO];
}

- (instancetype) initWithBestDevice:(BOOL)bestDevice {
  return [self initWithCaptureDevicePosition:AVCaptureDevicePositionBack
                              WithBestDevice:bestDevice];
}

- (instancetype) initWithCaptureDevicePosition:(AVCaptureDevicePosition)position
                                WithBestDevice:(BOOL)bestDevice {
  if (self = [super init]) {
    _position = position;
    [self configureVideoCaptureWithPosition:position withBestDevice:bestDevice];
  }
  return self;
}

- (void) updateCuptureDeviceWithPosition:(AVCaptureDevicePosition)position
                          withBestDevice:(BOOL)bestDevice {
  // capture device
  NSArray* captureDevices;
  AVCaptureDeviceDiscoverySession* captureDeviceDiscoverySession;
  if (bestDevice) {
    if (@available(iOS 13.0, *)) {
      captureDeviceDiscoverySession = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[
        AVCaptureDeviceTypeBuiltInTripleCamera,
        AVCaptureDeviceTypeBuiltInDualWideCamera,
        AVCaptureDeviceTypeBuiltInDualCamera,
        AVCaptureDeviceTypeBuiltInUltraWideCamera,
        AVCaptureDeviceTypeBuiltInWideAngleCamera]
        mediaType:AVMediaTypeVideo position:position];
    } else {
      captureDeviceDiscoverySession = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[
      AVCaptureDeviceTypeBuiltInDualCamera,
      AVCaptureDeviceTypeBuiltInWideAngleCamera]
      mediaType:AVMediaTypeVideo position:position];
    }
  } else {
    captureDeviceDiscoverySession =
    [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInWideAngleCamera]
                                                           mediaType:AVMediaTypeVideo
                                                            position:position];
  }
  
  captureDevices = [captureDeviceDiscoverySession devices];
  
  if (captureDevices.count != 0) {
    for (AVCaptureDevice* device in captureDevices) {
      if (device.position == position) {
        self.captureDevice = device;
        NSLog(@"Selected device: %@: %@", device.localizedName, device.deviceType);
        break;
      }
    }
  } else {
    NSLog(@"No available back camera devices");
  }
  
  //Set switching behavior if possible
  if (@available(iOS 15.0, *) ) {
    if ([@[AVCaptureDeviceTypeBuiltInTripleCamera,AVCaptureDeviceTypeBuiltInDualWideCamera, AVCaptureDeviceTypeBuiltInDualCamera]
         containsObject:self.captureDevice.deviceType]) {
      self.zoomState = sWide; //choose sUltrawide, sWide or sTelephoto for switching behavior
      [self.captureDevice setPrimaryConstituentDeviceSwitchingBehavior:AVCapturePrimaryConstituentDeviceSwitchingBehaviorAuto restrictedSwitchingBehaviorConditions:AVCapturePrimaryConstituentDeviceRestrictedSwitchingBehaviorConditionNone];
    }
  }
  
  // setting continuous auto focus
  if ([self.captureDevice lockForConfiguration:nil]) {
    if ([self.captureDevice isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus]) {
      self.captureDevice.focusMode = AVCaptureFocusModeContinuousAutoFocus;
    }
    if ([self.captureDevice isExposureModeSupported:AVCaptureExposureModeLocked]) {
          self.captureDevice.exposureMode = AVCaptureExposureModeContinuousAutoExposure;
    }
    if ([self.captureDevice isAutoFocusRangeRestrictionSupported]) {
      self.captureDevice.autoFocusRangeRestriction = AVCaptureAutoFocusRangeRestrictionNear;
    }
    
    [self.captureDevice unlockForConfiguration];
  }
}

- (void) configureVideoCaptureWithPosition:(AVCaptureDevicePosition)position
                            withBestDevice:(BOOL)bestDevice{
  
  [self updateCuptureDeviceWithPosition:position withBestDevice:bestDevice];
  
  // capture video data output
  self.captureVideoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
  self.captureVideoDataOutput.videoSettings =
      @{(NSString*)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA)};
  self.captureVideoDataOutput.alwaysDiscardsLateVideoFrames = YES;
  
  // capture device input
  self.captureDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:self.captureDevice
                                                                  error:nil];
  
  // capture session
  self.captureSession = [[AVCaptureSession alloc] init];
  [self updateCaptureSessionPreset];
  
  if ([self.captureSession canAddInput:self.captureDeviceInput]) {
    [self.captureSession addInput:self.captureDeviceInput];
  }
  
  [self.captureSession addOutput:self.captureVideoDataOutput];
}

- (CGSize) videoSize {
  return self.currentVideoSize;
}

- (void) setSampleBufferDelegate:(id<AVCaptureVideoDataOutputSampleBufferDelegate>)delegate {
  dispatch_queue_t videoQueue = dispatch_queue_create("com.ocrengines.video-queue", 0);
  [self.captureVideoDataOutput setSampleBufferDelegate:delegate
                                                 queue:videoQueue];
}

- (void) configurePreview:(OCRStudioSDKVideoPreviewView *)view {
  [view setSession:[self captureSession]];
  [[view videoPreviewLayer] setVideoGravity:AVLayerVideoGravityResizeAspectFill];
}

- (void) startCaptureSession {
  dispatch_queue_t backgroundQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
  dispatch_async(backgroundQueue, ^{
    [self.captureSession startRunning];
    [self setVideoZoomFactor];
  });
}

- (void) stopCaptureSession {
  [self.captureSession stopRunning];
}

- (void) focusAtPoint:(CGPoint)point
    completionHandler:(void(^)(void))completionHandler {
  AVCaptureDevice *device = self.captureDevice;
  CGPoint pointOfInterest = CGPointZero;
  CGSize frameSize = [[UIScreen mainScreen] bounds].size;
  pointOfInterest = CGPointMake(point.y / frameSize.height, 1.f - (point.x / frameSize.width));
  
    if ([device isFocusPointOfInterestSupported] &&
        [device isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
      
      //Lock camera for configuration if possible
      NSError* error;
      if ([device lockForConfiguration:&error]) {
        if ([device isWhiteBalanceModeSupported:AVCaptureWhiteBalanceModeAutoWhiteBalance]) {
          [device setWhiteBalanceMode:AVCaptureWhiteBalanceModeAutoWhiteBalance];
        }
        
        [device setFocusMode:AVCaptureFocusModeAutoFocus];
        [device setFocusPointOfInterest:pointOfInterest];
        [device unlockForConfiguration];
        
      }
    } else {
      if (completionHandler) {
        completionHandler();
      }
    }
}

- (BOOL) isAdjustingFocus {
  if ([self.captureDevice isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus]) {
    return [self.captureDevice isAdjustingFocus];
  }
  return NO;
}

- (void) changeSessionPreset:(AVCaptureSessionPreset)preset {
  if ([self.captureSession canSetSessionPreset:preset]) {
    [self.captureSession setSessionPreset:preset];
  }
}

- (void) updateCaptureSessionPreset{
//  to turn on 4K video-mode
  
//  if ([self.captureSession canSetSessionPreset:AVCaptureSessionPreset3840x2160]) {
//    self.captureSession.sessionPreset = AVCaptureSessionPreset3840x2160;
//    self.currentVideoSize = CGSizeMake(3840, 2160);
  
  if ([self.captureSession canSetSessionPreset:AVCaptureSessionPreset1920x1080]) {
    self.captureSession.sessionPreset = AVCaptureSessionPreset1920x1080;
    self.currentVideoSize = CGSizeMake(1920, 1080);
  } else {
    self.captureSession.sessionPreset = AVCaptureSessionPreset1280x720;
    self.currentVideoSize = CGSizeMake(1280, 720);
  }
}

- (void) turnTorchOnWithLevel:(float)level {
  if ([self.captureDevice hasTorch]) {
    [self.captureDevice lockForConfiguration:nil];
    [self.captureDevice setTorchModeOnWithLevel:level error:nil];
    [self.captureDevice unlockForConfiguration];
  }
}

- (void) turnTorchOff {
  if ([self.captureDevice hasTorch]) {
    [self.captureDevice lockForConfiguration:nil];
    [self.captureDevice setTorchMode:AVCaptureTorchModeOff];
    [self.captureDevice unlockForConfiguration];
  }
}

- (BOOL) isTorchOn {
  if ([self.captureDevice hasTorch]) {
    return [self.captureDevice torchMode] == AVCaptureTorchModeOn;
  }
  return false;
}

- (AVCaptureDevice*) getCaptureDevice {
  return self.captureDevice;
}

- (void) setVideoZoomFactor {
  CGFloat videoZoomFactor = [self getVideoZoomFactor];
  [self setVideoCaptureDeviceZoom:videoZoomFactor animated:NO rate:0];
}

- (void) setVideoCaptureDeviceZoom:(CGFloat)videoZoomFactor
                          animated:(BOOL) animated
                              rate:(CGFloat) rate {
  if (self.captureDevice == nil) {
    return;
  }
  [self.captureDevice lockForConfiguration:nil];
  if (animated) {
    [self.captureDevice rampToVideoZoomFactor:videoZoomFactor withRate:rate];
  } else {
    self.captureDevice.videoZoomFactor = videoZoomFactor;
  }
  [self.captureDevice unlockForConfiguration];
}

- (CGFloat) getVideoZoomFactor {
  if (self.zoomState == sUltrawide){
    return 1;
  } else if (self.zoomState == sWide){
    return [self getWideVideoZoomFactor];
  } else {
    return [self getTelephotoVideoZoomFactor];
  }
}

- (CGFloat) getWideVideoZoomFactor {
  if (@available(iOS 13.0, *)) {
    if (self.captureDevice.deviceType == AVCaptureDeviceTypeBuiltInTripleCamera) {
      return 2; // switch to 3 when so far
    } else if (self.captureDevice.deviceType == AVCaptureDeviceTypeBuiltInDualWideCamera) {
      return 2;
    } else {
      return 1;
    }
  } else {
    return 1;
  }
}

-(CGFloat) getTelephotoVideoZoomFactor {
  if (@available(iOS 13.0, *)) {
    if (self.captureDevice.deviceType == AVCaptureDeviceTypeBuiltInTripleCamera) {
      return 3;
    } else {
      return 2;
    }
  } else {
    return 2;
  }
}

- (void) switchCamera {
  AVCaptureDevicePosition currentPosition = self.captureDevice.position;
  AVCaptureDevicePosition newPosition =  (currentPosition == AVCaptureDevicePositionBack) ? AVCaptureDevicePositionFront : AVCaptureDevicePositionBack;
  
  [self.captureSession beginConfiguration];
  AVCaptureDeviceInput *oldInput = self.captureDeviceInput;
  [self.captureSession removeInput:self.captureDeviceInput];
  [self updateCuptureDeviceWithPosition:newPosition withBestDevice:YES];
  _position = newPosition;
  // capture device input
  self.captureDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:self.captureDevice
                                                                  error:nil];
  
  if ([self.captureSession canAddInput:self.captureDeviceInput]) {
    [self.captureSession addInput:self.captureDeviceInput];
    [self.captureSession commitConfiguration];
    [self updateCaptureSessionPreset];
  } else {
    [self.captureSession addInput:oldInput];
  }
}

@end

