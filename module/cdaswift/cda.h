#include <Foundation/Foundation.h>

@interface LSApplicationWorkspace
+ (id)defaultWorkspace;
- (id)allInstalledApplications;
@end

@interface LSBundleProxy

@property (nonatomic, readonly) NSURL *bundleContainerURL;
@property (nonatomic, readonly) NSString *bundleExecutable;
@property (nonatomic, readonly) NSString *bundleIdentifier;
@property (nonatomic, readonly) NSString *bundleType;
@property (nonatomic, readonly) NSURL *bundleURL;
@property (nonatomic, readonly) NSString *bundleVersion;
@property (nonatomic, readonly) NSURL *containerURL;
@property (nonatomic, readonly) NSURL *dataContainerURL;
@property (nonatomic, readonly) NSDictionary *entitlements;
@property (nonatomic, readonly) NSDictionary *groupContainerURLs;
@property (nonatomic, readonly) BOOL isContainerized;
@property (nonatomic, readonly) NSString *localizedShortName;
@property (nonatomic, readonly) NSString *signerIdentity;
@property (nonatomic, readonly) NSString *teamID;

@end


@interface LSApplicationProxy : LSBundleProxy
- (id)localizedName;
// - (id)resourcesDirectoryURL;
@end

#define NSLog(FORMAT, ...) printf("%s\n", [[NSString stringWithFormat:FORMAT, ##__VA_ARGS__] UTF8String]);

@interface AppUtils : NSObject

+ (instancetype)sharedInstance;
- (void) searchApp:(NSString *)name;
- (NSString*)searchAppExecutable:(NSString*)bundleId;
- (NSString*)searchAppResourceDir:(NSString*)bundleId;
- (NSString*)searchAppBundleDir:(NSString*)bundleId;
- (NSString*)searchAppDataDir:(NSString*)bundleId;

@end
