/**
  Copyright (c) 2024-2026, OCR Studio
  All rights reserved.
*/

#import "OCRStudioSDKQuadrangleView.h"

static NSString * const kAnimation = @"path";

@interface OCRStudioSDKQuadrangleView()

@property (nonatomic, strong) CAShapeLayer* animLayer;
@property (nonatomic, assign) QuadrangleAnimationMode mode;

@end

@implementation OCRStudioSDKQuadrangleView

- (instancetype) init {
  if (self = [super init]) {
    [self setBackgroundColor:[UIColor clearColor]];
  }
  return self;
}

- (void) configureWithMode:(QuadrangleAnimationMode)mode {
  if (mode == QuadrangleAnimationModeSmoothOneQuadrangle) {
    [self setAnimLayer:[CAShapeLayer new]];
    [[self layer] addSublayer:[self animLayer]];
    [[self animLayer] setStrokeColor:[UIColor yellowColor].CGColor];
    [[self animLayer] setFillColor:[UIColor clearColor].CGColor];
    [[self animLayer] setPath:[UIBezierPath new].CGPath];
    [[self animLayer] setLineWidth:1.5];
  }
  _mode = mode;
}

- (void) hideQuad {
  dispatch_async(dispatch_get_main_queue(), ^{
    [[self animLayer] removeAllAnimations];
    [[self animLayer] setPath:[UIBezierPath new].CGPath];
  });
}

- (void) animateQuadrangle:(NSArray *)quadrangle
                     color:(UIColor *)color
                     width:(CGFloat)width
                     alpha:(CGFloat)alpha
                   offsetX:(CGFloat)offsetX
                   offsetY:(CGFloat)offsetY
         deviceOrientation:(UIDeviceOrientation)dOrientation
      interfaceOrientation:(UIInterfaceOrientation)iOrientation
                sourceSize:(CGSize)size
                   isFront:(BOOL)isFront {
  
  quadrangle = [self preprocessQuad:quadrangle
             frameSize:[self frame].size
            sourceSize:size 
     deviceOrientation:dOrientation
  interfaceOrientation:iOrientation
               offsets:CGPointMake(offsetX, offsetY)
               isFront:isFront];
  
  if ([self mode] == QuadrangleAnimationModeDefault && quadrangle != nil) {

    CAShapeLayer *layer = [CAShapeLayer layer];
    
    UIBezierPath* path = [UIBezierPath bezierPath];
    [path moveToPoint:CGPointMake([quadrangle[0][0] floatValue], [quadrangle[0][1] floatValue])];
    [path addLineToPoint:CGPointMake([quadrangle[1][0] floatValue], [quadrangle[1][1] floatValue])];
    [path addLineToPoint:CGPointMake([quadrangle[2][0] floatValue], [quadrangle[2][1] floatValue])];
    [path addLineToPoint:CGPointMake([quadrangle[3][0] floatValue], [quadrangle[3][1] floatValue])];
    [path addLineToPoint:CGPointMake([quadrangle[0][0] floatValue], [quadrangle[0][1] floatValue])];

    layer.path = path.CGPath;
    layer.backgroundColor = UIColor.redColor.CGColor;
    layer.strokeColor = color.CGColor;
    layer.fillColor = [UIColor clearColor].CGColor;
    layer.lineWidth = width;
    layer.opacity = 0.0f;
    
    [self.layer addSublayer:layer];
    
    __weak CAShapeLayer *weakLayer = layer;
    
    dispatch_async(dispatch_get_main_queue(), ^{
      [CATransaction begin];
      [CATransaction setCompletionBlock:^{
        dispatch_async(dispatch_get_main_queue(), ^{
          [weakLayer removeFromSuperlayer];
        });
      }];
      
      CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"opacity"];
      animation.fromValue = @(alpha);
      animation.toValue = @(0.0f);
      animation.duration = 0.7f;
      
      [weakLayer addAnimation:animation forKey:animation.keyPath];
      
      [CATransaction commit];
      [self setNeedsDisplay];
    });
  } else {
    if ([[self animLayer] isHidden]) {
      return;
    }
    CABasicAnimation *anim = [CABasicAnimation animationWithKeyPath:kAnimation];
    [anim setFromValue:[[[self animLayer] presentationLayer] valueForKeyPath:kAnimation]];
    [[self animLayer] removeAnimationForKey:kAnimation];
    if (quadrangle != nil) {
      UIBezierPath* path = [UIBezierPath bezierPath];
      [path moveToPoint:CGPointMake([quadrangle[0][0] floatValue], [quadrangle[0][1] floatValue])];
      [path addLineToPoint:CGPointMake([quadrangle[1][0] floatValue], [quadrangle[1][1] floatValue])];
      [path addLineToPoint:CGPointMake([quadrangle[2][0] floatValue], [quadrangle[2][1] floatValue])];
      [path addLineToPoint:CGPointMake([quadrangle[3][0] floatValue], [quadrangle[3][1] floatValue])];
      [path addLineToPoint:CGPointMake([quadrangle[0][0] floatValue], [quadrangle[0][1] floatValue])];
      [anim setToValue:(id)path.CGPath];
    } else {
      [anim setToValue:nil];
    }
    [anim setDuration:0.1];
    [anim setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear]];
    [[self animLayer] removeAnimationForKey:kAnimation];
    [anim setFillMode:kCAFillModeBoth];
    [anim setRemovedOnCompletion:NO];
    [[self animLayer] addAnimation:anim forKey:kAnimation];
    
    CABasicAnimation *strokeAnim = [CABasicAnimation animationWithKeyPath:@"strokeColor"];
    [strokeAnim setFromValue:[[[self animLayer] presentationLayer] valueForKeyPath:@"strokeColor"]];
    [[self animLayer] removeAnimationForKey:@"strokeColor"];
    strokeAnim.toValue = (id) color.CGColor;
    strokeAnim.duration = 0.1;
    strokeAnim.repeatCount = 10;
    [strokeAnim setRemovedOnCompletion:NO];
    [[self animLayer] addAnimation:strokeAnim forKey:@"strokeColor"];
  }
}

- (NSArray *) preprocessQuad:(NSArray*)quadrangle
                   frameSize:(CGSize)frameSize                 // frame size of the view for drawing
                       sourceSize:(CGSize)ssize                     // source image size
                deviceOrientation:(UIDeviceOrientation)dOrientation // orientation when frame with given quadrangle captured
             interfaceOrientation:(UIInterfaceOrientation)iOrientation // interface orientatino
                     offsets:(CGPoint)offsets
                     isFront:(BOOL)isFront {

  NSMutableArray *updatedQuadrangle = [NSMutableArray arrayWithArray:quadrangle]; // Create a mutable copy of the original array

  [self shiftPoints:updatedQuadrangle
            offsets:offsets];
  
  const UIInterfaceOrientation current = iOrientation;
  
  if (UIInterfaceOrientationIsPortrait(current)) {
    ssize = CGSizeMake(ssize.height, ssize.width);
  }
  
  CGSize aspectFillFrameSize = CGSizeMake([self frame].size.width, [self frame].size.height);
  const CGFloat minWidth = [self frame].size.width / ssize.width;
  const CGFloat minHeight = [self frame].size.height / ssize.height;
  if (minHeight > minWidth) {
    aspectFillFrameSize.width = minHeight * ssize.width;
  } else {
    aspectFillFrameSize.height = minWidth * ssize.height;
  }
  
  for (int i = 0; i < 4; ++i) {
    CGPoint point = CGPointMake([updatedQuadrangle[i][0] floatValue] / ssize.width * aspectFillFrameSize.width, [updatedQuadrangle[i][1] floatValue] / ssize.height * aspectFillFrameSize.height);
    if (isFront) {
      updatedQuadrangle[i] = @[ @(aspectFillFrameSize.width - point.x), @(point.y) ];
    } else {
      updatedQuadrangle[i] = @[ @(point.x), @(point.y) ];
    }
  }
  
  const CGPoint aspectDifference = CGPointMake(
      (frameSize.width - aspectFillFrameSize.width) / 2,
      (frameSize.height - aspectFillFrameSize.height) / 2);
  
  if (current == UIInterfaceOrientationLandscapeRight) {
    if (dOrientation == UIDeviceOrientationPortrait) {
      [self rotate90cw:updatedQuadrangle size:CGSizeMake(frameSize.height, frameSize.width)];
    }
    [self shiftPoints:updatedQuadrangle offsets:CGPointMake(aspectDifference.x, aspectDifference.y)];
  } else if (current == UIInterfaceOrientationLandscapeLeft) {
    if (dOrientation == UIDeviceOrientationPortrait) {
      [self rotate90ccw:updatedQuadrangle size:CGSizeMake(frameSize.height, frameSize.width)];
    }
    [self shiftPoints:updatedQuadrangle offsets:CGPointMake(aspectDifference.x, aspectDifference.y)];
  } else {
    if (dOrientation == UIDeviceOrientationLandscapeLeft) {
      [self rotate90ccw:updatedQuadrangle size:CGSizeMake(frameSize.width, frameSize.height)];
      [self shiftPoints:updatedQuadrangle offsets:CGPointMake(-aspectDifference.x, aspectDifference.y)];
    } else if (dOrientation == UIDeviceOrientationLandscapeRight) {
      [self rotate90cw:updatedQuadrangle size:CGSizeMake(frameSize.width, frameSize.height)];
      [self shiftPoints:updatedQuadrangle offsets:CGPointMake(aspectDifference.x, -aspectDifference.y)];
    } else {
      [self shiftPoints:updatedQuadrangle offsets:CGPointMake(aspectDifference.x, aspectDifference.y)];
    }
  }
  
  return [updatedQuadrangle copy];
}

- (void) rotate90cw:(NSMutableArray *)quadrangle
               size:(CGSize)viewSize {
  for (int i = 0; i < 4; ++i) {
    CGPoint point = CGPointMake(viewSize.height - [quadrangle[i][0] floatValue], [quadrangle[i][1] floatValue] );
    quadrangle[i] = @[ @(point.x), @(point.y) ];
  }
}

- (void) rotate90ccw:(NSMutableArray *)quadrangle
                size:(CGSize)viewSize {
  for (int i = 0; i < 4; ++i) {
    CGPoint point = CGPointMake([quadrangle[i][0] floatValue], viewSize.width - [quadrangle[i][1] floatValue] );
    quadrangle[i] = @[ @(point.x), @(point.y) ];
  }
}

- (void) shiftPoints:(NSMutableArray *)quadrangle
             offsets:(CGPoint)offsets {
  for (int i = 0; i < 4; ++i) {
    CGPoint point = CGPointMake([quadrangle[i][0] floatValue] + offsets.x, [quadrangle[i][1] floatValue] + offsets.y);
    quadrangle[i] = @[ @(point.x), @(point.y) ];
  }
}

@end

