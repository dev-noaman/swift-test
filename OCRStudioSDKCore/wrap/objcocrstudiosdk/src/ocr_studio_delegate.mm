/**
  Copyright (c) 2024-2026, OCR Studio
  All rights reserved.
*/

#import <objcocrstudiosdk_impl/ocr_studio_delegate_impl.h>

ProxyDelegate::ProxyDelegate(id<OBJCOCRStudioSDKDelegate> delegate) {
  SetDelegate(delegate);
}

void ProxyDelegate::SetDelegate(id<OBJCOCRStudioSDKDelegate> delegate) {
  delegate_ = delegate;
  RecalculateCache();
}

void ProxyDelegate::RecalculateCache() {
  responds_to_callback_ = [delegate_ respondsToSelector:@selector(callbackWithMessage:)];
}

void ProxyDelegate::Callback(const char* json_message) {
  if (delegate_ && responds_to_callback_) {
    [delegate_ callbackWithMessage:[NSString stringWithUTF8String:json_message]];
  }
}
