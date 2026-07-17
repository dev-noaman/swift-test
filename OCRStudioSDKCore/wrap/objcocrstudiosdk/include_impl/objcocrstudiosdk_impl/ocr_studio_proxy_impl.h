/**
  Copyright (c) 2024-2026, OCR Studio
  All rights reserved.
*/

#ifndef OBJCOCRSTUDIOSDK_IMPL_OCR_STUDIO_PROXY_H_INCLUDED
#define OBJCOCRSTUDIOSDK_IMPL_OCR_STUDIO_PROXY_H_INCLUDED

#import <Foundation/Foundation.h>

#include <ocrstudiosdk/ocr_studio_exception.h>

#include <stdexcept>

void throwFromException(const ocrstudio::OCRStudioSDKException& e);

void throwFromSTLException(const std::exception& e);

void throwNonMutableRefException();

#endif // OBJCOCRSTUDIOSDK_IMPL_OCR_STUDIO_PROXY_H_INCLUDED
