/**
  Copyright (c) 2024-2026, OCR Studio
  All rights reserved.
*/

#ifndef OBJCOCRSTUDIOSDK_IMPL_OCR_STUDIO_SESSION_H_INCLUDED
#define OBJCOCRSTUDIOSDK_IMPL_OCR_STUDIO_SESSION_H_INCLUDED

#import <objcocrstudiosdk/ocr_studio_session.h>
#import <objcocrstudiosdk_impl/ocr_studio_delegate_impl.h>

#include <ocrstudiosdk/ocr_studio_session.h>


@interface OBJCOCRStudioSDKSession (Internal)

- (instancetype) initFromCreatedSession:(ocrstudio::OCRStudioSDKSession *)session_ptr
                 withCreatedProxyDelegate:(ProxyDelegate *)proxy_delegate;
- (ocrstudio::OCRStudioSDKSession &) getInternalSession;

@end

#endif // OBJCOCRSTUDIOSDK_IMPL_OCR_STUDIO_SESSION_H_INCLUDED
