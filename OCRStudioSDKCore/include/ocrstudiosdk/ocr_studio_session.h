/**
  Copyright (c) 2024-2026, OCR Studio
  All rights reserved.
*/

/**
 * @file ocr_studio_session.h
 * @brief Main processing session class declaration
 */

#pragma once
#ifndef OCRSTUDIOSDK_OCR_STUDIO_SESSION_H_INCLUDED
#define OCRSTUDIOSDK_OCR_STUDIO_SESSION_H_INCLUDED

#include <ocrstudiosdk/ocr_studio_export.h>
#include <ocrstudiosdk/ocr_studio_image.h>
#include <ocrstudiosdk/ocr_studio_result.h>

namespace ocrstudio {

/**
 * @brief Main processing session class - agent for performing image analysis
 */
class OCR_STUDIO_SDK_DLL_EXPORT OCRStudioSDKSession {
public:
  /// Default destructor
  virtual ~OCRStudioSDKSession() = default;

public:
  /**
   * @brief Returns a description of a created session in JSON format
   * @return a JSON description in the following format:
   *        {
   *          "session_type": "(session_type)",
   *          "target_group_type": "(group_type_name)",
   *          "targets": ["(target_name)", ...],
   *          "options": {
   *            "(option_name)": "(option_value)",
   *            ...
   *          },
   *          "output_modes": ["(output_mode)", ...]
   *        }
   */
  virtual const char* Description() const = 0;

  /**
   * @brief Processes an input image or video frame, updates the internal
   *        session state.
   * @param image - the input image to be processed
   */
  virtual void ProcessImage(const OCRStudioSDKImage& image) = 0;

   /**
   * @brief Processes an input json as a string
   * @param data_str - the input JSON containing a description of mrz and photo in the following format:
   *        {
   *          "doc_type": "(doc_type)",
   *          "physical_fields": {
   *            "rfid_mrz": {
   *              "value": "(mrz)",
   *              "type": "String"
   *            },
   *            "rfid_photo": {
   *              "value": "(photo_string)",
   *              "type": "Image"
   *            }
   *          }
   *        }
   */
  virtual void ProcessData(const char* data_str) = 0;

  /**
   * @brief Returns the current accumulated result
   * @return Current accumulated session result (constant reference to an
   *         internal structure, the memory is owned by the session)
   */
  virtual const OCRStudioSDKResult& CurrentResult() const = 0;

  /**
   * @brief Resets the state of the session to the initial one
   */
  virtual void Reset() = 0;

  /**
   * @brief Suspend the session
   */
  virtual void Suspend() = 0;

  /**
   * @brief Resume the session
   */
  virtual void Resume() = 0;
  
};

} // namespace ocrstudio

#endif // OCRSTUDIOSDK_OCR_STUDIO_SESSION_H_INCLUDED
