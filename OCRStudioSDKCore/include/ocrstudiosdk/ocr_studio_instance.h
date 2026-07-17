/**
  Copyright (c) 2024-2026, OCR Studio
  All rights reserved.
*/

/**
 * @file ocr_studio_instance.h
 * @brief Main recognition engine instance class declaration
 */

#pragma once
#ifndef OCRSTUDIOSDK_OCR_STUDIO_INSTANCE_H_INCLUDED
#define OCRSTUDIOSDK_OCR_STUDIO_INSTANCE_H_INCLUDED

#include <ocrstudiosdk/ocr_studio_export.h>
#include <ocrstudiosdk/ocr_studio_session.h>
#include <ocrstudiosdk/ocr_studio_delegate.h>

namespace ocrstudio {

/**
 * @brief Main recognition engine class containing configuration for creating
 *        recognition sessions
 */
class OCR_STUDIO_SDK_DLL_EXPORT OCRStudioSDKInstance {
public:
  /**
   * @brief Creates a new recognition engine instance from an internal configuration,
   *        embedded inside the library, if one is available. If no configuration is
   *        embedded inside, the method will throw an exception.
   * @param json_instance_init_params - optional JSON with initialization parameters,
   *        in the following format (all keys are optional): 
   *        {
   *          "enable_lazy_initialization": (bool),
   *          "enable_delayed_initialization": (bool),
   *          "initialization_num_threads": (int >= 0)
   *        }
   * @return Pointer to a new instance object, the ownership is relinquished.
   */
  static OCRStudioSDKInstance* CreateStandalone(
      const char* json_instance_init_params = nullptr);

  /**
   * @brief Creates a new recognition engine instance from a configuration file (a binary
   *        file with an extension '.ocr').
   * @param configuration_filename - path to a configuration file *.ocr
   * @param json_instance_init_params - optional JSON with initialization parameters,
   *        in the following format (all keys are optional): 
   *        {
   *          "enable_lazy_initialization": (bool),
   *          "enable_delayed_initialization": (bool),
   *          "initialization_num_threads": (int >= 0)
   *        }
   * @return Pointer to a new instance object, the ownership is relinquished.
   */
  static OCRStudioSDKInstance* CreateFromPath(
      const char* configuration_filename,
      const char* json_instance_init_params = nullptr);

  /**
   * @brief Creates a new recognition engine instance from a configuration buffer (a binary
   *        buffer where the configuration file is loaded).
   * @param configuration_buffer - pointer to a binary configuration buffer
   * @param configuration_buffer_size - size of the configuration buffer in bytes
   * @param json_instance_init_params - optional JSON with initialization parameters,
   *        in the following format (all keys are optional): 
   *        {
   *          "enable_lazy_initialization": (bool),
   *          "enable_delayed_initialization": (bool),
   *          "initialization_num_threads": (int >= 0)
   *        }
   * @return Pointer to a new instance object, the ownership is relinquished.
   */ 
  static OCRStudioSDKInstance* CreateFromBuffer(
      unsigned char* configuration_buffer,
      int            configuration_buffer_size,
      const char*    json_instance_init_params = nullptr);

public:

  /**
   * @brief Returns a string representation of the OCRStudioSDK library version
   */
  static const char* LibraryVersion();

public:
  /// Default destructor
  virtual ~OCRStudioSDKInstance() = default;

  /**
   * @brief Returns a description of a configured engine in JSON format
   * @return a JSON description in the following format:
   *         {
   *           "session_types": [
   *             (list of available session types)
   *           ],
   *           "target_groups": [ // present if there are target-oriented sessions
   *             {
   *               "target_group_type": "(group_type_name)",
   *               "targets": ["(target_name)", ...],
   *               "target_masks": ["(target_mask)", ...]
   *             },
   *             ...
   *           ]
   *         }
   */
  virtual const char* Description() const = 0;

  /**
   * @brief Creates a processing session with the provided parameters
   * @param authorization_signature - signature of an authorized SDK user
   * @param json_session_params - parameters of the created session,
   *        encoded in JSON in the following format:
   *        {
   *          "session_type": "(session_type)",
   *          "target_group_type": "(group_type_name)",
   *          "target_masks": ["(target_name_or_mask", ...], // optional, single string permitted
   *          "options": { // optional
   *            "(option_name)": "(option_value)",
   *            ...
   *          },
   *          "output_modes": ["(output_mode)", ...]  
   *        }
   *        Possible variants for "output_mode" are "character_alternatives" and "field_geometry".
   * @param callback_delegate - optional pointer to an implemented instance
   *        of a delegate for receiving runtime messages.
   * @return Pointer to a new session, the ownership is relinquished.
   */
  virtual OCRStudioSDKSession* CreateSession(
      const char* authorization_signature,
      const char* json_session_params,
      OCRStudioSDKDelegate* callback_delegate = nullptr) const = 0;
};

} // namespace ocrstudio

#endif // OCRSTUDIOSDK_OCR_STUDIO_INSTANCE_H_INCLUDED
