/**
  Copyright (c) 2024-2026, OCR Studio
  All rights reserved.
*/

#import <objcocrstudiosdk_impl/ocr_studio_proxy_impl.h>

void throwFromException(const ocrstudio::OCRStudioSDKException& e) {
  NSException* exc = [NSException
      exceptionWithName:[NSString stringWithUTF8String:e.Type()]
      reason:[NSString stringWithUTF8String:e.Message()]
      userInfo:nil];
  @throw exc;
}

void throwFromSTLException(const std::exception& e) {
  NSException* exc = [NSException
      exceptionWithName:@"STL Exception"
      reason:[NSString stringWithUTF8String:e.what()]
      userInfo:nil];
  @throw exc;
}


void throwNonMutableRefException() {
  NSException* exc = [NSException
      exceptionWithName:@"Reference Exception"
      reason:@"Trying to call mutating method from non-mutable ref"
      userInfo:nil];
  @throw exc;
}
