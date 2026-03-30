#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// 组1：截屏拦截
%group ScreenshotHook
%hook NSNotificationCenter
- (void)addObserver:(id)observer selector:(SEL)aSelector name:(NSNotificationName)aName object:(id)anObject {
    if ([aName isEqualToString:UIApplicationUserDidTakeScreenshotNotification]) {
        return; 
    }
    %orig;
}
%end
%end

// 组2：录屏拦截
%group RecordHook
%hook UIScreen
- (BOOL)isCaptured {
    return NO;
}
%end
%end

// 插件加载时的初始化入口
%ctor {
    // 读取系统设置里该插件的配置文件
    NSUserDefaults *prefs = [[NSUserDefaults alloc] initWithSuiteName:@"com.anfyya.screenshotbypass"];
    
    // 获取你在设置里勾选的 App 数组
    NSArray *screenshotApps = [prefs arrayForKey:@"screenshotApps"];
    NSArray *recordApps = [prefs arrayForKey:@"recordApps"];
    
    // 获取当前正在运行的 App 的包名 (如 com.tencent.xin)
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    
    // 如果当前 App 在你的勾选名单里，才激活对应的 Hook
    if ([screenshotApps containsObject:bundleID]) {
        %init(ScreenshotHook);
    }
    if ([recordApps containsObject:bundleID]) {
        %init(RecordHook);
    }
}