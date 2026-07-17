/**
  Copyright (c) 2024-2026, OCR Studio
  All rights reserved.
*/

#import <objcocrstudiosdk_impl/ocr_studio_session_impl.h>
#import <objcocrstudiosdk_impl/ocr_studio_instance_impl.h>
#import <objcocrstudiosdk_impl/ocr_studio_image_impl.h>
#import <objcocrstudiosdk_impl/ocr_studio_result_impl.h>
#import <objcocrstudiosdk_impl/ocr_studio_delegate_impl.h>

#include <ocrstudiosdk/ocr_studio_session.h>
#include <ocrstudiosdk/ocr_studio_exception.h>

#include <memory>

@implementation OBJCOCRStudioSDKSession {
    std::unique_ptr<ocrstudio::OCRStudioSDKSession> internal;
    std::unique_ptr<ProxyDelegate> proxyDelegate;
}

- (instancetype) initFromCreatedSession:(ocrstudio::OCRStudioSDKSession *) session_ptr
                 withCreatedProxyDelegate:(ProxyDelegate *)proxy_delegate {
  if (self = [super init]) {
    internal.reset(session_ptr);
    proxyDelegate.reset(proxy_delegate);
  }
  return self;
}

- (ocrstudio::OCRStudioSDKSession &) getInternalOCRStudioSDKSession {
  return *internal;
}

- (void) reset {
  try {
    internal->Reset();    
  } catch (const ocrstudio::OCRStudioSDKException& e) {
    printf("Exception thrown: %s\n", e.Message());
  }
}

- (void) suspend {
  try {
    internal->Suspend();    
  } catch (const ocrstudio::OCRStudioSDKException& e) {
    printf("Exception thrown: %s\n", e.Message());
  }
}

- (void) resume {
  try {
    internal->Resume();    
  } catch (const ocrstudio::OCRStudioSDKException& e) {
    printf("Exception thrown: %s\n", e.Message());
  }
}


- (void) processImage:(OBJCOCRStudioSDKImageRef *)image {
  try {
    internal->ProcessImage(*[image getInternalOCRStudioSDKImagePointer]);
  } catch (const ocrstudio::OCRStudioSDKException& e) {
    printf("Exception thrown: %s\n", e.Message());
  }
}

- (void) processData:(NSString *)dataStr {
  try {
    internal->ProcessData([dataStr UTF8String]);
  } catch (const ocrstudio::OCRStudioSDKException& e) {
    printf("Exception thrown: %s\n", e.Message());
  }
}

- (OBJCOCRStudioSDKResultRef *) currentResult{
  return [[OBJCOCRStudioSDKResultRef alloc]
      initFromInternalOCRStudioSDKResultPointer:const_cast<ocrstudio::OCRStudioSDKResult*>(&internal->CurrentResult())
                 withMutabilityFlag:NO];
}

- (NSString *) description {
  return [NSString stringWithUTF8String:internal->Description()];
}

@end
