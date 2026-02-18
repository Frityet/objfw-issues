#include <stdio.h>
#import <ObjFW/ObjFW.h>

int
main(void)
{
	void *pool = objc_autoreleasePoolPush();
	OFMutableArray *arr = [OFMutableArray arrayWithObject: @"x"];
	OFIndexSet *indexes =
	    [OFIndexSet indexSetWithIndexesInRange: OFMakeRange(5, 1)];

	for (size_t i = 0; i < 1000; i++) {
		@try {
			[arr removeObjectsAtIndexes: indexes];
		} @catch (OFOutOfRangeException *e) {
			(void)e;
		}
	}

	objc_autoreleasePoolPop(pool);
	puts("DONE");
	return 0;
}
