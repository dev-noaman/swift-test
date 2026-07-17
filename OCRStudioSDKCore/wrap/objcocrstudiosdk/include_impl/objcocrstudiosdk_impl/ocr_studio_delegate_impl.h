/**
  Copyright (c) 2024-2026, OCR Studio
  All rights reserved.
*/

#ifndef OBJCOCRSTUDIOSDK_IMPL_OCR_STUDIO_DELEGATE_H_INCLUDED
#define OBJCOCRSTUDIOSDK_IMPL_OCR_STUDIO_DELEGATE_H_INCLUDED

#import <objcocrstudiosdk/ocr_studio_delegate.h>
#include <ocrstudiosdk/ocr_studio_delegate.h>

class ProxyDelegate : public ocrstudio::OCRStudioSDKDelegate {
public:
  ProxyDelegate(id<OBJCOCRStudioSDKDelegate> delegate);

  void SetDelegate(id<OBJCOCRStudioSDKDelegate> delegate);

public:
  virtual void Callback(const char* json_message) override final;

private:
  void RecalculateCache();

  id<OBJCOCRStudioSDKDelegate> delegate_;

  bool responds_to_callback_ = false;
};

#endif // OBJCOCRSTUDIOSDK_IMPL_OCR_STUDIO_DELEGATE_H_INCLUDED
