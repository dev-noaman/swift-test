/**
  Copyright (c) 2024-2026, OCR Studio
  All rights reserved.
*/

#import <objcocrstudiosdk_impl/ocr_studio_result_impl.h>
#import <objcocrstudiosdk_impl/ocr_studio_image_impl.h>

#include <ocrstudiosdk/ocr_studio_result.h>
#include <ocrstudiosdk/ocr_studio_exception.h>
#include <memory>


@implementation OBJCOCRStudioSDKItemRef {
  ocrstudio::OCRStudioSDKItem* ptr;
  bool is_mutable;
}

- (instancetype) initFromInternalOCRStudioSDKItemPointer:(ocrstudio::OCRStudioSDKItem *)itemtptr
                            withMutabilityFlag:(BOOL)mutabilityFlag {
  if (self = [super init]) {
    ptr = itemtptr;
    is_mutable = (YES == mutabilityFlag);
  }
  return self;
}

- (ocrstudio::OCRStudioSDKItem *) getInternalOCRStudioSDKItemPointer {
  return ptr;
}

- (BOOL) isMutable {
  return is_mutable? YES : NO;
}

- (OBJCOCRStudioSDKItem *) deepCopy {
  try {
    return [[OBJCOCRStudioSDKItem alloc] initFromInternalOCRStudioSDKItem:*ptr->DeepCopy()];
  } catch (const ocrstudio::OCRStudioSDKException& e) {
    printf("Exception thrown: %s\n", e.Message());
    return nil;
  }
  return nil;
}

- (NSString *) type {
  return [NSString stringWithUTF8String:ptr->Type()];
}

- (NSString *) name {
  return [NSString stringWithUTF8String:ptr->Name()];
}

- (NSString *) value {
  return [NSString stringWithUTF8String:ptr->Value()];
}

- (double) confidence {
  return ptr->Confidence();
}

- (BOOL) accepted {
  return ptr->Accepted();
}

- (NSString *) attributes {
  return [NSString stringWithUTF8String:ptr->Attributes()];
}

- (BOOL) hasImage {
  return ptr->HasImage();
}

- (OBJCOCRStudioSDKImageRef *) image {
  try {
    return [[OBJCOCRStudioSDKImageRef alloc] 
      initFromInternalOCRStudioSDKImagePointer:const_cast<ocrstudio::OCRStudioSDKImage*>(&ptr->Image())
      withMutabilityFlag:NO];
  } catch (const ocrstudio::OCRStudioSDKException& e) {
    printf("Exception thrown: %s\n", e.Message());
    return nil;
  }
  return nil;
}

- (NSString *) description {
  return [NSString stringWithUTF8String:ptr->Description()];
}

@end

@implementation OBJCOCRStudioSDKItem {
  std::unique_ptr<ocrstudio::OCRStudioSDKItem> internal;
}

- (instancetype) initFromInternalOCRStudioSDKItem:(ocrstudio::OCRStudioSDKItem &) item {
  if (self = [super init]) {
    internal.reset(item.DeepCopy());
  }
  return self;
}

- (ocrstudio::OCRStudioSDKItem &) getInternalOCRStudioSDKItem {
  return *internal;
}

- (OBJCOCRStudioSDKItemRef *) getRef {
  return [[OBJCOCRStudioSDKItemRef alloc]
      initFromInternalOCRStudioSDKItemPointer:internal.get()
                 withMutabilityFlag:NO];
}

- (OBJCOCRStudioSDKItemRef *) getMutableRef {
  return [[OBJCOCRStudioSDKItemRef alloc]
      initFromInternalOCRStudioSDKItemPointer:internal.get()
                 withMutabilityFlag:YES];
}

@end


@implementation OBJCOCRStudioSDKItemIterator {
    std::unique_ptr<ocrstudio::OCRStudioSDKItemIterator> internal;
}

- (instancetype) initFromInternalOCRStudioSDKItemIterator:(const ocrstudio::OCRStudioSDKItemIterator &) item_iteratir {
  
  if (self = [super init]) {
    internal.reset(new ocrstudio::OCRStudioSDKItemIterator(item_iteratir));
  }
  return self;
}

- (const ocrstudio::OCRStudioSDKItemIterator &) getInternalOCRStudioSDKItemIterator {
  return *internal;
}

- (BOOL) isEqualTo:(OBJCOCRStudioSDKItemIterator *) other {
  return internal->IsEqualTo([other getInternalOCRStudioSDKItemIterator]);
}

-(void) step {
  internal->Step();
}

- (NSString *) key {
  return [NSString stringWithUTF8String:internal->Key()];
}

- (OBJCOCRStudioSDKItemRef *) item {
  try {
    const ocrstudio::OCRStudioSDKItem& item_ = internal->Item();
    ocrstudio::OCRStudioSDKItem* item_ptr = const_cast< ocrstudio::OCRStudioSDKItem*>(&item_);

    return [[OBJCOCRStudioSDKItemRef alloc]
      initFromInternalOCRStudioSDKItemPointer: item_ptr withMutabilityFlag:NO];
  } catch (const ocrstudio::OCRStudioSDKException& e) {
    printf("Exception thrown: %s\n", e.Message());
    return nil;
  }
  return nil;
}

- (OBJCOCRStudioSDKItemIterator *) next {
    try {
    return [[OBJCOCRStudioSDKItemIterator alloc] initFromInternalOCRStudioSDKItemIterator:internal->Next()];
  } catch (const ocrstudio::OCRStudioSDKException& e) {
    printf("Exception thrown: %s\n", e.Message());
    return nil;
  }
  return nil;
}

@end


@implementation OBJCOCRStudioSDKResultRef {
  ocrstudio::OCRStudioSDKResult* ptr;
  bool is_mutable;
}

- (instancetype) initFromInternalOCRStudioSDKResultPointer:(ocrstudio::OCRStudioSDKResult *)resultptr
                            withMutabilityFlag:(BOOL)mutabilityFlag {
  if (self = [super init]) {
    ptr = resultptr;
    is_mutable = (YES == mutabilityFlag);
  } 
  return self;
}

- (ocrstudio::OCRStudioSDKResult *) getInternalOCRStudioSDKResultPointer {
  return ptr;
}

- (BOOL) isMutable {
  return is_mutable? YES : NO;
}

- (OBJCOCRStudioSDKResult *) clone {
  return [[OBJCOCRStudioSDKResult alloc] initFromInternalOCRStudioSDKResult:(*ptr)];
}

- (OBJCOCRStudioSDKResult *) deepCopy {
  try {
    return [[OBJCOCRStudioSDKResult alloc] initFromInternalOCRStudioSDKResult:*ptr->DeepCopy()];
  } catch (const ocrstudio::OCRStudioSDKException& e) {
    printf("Exception thrown: %s\n", e.Message());
    return nil;
  }
  return nil;
}

- (int) targetsCount {
  try {
    return ptr->TargetsCount();
  } catch (const ocrstudio::OCRStudioSDKException& e) {
    printf("Exception thrown: %s\n", e.Message());
    return 0;
  }
  return -1;
}

- (OBJCOCRStudioSDKTargetRef *) targetByIndex:(int)target_index{
  try {
    return [[OBJCOCRStudioSDKTargetRef alloc] 
      initFromInternalOCRStudioSDKTargetPointer:const_cast<ocrstudio::OCRStudioSDKTarget*>(&ptr->TargetByIndex(target_index))
      withMutabilityFlag:NO];
  } catch (const ocrstudio::OCRStudioSDKException& e) {
    printf("Exception thrown: %s\n", e.Message());
    return nil;
  }
  return nil;
}

- (BOOL) allTargetsFinal {
  return ptr->AllTargetsFinal();
}

- (NSString *) serialize {
    return [NSString stringWithUTF8String:ptr->Serialize().CStr()];
}

@end



@implementation OBJCOCRStudioSDKResult {
  std::unique_ptr<ocrstudio::OCRStudioSDKResult> internal;
}

- (instancetype) initFromInternalOCRStudioSDKResult:(const ocrstudio::OCRStudioSDKResult &)result {
  if (self = [super init]) {
    internal.reset(result.DeepCopy());
  }
  return self;
}

- (const ocrstudio::OCRStudioSDKResult &) getInternalOCRStudioSDKResult {
  return *internal;
}

- (OBJCOCRStudioSDKResultRef *) getRef {
  return [[OBJCOCRStudioSDKResultRef alloc]
      initFromInternalOCRStudioSDKResultPointer:internal.get()
                 withMutabilityFlag:NO];
}

- (OBJCOCRStudioSDKResultRef *) getMutableRef {
  return [[OBJCOCRStudioSDKResultRef alloc]
      initFromInternalOCRStudioSDKResultPointer:internal.get()
                 withMutabilityFlag:YES];
}

@end


@implementation OBJCOCRStudioSDKTargetRef {
  ocrstudio::OCRStudioSDKTarget* target;
  bool is_mutable;
}

- (instancetype) initFromInternalOCRStudioSDKTargetPointer:(ocrstudio::OCRStudioSDKTarget *)targetptr
                            withMutabilityFlag:(BOOL)mutabilityFlag {
  if (self = [super init]) {
    target = targetptr;
    is_mutable = (YES == mutabilityFlag);
  }
  return self;
}

- (ocrstudio::OCRStudioSDKTarget *) getInternalOCRStudioSDKTargetPointer {
  return target;
}

- (BOOL) isMutable {
  return is_mutable? YES : NO;
}

- (OBJCOCRStudioSDKTarget *) deepCopy {
  try {
    return [[OBJCOCRStudioSDKTarget alloc] initFromInternalOCRStudioSDKTarget:target->DeepCopy()];
  } catch (const ocrstudio::OCRStudioSDKException& e) {
    printf("Exception thrown: %s\n", e.Message());
    return nil;
  }
  return nil;
}

- (NSString *) description {
  return [NSString stringWithUTF8String:target->Description()];
}

- (int) itemsCountByType:(NSString *) item_type {
  return target->ItemsCountByType([item_type UTF8String]);
}

- (BOOL) hasItem:(NSString *)item_type
    withItemName:(NSString *)item_name {
  return target->HasItem([item_type UTF8String], [item_name UTF8String]);
}

- (OBJCOCRStudioSDKItemRef *) item:(NSString *)item_type
                                              withItemName:(NSString *)item_name {
  try {
    return [[OBJCOCRStudioSDKItemRef alloc] 
      initFromInternalOCRStudioSDKItemPointer:const_cast<ocrstudio::OCRStudioSDKItem*>(&target->Item([item_type UTF8String], [item_name UTF8String]))
      withMutabilityFlag:NO];
  } catch (const ocrstudio::OCRStudioSDKException& e) {
    printf("Exception thrown: %s\n", e.Message());
    return nil;
  }
  return nil;
}

- (OBJCOCRStudioSDKItemIterator *) itemsBegin:(NSString *) item_type {
  return [[OBJCOCRStudioSDKItemIterator alloc] 
      initFromInternalOCRStudioSDKItemIterator:target->ItemsBegin([item_type UTF8String])];
}

- (OBJCOCRStudioSDKItemIterator *) itemsEnd:(NSString *) item_type {
  return [[OBJCOCRStudioSDKItemIterator alloc] 
      initFromInternalOCRStudioSDKItemIterator:target->ItemsEnd([item_type UTF8String])];
}

- (BOOL) isFinal {
  return target->IsFinal();
}

@end


@implementation OBJCOCRStudioSDKTarget {
  std::unique_ptr<ocrstudio::OCRStudioSDKTarget> internal;
}

- (instancetype) initFromInternalOCRStudioSDKTarget:(ocrstudio::OCRStudioSDKTarget *)target {
  if (self = [super init]) {
    internal.reset(target);
  }
  return self;
}

- (const ocrstudio::OCRStudioSDKTarget &) getInternalOCRStudioSDKTarget {
  return *internal;
}

- (OBJCOCRStudioSDKTargetRef *) getRef {
  return [[OBJCOCRStudioSDKTargetRef alloc]
      initFromInternalOCRStudioSDKTargetPointer:internal.get()
                 withMutabilityFlag:NO];
}

- (OBJCOCRStudioSDKTargetRef *) getMutableRef {
  return [[OBJCOCRStudioSDKTargetRef alloc]
      initFromInternalOCRStudioSDKTargetPointer:internal.get()
                 withMutabilityFlag:YES];
}

@end
