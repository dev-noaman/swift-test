/**
  Copyright (c) 2024-2026, OCR Studio
  All rights reserved.
*/

#ifndef OBJCOCRSTUDIOSDK_OCR_STUDIO_IMAGE_H_INCLUDED
#define OBJCOCRSTUDIOSDK_OCR_STUDIO_IMAGE_H_INCLUDED

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

#ifndef OBJCOCRSTUDIOSDK_WITHOUT_UIKIT
#import <UIKit/UIImage.h>
#endif // OBJCOCRSTUDIOSDK_WITHOUT_UIKIT

typedef enum {
  OBJCOCRStudioSDKPixelFormat_G = 0,     ///< Greyscale
  OBJCOCRStudioSDKPixelFormat_GA,        ///< Greyscale + Alpha
  OBJCOCRStudioSDKPixelFormat_AG,        ///< Alpha + Greyscale
  OBJCOCRStudioSDKPixelFormat_RGB,       ///< RGB
  OBJCOCRStudioSDKPixelFormat_BGR,       ///< BGR
  OBJCOCRStudioSDKPixelFormat_BGRA,      ///< BGR + Alpha
  OBJCOCRStudioSDKPixelFormat_ARGB,      ///< Alpha + RGB
  OBJCOCRStudioSDKPixelFormat_RGBA       ///< RGB + Alpha
} OBJCOCRStudioSDKPixelFormat;

typedef enum {
  OBJCOCRStudioSDKYUVFormat_NOT_SET = 0,  ///< Not set
  OBJCOCRStudioSDKYUVFormat_NNV21,         ///< NV 21
  OBJCOCRStudioSDKYUVFormat_420_888       ///< YUV 420 888
} OBJCOCRStudioSDKYUVFormat;


@class OBJCOCRStudioSDKImage;

@interface OBJCOCRStudioSDKImageRef : NSObject

- (BOOL) isMutable;

#ifndef OBJCOCRSTUDIOSDK_WITHOUT_UIKIT
- (nonnull UIImage *) convertToUIImage;
#endif // OBJCOCRSTUDIOSDK_WITHOUT_UIKIT

- (nonnull OBJCOCRStudioSDKImage *) deepCopy;
- (nonnull OBJCOCRStudioSDKImage *) shallowCopy;
- (void) clear;

- (int) exportPixelBufferLength;
- (int) exportPixelBuffer:(nonnull unsigned char *) export_buffer
   withExportBufferLength:(int) export_buffer_length;

- (nonnull NSString *) exportBase64JPEG;

- (void) scale:(int) width
    withHeight:(int) height;

- (nonnull OBJCOCRStudioSDKImage *) deepCopyScaled:(int) width
                                            withHeight:(int) height;

- (void) cropByQuad:(nonnull NSString *) quad_json
          withWidth:(int) width
         withHeight:(int) height;

- (nonnull OBJCOCRStudioSDKImage *) deepCopyCroppedByQuad:(nonnull NSString *) quad_json
                                         withWidth:(int) width
                                        withHeight:(int) height;

- (void) cropByRect:(int) x
             withY:(int) y
         withWidth:(int) width
        withHeight:(int) height;

- (nonnull OBJCOCRStudioSDKImage *) deepCopyCroppedByRect:(int) x
                                                        withY:(int) y
                                                    withWidth:(int) width
                                                   withHeight:(int) height;

- (nonnull OBJCOCRStudioSDKImage *) shallowCopyCroppedByRect:(int) x
                                                           withY:(int) y
                                                       withWidth:(int) width
                                                      withHeight:(int) height;

- (void) rotateByNinety:(int) num_rotations;
- (nonnull OBJCOCRStudioSDKImage *) deepCopyRotatedByNinety:(int) num_rotations;

- (int) width;
- (int) height;
- (int) bytesPerLine;
- (int) channels;
- (BOOL) ownsPixelData;
- (void) forcePixelDataOwnership;

@end

@interface OBJCOCRStudioSDKImage : NSObject

- (nonnull instancetype) init;
- (nonnull instancetype) initFromFile:(nonnull NSString *) filename
                                        withPageNumber:(int) page_number
                                          withMaxWidth:(int) max_width
                                         withMaxHeight:(int) max_height;

- (nonnull instancetype) initFromFileBuffer:(nonnull unsigned char *) data
                                                withDataSize:(int) data_size
                                              withPageNumber:(int) page_number
                                                withMaxWidth:(int) max_width
                                               withMaxHeight:(int) max_height;                                      

- (nonnull instancetype) initFromBase64FileBuffer:(nonnull NSString *) base64_data
                                                    withPageNumber:(int) page_number
                                                      withMaxWidth:(int) max_width
                                                     withMaxHeight:(int) max_height;

- (nonnull instancetype) initFromPixelBuffer:(nonnull unsigned char *) data
                                                 withDataSize:(int) data_size
                                                     witWidth:(int) width
                                                   withHeight:(int) height
                                             withBytesPerLine:(int) bytes_per_line
                                          withBytesPerChannel:(int) bytes_per_channel
                                              withPixelFormat:(OBJCOCRStudioSDKPixelFormat) pixel_format;

- (nonnull instancetype) initFromSampleBuffer:(nonnull CMSampleBufferRef)sampleBuffer;

- (nonnull instancetype) initFromYUVSimple:(nonnull unsigned char *) yuv_data
                                            withYuvDataSize:(int) yuv_data_size
                                                  withWidth:(int) width
                                                 withHeight:(int) height;

- (nonnull instancetype) initFromYUV:(nonnull unsigned char *) y_plane
                                         withYPlaneSize:(int) y_plane_size
                                    withYPlaneRowStride:(int) y_plane_row_stride
                                  withYPlanePixelStride:(int) y_plane_pixel_stride
                                             withUPlane:(nonnull unsigned char *) u_plane
                                         withUPlaneSize:(int) u_plane_size
                                    withUPlaneRowStride:(int) u_plane_row_stride
                                  withUPlanePixelStride:(int) u_plane_pixel_stride
                                             withVPlane:(nonnull unsigned char *) v_plane
                                         withVPlaneSize:(int) v_plane_size
                                    withVPlaneRowStride:(int) v_plane_row_stride
                                  withVPlanePixelStride:(int) v_plane_pixel_stride
                                               witWidth:(int) width
                                             withHeight:(int) height
                                          withYUVFormat:(OBJCOCRStudioSDKYUVFormat) yuv_format;

#ifndef OBJCOCRSTUDIOSDK_WITHOUT_UIKIT
- (nonnull instancetype) initFromUIImage:(nonnull UIImage *)image;
#endif // OBJCOCRSTUDIOSDK_WITHOUT_UIKIT

+ (int) pagesCount:(nonnull NSString *) filename;
+ (nonnull NSString *) pageName:(nonnull NSString *) filename
                                   withPageNumber:(int) page_number;

- (nonnull OBJCOCRStudioSDKImageRef *) getRef;
- (nonnull OBJCOCRStudioSDKImageRef *) getMutableRef;

@end

#endif // OBJCOCRSTUDIOSDK_OCR_STUDIO_IMAGE_H_INCLUDED

