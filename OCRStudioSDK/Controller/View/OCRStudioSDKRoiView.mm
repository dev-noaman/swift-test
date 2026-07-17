/**
  Copyright (c) 2024-2026, OCR Studio
  All rights reserved.
*/

#import "OCRStudioSDKRoiView.h"

@implementation OCRStudioSDKRoiView

- (instancetype) init {
  if (self = [super init]) {
    self.offsetX = 0;
    self.offsetY = 0;
    self.backgroundColor = [UIColor clearColor];
    self.displayRoi = NO;
  }
  return self;
}

- (void) setOffsetsX:(CGFloat)offsetX
                   Y:(CGFloat)offsetY {
  self.offsetX = offsetX;
  self.offsetY = offsetY;
}

- (void) displayRoi:(BOOL)displayroi {
  self.displayRoi = displayroi;
}

- (void) drawRect:(CGRect)rect {
  CGContextRef context = UIGraphicsGetCurrentContext();
  CGContextSetAllowsAntialiasing(context, true);
  CGContextSetInterpolationQuality(context, kCGInterpolationNone);
  CGContextClipToRect(context, rect);
  
  CGMutablePathRef path = CGPathCreateMutable();
    
  if (_displayRoi) {
    CGFloat offsetX = rect.size.width * self.offsetX;
    CGFloat widthX  = rect.size.width - 2*offsetX;
    
    CGFloat heightY = widthX * self.offsetY;
    CGFloat offsetY = (rect.size.height - heightY)/2;
    
    CGPathMoveToPoint(path, NULL, offsetX, offsetY);
    CGPathAddLineToPoint(path, NULL, offsetX, offsetY + heightY);
    CGPathAddLineToPoint(path, NULL, offsetX + widthX, offsetY + heightY);
    CGPathAddLineToPoint(path, NULL, offsetX + widthX, offsetY);
    CGPathAddLineToPoint(path, NULL, offsetX, offsetY);
  } else {
    CGPathMoveToPoint(path, NULL, self.offsetX, self.offsetY);
    CGPathAddLineToPoint(path, NULL, self.offsetX, rect.size.height - self.offsetY);
    CGPathAddLineToPoint(path, NULL, rect.size.width - self.offsetX, rect.size.height - self.offsetY);
    CGPathAddLineToPoint(path, NULL, rect.size.width - self.offsetX, self.offsetY);
    CGPathAddLineToPoint(path, NULL, self.offsetX, self.offsetY);
  }

  CGPathCloseSubpath(path);
  
  CGContextAddPath(context, path);
  CGContextSetLineWidth(context, 3);
  CGContextSetLineCap(context, kCGLineCapRound);
  CGContextSetLineJoin(context, kCGLineJoinRound);
  
  CGFloat red = 100.f / 255, green = 100.f / 255, blue = 103.f / 255;
  CGFloat alpha = 0.5;
  
  CGContextSetRGBStrokeColor(context, red, green, blue, 0.0);
  CGContextStrokePath(context);
  
  CGContextSaveGState(context);
  CGContextAddPath(context, path);
  CGContextAddRect(context, self.bounds);
  CGContextEOClip(context);
  CGContextSetRGBFillColor(context, red, green, blue, alpha);
  CGContextFillRect(context, self.bounds);
  CGPathRelease(path);
  CGContextRestoreGState(context);
}

+ (CGRect) calculateRoiWith:(UIDeviceOrientation)deviceOrientation
                   viewSize:(CGSize)previewSize
                orientation:(UIInterfaceOrientation)orientation
                 cameraSize:(CGSize)cameraSize
                 andOffsets:(CGSize)offsets
                 displayRoi:(BOOL)displayroi {
    if (UIDeviceOrientationIsPortrait(deviceOrientation)) {
      cameraSize = CGSizeMake(cameraSize.height, cameraSize.width);
      previewSize = CGSizeMake(fmin(previewSize.height, previewSize.width),
                             fmax(previewSize.height, previewSize.width));
    } else {
      offsets = CGSizeMake(offsets.height, offsets.width);
      previewSize = CGSizeMake(fmax(previewSize.height, previewSize.width),
                             fmin(previewSize.height, previewSize.width));
    }
    
    if (displayroi){
      CGFloat offsetX = cameraSize.width * offsets.width;
      CGFloat widthX  = cameraSize.width - 2*offsetX;
        
      CGFloat heightY = widthX * offsets.height;
      CGFloat offsetY = (cameraSize.height - heightY)/2;
        
      return CGRectMake(offsetX, offsetY, widthX, heightY);
    } else {
      CGFloat scaleX =  cameraSize.width / previewSize.width;
      CGFloat scaleY = cameraSize.height / previewSize.height;
      CGSize realOffsets = CGSizeMake(offsets.width * scaleX, offsets.height * scaleY);
      
      return CGRectMake(realOffsets.width,
                        realOffsets.height,
                        cameraSize.width - 2 * realOffsets.width,
                        cameraSize.height - 2 * realOffsets.height);
    }
}

@end
