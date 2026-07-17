/**
  Copyright (c) 2024-2026, OCR Studio
  All rights reserved.
*/

#import <objcocrstudiosdk_impl/ocr_studio_instance_impl.h>
#import <objcocrstudiosdk_impl/ocr_studio_session_impl.h>
#import <objcocrstudiosdk_impl/ocr_studio_delegate_impl.h>

#include <ocrstudiosdk/ocr_studio_instance.h>
#include <ocrstudiosdk/ocr_studio_exception.h>

#include <memory>


@implementation OBJCOCRStudioSDKInstance {
    std::unique_ptr<ocrstudio::OCRStudioSDKInstance> internal;
}

- (ocrstudio::OCRStudioSDKInstance &) getInternalOCRStudioSDKInstance {
  return *internal;
}

- (instancetype) initStandalone:(NSString *) json_instance_init_params {
    try{
        if (self = [super init]){
            internal.reset(ocrstudio::OCRStudioSDKInstance::CreateStandalone([json_instance_init_params UTF8String]));
        }
        return self;
    } catch (const ocrstudio::OCRStudioSDKException& e){
        printf("Exception thrown: %s\n", e.Message());
        return nil;
    }
}

- (instancetype) initFromPath:(NSString *) configuration_filename
     withJsonInstanceInitParams:(NSString *) json_instance_init_params {

    try{
        if (self = [super init]){
            internal.reset(ocrstudio::OCRStudioSDKInstance::CreateFromPath([configuration_filename UTF8String], 
                                                              [json_instance_init_params UTF8String]));
        }
        return self;
    } catch (const ocrstudio::OCRStudioSDKException& e){
        printf("Exception thrown: %s\n", e.Message());
        return nil;
    }
}

 - (instancetype) initFromBuffer:(nonnull unsigned char *) configuration_buffer
       withConfigurationBufferSize:(int) configuration_buffer_size
      withJsonInstanceInitParams:(NSString *) json_instance_init_params {
   if (self = [super init]) {
     try {
       internal.reset(ocrstudio::OCRStudioSDKInstance::CreateFromBuffer(configuration_buffer, configuration_buffer_size, [json_instance_init_params UTF8String]));
     } catch (const ocrstudio::OCRStudioSDKException& e) {
       printf("Exception thrown: %s\n", e.Message());
       return nil;
     }
   }
   return self;
 }

+ (NSString *) libraryVersion {
  return [NSString stringWithUTF8String:ocrstudio::OCRStudioSDKInstance::LibraryVersion()];
}

- (NSString *) description {
  return [NSString stringWithUTF8String:internal->Description()];
}

- (OBJCOCRStudioSDKSession *) createSession: (NSString *) authorization_signature
                           withJsonSessionParams: (NSString *) json_session_params 
                           withDelegate:(id<OBJCOCRStudioSDKDelegate>)delegate {
    try {
        std::unique_ptr<ProxyDelegate> proxy_delegate(new ProxyDelegate(delegate));
        ProxyDelegate* proxy_delegate_ptr = proxy_delegate.get();
        return [[OBJCOCRStudioSDKSession alloc] 
                initFromCreatedSession:internal->CreateSession([authorization_signature UTF8String], 
                                                               [json_session_params UTF8String],
                                                               proxy_delegate_ptr)
                withCreatedProxyDelegate:proxy_delegate.release()];
    } catch (const ocrstudio::OCRStudioSDKException& e){
        printf("Exception thrown: %s\n", e.Message());
        return nil;
    }
}

@end
