#include "localnotify.h"

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <UserNotifications/UserNotifications.h>

LocalNotify *LocalNotify::instance = NULL;

void LocalNotify::_bind_methods() {
	ClassDB::bind_method(D_METHOD("refresh_status"), &LocalNotify::refresh_status);
	ClassDB::bind_method(D_METHOD("get_status"), &LocalNotify::get_status);
	ClassDB::bind_method(D_METHOD("request_permission"), &LocalNotify::request_permission);
	ClassDB::bind_method(D_METHOD("schedule", "id", "title", "body", "seconds"), &LocalNotify::schedule);
	ClassDB::bind_method(D_METHOD("cancel_all"), &LocalNotify::cancel_all);
}

static int status_of(UNAuthorizationStatus s) {
	switch (s) {
		case UNAuthorizationStatusNotDetermined:
			return 0;
		case UNAuthorizationStatusDenied:
			return 2;
		default:
			return 1;
	}
}

void LocalNotify::refresh_status() {
	[[UNUserNotificationCenter currentNotificationCenter] getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings *settings) {
		status = status_of(settings.authorizationStatus);
	}];
}

int LocalNotify::get_status() {
	return status;
}

void LocalNotify::request_permission() {
	UNAuthorizationOptions opts = UNAuthorizationOptionAlert | UNAuthorizationOptionSound | UNAuthorizationOptionBadge;
	[[UNUserNotificationCenter currentNotificationCenter] requestAuthorizationWithOptions:opts
																		completionHandler:^(BOOL granted, NSError *error) {
																			status = granted ? 1 : 2;
																		}];
}

void LocalNotify::schedule(String p_id, String p_title, String p_body, int p_seconds) {
	if (p_seconds < 1) {
		p_seconds = 1;
	}
	UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
	content.title = [NSString stringWithUTF8String:p_title.utf8().get_data()];
	content.body = [NSString stringWithUTF8String:p_body.utf8().get_data()];
	content.sound = [UNNotificationSound defaultSound];
	UNTimeIntervalNotificationTrigger *trigger = [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:(NSTimeInterval)p_seconds repeats:NO];
	NSString *ident = [NSString stringWithUTF8String:p_id.utf8().get_data()];
	UNNotificationRequest *req = [UNNotificationRequest requestWithIdentifier:ident content:content trigger:trigger];
	[[UNUserNotificationCenter currentNotificationCenter] addNotificationRequest:req withCompletionHandler:nil];
}

void LocalNotify::cancel_all() {
	UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
	[center removeAllPendingNotificationRequests];
	[center removeAllDeliveredNotifications];
	dispatch_async(dispatch_get_main_queue(), ^{
		[UIApplication sharedApplication].applicationIconBadgeNumber = 0;
	});
}

LocalNotify *LocalNotify::get_singleton() {
	return instance;
}

LocalNotify::LocalNotify() {
	ERR_FAIL_COND(instance != NULL);
	instance = this;
	refresh_status();
}

LocalNotify::~LocalNotify() {
	if (instance == this) {
		instance = NULL;
	}
}
