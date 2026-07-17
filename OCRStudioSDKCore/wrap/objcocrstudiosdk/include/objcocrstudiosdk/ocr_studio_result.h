/**
  Copyright (c) 2024-2026, OCR Studio
  All rights reserved.
*/

#ifndef OBJCOCRSTUDIOSDK_OCR_STUDIO_RESULT_H_INCLUDED
#define OBJCOCRSTUDIOSDK_OCR_STUDIO_RESULT_H_INCLUDED

#import <Foundation/Foundation.h>
#import <objcocrstudiosdk/ocr_studio_image.h>


@class OBJCOCRStudioSDKItem;

@interface OBJCOCRStudioSDKItemRef : NSObject

- (BOOL) isMutable;

- (nonnull OBJCOCRStudioSDKItem *) deepCopy;

- (nonnull NSString *) type;
- (nonnull NSString *) name;
- (nonnull NSString *) value;

- (double) confidence;
- (BOOL) accepted;

- (nonnull NSString *) attributes;

- (BOOL) hasImage;
- (nonnull OBJCOCRStudioSDKImageRef *) image;

- (nonnull NSString *) description;

@end

@interface OBJCOCRStudioSDKItem : NSObject

- (nonnull OBJCOCRStudioSDKItemRef *) getRef;
- (nonnull OBJCOCRStudioSDKItemRef *) getMutableRef;

@end


@interface OBJCOCRStudioSDKItemIteratorImplementation : NSObject

@end

@interface OBJCOCRStudioSDKItemIterator : NSObject

- (BOOL) isEqualTo:(nullable OBJCOCRStudioSDKItemIterator *) other;

- (void) step;
- (nonnull NSString *) key;

- (nonnull OBJCOCRStudioSDKItemRef *) item;

- (nonnull OBJCOCRStudioSDKItemIterator *) next;

@end


@class OBJCOCRStudioSDKTarget;

@interface OBJCOCRStudioSDKTargetRef : NSObject 

- (BOOL) isMutable;

- (nonnull OBJCOCRStudioSDKTarget *) deepCopy;

- (nonnull NSString *) description;
- (int) itemsCountByType:(nonnull NSString *) item_type;

- (BOOL) hasItem:(nonnull NSString *)item_type
    withItemName:(nonnull NSString *)item_name;

- (nonnull OBJCOCRStudioSDKItemRef *) item:(nonnull NSString *)item_type
                               withItemName:(nonnull NSString *)item_name;

- (nonnull OBJCOCRStudioSDKItemIterator *) itemsBegin:(nonnull NSString *) item_type;

- (nonnull OBJCOCRStudioSDKItemIterator *) itemsEnd:(nonnull NSString *) item_type;

- (BOOL) isFinal;

@end

@interface OBJCOCRStudioSDKTarget : NSObject

- (nonnull OBJCOCRStudioSDKTargetRef *) getRef;
- (nonnull OBJCOCRStudioSDKTargetRef *) getMutableRef;

@end


@class OBJCOCRStudioSDKResult;

@interface OBJCOCRStudioSDKResultRef : NSObject

- (BOOL) isMutable;

- (nonnull OBJCOCRStudioSDKResult *) clone;
- (nonnull OBJCOCRStudioSDKResult *) deepCopy;
- (int) targetsCount;
- (nonnull OBJCOCRStudioSDKTargetRef *) targetByIndex:(int) target_index;
- (BOOL) allTargetsFinal;
- (nonnull NSString*) serialize;

@end

@interface OBJCOCRStudioSDKResult : NSObject

- (nonnull OBJCOCRStudioSDKResultRef *) getRef;
- (nonnull OBJCOCRStudioSDKResultRef *) getMutableRef;

@end



#endif // OBJCOCRSTUDIOSDK_OCR_STUDIO_RESULT_H_INCLUDED
