/**
  Copyright (c) 2024-2026, OCR Studio
  All rights reserved.
*/

#import <UIKit/UIKit.h>

typedef enum : NSUInteger {
  QuadrangleAnimationModeSmoothOneQuadrangle,
  QuadrangleAnimationModeDefault,
} QuadrangleAnimationMode;

@interface OCRStudioSDKQuadrangleView : UIView

- (instancetype) init;

- (void) hideQuad;

- (void) configureWithMode:(QuadrangleAnimationMode)mode;

- (void) animateQuadrangle:(NSArray *)quadrangle
                     color:(UIColor *)color
                     width:(CGFloat)width
                     alpha:(CGFloat)alpha
                   offsetX:(CGFloat)offsetX
                   offsetY:(CGFloat)offsetY
         deviceOrientation:(UIDeviceOrientation)dOrientation
      interfaceOrientation:(UIInterfaceOrientation)iOrientation
                sourceSize:(CGSize)size
                   isFront:(BOOL)isFront;

- (NSArray *) preprocessQuad:(NSArray *)quadrangle
                  frameSize:(CGSize)frameSize                 // frame size of the view for drawing
                 sourceSize:(CGSize)ssize                     // source image size
          deviceOrientation:(UIDeviceOrientation)dOrientation // orientation when frame with given quadrangle captured
       interfaceOrientation:(UIInterfaceOrientation)iOrientation // current interface orientation
                    offsets:(CGPoint)offsets                  // roi offsets
                    isFront:(BOOL)isFront;                    // mirror quads if it's front camera

- (void) rotate90ccw:(NSMutableArray *)quadrangle
                size:(CGSize)viewSize;
- (void) rotate90cw:(NSMutableArray *)quadrangle
               size:(CGSize)viewSize;
- (void) shiftPoints:(NSMutableArray *)quadrangle
             offsets:(CGPoint)offsets;
@end

