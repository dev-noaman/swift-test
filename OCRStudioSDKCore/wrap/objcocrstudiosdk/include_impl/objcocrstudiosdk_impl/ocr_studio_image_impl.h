/**
  Copyright (c) 2024-2026, OCR Studio
  All rights reserved.
*/

#ifndef OBJCOCRSTUDIOSDK_IMPL_OCR_STUDIO_IMAGE_H_INCLUDED
#define OBJCOCRSTUDIOSDK_IMPL_OCR_STUDIO_IMAGE_H_INCLUDED

#include <ocrstudiosdk/ocr_studio_image.h>

#import <objcocrstudiosdk/ocr_studio_image.h>


@interface OBJCOCRStudioSDKImage (Internal)

- (instancetype) initFromInternalOCRStudioSDKImage:(ocrstudio::OCRStudioSDKImage *) image;
- (const ocrstudio::OCRStudioSDKImage &) getInternalOCRStudioSDKImage;

@end

@interface OBJCOCRStudioSDKImageRef (Internal)

- (instancetype) initFromInternalOCRStudioSDKImagePointer:(ocrstudio::OCRStudioSDKImage *) imageptr
                          withMutabilityFlag:(BOOL)mutabilityFlag;
- (ocrstudio::OCRStudioSDKImage *) getInternalOCRStudioSDKImagePointer;


@end

#endif // OBJCOCRSTUDIOSDK_IMPL_OCR_STUDIO_IMAGE_H_INCLUDED
