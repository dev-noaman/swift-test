/**
  Copyright (c) 2024-2026, OCR Studio
  All rights reserved.
*/

#import <objcocrstudiosdk_impl/ocr_studio_image_impl.h>
#import <objcocrstudiosdk_impl/ocr_studio_proxy_impl.h>

#include <ocrstudiosdk/ocr_studio_exception.h>

#include <memory>

ocrstudio::OCRStudioSDKPixelFormat convertFormat(OBJCOCRStudioSDKPixelFormat pixel_format) {
  if (pixel_format == OBJCOCRStudioSDKPixelFormat_G) {
    return ocrstudio::OCRSTUDIOSDK_PIXEL_FORMAT_G;
  }
  if (pixel_format == OBJCOCRStudioSDKPixelFormat_GA) {
    return ocrstudio::OCRSTUDIOSDK_PIXEL_FORMAT_GA;
  }
  if (pixel_format == OBJCOCRStudioSDKPixelFormat_AG) {
    return ocrstudio::OCRSTUDIOSDK_PIXEL_FORMAT_AG;
  }
  if (pixel_format == OBJCOCRStudioSDKPixelFormat_RGB) {
    return ocrstudio::OCRSTUDIOSDK_PIXEL_FORMAT_RGB;
  }
  if (pixel_format == OBJCOCRStudioSDKPixelFormat_BGR) {
    return ocrstudio::OCRSTUDIOSDK_PIXEL_FORMAT_BGR;
  }
  if (pixel_format == OBJCOCRStudioSDKPixelFormat_BGRA) {
    return ocrstudio::OCRSTUDIOSDK_PIXEL_FORMAT_BGRA;
  }
  if (pixel_format == OBJCOCRStudioSDKPixelFormat_ARGB) {
    return ocrstudio::OCRSTUDIOSDK_PIXEL_FORMAT_ARGB;
  }
  if (pixel_format == OBJCOCRStudioSDKPixelFormat_RGBA) {
    return ocrstudio::OCRSTUDIOSDK_PIXEL_FORMAT_RGBA;
  }
  return ocrstudio::OCRSTUDIOSDK_PIXEL_FORMAT_G;
}

ocrstudio::OCRStudioSDKYUVFormat convertFormat(OBJCOCRStudioSDKYUVFormat yuv_format) {
  if (yuv_format == OBJCOCRStudioSDKYUVFormat_NOT_SET) {
    return ocrstudio::OCRSTUDIOSDK_YUV_FORMAT_NOT_SET;
  }
  if (yuv_format == OBJCOCRStudioSDKYUVFormat_NNV21) {
    return ocrstudio::OCRSTUDIOSDK_YUV_FORMAT_NV21;
  }
  if (yuv_format == OBJCOCRStudioSDKYUVFormat_420_888) {
    return ocrstudio::OCRSTUDIOSDK_YUV_FORMAT_420_888;
  }
  return ocrstudio::OCRSTUDIOSDK_YUV_FORMAT_NOT_SET;
}

@implementation OBJCOCRStudioSDKImageRef {
  ocrstudio::OCRStudioSDKImage* ptr;
  bool is_mutable;
}

- (instancetype) initFromInternalOCRStudioSDKImagePointer:(ocrstudio::OCRStudioSDKImage *) imageptr
                                        withMutabilityFlag:(BOOL)mutabilityFlag {
  if (self = [super init]) {
    ptr = imageptr;
    is_mutable = (YES == mutabilityFlag);
  }
  return self;
}

- (ocrstudio::OCRStudioSDKImage *) getInternalOCRStudioSDKImagePointer {
  return ptr;
}

- (BOOL) isMutable {
  return is_mutable? YES : NO;
}

#ifndef OBJCOCRSTUDIOSDK_WITHOUT_UIKIT
- (UIImage *) convertToUIImage {
  NSData* data = [NSData dataWithBytes:ptr->UnsafeBufferPtr()
                                length:ptr->Height() * ptr->BytesPerLine()];
  CGColorSpaceRef colorSpace;
  if (ptr->Channels() == 1) {
    colorSpace = CGColorSpaceCreateDeviceGray();
  } else {
    colorSpace = CGColorSpaceCreateDeviceRGB();
  }

  CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
  CGImageRef imageRef = CGImageCreate(
      ptr->Width(), // width
      ptr->Height(),  // height
      8,  // bits per component
      8 * ptr->Channels(),   // bits per pixel
      ptr->BytesPerLine(),  // bytes per row
      colorSpace, // colorspace
      kCGImageAlphaNone | kCGBitmapByteOrderDefault, // bitmap info flags
      provider, // CGDataProviderRef,
      NULL, // Decode
      false, // Should interpolate
      kCGRenderingIntentDefault); // intent

  UIImage* ret = [UIImage imageWithCGImage:imageRef
                                     scale:1.0f
                               orientation:UIImageOrientationUp];
  CGImageRelease(imageRef);
  CGDataProviderRelease(provider);
  CGColorSpaceRelease(colorSpace);
  return ret;
}
#endif // OBJCOCRSTUDIOSDK_WITHOUT_UIKIT

- (OBJCOCRStudioSDKImage *) deepCopy {
  try {
    return [[OBJCOCRStudioSDKImage alloc] initFromInternalOCRStudioSDKImage:ptr->DeepCopy()];
  } catch (const ocrstudio::OCRStudioSDKException& e) {
    printf("Exception thrown: %s\n", e.Message());
    return nil;
  }
  return nil;
}

- (OBJCOCRStudioSDKImage *) shallowCopy {
  try {
    return [[OBJCOCRStudioSDKImage alloc] initFromInternalOCRStudioSDKImage:ptr->ShallowCopy()];
  } catch (const ocrstudio::OCRStudioSDKException& e) {
    printf("Exception thrown: %s\n", e.Message());
    return nil;
  }
  return nil;
}

- (void) clear {
  if (!is_mutable) {
    throwNonMutableRefException();
  } else {
    ptr->Clear();
  }
}

- (int) exportPixelBufferLength {
  return ptr->ExportPixelBufferLength();
}

- (int) exportPixelBuffer:(unsigned char *) export_buffer
   withExportBufferLength:(int) export_buffer_length {
  try {
    return ptr->ExportPixelBuffer(export_buffer, export_buffer_length);
  } catch (const ocrstudio::OCRStudioSDKException& e) {
    printf("Exception thrown: %s\n", e.Message());
    return 0;
  }
  return -1;
}

-(NSString *) exportBase64JPEG {
  return [NSString stringWithUTF8String:ptr->ExportBase64JPEG().CStr()];
}

- (void) scale:(int) width
    withHeight:(int) height {
  if (!is_mutable) {
    throwNonMutableRefException();
  } else {
    try {
      ptr->Scale(width, height);
    } catch (const ocrstudio::OCRStudioSDKException& e) {
      printf("Exception thrown: %s\n", e.Message());
    }
  }
}

- (OBJCOCRStudioSDKImage *) deepCopyScaled:(int) width
                                                            withHeight:(int) height {
  try {
    return [[OBJCOCRStudioSDKImage alloc] initFromInternalOCRStudioSDKImage:ptr->DeepCopyScaled(width, height)];
  } catch (const ocrstudio::OCRStudioSDKException& e) {
    printf("Exception thrown: %s\n", e.Message());
    return nil;
  }
  return nil;
}

- (void) cropByQuad:(NSString *) quad_json
          withWidth:(int) width
         withHeight:(int) height {

  if (!is_mutable) {
    throwNonMutableRefException();
  } else {
    try {
      ptr->CropByQuad([quad_json UTF8String], width, height);
    } catch (const ocrstudio::OCRStudioSDKException& e) {
      printf("Exception thrown: %s\n", e.Message());
    }
  }
}

- (OBJCOCRStudioSDKImage *) deepCopyCroppedByQuad:(NSString *) quad_json
                                         withWidth:(int) width
                                        withHeight:(int) height {
  try {
    return [[OBJCOCRStudioSDKImage alloc] initFromInternalOCRStudioSDKImage:ptr->DeepCopyCroppedByQuad([quad_json UTF8String], width, height)];
  } catch (const ocrstudio::OCRStudioSDKException& e) {
    printf("Exception thrown: %s\n", e.Message());
    return nil;
  }
  return nil;
}

- (void) cropByRect:(int) x
             withY:(int) y
         withWidth:(int) width
        withHeight:(int) height {
  if (!is_mutable) {
    throwNonMutableRefException();
  } else {
    try {
      ptr->CropByRect(x, y, width, height);
    } catch (const ocrstudio::OCRStudioSDKException& e) {
      printf("Exception thrown: %s\n", e.Message());
    }
  }
}

- (OBJCOCRStudioSDKImage *) deepCopyCroppedByRect:(int) x
                                                                  withY:(int) y
                                                              withWidth:(int) width
                                                             withHeight:(int) height {
  try {
    return [[OBJCOCRStudioSDKImage alloc] initFromInternalOCRStudioSDKImage:ptr->DeepCopyCroppedByRect(x, y, width, height)];
  } catch (const ocrstudio::OCRStudioSDKException& e) {
    printf("Exception thrown: %s\n", e.Message());
    return nil;
  }
  return nil;
}

- (OBJCOCRStudioSDKImage *) shallowCopyCroppedByRect:(int) x
                                                                  withY:(int) y
                                                              withWidth:(int) width
                                                             withHeight:(int) height {
  try {
    return [[OBJCOCRStudioSDKImage alloc] initFromInternalOCRStudioSDKImage:ptr->ShallowCopyCroppedByRect(x, y, width, height)];
  } catch (const ocrstudio::OCRStudioSDKException& e) {
    printf("Exception thrown: %s\n", e.Message());
    return nil;
  }
  return nil;
}

- (void) rotateByNinety:(int) num_rotations {
  if (!is_mutable) {
    throwNonMutableRefException();
  } else {
    try {
      ptr->RotateByNinety(num_rotations);
    } catch (const ocrstudio::OCRStudioSDKException& e) {
      printf("Exception thrown: %s\n", e.Message());
    }
  }
}

- (OBJCOCRStudioSDKImage *) deepCopyRotatedByNinety:(int) num_rotations {
  try {
    return [[OBJCOCRStudioSDKImage alloc] initFromInternalOCRStudioSDKImage:ptr->DeepCopyRotatedByNinety(num_rotations)];
  } catch (const ocrstudio::OCRStudioSDKException& e) {
    printf("Exception thrown: %s\n", e.Message());
    return nil;
  }
  return nil;
}

- (int) width {
  return ptr->Width();
}

- (int) height {
  return ptr->Height();
}

- (int) bytesPerLine {
  return ptr->BytesPerLine();
}

- (int) channels {
  return ptr->Channels();
}

- (BOOL) ownsPixelData {
  return ptr->OwnsPixelData();
}

- (void) forcePixelDataOwnership {
  ptr->ForcePixelDataOwnership();
}

@end



@implementation OBJCOCRStudioSDKImage {
    std::unique_ptr<ocrstudio::OCRStudioSDKImage> internal;
}

- (instancetype) initFromInternalOCRStudioSDKImage:(ocrstudio::OCRStudioSDKImage *)image {
  if (self = [super init]) {
    internal.reset(image);
  }
  return self;
}

- (const ocrstudio::OCRStudioSDKImage &) getInternalOCRStudioSDKImage {
  return *internal;
}

- (instancetype) init {
  if (self = [super init]) {
    internal.reset(ocrstudio::OCRStudioSDKImage::CreateEmpty());
  }
  return self;
}

- (instancetype) initFromFile:(NSString *) filename
                        withPageNumber:(int) page_number
                          withMaxWidth:(int) max_width
                         withMaxHeight:(int) max_height {
  try {
    
    if (self = [super init]) {
      internal.reset(ocrstudio::OCRStudioSDKImage::CreateFromFile([filename UTF8String], 
                                                                                      page_number, 
                                                                                      max_width, 
                                                                                      max_height));
    }
    return self;
  } catch (const ocrstudio::OCRStudioSDKException& e){
      printf("Exception thrown: %s\n", e.Message());
      return nil;
  }
}

- (instancetype) initFromFileBuffer:(unsigned char *) data
                          withDataSize:(int) data_size
                        withPageNumber:(int) page_number
                          withMaxWidth:(int) max_width
                         withMaxHeight:(int) max_height {
  try {
    if (self = [super init]) {
      internal.reset(ocrstudio::OCRStudioSDKImage::CreateFromFileBuffer(data, 
                                                                                data_size, 
                                                                                page_number, 
                                                                                max_width, 
                                                                                max_height));
    }
    return self;
  } catch (const ocrstudio::OCRStudioSDKException& e){
      printf("Exception thrown: %s\n", e.Message());
      return nil;
  }
}

- (instancetype) initFromBase64FileBuffer:(NSString *) base64_data
                                    withPageNumber:(int) page_number
                                          withMaxWidth:(int) max_width
                                         withMaxHeight:(int) max_height{
  try {
    if (self = [super init]) {
      internal.reset(ocrstudio::OCRStudioSDKImage::CreateFromBase64FileBuffer([base64_data UTF8String], 
                                                                              page_number, 
                                                                              max_width, 
                                                                              max_height));
    }
    return self;
  } catch (const ocrstudio::OCRStudioSDKException& e){
      printf("Exception thrown: %s\n", e.Message());
      return nil;
  }
}

- (nonnull instancetype) initFromPixelBuffer:(unsigned char *) data
                                                 withDataSize:(int) data_size
                                                     witWidth:(int) width
                                                   withHeight:(int) height
                                             withBytesPerLine:(int) bytes_per_line
                                          withBytesPerChannel:(int) bytes_per_channel
                                              withPixelFormat:(OBJCOCRStudioSDKPixelFormat) pixel_format{
  try {
    if (self = [super init]) {
      ocrstudio::OCRStudioSDKPixelFormat pixel_f = convertFormat(pixel_format);
      internal.reset(ocrstudio::OCRStudioSDKImage::CreateFromPixelBuffer(data, 
                                                              data_size, 
                                                              width, height, 
                                                              bytes_per_line, 
                                                              bytes_per_channel, 
                                                              pixel_f));
    }
    return self;
  } catch (const ocrstudio::OCRStudioSDKException& e){
      printf("Exception thrown: %s\n", e.Message());
      return nil;
  }
}

- (instancetype) initFromSampleBuffer:(CMSampleBufferRef)sampleBuffer {
  if (self = [super init]) {
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    uint8_t* basePtr = (uint8_t*)CVPixelBufferGetBaseAddress(imageBuffer);

    const int bytesPerRow = static_cast<int>(CVPixelBufferGetBytesPerRow(imageBuffer));
    const int width = static_cast<int>(CVPixelBufferGetWidth(imageBuffer));
    const int height = static_cast<int>(CVPixelBufferGetHeight(imageBuffer));
    const int channels = 4; // assuming BGRA

    if (basePtr == 0 || bytesPerRow == 0 || width == 0 || height == 0) {
      return nil;
    }

    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
    try {
      internal.reset(ocrstudio::OCRStudioSDKImage::CreateFromBuffer(basePtr, 
                                                                 bytesPerRow * height,
                                                                 width,
                                                                 height,
                                                                 bytesPerRow,
                                                                 channels));
    } catch (const ocrstudio::OCRStudioSDKException& e) {
      internal.reset();
      throwFromException(e);
    }
  }
  return self;
}

- (nonnull OBJCOCRStudioSDKImage *) initFromYUVSimple:(unsigned char *) yuv_data
                                            withYuvDataSize:(int) yuv_data_size
                                                  withWidth:(int) width
                                                 withHeight:(int) height{
  try {
    if (self = [super init]) {
      internal.reset(ocrstudio::OCRStudioSDKImage::CreateFromYUVSimple(yuv_data, 
                                                              yuv_data_size, width, height));
    }
    return self;
  } catch (const ocrstudio::OCRStudioSDKException& e){
      printf("Exception thrown: %s", e.Message());
      return nil;
  }
}

- (nonnull OBJCOCRStudioSDKImage *) initFromYUV:(unsigned char *) y_plane
                                         withYPlaneSize:(int) y_plane_size
                                    withYPlaneRowStride:(int) y_plane_row_stride
                                  withYPlanePixelStride:(int) y_plane_pixel_stride
                                             withUPlane:(unsigned char *) u_plane
                                         withUPlaneSize:(int) u_plane_size
                                    withUPlaneRowStride:(int) u_plane_row_stride
                                  withUPlanePixelStride:(int) u_plane_pixel_stride
                                             withVPlane:(unsigned char *) v_plane
                                         withVPlaneSize:(int) v_plane_size
                                    withVPlaneRowStride:(int) v_plane_row_stride
                                  withVPlanePixelStride:(int) v_plane_pixel_stridet
                                               witWidth:(int) width
                                             withHeight:(int) height
                                          withYUVFormat:(OBJCOCRStudioSDKYUVFormat) yuv_format{
  try {
    if (self = [super init]) {
      ocrstudio::OCRStudioSDKYUVFormat yuv_format_ = convertFormat(yuv_format);
      internal.reset(ocrstudio::OCRStudioSDKImage::CreateFromYUV(y_plane, 
                                                              y_plane_size, y_plane_row_stride, y_plane_pixel_stride,
                                                              u_plane,
                                                              u_plane_size, u_plane_row_stride, u_plane_pixel_stride,
                                                              v_plane,
                                                              v_plane_size, v_plane_row_stride, v_plane_pixel_stridet,
                                                              width, height,
                                                              yuv_format_));
    }
    return self;
  } catch (const ocrstudio::OCRStudioSDKException& e){
      printf("Exception thrown: %s\n", e.Message());
      return nil;
  }
}

#ifndef OBJCOCRSTUDIOSDK_WITHOUT_UIKIT
- (instancetype) initFromUIImage:(UIImage *)image {

  if (self = [super init]) {
    CGImageRef cgImage = [image CGImage];
    CGDataProviderRef provider = CGImageGetDataProvider(cgImage);
    CGImageAlphaInfo alpha_info = CGImageGetAlphaInfo(cgImage);
    size_t channels_num = CGImageGetBitsPerPixel(cgImage) / CGImageGetBitsPerComponent(cgImage);
    CFDataRef dataRef = CGDataProviderCopyData(provider);
    unsigned char* data = const_cast<unsigned char*>(CFDataGetBytePtr(dataRef));
    try {
      OBJCOCRStudioSDKPixelFormat pixel_format;
      switch (alpha_info) {
        case kCGImageAlphaNone:
          if (channels_num == 1) {
            pixel_format = OBJCOCRStudioSDKPixelFormat_G;
          } else if (channels_num == 3) {
            pixel_format = OBJCOCRStudioSDKPixelFormat_RGB;
          } else {
            throw(ocrstudio::OCRStudioSDKException("NotSupportedException", "Unsupported image format"));
          }
          break;
        case kCGImageAlphaLast:
          if (channels_num == 2) {
            pixel_format = OBJCOCRStudioSDKPixelFormat_GA;
          } else if (channels_num == 4) {
            pixel_format = OBJCOCRStudioSDKPixelFormat_RGBA;
          } else {
            throw(ocrstudio::OCRStudioSDKException("NotSupportedException", "Unsupported image format"));
          }
          break;
        case kCGImageAlphaFirst:
          if (channels_num == 2) {
            pixel_format = OBJCOCRStudioSDKPixelFormat_AG;
          } else if (channels_num == 4) {
            pixel_format = OBJCOCRStudioSDKPixelFormat_ARGB;
          } else {
            throw(ocrstudio::OCRStudioSDKException("NotSupportedException", "Unsupported image format"));
          }
          break;
        case kCGImageAlphaNoneSkipLast:
          if (channels_num == 2) {
            pixel_format = OBJCOCRStudioSDKPixelFormat_GA;
          } else if (channels_num == 4) {
            pixel_format = OBJCOCRStudioSDKPixelFormat_RGBA;
          } else {
            throw(ocrstudio::OCRStudioSDKException("NotSupportedException", "Unsupported image format"));
          }
          break;
        case kCGImageAlphaNoneSkipFirst:
          if (channels_num == 2) {
            pixel_format = OBJCOCRStudioSDKPixelFormat_AG;
          } else if (channels_num == 4) {
            pixel_format = OBJCOCRStudioSDKPixelFormat_ARGB;
          } else {
            throw(ocrstudio::OCRStudioSDKException("NotSupportedException", "Unsupported image format"));
          }
          break;
          case kCGImageAlphaPremultipliedLast:
          if (channels_num == 2) {
            pixel_format = OBJCOCRStudioSDKPixelFormat_AG;
          } else if (channels_num == 4){
            pixel_format = OBJCOCRStudioSDKPixelFormat_RGBA;
          } else {
            throw(ocrstudio::OCRStudioSDKException("NotSupportedException", "Unsupported image format"));
          }
          break;
          case kCGImageAlphaPremultipliedFirst:
          if (channels_num == 2) {
            pixel_format = OBJCOCRStudioSDKPixelFormat_AG;
          } else if (channels_num == 4) {
            pixel_format = OBJCOCRStudioSDKPixelFormat_ARGB;
          } else {
            throw(ocrstudio::OCRStudioSDKException("NotSupportedException", "Unsupported image format"));
          }
          break;
          case kCGImageAlphaOnly:
              throw(ocrstudio::OCRStudioSDKException("NotSupportedException", "Unsupported image format. No color data, alpha data only"));
          break;
        default:
          throw(ocrstudio::OCRStudioSDKException("NotSupportedException", "Unsupported image format"));
          break;
      }
      
      int bits_per_comp = static_cast<int>(CGImageGetBitsPerComponent(cgImage));
      
      int bytes_per_comp = bits_per_comp / 8;
      
      int width = static_cast<int>(CGImageGetWidth(cgImage));
      int height = static_cast<int>(CGImageGetHeight(cgImage));
      int stride = static_cast<int>(CGImageGetBytesPerRow(cgImage));
      
      internal.reset(ocrstudio::OCRStudioSDKImage::CreateFromPixelBuffer(data,
                                                                      stride * height,
                                                                      width,
                                                                      height,
                                                                      stride,
                                                                      bytes_per_comp,
                                                                      convertFormat(pixel_format)));

      CFRelease(dataRef);
    } catch (const ocrstudio::OCRStudioSDKException& e) {
      internal.reset();
      CFRelease(dataRef);
      throwFromException(e);
    }
  }
  return self;
}
#endif // OBJCOCRSTUDIOSDK_WITHOUT_UIKIT

+ (int) pagesCount:(NSString *) filename {
  return ocrstudio::OCRStudioSDKImage::PagesCount([filename UTF8String]);
}

+ (NSString *) pageName:(NSString *) filename
                withPageNumber:(int) page_number {
  return [NSString stringWithUTF8String:ocrstudio::OCRStudioSDKImage::PageName([filename UTF8String], page_number).CStr()];
  // return [NSString stringWithUTF8String:internal->PageName([filename UTF8String], page_number).CStr()];
}


- (OBJCOCRStudioSDKImageRef *) getRef {
  return [[OBJCOCRStudioSDKImageRef alloc]
      initFromInternalOCRStudioSDKImagePointer:internal.get()
                 withMutabilityFlag:NO];
}

- (OBJCOCRStudioSDKImageRef *) getMutableRef {
  return [[OBJCOCRStudioSDKImageRef alloc]
      initFromInternalOCRStudioSDKImagePointer:internal.get()
                 withMutabilityFlag:YES];
}

@end
