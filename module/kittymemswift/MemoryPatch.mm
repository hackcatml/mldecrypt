#import "MemoryPatch.h"

@implementation MemoryPatch

- (instancetype)init {
    self = [super init];
    if (self) {
        _address = 0;
        _size = 0;
        _orig_code = [NSMutableData data];
        _patch_code = [NSMutableData data];
    }
    return self;
}

- (instancetype)initWithAbsoluteAddress:(uintptr_t)absolute_address patchCode:(const void *)patch_code patchSize:(size_t)patch_size {
    self = [super init];
    if (self) {
        if (absolute_address == 0 || !patch_code || patch_size < 1) {
            return self;
        }
        
        _address = absolute_address;
        _size = patch_size;
        _orig_code = [NSMutableData dataWithLength:patch_size];
        _patch_code = [NSMutableData dataWithLength:patch_size];
        
        // initialize patch & backup current content
        [KittyMemory memRead:[_patch_code mutableBytes] buffer:patch_code length:patch_size];
        [KittyMemory memRead:[_orig_code mutableBytes] buffer:reinterpret_cast<const void*>(_address) length:patch_size];
    }
    return self;
}

- (instancetype)initWithFileName:(const char *)fileName address:(uintptr_t)address patchCode:(const void *)patch_code patchSize:(size_t)patch_size {
    self = [super init];
    if (self) {
        if (address == 0 || !patch_code || patch_size < 1) {
            return self;
        }
        
        uint64_t absolute_address = [KittyMemory getAbsoluteAddress:fileName address:address];
        if (absolute_address == 0) {
            return self;
        }
        
        _address = absolute_address;
        _size = patch_size;
        _orig_code = [NSMutableData dataWithLength:patch_size];
        _patch_code = [NSMutableData dataWithLength:patch_size];
        
        // initialize patch & backup current content
        [KittyMemory memRead:[_patch_code mutableBytes] buffer:patch_code length:patch_size];
        [KittyMemory memRead:[_orig_code mutableBytes] buffer:reinterpret_cast<const void*>(_address) length:patch_size];
    }
    return self;
}

+ (instancetype)createWithHexWithFileName:(const char *)fileName address:(uintptr_t)address hex:(NSString *)hex {
    MemoryPatch *patch = [[MemoryPatch alloc] init];
    
    if (address == 0 || ![KittyUtils validateHexString:hex]) {
        return patch;
    }
    
    patch->_address = [KittyMemory getAbsoluteAddress:fileName address:address];
    if (patch->_address == 0) {
        return patch;
    }
    
    patch->_size = (int)(hex.length / 2);
    
    patch->_orig_code = [NSMutableData dataWithLength:patch->_size];
    patch->_patch_code = [NSMutableData dataWithLength:patch->_size];
    
    // initialize patch
    [KittyUtils fromHex:hex data:[patch->_patch_code mutableBytes]];
    
    // backup current content
    [KittyMemory memRead:[patch->_orig_code mutableBytes] buffer:reinterpret_cast<const void*>(patch->_address) length:patch->_size];
    
    return patch;
}

+ (instancetype)createWithHex:(uintptr_t)absolute_address hex:(NSString *)hex {
    MemoryPatch *patch = [[MemoryPatch alloc] init];
    
    if (absolute_address == 0 || ![KittyUtils validateHexString:hex]) {
        return patch;
    }
    
    patch->_address = absolute_address;
    patch->_size = (int)(hex.length / 2);
    
    patch->_orig_code = [NSMutableData dataWithLength:patch->_size];
    patch->_patch_code = [NSMutableData dataWithLength:patch->_size];
    
    // initialize patch
    [KittyUtils fromHex:hex data:[patch->_patch_code mutableBytes]];
    
    // backup current content
    [KittyMemory memRead:[patch->_orig_code mutableBytes] buffer:reinterpret_cast<const void*>(patch->_address) length:patch->_size];
    
    return patch;
}

- (BOOL)isValid {
    return (self->_address != 0 && self->_size > 0 &&
            self->_orig_code.length == self->_size &&
            self->_patch_code.length == self->_size);
}

- (size_t)getPatchSize {
    return self->_size;
}

- (uintptr_t)getTargetAddress {
    return self->_address;
}

- (BOOL)restore {
    if(![self isValid]) return NO;
    
    return [KittyMemory memWrite:reinterpret_cast<void*>(_address) buffer:[_orig_code mutableBytes] length:_size] == SUCCESS;
}

- (BOOL)modify {
    if(![self isValid]) return NO;
    
    return [KittyMemory memWrite:reinterpret_cast<void *>(_address) buffer:[_patch_code mutableBytes] length:_size] == SUCCESS;
}

- (NSString *)getCurrBytes {
    if(![self isValid]) return @"";
    
    return [KittyMemory read2HexStr:reinterpret_cast<const void*>(_address) length:_size];
}

- (NSString *)getOrigBytes {
    if(![self isValid]) return @"";
    
    return [KittyMemory read2HexStr:[_orig_code mutableBytes] length:_orig_code.length];
}

- (NSString *)getPatchBytes {
    if(![self isValid]) return @"";
    
    return [KittyMemory read2HexStr:[_patch_code mutableBytes] length:_patch_code.length];
}

@end
