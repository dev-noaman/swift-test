/**
  Copyright (c) 2024-2026, OCR Studio
  All rights reserved.
*/

#ifndef OBJCOCRSTUDIOSDK_IMPL_OCR_STUDIO_INSTANCE_H_INCLUDED
#define OBJCOCRSTUDIOSDK_IMPL_OCR_STUDIO_INSTANCE_H_INCLUDED

#include <ocrstudiosdk/ocr_studio_instance.h>

#import <objcocrstudiosdk/ocr_studio_instance.h>

@interface OBJCOCRStudioSDKInstance (Internal)

- (ocrstudio::OCRStudioSDKInstance &) getInternalOCRStudioSDKInstance;

@end

#endif // OBJCOCRSTUDIOSDK_IMPL_OCR_STUDIO_INSTANCE_H_INCLUDED
