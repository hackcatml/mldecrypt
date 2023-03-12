#pragma once

#include <Foundation/Foundation.h>

@interface KittyUtils : NSObject

+ (void)trimString:(NSString **)str;
+ (BOOL)validateHexString:(NSString *)hex;
+ (void)toHex:(void *const)data dataLength:(const size_t)dataLength dest:(NSString **)dest;
+ (void)fromHex:(NSString *)in data:(void *const)data;
+ (NSString *)HexDump:(const void *)address length:(size_t)len;

@end
