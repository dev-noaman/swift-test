/**
  Copyright (c) 2024-2026, OCR Studio
  All rights reserved.
*/

/**
 * @file ocr_studio_export.h
 * @brief Common definitions for library exports
 */

#pragma once
#ifndef OCRSTUDIOSDK_OCR_STUDIO_EXPORT_H_INCLUDED
#define OCRSTUDIOSDK_OCR_STUDIO_EXPORT_H_INCLUDED

#if defined _WIN32
# define OCR_STUDIO_SDK_DLL_EXPORT __declspec(dllexport)
#else // defined _WIN32
# if defined(__clang__) || defined(__GNUC__)
#  define OCR_STUDIO_SDK_DLL_EXPORT __attribute__ ((visibility ("default")))
# else // clang of gnuc
#  define OCR_STUDIO_SDK_DLL_EXPORT
# endif // clang of gnuc
#endif // defined _WIN32

#endif // OCRSTUDIOSDK_OCR_STUDIO_EXPORT_H_INCLUDED
