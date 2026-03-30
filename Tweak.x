#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <rootless.h>

static NSString *const kSBPPreferencesIdentifier = @"com.anfyya.screenshotbypass";
static NSString *const kSBPScreenshotAppsKey = @"screenshotApps";
static NSString *const kSBPRecordAppsKey = @"recordApps";

static BOOL gSBPScreenshotEnabled = NO;
static BOOL gSBPRecordEnabled = NO;

static BOOL SBPIsScreenshotNotificationName(NSString *name) {
    if (!gSBPScreenshotEnabled || name.length == 0) {
        return NO;
    }

    return [name isEqualToString:UIApplicationUserDidTakeScreenshotNotification] ||
           [name isEqualToString:@"UIApplicationUserDidTakeScreenshotNotification"];
}

static BOOL SBPIsRecordNotificationName(NSString *name) {
    if (!gSBPRecordEnabled || name.length == 0) {
        return NO;
    }

    return [name isEqualToString:UIScreenCapturedDidChangeNotification] ||
           [name isEqualToString:@"UIScreenCapturedDidChangeNotification"];
}

static BOOL SBPShouldBlockNotificationName(NSString *name) {
    return SBPIsScreenshotNotificationName(name) || SBPIsRecordNotificationName(name);
}

static BOOL SBPShouldBlockNotification(NSNotification *notification) {
    return notification != nil && SBPShouldBlockNotificationName(notification.name);
}

%group NotificationHook

%hook NSNotificationCenter

- (void)addObserver:(id)observer selector:(SEL)selector name:(NSNotificationName)name object:(id)object {
    if (SBPShouldBlockNotificationName(name)) {
        return;
    }

    %orig;
}

- (id)addObserverForName:(NSNotificationName)name object:(id)object queue:(NSOperationQueue *)queue usingBlock:(void (^)(NSNotification *note))block {
    if (SBPShouldBlockNotificationName(name)) {
        return %orig(name, object, queue, ^(NSNotification *note) {});
    }

    return %orig;
}

- (void)postNotification:(NSNotification *)notification {
    if (SBPShouldBlockNotification(notification)) {
        return;
    }

    %orig;
}

- (void)postNotificationName:(NSNotificationName)name object:(id)object {
    if (SBPShouldBlockNotificationName(name)) {
        return;
    }

    %orig;
}

- (void)postNotificationName:(NSNotificationName)name object:(id)object userInfo:(NSDictionary *)userInfo {
    if (SBPShouldBlockNotificationName(name)) {
        return;
    }

    %orig;
}

%end

%hook NSNotificationQueue

- (void)enqueueNotification:(NSNotification *)notification postingStyle:(NSPostingStyle)postingStyle {
    if (SBPShouldBlockNotification(notification)) {
        return;
    }

    %orig;
}

- (void)enqueueNotification:(NSNotification *)notification postingStyle:(NSPostingStyle)postingStyle coalesceMask:(NSNotificationCoalescing)coalesceMask forModes:(NSArray<NSString *> *)modes {
    if (SBPShouldBlockNotification(notification)) {
        return;
    }

    %orig;
}

%end

%end

%group RecordHook

%hook UIScreen

- (BOOL)isCaptured {
    return NO;
}

- (BOOL)captured {
    return NO;
}

- (BOOL)_isCaptured {
    return NO;
}

%end

%hook UITraitCollection

- (NSInteger)sceneCaptureState {
    return 0;
}

%end

%hook UIWindowScene

- (NSInteger)captureState {
    return 0;
}

%end

%end

%ctor {
    NSString *prefsPath = ROOT_PATH_NS(@"/var/mobile/Library/Preferences/com.anfyya.screenshotbypass.plist");
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:prefsPath];

    NSDictionary *screenshotApps = prefs[kSBPScreenshotAppsKey];
    NSDictionary *recordApps     = prefs[kSBPRecordAppsKey];
    NSString *bid = [[NSBundle mainBundle] bundleIdentifier];

    gSBPScreenshotEnabled = [screenshotApps[bid] boolValue];
    gSBPRecordEnabled     = [recordApps[bid] boolValue];

    if (gSBPScreenshotEnabled || gSBPRecordEnabled) {
        %init(NotificationHook);
    }
    if (gSBPRecordEnabled) {
        %init(RecordHook);
    }
}
