/**
  Copyright (c) 2024-2026, OCR Studio
  All rights reserved.
*/

/**
 * @file ocr_studio_image.h
 * @brief Common image manipulation facilities
 */

#pragma once
#ifndef OCRSTUDIOSDK_OCR_STUDIO_IMAGE_H_INCLUDED
#define OCRSTUDIOSDK_OCR_STUDIO_IMAGE_H_INCLUDED

#include <ocrstudiosdk/ocr_studio_export.h>
#include <ocrstudiosdk/ocr_studio_string.h>

namespace ocrstudio {

/**
 * @brief Pixel format - sequence of pixel components
 */
enum OCR_STUDIO_SDK_DLL_EXPORT OCRStudioSDKPixelFormat {
  OCRSTUDIOSDK_PIXEL_FORMAT_G = 0,     ///< Greyscale
  OCRSTUDIOSDK_PIXEL_FORMAT_GA,        ///< Greyscale + Alpha
  OCRSTUDIOSDK_PIXEL_FORMAT_AG,        ///< Alpha + Greyscale
  OCRSTUDIOSDK_PIXEL_FORMAT_RGB,       ///< RGB
  OCRSTUDIOSDK_PIXEL_FORMAT_BGR,       ///< BGR
  OCRSTUDIOSDK_PIXEL_FORMAT_BGRA,      ///< BGR + Alpha
  OCRSTUDIOSDK_PIXEL_FORMAT_ARGB,      ///< Alpha + RGB
  OCRSTUDIOSDK_PIXEL_FORMAT_RGBA       ///< RGB + Alpha
};



/**
 * @brief YUV format standard type - YUV subtype, used for extended YUV decoding
 */
enum OCR_STUDIO_SDK_DLL_EXPORT OCRStudioSDKYUVFormat {
  OCRSTUDIOSDK_YUV_FORMAT_NOT_SET = 0,  ///< Not set
  OCRSTUDIOSDK_YUV_FORMAT_NV21,         ///< NV 21
  OCRSTUDIOSDK_YUV_FORMAT_420_888       ///< YUV 420 888
};



/**
 * @brief Bitmap image class
 */
class OCR_STUDIO_SDK_DLL_EXPORT OCRStudioSDKImage {
public:
  /**
   * @brief For multi-page images, returns the number of pages in an image file
   * @param filename - path to an image file
   * @return The number of pages in an image
   */
  static int PagesCount(const char* filename);

  /**
   * @brief For multi-page images, returns the filename of a particular page
   * @param filename - Filename of a particular image page
   * @param page_number - page number, starting with 0
   * @returns The string representation of a page filename
   */
  static OCRStudioSDKString PageName(
      const char *filename, int page_number);

public:
  /**
   * @brief Creates an empty image
   * @return Pointer to a new image, the ownership is relinquished.
   */
  static OCRStudioSDKImage* CreateEmpty();

  /**
   * @brief Creates an image from file
   * @param filename - path to an image file (png, jpg, tif)
   * @param page_number - page number, starting with 0
   * @param max_width - maximum image width in pixels (0 for unrestricted)
   * @param max_height - maximum image height in pixels (0 for unrestricted)
   * @return Pointer to a new image, the ownership is relinquished.
   */
  static OCRStudioSDKImage* CreateFromFile(
      const char* filename,
      int         page_number = 0,
      int         max_width = 25000,
      int         max_height = 25000);

  /**
   * @brief Creates an image from file loaded in a buffer
   * @param data - pointer to a loaded file buffer
   * @param data_size - size of the loaded file buffer
   * @param page_number - page number, starting with 0
   * @param max_width - maximum image width in pixels (0 for unrestricted)
   * @param max_height - maximum image height in pixels (0 for unrestricted)
   * @return Pointer to a new image, the ownership is relinquished.
   */
  static OCRStudioSDKImage* CreateFromFileBuffer(
      unsigned char* data,
      int            data_size,
      int            page_number = 0,
      int            max_width = 25000,
      int            max_height = 25000);

  /**
   * @brief Creates an image from file loaded in a buffer encoded in base64
   * @param base64_data - file buffer encoded as a base64 string
   * @param page_number - page number, starting with 0
   * @param max_width - maximum image width in pixels (0 for unrestricted)
   * @param max_height - maximum image height in pixels (0 for unrestricted)
   * @return Pointer to a new image, the ownership is relinquished.
   */
  static OCRStudioSDKImage* CreateFromBase64FileBuffer(
      const char* base64_data, 
      int         page_number = 0,
      int         max_width = 25000,
      int         max_height = 25000);

  /**
   * @brief Creates an image from a pixel buffer, the content is copied
   * @param data - pointer to a pixels buffer
   * @param data_size - size of the pixels buffer
   * @param width - width of the image in pixels
   * @param height - height of the image in pixels
   * @param bytes_per_line - size of an image row in bytes (including alignment)
   * @param bytes_per_channel - size of a pixel component in bytes
   * @param pixel_format - pixel format
   * @return Pointer to a new image, the ownership is relinquished.
   */
  static OCRStudioSDKImage* CreateFromPixelBuffer(
      unsigned char* data,
      int            data_size,
      int            width,
      int            height,
      int            bytes_per_line,
      int            bytes_per_channel,
      OCRStudioSDKPixelFormat pixel_format);
  
  /**
   * @brief Creates an image from a buffer, the content is copied
   * @param data - pointer to a pixels buffer
   * @param data_size - size of the pixels buffer
   * @param width - width of the image in pixels
   * @param height - height of the image in pixels
   * @param bytes_per_line - size of an image row in bytes (including alignment)
   * @param channels number of channels per-pixel
   * @return Pointer to a new image, the ownership is relinquished.
   */
  static OCRStudioSDKImage* CreateFromBuffer(
      unsigned char* data,
      int            data_size,
      int            width,
      int            height,
      int            bytes_per_line,
      int            channels);

  /**
   * @brief Creates an image from a simple YUV NV21 buffer
   * @param yuv_data - pointer to YUV NV21 buffer
   * @param yuv_data_size - size of the YUV NV21 buffer
   * @param width - width of the image in pixels
   * @param height - height of the image in pixels
   * @return Pointer to a new image, the ownership is relinquished.
   */
  static OCRStudioSDKImage* CreateFromYUVSimple(
      unsigned char* yuv_data,
      int            yuv_data_size,
      int            width,
      int            height);

  /**
   * @brief Creates an image from a universal YUV buffer.
   * @param y_plane - pointer to Y plane buffer
   * @param y_plane_size - Y plane buffer size
   * @param y_plane_row_stride - Y plane row stride
   * @param y_plane_pixel_stride - Y plane pixel stride
   * @param u_plane - pointer to U plane buffer
   * @param u_plane_size - U plane buffer size
   * @param u_plane_row_stride - U plane row stride
   * @param u_plane_pixel_stride - U plane pixel stride
   * @param v_plane - pointer to V plane buffer
   * @param v_plane_size - V plane buffer size
   * @param v_plane_row_stride - V plane row stride
   * @param v_plane_pixel_stride - V plane pixel stride
   * @param width - image width in pixels
   * @param height - image height in pixels
   * @param yuv_format - YUV format specification
   * @return Pointer to a new image, the ownership is relinquished.
   */
  static OCRStudioSDKImage* CreateFromYUV(
      unsigned char* y_plane,
      int            y_plane_size,
      int            y_plane_row_stride,
      int            y_plane_pixel_stride,
      unsigned char* u_plane,
      int            u_plane_size,
      int            u_plane_row_stride,
      int            u_plane_pixel_stride,
      unsigned char* v_plane,
      int            v_plane_size,
      int            v_plane_row_stride,
      int            v_plane_pixel_stride,
      int            width,
      int            height,
      OCRStudioSDKYUVFormat yuv_format);

public:
  /// Default destructor
  virtual ~OCRStudioSDKImage() = default;

  /**
   * @brief Copies an image with copying of all pixels.
   * @return Pointer to a new copied image, the ownership is relinquished.
   */
  virtual OCRStudioSDKImage* DeepCopy() const = 0;

  /**
   * @brief Copies an image without copying the pixels, retaining internal
   *        memory reference. The operations with the copied image will be
   *        invalid after the source is deleted.
   * @return Pointer to a new copied image, the ownership is relinquished.
   */
  virtual OCRStudioSDKImage* ShallowCopy() const = 0;

  /**
   * @brief Clears the internal structure of the image
   */
  virtual void Clear() = 0;

  /**
   * @brief Returns the required size of the export pixel buffer
   * @return Number of required bytes
   */
  virtual int ExportPixelBufferLength() const = 0;

  /**
   * @brief Copies the pixels into an external buffer. For any image the exported
   *        buffer pixels will have 8-bit channels (0 means lowest intensity,
   *        255 means highest intensity). 1-channel images are exported as grayscale,
   *        3-channel images are exported as RGB, other images are copied as-is.
   * @param export_buffer - pointer to an output pixels buffer
   * @param export_buffer_length - available buffer size. Must be at least the size
   *        returned by the ExportPixelBufferLength() method.
   * @return The number of written bytes
   */
  virtual int ExportPixelBuffer(unsigned char* export_buffer, int export_buffer_length) const = 0;

  /**
   * @brief Exports image as a JPEG buffer encoded in base64
   * @return Base64 JPEG encoding of an image in a OCRStudioSDKString form
   */
  virtual OCRStudioSDKString ExportBase64JPEG() const = 0;

  /**
   * @brief Scales the internal image to a new size
   * @param width - new width of the image in pixels
   * @param height - new height of the image in pixels
   */
  virtual void Scale(int width, int height) = 0;

  /**
   * @brief Copies the image with scaling to a new size
   * @param width - new width of the image in pixels
   * @param height - new height of the image in pixels
   * @return Pointer to a new scaled image, the ownership is relinquished.
   */
  virtual OCRStudioSDKImage* DeepCopyScaled(int width, int height) const = 0;

  /**
   * @brief Crops an image quadrilateral to a new image, with a new 
   *        provided size. If width or height is less or equal to zero, the size
   *        will be calculated approximately based on an input quadrilateral
   * @param quad_json - JSON representation of a quadrangle coordinates, 
   *        in form [[x1, y1], [x2, y2], [x3, y3], [x4, y4]]
   * @param width - new width of the image in pixels (or <= 0 for size autoselection)
   * @param height - new height of the image in pixels (or <= 0 for size autoselection)
   */

  virtual void CropByQuad(const char* quad_json, int width, int height) = 0;

  /**
   * @brief Copies an image cropped by a quadrilateral, with a new provided
   *        size. If width or height is less or equal to zero, the size will
   *        be calculated approximately based on an input quadrilateral
   * @param quad_json - JSON representation of a quadrangle coordinates,
   *        in form [[x1, y1], [x2, y2], [x3, y3], [x4, y4]]
   * @param width - new width of the image in pixels (or <= 0 for size autoselection)
   * @param height - new height of the image in pixels (or <= 0 for size autoselection)
   * @return Pointer to a new cropped image, the ownership is relinquished.
   */
  virtual OCRStudioSDKImage* DeepCopyCroppedByQuad(
      const char* quad_json, int width, int height) const = 0;

  /**
   * @brief Crops an image to a rectangular region
   * @param x - horizontal coordinate of the top-left corner
   * @param y - vertical coordinate of the top-left corner
   * @param width - width of the rectangle
   * @param height - height of the rectangle
   */
  virtual void CropByRect(int x, int y, int width, int height) = 0;

  /**
   * @brief Copies an image cropped to a rectangular region
   * @param x - horizontal coordinate of the top-left corner
   * @param y - vertical coordinate of the top-left corner
   * @param width - width of the rectangle
   * @param height - height of the rectangle
   * @return Pointer to a new cropped image, the ownership is relinquished.
   */
  virtual OCRStudioSDKImage* DeepCopyCroppedByRect(
      int x, int y, int width, int height) const = 0;

  /**
   * @brief Shallow-copies an image cropped to a rectangular region.
   *        Operations on the resulting image are invalid after the source
   *        image is deleted.
   * @param x - horizontal coordinate of the top-left corner
   * @param y - vertical coordinate of the top-left corner
   * @param width - width of the rectangle
   * @param height - height of the rectangle
   * @return Pointer to a new cropped image, the ownership is relinquished.
   */
  virtual OCRStudioSDKImage* ShallowCopyCroppedByRect(
      int x, int y, int width, int height) const = 0;

  /**
   * @brief Rotates the image clockwise by 90 degrees
   * @param num_rotations - the number of times the rotation is performed
   */
  virtual void RotateByNinety(int num_rotations) = 0;

  /**
   * @brief Copies the image rotated clockwise by 90 degrees
   * @param num_rotations - the number of times the rotation is performed
   * @return Pointer to a new rotated image, the ownership is relinquished.
   */
  virtual OCRStudioSDKImage* DeepCopyRotatedByNinety(int num_rotations) const = 0;

  /// Image width in pixels
  virtual int Width() const = 0;

  /// Image height in pixels
  virtual int Height() const = 0;

  /// Size of the image row in bytes, including alignment
  virtual int BytesPerLine() const = 0;

  /// The number of channels per pixel
  virtual int Channels() const = 0;

  /// Gets the pointer to the pixels buffer
  virtual void* UnsafeBufferPtr() const = 0;

  /// Whether this instance owns and will release pixel data
  virtual bool OwnsPixelData() const = 0;

  /// Forces pixel data ownership - for shallow images, copies all pixels
  virtual void ForcePixelDataOwnership() = 0;


  /**
  * @brief Add the image with the specified name to the internal layers collection
  *        by transfering the given image to the internal layers collection. 
  *        The caller has to release the ownership of the set image.
  * @param name the name of the new layer
  * @param image the pointer to the value of the new layer
  */
  virtual void SetLayerWithOwnership(const char* name, OCRStudioSDKImage* image) = 0;
};


} // namespace ocrstudio

#endif // OCRSTUDIOSDK_OCR_STUDIO_IMAGE_H_INCLUDED
