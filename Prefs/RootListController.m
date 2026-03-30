#import "RootListController.h"

#import <Preferences/PSSpecifier.h>
#import <objc/message.h>

static NSString *const kSBPPreferencesIdentifier = @"com.anfyya.screenshotbypass";
static NSString *const kSBPScreenshotAppsKey = @"screenshotApps";
static NSString *const kSBPRecordAppsKey = @"recordApps";
static NSString *const kSBPBundleIdentifierProperty = @"SBPBundleIdentifier";

static id SBPObjectMessage(id target, SEL selector) {
	return ((id (*)(id, SEL))objc_msgSend)(target, selector);
}

static id SBPClassObjectMessage(Class target, SEL selector) {
	return ((id (*)(Class, SEL))objc_msgSend)(target, selector);
}

static BOOL SBPBoolMessage(id target, SEL selector) {
	return ((BOOL (*)(id, SEL))objc_msgSend)(target, selector);
}

static NSArray<NSDictionary<NSString *, NSString *> *> *SBPInstalledApplications(void) {
	Class workspaceClass = NSClassFromString(@"LSApplicationWorkspace");
	if (workspaceClass == Nil) {
		return @[];
	}

	SEL defaultWorkspaceSelector = NSSelectorFromString(@"defaultWorkspace");
	if (![workspaceClass respondsToSelector:defaultWorkspaceSelector]) {
		return @[];
	}

	id workspace = SBPClassObjectMessage(workspaceClass, defaultWorkspaceSelector);
	if (workspace == nil) {
		return @[];
	}

	NSArray *applicationProxies = nil;
	for (NSString *selectorName in @[ @"allInstalledApplications", @"allApplications" ]) {
		SEL selector = NSSelectorFromString(selectorName);
		if ([workspace respondsToSelector:selector]) {
			id result = SBPObjectMessage(workspace, selector);
			if ([result isKindOfClass:[NSArray class]]) {
				applicationProxies = result;
				break;
			}
		}
	}

	if (![applicationProxies isKindOfClass:[NSArray class]]) {
		return @[];
	}

	NSMutableArray<NSDictionary<NSString *, NSString *> *> *applications = [NSMutableArray array];
	NSMutableSet<NSString *> *seenBundleIdentifiers = [NSMutableSet set];
	SEL hiddenSelector = NSSelectorFromString(@"isHiddenApp");
	SEL typeSelector = NSSelectorFromString(@"applicationType");

	for (id proxy in applicationProxies) {
		if ([proxy respondsToSelector:hiddenSelector] && SBPBoolMessage(proxy, hiddenSelector)) {
			continue;
		}

		NSString *applicationType = nil;
		if ([proxy respondsToSelector:typeSelector]) {
			id typeValue = SBPObjectMessage(proxy, typeSelector);
			if ([typeValue isKindOfClass:[NSString class]]) {
				applicationType = typeValue;
			}
		}
		if (applicationType.length > 0 &&
			![applicationType isEqualToString:@"User"] &&
			![applicationType isEqualToString:@"System"]) {
			continue;
		}

		NSString *bundleIdentifier = nil;
		for (NSString *selectorName in @[ @"applicationIdentifier", @"bundleIdentifier" ]) {
			SEL selector = NSSelectorFromString(selectorName);
			if ([proxy respondsToSelector:selector]) {
				id value = SBPObjectMessage(proxy, selector);
				if ([value isKindOfClass:[NSString class]] && [value length] > 0) {
					bundleIdentifier = value;
					break;
				}
			}
		}

		NSString *displayName = nil;
		for (NSString *selectorName in @[ @"localizedName", @"itemName" ]) {
			SEL selector = NSSelectorFromString(selectorName);
			if ([proxy respondsToSelector:selector]) {
				id value = SBPObjectMessage(proxy, selector);
				if ([value isKindOfClass:[NSString class]] && [value length] > 0) {
					displayName = value;
					break;
				}
			}
		}

		if (bundleIdentifier.length == 0 || displayName.length == 0) {
			continue;
		}
		if ([bundleIdentifier hasPrefix:@"com.apple.webapp"]) {
			continue;
		}
		if ([seenBundleIdentifiers containsObject:bundleIdentifier]) {
			continue;
		}

		[seenBundleIdentifiers addObject:bundleIdentifier];
		[applications addObject:@{
			@"name": displayName,
			@"bundleIdentifier": bundleIdentifier,
		}];
	}

	[applications sortUsingComparator:^NSComparisonResult(NSDictionary<NSString *, NSString *> *lhs,
														 NSDictionary<NSString *, NSString *> *rhs) {
		return [lhs[@"name"] localizedCaseInsensitiveCompare:rhs[@"name"]];
	}];

	return applications;
}

@interface SBPAppSelectionController : PSListController

@property (nonatomic, strong) NSMutableSet<NSString *> *selectedBundleIdentifiers;

- (NSString *)preferenceKey;
- (NSString *)controllerTitle;
- (NSString *)emptyStateText;
- (NSString *)footerText;

@end

@implementation SBPAppSelectionController

- (NSString *)preferenceKey {
	[self doesNotRecognizeSelector:_cmd];
	return nil;
}

- (NSString *)controllerTitle {
	return @"";
}

- (NSString *)emptyStateText {
	return @"No applications were found.";
}

- (NSString *)footerText {
	return @"Turn on the apps that should be bypassed.";
}

- (NSMutableSet<NSString *> *)selectedBundleIdentifiers {
	if (_selectedBundleIdentifiers == nil) {
		CFPropertyListRef value = CFPreferencesCopyAppValue((CFStringRef)[self preferenceKey],
			(CFStringRef)kSBPPreferencesIdentifier);
		NSArray *savedBundleIdentifiers = CFBridgingRelease(value);
		if ([savedBundleIdentifiers isKindOfClass:[NSArray class]]) {
			_selectedBundleIdentifiers = [NSMutableSet setWithArray:savedBundleIdentifiers];
		} else {
			_selectedBundleIdentifiers = [NSMutableSet set];
		}
	}
	return _selectedBundleIdentifiers;
}

- (NSArray *)specifiers {
	if (_specifiers == nil) {
		self.title = [self controllerTitle];

		NSMutableArray<PSSpecifier *> *generatedSpecifiers = [NSMutableArray array];
		PSSpecifier *groupSpecifier = [PSSpecifier emptyGroupSpecifier];
		NSArray<NSDictionary<NSString *, NSString *> *> *applications = SBPInstalledApplications();
		[groupSpecifier setProperty:(applications.count > 0 ? [self footerText] : [self emptyStateText])
							 forKey:@"footerText"];
		[generatedSpecifiers addObject:groupSpecifier];

		for (NSDictionary<NSString *, NSString *> *application in applications) {
			PSSpecifier *specifier =
				[PSSpecifier preferenceSpecifierNamed:application[@"name"]
												 target:self
													set:@selector(setPreferenceValue:specifier:)
													get:@selector(readPreferenceValue:)
												detail:nil
												  cell:PSSwitchCell
												  edit:nil];
			[specifier setProperty:application[@"bundleIdentifier"] forKey:kSBPBundleIdentifierProperty];
			[generatedSpecifiers addObject:specifier];
		}

		_specifiers = [generatedSpecifiers copy];
	}
	return _specifiers;
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
	NSString *bundleIdentifier = [specifier propertyForKey:kSBPBundleIdentifierProperty];
	return @([[self selectedBundleIdentifiers] containsObject:bundleIdentifier]);
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
	NSString *bundleIdentifier = [specifier propertyForKey:kSBPBundleIdentifierProperty];
	if (bundleIdentifier.length == 0) {
		return;
	}

	BOOL enabled = [value boolValue];
	if (enabled) {
		[[self selectedBundleIdentifiers] addObject:bundleIdentifier];
	} else {
		[[self selectedBundleIdentifiers] removeObject:bundleIdentifier];
	}

	NSArray<NSString *> *sortedBundleIdentifiers =
		[[[self selectedBundleIdentifiers] allObjects] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
	CFPreferencesSetAppValue((CFStringRef)[self preferenceKey],
		(__bridge CFPropertyListRef)sortedBundleIdentifiers,
		(CFStringRef)kSBPPreferencesIdentifier);
	CFPreferencesAppSynchronize((CFStringRef)kSBPPreferencesIdentifier);
}

@end

@interface SBPScreenshotAppsController : SBPAppSelectionController
@end

@implementation SBPScreenshotAppsController

- (NSString *)preferenceKey {
	return kSBPScreenshotAppsKey;
}

- (NSString *)controllerTitle {
	return @"Screenshot Apps";
}

- (NSString *)footerText {
	return @"Enable apps that should ignore screenshot detection.";
}

@end

@interface SBPRecordAppsController : SBPAppSelectionController
@end

@implementation SBPRecordAppsController

- (NSString *)preferenceKey {
	return kSBPRecordAppsKey;
}

- (NSString *)controllerTitle {
	return @"Recording Apps";
}

- (NSString *)footerText {
	return @"Enable apps that should ignore screen recording detection.";
}

@end

@implementation RootListController

- (NSArray *)specifiers {
	if (_specifiers == nil) {
		_specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
	}
	return _specifiers;
}

@end
