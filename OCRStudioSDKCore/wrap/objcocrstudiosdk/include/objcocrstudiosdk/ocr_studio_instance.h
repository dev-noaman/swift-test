/**
  Copyright (c) 2024-2026, OCR Studio
  All rights reserved.
*/

#ifndef OBJCOCRSTUDIOSDK_OCR_STUDIO_INSTANCE_H_INCLUDED
#define OBJCOCRSTUDIOSDK_OCR_STUDIO_INSTANCE_H_INCLUDED

#import <objcocrstudiosdk/ocr_studio_session.h>
#import <objcocrstudiosdk/ocr_studio_delegate.h>

#import <Foundation/Foundation.h>

@interface OBJCOCRStudioSDKInstance : NSObject

- (nonnull  OBJCOCRStudioSDKInstance *) initStandalone:(nonnull NSString *) json_instance_init_params;

- (nonnull  OBJCOCRStudioSDKInstance *) initFromPath:(nullable NSString *) configuration_filename
                                withJsonInstanceInitParams:(nullable NSString *) json_instance_init_params;

- (nonnull  OBJCOCRStudioSDKInstance *) initFromBuffer:(nonnull unsigned char *) configuration_buffer
                                 withConfigurationBufferSize:(int) configuration_buffer_size
                                  withJsonInstanceInitParams:(nonnull NSString *) json_instance_init_params;

+ (nonnull NSString *) libraryVersion;

- (nonnull NSString *) description;

- (nonnull OBJCOCRStudioSDKSession *) createSession:(nonnull NSString *) authorization_signature
                                                                      withJsonSessionParams:(nonnull NSString *) json_session_params
                                                                      withDelegate:(nullable id<OBJCOCRStudioSDKDelegate>)delegate;

@end

#endif // OBJCOCRSTUDIOSDK_OCR_STUDIO_INSTANCE_H_INCLUDED
