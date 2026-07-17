/**
  Copyright (c) 2024-2026, OCR Studio
  All rights reserved.
*/

/**
 * @file ocr_studio_result.h
 * @brief Result containers
 */

#pragma once
#ifndef OCRSTUDIOSDK_OCR_STUDIO_RESULT_H_INCLUDED
#define OCRSTUDIOSDK_OCR_STUDIO_RESULT_H_INCLUDED

#include <ocrstudiosdk/ocr_studio_export.h>
#include <ocrstudiosdk/ocr_studio_string.h>
#include <ocrstudiosdk/ocr_studio_image.h>

namespace ocrstudio {

/**
 * @brief A constituent object of a recognized or analyzed target
 */
class OCR_STUDIO_SDK_DLL_EXPORT OCRStudioSDKItem {
public:
  /// Default destructor
  virtual ~OCRStudioSDKItem() = default;

  /**
   * @brief Copies an item with copying of all internal information
   * @return Pointer to a new item structure, the ownership is relinquished.
   */
  virtual OCRStudioSDKItem* DeepCopy() const = 0;

  /// Returns the type of the item
  virtual const char* Type() const = 0;

  /// Returns the name of the item
  virtual const char* Name() const = 0;

  /// Returns the string representatio of the value of the item
  virtual const char* Value() const = 0;

  /// Returns the item confidence value (doubole in range [0.0, 1.0])
  virtual double Confidence() const = 0;

  /// Returns the item accept flag
  virtual bool Accepted() const = 0;

  /**
   * @brief Returns the attributes of the item in JSON format
   * @return a JSON attributes map in the following format:
   *         {
   *           "(attribute_name)": "(attribute_value)"
   *         }
   */
  virtual const char* Attributes() const = 0;

  /// Returns true iff the item has an associated image
  virtual bool HasImage() const = 0;

  /// Returns the associated image
  virtual const OCRStudioSDKImage& Image() const = 0;

  /// Returns a detailed JSON description (format depends on the type)
  virtual const char* Description() const = 0;
};



/**
 * @brief Forward declaraction of an internal implementation of OCRStudioSDKItemIterator
 */
class OCRStudioSDKItemIteratorImplementation;

/**
 * @brief Map-like iterator for a collection of OCRStudioSDKItem objects
 */
class OCR_STUDIO_SDK_DLL_EXPORT OCRStudioSDKItemIterator {
public:
  /// Non-trivial destructor
  ~OCRStudioSDKItemIterator();

  /// Copy constructor
  OCRStudioSDKItemIterator(const OCRStudioSDKItemIterator& copy);

  /// Assignment operator
  OCRStudioSDKItemIterator& operator =(const OCRStudioSDKItemIterator& other);

  /// Returns true iff the instances point to the same item
  bool IsEqualTo(const OCRStudioSDKItemIterator& other) const;

  /// Equality operator
  bool operator ==(const OCRStudioSDKItemIterator& other) const;

  /// Inequality operator
  bool operator !=(const OCRStudioSDKItemIterator& other) const;

  /// Returns the iterator to the next item in the collection
  OCRStudioSDKItemIterator Next() const;

  /// Moves the iterator to the next item in the collection
  void Step();

  /// Moves the iterator to the next item in the collection
  void operator ++();

  /// Returns the key of the item in the collection
  const char* Key() const;

  /// Returns the item to which the iterator points (const ref)
  const OCRStudioSDKItem& Item() const;

public:
  /// Creates an OCRStudioSDKItemIterator object from its internal implementation
  static OCRStudioSDKItemIterator CreateFromImplementation(
      const OCRStudioSDKItemIteratorImplementation& rimpl);

private:
  /// Private constructor from an internal implementation
  OCRStudioSDKItemIterator(const OCRStudioSDKItemIteratorImplementation& rimpl);

  /// Internal implementation
  OCRStudioSDKItemIteratorImplementation* pimpl_;
};



/**
 * @brief Recognition or analysis target (document or other object)
 */
class OCR_STUDIO_SDK_DLL_EXPORT OCRStudioSDKTarget {
public:
  /// Default destructor
  virtual ~OCRStudioSDKTarget() = default;

  /**
   * @brief Copies a target with copying of all internal information
   * @return Pointer to a new target structure, the ownership is relinquished.
   */
  virtual OCRStudioSDKTarget* DeepCopy() const = 0;

  /**
   * @brief Returns a description of a target in JSON format
   * @return a JSON description in the following format:
   *         {
   *          "target_type": "(target_type_name)",
   *          "specific_type": "(specific_type_name)",
   *          "item_types": ["(item_type_name)", ...],
   *          "attributes": {
   *            "(attribute_name)": "(attribute_value)",
   *            ...
   *          }  
   *        }
   */
  virtual const char* Description() const = 0;

  /**
   * @brief Returns the number of items with a provided item type
   * @param item_type - name of the item type
   * @return The number of items of the specified type. The number of items
   *         is zero if the stored collection has zero size or if the
   *         specified item type is not supported for the returned target type
   */ 
  virtual int ItemsCountByType(const char* item_type) const = 0;

  /**
   * @brief Checks whether ther is an item of a specified type with 
   *        a specified item name
   * @param item_type - name of the item type 
   * @param item_name - name of the specific item
   * @return true iff there exists an item with a provided name in the
   *         collection of items of the provided type
   */
  virtual bool HasItem(const char* item_type, const char* item_name) const = 0;

  /**
   * @brief Returns a specific item
   * @param item_type - name of the item type
   * @param item_name - name of the specific item
   * @return Specific item object (constant reference)
   */
  virtual const OCRStudioSDKItem& Item(
      const char* item_type, const char* item_name) const = 0;

  /**
   * @brief Returns a map-like iterator to the start of the collection of 
   *        items with the specified type
   * @param item_type - name of the item type
   * @return A map-like 'begin' iterator to the collection of items
   */
  virtual OCRStudioSDKItemIterator ItemsBegin(const char* item_type) const = 0;

  /**
   * @brief Returns a map-like iterator to the end of the collection of 
   *        items with the specified type
   * @param item_type - name of the item type
   * @return A map-like 'end' iterator to the collection of items
   */
  virtual OCRStudioSDKItemIterator ItemsEnd(const char* item_type) const = 0;

  /**
   * @brief Returns true if the target can be considered final
   * @return Can the target be considered final
   */
  virtual bool IsFinal() const = 0;
};



/**
 * @brief Main session result class - container with full session result
 */
class OCR_STUDIO_SDK_DLL_EXPORT OCRStudioSDKResult {
public:
  /// Default destructor
  virtual ~OCRStudioSDKResult() = default;

  /**
   * @brief Copies a result with copying of all internal information
   * @return Pointer to a new result structure, the ownership is relinquished.
   */
  virtual OCRStudioSDKResult* DeepCopy() const = 0;

  /**
   * @brief Returns the number of stored targets
   * @return The number of stored targets
   */
  virtual int TargetsCount() const = 0;

  /**
   * @brief Returns a specific stored target by its index
   * @param target_index - 0-based index of a stored target
   * @return Specific stored target (constant reference)
   */
  virtual const OCRStudioSDKTarget& TargetByIndex(int target_index) const = 0;

  /**
   * @brief Returns true if all targets can be considered final
   * @return All targets can be considered final
   */
  virtual bool AllTargetsFinal() const = 0;

  /**
   * @brief Serialize to JSON object current result
   * @return JSON string with current result 
   */
  virtual OCRStudioSDKString Serialize() const = 0;
};

} // namespace ocrstudio

#endif // OCRSTUDIOSDK_OCR_STUDIO_RESULT_H_INCLUDED
