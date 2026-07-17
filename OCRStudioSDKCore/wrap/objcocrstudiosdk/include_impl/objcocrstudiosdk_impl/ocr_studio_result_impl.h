/**
  Copyright (c) 2024-2026, OCR Studio
  All rights reserved.
*/

#ifndef OBJCOCRSTUDIOSDK_IMPL_OCR_STUDIO_RESULT_H_INCLUDED
#define OBJCOCRSTUDIOSDK_IMPL_OCR_STUDIO_RESULT_H_INCLUDED

#include <ocrstudiosdk/ocr_studio_result.h>

#import <objcocrstudiosdk/ocr_studio_result.h>


@interface OBJCOCRStudioSDKItem (Internal)

- (instancetype) initFromInternalOCRStudioSDKItem:(ocrstudio::OCRStudioSDKItem &) item;
- (ocrstudio::OCRStudioSDKItem &) getInternalOCRStudioSDKItem;

@end

@interface OBJCOCRStudioSDKItemRef (Internal)

- (instancetype) initFromInternalOCRStudioSDKlItemPointer:(ocrstudio::OCRStudioSDKItem *) itemptr
                          withMutabilityFlag:(BOOL)mutabilityFlag;
- (ocrstudio::OCRStudioSDKItem *) getInternalOCRStudioSDKItemPointer;

@end

@interface OBJCOCRStudioSDKItemIteratorImplementation (Internal)

@end

@interface OBJCOCRStudioSDKItemIterator (Internal)

- (instancetype) initFromInternalOCRStudioSDKItemIterator:(const ocrstudio::OCRStudioSDKItemIterator &) item_iteratir;
- (const ocrstudio::OCRStudioSDKItemIterator &) getInternalOCRStudioSDKItemIterator;

@end

@interface OBJCOCRStudioSDKTarget (Internal)

- (instancetype) initFromInternalOCRStudioSDKTarget:(ocrstudio::OCRStudioSDKTarget *) target;
- (const ocrstudio::OCRStudioSDKTarget &) getInternalOCRStudioSDKTarget;

@end

@interface OBJCOCRStudioSDKTargetRef (Internal)

- (instancetype) initFromInternalOCRStudioSDKTargetPointer:(ocrstudio::OCRStudioSDKTarget *) targetptr
                                                withMutabilityFlag:(BOOL)mutabilityFlag;

- (ocrstudio::OCRStudioSDKTarget *) getInternalOCRStudioSDKTargetPointer;

@end

@interface OBJCOCRStudioSDKResult (Internal)

- (instancetype) initFromInternalOCRStudioSDKResult:(const ocrstudio::OCRStudioSDKResult &) result;
- (const ocrstudio::OCRStudioSDKResult &) getInternalOCRStudioSDKResult;

@end

@interface OBJCOCRStudioSDKResultRef (Internal)

- (instancetype) initFromInternalOCRStudioSDKResultPointer:(ocrstudio::OCRStudioSDKResult *) resultptr
                                                withMutabilityFlag:(BOOL)mutabilityFlag;

- (ocrstudio::OCRStudioSDKResult *) getInternalOCRStudioSDKResultPointer;

@end

#endif // OBJCOCRSTUDIOSDK_IMPL_OCR_STUDIO_RESULT_H_INCLUDED
