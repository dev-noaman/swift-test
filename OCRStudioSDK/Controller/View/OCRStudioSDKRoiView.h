/**
  Copyright (c) 2024-2026, OCR Studio
  All rights reserved.
*/

#import <UIKit/UIKit.h>

@interface OCRStudioSDKRoiView : UIView

@property (nonatomic, assign) CGFloat offsetX;
@property (nonatomic, assign) CGFloat offsetY;
@property (nonatomic, assign) BOOL displayRoi;

+ (CGRect) calculateRoiWith:(UIDeviceOrientation)deviceOrientation
                   viewSize:(CGSize)previewSize
                orientation:(UIInterfaceOrientation)orientation
                 cameraSize:(CGSize)camSize
                 andOffsets:(CGSize)offsets
                 displayRoi:(BOOL)displayroi;

@end
