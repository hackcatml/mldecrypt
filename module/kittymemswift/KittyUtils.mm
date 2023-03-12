#import "KittyUtils.h"

@implementation KittyUtils

+ (void)trimString:(NSString **)str {
    if (*str == nil) {
        return;
    }
    
    NSMutableString *mutableStr = [*str mutableCopy];
    NSCharacterSet *whitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    [mutableStr stringByTrimmingCharactersInSet:whitespace];
    *str = [mutableStr copy];
}

+ (BOOL)validateHexString:(NSString *)hex {
    if (hex.length == 0) {
        return NO;
    }
    
    if ([hex hasPrefix:@"0x"]) {
        hex = [hex substringFromIndex:2];
    }
    
    NSString *trimmedHex = hex; // create a temporary NSString variable
    [self trimString:&trimmedHex]; // pass a pointer to the temporary variable
    
    if (trimmedHex.length < 2 || trimmedHex.length % 2 != 0) {
        return NO;
    }
    
    for (NSUInteger i = 0; i < trimmedHex.length; i++) {
        if (!isxdigit([trimmedHex characterAtIndex:i])) {
            return NO;
        }
    }
    
    return YES;
}


+ (void)toHex:(void *)data dataLength:(size_t)dataLength dest:(NSString **)dest {
    unsigned char *byteData = (unsigned char *)data;
    NSMutableString *hexString = [NSMutableString string];
    
    for (NSUInteger index = 0; index < dataLength; ++index) {
        [hexString appendFormat:@"%02x", byteData[index]];
    }
    
    *dest = hexString;
}

+ (void)fromHex:(NSString *)hex data:(void *const)data {
    NSUInteger length = hex.length;
    unsigned char *byteData = (unsigned char *)data;
    
    for (NSUInteger strIndex = 0, dataIndex = 0; strIndex < length; ++dataIndex) {
        // Read out and convert the string two characters at a time
        const char tmpStr[3] = { static_cast<char>([hex characterAtIndex:strIndex++]), static_cast<char>([hex characterAtIndex:strIndex++]), 0 };
        
        // Do the conversion
        int tmpValue = 0;
        sscanf(tmpStr, "%x", &tmpValue);
        byteData[dataIndex] = (unsigned char)tmpValue;
    }
}

+ (NSString *)HexDump:(const void *)address length:(size_t)len {
    if (!address || len == 0) {
        return @"";
    }
    
    const unsigned char *data = (const unsigned char *)address;
    
    NSMutableString *result = [NSMutableString string];
    [result appendString:@"Offset  Data                         ASCII\n"];
    
    for (size_t i = 0; i < len; i += 8) {
        [result appendFormat:@"%08lx ", i];
        
        // data bytes
        for (size_t j = 0; j < 8; j++) {
            if (i + j < len) {
                [result appendFormat:@"%02x ", data[i + j]];
            } else {
                [result appendString:@"   "];
            }
        }
        
        [result appendString:@" "];
        
        // ASCII representation
        for (size_t j = 0; j < 8; j++) {
            if (i + j < len) {
                unsigned char c = data[i + j];
                if (isprint(c)) {
                    [result appendFormat:@"%c", c];
                } else {
                    [result appendString:@"."];
                }
            }
        }
        
        [result appendString:@"\n"];
    }
    
    return [result copy];
}

@end
