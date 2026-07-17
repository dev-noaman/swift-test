/**
  Copyright (c) 2024-2026, OCR Studio
  All rights reserved.
*/

/**
 * @file ocr_studio_exception.h
 * @brief Main C++ exception class
 */

#pragma once
#ifndef OCRSTUDIOSDK_OCR_STUDIO_EXCEPTION_H_INCLUDED
#define OCRSTUDIOSDK_OCR_STUDIO_EXCEPTION_H_INCLUDED

#include <ocrstudiosdk/ocr_studio_export.h>

namespace ocrstudio {

class OCR_STUDIO_SDK_DLL_EXPORT OCRStudioSDKException {
public:
  /// Non-trivial destructor
  virtual ~OCRStudioSDKException();

  /// Main constructor
  OCRStudioSDKException(
      const char* type, const char* msg);

  /// Copy constructor
  OCRStudioSDKException(
      const OCRStudioSDKException& copy);

  /// Returns exception type
  const char* Type() const;

  /// Returns exception message
  const char* Message() const;

private:
  char* type_; ///< stored exception type
  char* msg_;  ///< stored exception message
};

} // namespace ocrstudio

#endif // OCRSTUDIOSDK_OCR_STUDIO_EXCEPTION_H_INCLUDED
