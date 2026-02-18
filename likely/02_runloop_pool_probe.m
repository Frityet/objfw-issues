#include <stdio.h>
#include <stdatomic.h>
#import <ObjFW/ObjFW.h>

static _Atomic int gLive = 0;
static _Atomic int gCreated = 0;

@interface Token: OFObject
+ (instancetype)token;
@end

@implementation Token
+ (instancetype)token
{
	return objc_autorelease([[self alloc] init]);
}

- (instancetype)init
{
	self = [super init];
	if (self != nil) {
		atomic_fetch_add(&gLive, 1);
		atomic_fetch_add(&gCreated, 1);
	}
	return self;
}

- (void)dealloc
{
	atomic_fetch_sub(&gLive, 1);
	[super dealloc];
}
@end

@interface ProbeDelegate: OFObject <OFApplicationDelegate>
@end

@implementation ProbeDelegate
- (void)makeGarbage
{
	for (int i = 0; i < 20000; i++)
		(void)[Token token];

	printf("after_first_timer created=%d live=%d\n",
	    atomic_load(&gCreated), atomic_load(&gLive));
}

- (void)checkAndExit
{
	printf("before_terminate created=%d live=%d\n",
	    atomic_load(&gCreated), atomic_load(&gLive));
	[OFApplication terminate];
}

- (void)applicationDidFinishLaunching: (OFNotification *)notification
{
	(void)notification;
	[OFTimer scheduledTimerWithTimeInterval: 0.01
					    target: self
					  selector: @selector(makeGarbage)
					   repeats: false];
	[OFTimer scheduledTimerWithTimeInterval: 0.02
					    target: self
					  selector: @selector(checkAndExit)
					   repeats: false];
}
@end

OF_APPLICATION_DELEGATE(ProbeDelegate)
