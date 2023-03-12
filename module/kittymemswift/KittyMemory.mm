#import "KittyMemory.h"

extern "C" kern_return_t mach_vm_remap(vm_map_t, mach_vm_address_t *, mach_vm_size_t,
                                       mach_vm_offset_t, int, vm_map_t, mach_vm_address_t,
                                       boolean_t, vm_prot_t *, vm_prot_t *, vm_inherit_t);

#ifndef _NO_SUBSTRATE_LINK
#include <substrate.h>

bool findMSHookMemory(void *dst, const void *src, size_t len)
{
    static bool checked = false;
    static void *fnPtr = nullptr;
    
    if (!checked)
    {
        MSImageRef image = MSGetImageByName("/usr/lib/libsubstrate.dylib");
        if(image)
        {
            fnPtr = MSFindSymbol(image, "_MSHookMemory");
        }
        checked = true;
    }
    
    if (fnPtr)
    {
        reinterpret_cast<void (*)(void *, const void *, size_t)>(fnPtr)(dst, src, len);
        return true;
    }
    
    return false;
}

#else
bool findMSHookMemory(void *dst, const void *src, size_t len) { return false; }
#endif

@implementation KittyMemory

+ (BOOL)setAddressProtection:(void *)address length:(size_t)length protection:(int)protection
{
    uintptr_t pageStart = _PAGE_START_OF_(address);
    uintptr_t pageLen = _PAGE_LEN_OF_(address, length);
    return mprotect(reinterpret_cast<void *>(pageStart), pageLen, protection) == 0;
}

kern_return_t getPageInfo(void *page_start, vm_region_submap_short_info_64 *outInfo)
{
    vm_address_t region = reinterpret_cast<vm_address_t>(page_start);
    vm_size_t region_len = 0;
    mach_msg_type_number_t info_count = VM_REGION_SUBMAP_SHORT_INFO_COUNT_64;
    unsigned int depth = 0;
    return vm_region_recurse_64(mach_task_self(), &region, &region_len,
                                &depth,
                                (vm_region_recurse_info_t)outInfo,
                                &info_count);
}

+ (Memory_Status)memWrite:(void *)address buffer:(const void *)buffer length:(size_t)len
{
    if (address == NULL)
        return INV_ADDR;
    
    if (buffer == NULL)
        return INV_BUF;
    
    if (len < 1 || len > INT_MAX)
        return INV_LEN;
    
    void *page_start = reinterpret_cast<void *>(_PAGE_START_OF_(address));
    void *page_offset = reinterpret_cast<void *>(_PAGE_OFFSET_OF_(address));
    size_t page_len = _PAGE_LEN_OF_(address, len);
    
    vm_region_submap_short_info_64 page_info;
    if (BAD_KERN_CALL(getPageInfo(page_start, &page_info)))
        return INV_KERN_CALL;
    
    if (page_info.protection & VM_PROT_WRITE)
    {
        if (memcpy(address, buffer, len) != NULL)
            return SUCCESS;
        else
            return FAILED;
    }
    
    // check for cydia MSHookMemory existance first
    if (findMSHookMemory(address, buffer, len))
        return SUCCESS;
    
    // create new map, copy our code to it then remap it over target map
    
    void *new_map = mmap(NULL, page_len, _PROT_RW_, MAP_ANONYMOUS | MAP_PRIVATE, 0, 0);
    if (!new_map) return INV_MAP;
    
    task_t self_task = mach_task_self();
    
    if (BAD_KERN_CALL(vm_copy(self_task,
                              reinterpret_cast<vm_address_t>(page_start), page_len, reinterpret_cast<vm_address_t>(new_map))))
    {
        munmap(new_map, page_len);
        return INV_KERN_CALL;
    }
    
    void *dst = (void *)((uintptr_t)new_map + (uintptr_t)page_offset);
    if (memcpy(dst, buffer, len) == NULL || mprotect(new_map, page_len, _PROT_RX_) == -1) {
        munmap(new_map, page_len);
        return FAILED;
    }
    
    vm_prot_t cur_protection, max_protection;
    mach_vm_address_t mach_vm_page_start = (mach_vm_address_t)page_start;
    if (BAD_KERN_CALL(mach_vm_remap(self_task, &mach_vm_page_start, page_len, 0, VM_FLAGS_OVERWRITE,
                                    self_task, (mach_vm_address_t)new_map, TRUE, &cur_protection, &max_protection,
                                    page_info.inheritance))) {
        munmap(new_map, page_len);
        return INV_KERN_CALL;
    }
    
    munmap(new_map, page_len);
    return SUCCESS;
}

+ (Memory_Status)memRead:(void *)address buffer:(const void *)buffer length:(size_t)len {
    if (!address)
        return INV_ADDR;
    
    if (!buffer)
        return INV_BUF;
    
    if (len < 1 || len > INT_MAX)
        return INV_LEN;
    
    memcpy(address, buffer, len);
    
    return SUCCESS;
}

+ (NSString *)read2HexStr:(const void *)address length:(size_t)len {
    NSMutableData *tempData = [[NSMutableData alloc] initWithLength:len];
    if (![self memRead:[tempData mutableBytes] buffer:address length:len]) {
        return @"";
    }
    
    NSMutableString *ret = [[NSMutableString alloc] initWithCapacity:len * 2];
    const unsigned char *bytes = (const unsigned char*)[tempData bytes];
    for (int i = 0; i < len; i++) {
        [ret appendFormat:@"%02X", bytes[i]];
    }
    return ret;
}

+ (MemoryFileInfo)getBaseInfo
{
    MemoryFileInfo info;
    
    info.index = 0;
    info.header = _dyld_get_image_header(0);
    info.name = _dyld_get_image_name(0);
    info.address = _dyld_get_image_vmaddr_slide(0);
    
    return info;
}

+ (MemoryFileInfo)getMemoryFileInfo:(NSString *)fileName
{
    MemoryFileInfo info;

    const uint32_t imageCount = _dyld_image_count();

    for (uint32_t i = 0; i < imageCount; i++)
    {
        const char *name = _dyld_get_image_name(i);
        if (!name) continue;

        NSString *fullpath = [NSString stringWithUTF8String:name];

        if ([fullpath length] < [fileName length] || ![fullpath hasSuffix:fileName])
            continue;

        info.index = i;
        info.header = _dyld_get_image_header(i);
        info.name = _dyld_get_image_name(i);
        info.address = _dyld_get_image_vmaddr_slide(i);

        break;
    }
    return info;
}

+ (uintptr_t)getAbsoluteAddress:(const char *)fileName address:(uintptr_t)address
{
    MemoryFileInfo info;

    if (fileName)
        info = [self getMemoryFileInfo:[NSString stringWithUTF8String:fileName]];
    else
        info = [self getBaseInfo];

    if (info.address == 0)
        return 0;

    return info.address + address;
}

+ (uintptr_t)readPtr:(void *)ptr
{
    uintptr_t defaultVal = 0;
    if (ptr == NULL)
        return defaultVal;
    
    return *(typeof(defaultVal) *)ptr;
}

+ (uint32_t)readU32:(void *)ptr
{
    uint32_t defaultVal = 0;
    if (ptr == NULL)
        return defaultVal;
    
    return *(typeof(defaultVal) *)ptr;
}

+ (BOOL)writePtr:(void *)ptr withValue:(id)value
{
    if (ptr == NULL)
        return false;
    
    *(typeof(value) *)ptr = value;
    return true;
}

@end
