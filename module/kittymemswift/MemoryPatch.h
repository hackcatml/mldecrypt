//
//  MemoryPatch.h
//
//  Created by MJ (Ruit) on 1/1/19.
//

#pragma once

#import "KittyMemory.h"
#import "KittyUtils.h"

@interface MemoryPatch : NSObject

@property (nonatomic, assign) uintptr_t address;
@property (nonatomic, assign) size_t size;
@property (nonatomic, strong) NSMutableData *orig_code;
@property (nonatomic, strong) NSMutableData *patch_code;

- (instancetype)init;
- (instancetype)initWithAbsoluteAddress:(uintptr_t)absoluteAddress patchCode:(const void *)patchCode patchSize:(size_t)patchSize;
- (instancetype)initWithFileName:(const char *)fileName address:(uintptr_t)address patchCode:(const void *)patchCode patchSize:(size_t)patchSize;

+ (instancetype)createWithHexWithFileName:(const char *)fileName address:(uintptr_t)address hex:(NSString *)hex;
+ (instancetype)createWithHex:(uintptr_t)absoluteAddress hex:(NSString *)hex;

- (BOOL)isValid;
- (size_t)getPatchSize;
- (uintptr_t)getTargetAddress;

- (BOOL)restore;
- (BOOL)modify;

- (NSString *)getCurrBytes;
- (NSString *)getOrigBytes;
- (NSString *)getPatchBytes;

@end
