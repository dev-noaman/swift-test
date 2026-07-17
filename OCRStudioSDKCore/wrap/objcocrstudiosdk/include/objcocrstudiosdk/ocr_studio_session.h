/**
  Copyright (c) 2024-2026, OCR Studio
  All rights reserved.
*/

#ifndef OBJCOCRSTUDIOSDK_OCR_STUDIO_SESSION_H_INCLUDED
#define OBJCOCRSTUDIOSDK_OCR_STUDIO_SESSION_H_INCLUDED

#import <objcocrstudiosdk/ocr_studio_image.h>
#import <objcocrstudiosdk/ocr_studio_result.h>

#import <Foundation/Foundation.h>

@interface OBJCOCRStudioSDKSession : NSObject

- (nonnull NSString *) description;

- (void) processImage:(nonnull OBJCOCRStudioSDKImageRef *)image;

- (void) processData:(nonnull NSString *)dataStr;

- (nonnull OBJCOCRStudioSDKResultRef *) currentResult;

- (void) reset;

- (void) suspend;

- (void) resume;

@end

#endif // OBJCOCRSTUDIOSDK_OCR_STUDIO_SESSION_H_INCLUDED
