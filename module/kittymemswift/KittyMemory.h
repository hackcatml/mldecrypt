#pragma once

#include <stdio.h>
#include <unistd.h>
#include <sys/mman.h>
#include <mach-o/dyld.h>
#include <mach/mach.h>
#include <libkern/OSCacheControl.h>
#include <Foundation/Foundation.h>

#define BAD_KERN_CALL(call) (call != KERN_SUCCESS)

#define _SYS_PAGE_SIZE_ (sysconf(_SC_PAGE_SIZE))

#define _PAGE_START_OF_(x) ((uintptr_t)x & ~(uintptr_t)(_SYS_PAGE_SIZE_ - 1))
#define _PAGE_END_OF_(x, len) (_PAGE_START_OF_((uintptr_t)x + len - 1))
#define _PAGE_LEN_OF_(x, len) (_PAGE_END_OF_(x, len) - _PAGE_START_OF_(x) + _SYS_PAGE_SIZE_)
#define _PAGE_OFFSET_OF_(x) ((uintptr_t)x - _PAGE_START_OF_(x))

#define _PROT_RWX_ (PROT_READ | PROT_WRITE | PROT_EXEC)
#define _PROT_RX_ (PROT_READ | PROT_EXEC)
#define _PROT_RW_ (PROT_READ | PROT_WRITE)

@interface KittyMemory : NSObject

typedef NS_ENUM(NSUInteger, Memory_Status) {
    FAILED = 0,
    SUCCESS = 1,
    INV_ADDR = 2,
    INV_LEN = 3,
    INV_BUF = 4,
    INV_PROT = 5,
    INV_KERN_CALL = 6,
    INV_MAP = 7
};

typedef struct MemoryFileInfo {
    uint32_t index;
    const struct mach_header *header;
    const char *name;
    intptr_t address;
} MemoryFileInfo;

/*
 * Changes protection of an address with given length
 */
+ (BOOL)setAddressProtection:(void *)address length:(size_t)length protection:(int)protection;

/*
 * Writes buffer content to an address
 */
+ (Memory_Status)memWrite:(void *)address buffer:(const void *)buffer length:(size_t)len;

/*
 * Reads an address content into a buffer
 */
+ (Memory_Status)memRead:(void *)address buffer:(const void *)buffer length:(size_t)len;

/*
 * Reads an address content and returns hex string
 */
+ (NSString *)read2HexStr:(const void *)address length:(size_t)len;

/*
 * returns base executable info
 */
+ (MemoryFileInfo)getBaseInfo;

/*
 * find in memory file info
 */
+ (MemoryFileInfo)getMemoryFileInfo:(NSString *)fileName;

/*
 * returns relative address of file in memory, NULL as fileName will return base executable
 */
+ (uintptr_t)getAbsoluteAddress:(const char *)fileName address:(uintptr_t)address;

+ (uintptr_t)readPtr:(void *)ptr;

+ (uint32_t)readU32:(void *)ptr;

+ (BOOL)writePtr:(void *)ptr withValue:(id)value;

@end