#include <stdio.h>
#include <stdlib.h>
#include <stdatomic.h>
#import <ObjFW/ObjFW.h>
#import <ObjFWRT/ObjFWRT.h>

static _Atomic bool gStop = false;
static id gWeak;

@interface LoaderThread: OFThread
@end

@implementation LoaderThread
- (id)main
{
	while (!atomic_load(&gStop)) {
		id value = objc_loadWeakRetained(&gWeak);
		if (value != nil)
			objc_release(value);
	}
	return nil;
}
@end

int
main(int argc, char **argv)
{
	void *pool = objc_autoreleasePoolPush();
	unsigned long iterations = 500000;
	LoaderThread *t1 = [[LoaderThread alloc] init];
	LoaderThread *t2 = [[LoaderThread alloc] init];

	if (argc > 1)
		iterations = strtoul(argv[1], NULL, 10);

	[t1 start];
	[t2 start];

	for (unsigned long i = 0; i < iterations; i++) {
		id obj = [[OFObject alloc] init];
		objc_storeWeak(&gWeak, obj);
		objc_release(obj);
	}

	atomic_store(&gStop, true);
	[t1 join];
	[t2 join];

	objc_release(t1);
	objc_release(t2);
	printf("completed iterations=%lu\n", iterations);
	objc_autoreleasePoolPop(pool);
	return 0;
}
