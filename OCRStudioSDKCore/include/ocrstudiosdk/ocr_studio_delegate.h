/**
  Copyright (c) 2024-2026, OCR Studio
  All rights reserved.
*/

/**
 * @file ocr_studio_delegate.h
 * @brief Feedback base class, allows to receive runtime messages from OCRStudioSDKSession
 */

#pragma once
#ifndef OCRSTUDIOSDK_OCR_STUDIO_DELEGATE_H_INCLUDED
#define OCRSTUDIOSDK_OCR_STUDIO_DELEGATE_H_INCLUDED

#include <ocrstudiosdk/ocr_studio_export.h>

namespace ocrstudio {

class OCR_STUDIO_SDK_DLL_EXPORT OCRStudioSDKDelegate {
public:
  /// Virtual destructor
  virtual ~OCRStudioSDKDelegate() = default;

  /**
   * @brief Callback for receiving messages from processing session
   * @param json_message - callback message encoded in JSON string
   */
  virtual void Callback(const char* json_message) = 0;
};

} // namespace ocrstudio

#endif // OCRSTUDIOSDK_OCR_STUDIO_DELEGATE_H_INCLUDED
