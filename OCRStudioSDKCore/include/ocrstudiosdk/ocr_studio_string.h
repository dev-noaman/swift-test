/**
  Copyright (c) 2024-2026, OCR Studio
  All rights reserved.
*/

/**
 * @file ocr_studio_string.h
 * @brief String manipulation facilities
 */

#pragma once
#ifndef OCRSTUDIOSDK_OCR_STUDIO_STRING_H_INCLUDED
#define OCRSTUDIOSDK_OCR_STUDIO_STRING_H_INCLUDED

#include <ocrstudiosdk/ocr_studio_export.h>

namespace ocrstudio {

class OCR_STUDIO_SDK_DLL_EXPORT OCRStudioSDKString {
public:
  /// Non-trivial destructor
  ~OCRStudioSDKString();

  /// Default constructor
  OCRStudioSDKString();

  /// Constructor from a C-string
  explicit OCRStudioSDKString(const char* c_str);

  /// Copy constructor
  OCRStudioSDKString(
      const OCRStudioSDKString& copy);

  /// Assignment operator
  OCRStudioSDKString& operator =(
      const OCRStudioSDKString& other);    

  /// Inplace concatenation
  OCRStudioSDKString& operator +=(
      const OCRStudioSDKString& other);

  /// General concatenation
  OCRStudioSDKString operator +(
      const OCRStudioSDKString& other) const;

  /// Returns internal c-string
  const char* CStr() const;

  /// Returns number of bytes stored
  int Size() const;  

private:
  int size_;  ///< length of the internal string in bytes
  char* str_; ///< internal c-string
};

} // namespace ocrstudio

#endif // OCRSTUDIOSDK_OCR_STUDIO_STRING_H_INCLUDED
