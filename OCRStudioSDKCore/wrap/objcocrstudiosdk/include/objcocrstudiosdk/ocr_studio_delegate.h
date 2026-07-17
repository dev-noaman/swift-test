/**
  Copyright (c) 2024-2026, OCR Studio
  All rights reserved.
*/

#ifndef OBJCOCRSTUDIOSDK_OCR_STUDIO_DELEGATE_H_INCLUDED
#define OBJCOCRSTUDIOSDK_OCR_STUDIO_DELEGATE_H_INCLUDED

#import <Foundation/Foundation.h>

@protocol OBJCOCRStudioSDKDelegate <NSObject>

@optional

- (void) callbackWithMessage:(nonnull NSString*)json_message;

@end


#endif // OBJCOCRSTUDIOSDK_OCR_STUDIO_DELEGATE_H_INCLUDED
