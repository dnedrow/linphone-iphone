//
//  LinphoneTester_Tests.m
//  LinphoneTester Tests
//
//  Created by guillaume on 10/09/2014.
//
//

#import <XCTest/XCTest.h>
#include "linphone/linphonecore.h"
#include "linphone/liblinphone_tester.h"
#import "NSObject+DTRuntime.h"
#import "Utils.h"
#import "Log.h"

@interface LinphoneTester_Tests : XCTestCase
@property(retain, nonatomic) NSString *bundlePath;
@property(retain, nonatomic) NSString *documentPath;
@end

@implementation LinphoneTester_Tests

+ (NSArray *)skippedSuites {
	NSArray *skipped_suites = @[ @"Flexisip" ];
	return skipped_suites;
}

+ (NSString *)safetyTestString:(NSString *)testString {
	NSCharacterSet *charactersToRemove = [[NSCharacterSet alphanumericCharacterSet] invertedSet];
	return [[testString componentsSeparatedByCharactersInSet:charactersToRemove] componentsJoinedByString:@"_"];
}

void tester_logs_handler(int level, const char *fmt, va_list args) {
	linphone_iphone_log_handler(NULL, level, fmt, args);
}

+ (void)initialize {
#if TARGET_IPHONE_SIMULATOR
	[Log enableLogs:ORTP_DEBUG];
#else
	// turn off logs since xcodebuild fails to retrieve whole output otherwise on
	// real device. If you need to debug, comment this line temporary
	[Log enableLogs:NO];
#endif

	bc_tester_init(tester_logs_handler, ORTP_MESSAGE, ORTP_ERROR, "rcfiles");
	liblinphone_tester_add_suites();

	NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
	NSString *writablePath = [paths objectAtIndex:0];

	LOGI(@"Bundle path: %@", bundlePath);
	LOGI(@"Document path: %@", writablePath);

	bc_tester_set_resource_dir_prefix(bundlePath.UTF8String);
	bc_tester_set_writable_dir_prefix(writablePath.UTF8String);

	liblinphonetester_ipv6 = true;

	liblinphone_tester_keep_accounts(TRUE);
	int count = bc_tester_nb_suites();

	for (int i = 0; i < count; i++) {
		const char *suite = bc_tester_suite_name(i);

		int test_count = bc_tester_nb_tests(suite);
		for (int k = 0; k < test_count; k++) {
			const char *test = bc_tester_test_name(suite, k);
			NSString *sSuite = [NSString stringWithUTF8String:suite];
			NSString *sTest = [NSString stringWithUTF8String:test];

			if ([[LinphoneTester_Tests skippedSuites] containsObject:sSuite])
				continue;
			// prepend "test_" so that it gets found by introspection
			NSString *safesTest = [self safetyTestString:sTest];
			NSString *safesSuite = [self safetyTestString:sSuite];
			NSString *selectorName = [NSString stringWithFormat:@"test_%@__%@", safesSuite, safesTest];

			[LinphoneTester_Tests addInstanceMethodWithSelectorName:selectorName
															  block:^(LinphoneTester_Tests *myself) {
																[myself testForSuite:sSuite andTest:sTest];
															  }];
		}
	}
}

- (void)setUp {
	[super setUp];
}

- (void)tearDown {
	[super tearDown];
}

- (void)testForSuite:(NSString *)suite andTest:(NSString *)test {
	LOGI(@"Launching test %@ from suite %@", test, suite);
	XCTAssertFalse(bc_tester_run_tests([suite UTF8String], [test UTF8String], NULL), @"Suite '%@' / Test '%@' failed",
				   suite, test);
}

- (void)dealloc {
	liblinphone_tester_clear_accounts();
}

@end