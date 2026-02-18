#include <stdio.h>
#include <stdint.h>
#import <ObjFW/ObjFW.h>

int
main(void)
{
	void *pool = objc_autoreleasePoolPush();
	OFMemoryStream *stream;

	@try {
		stream = [OFMemoryStream streamWithMemoryAddress: (char *)"A" size: 1 writable: false];
		(void)[stream readStringWithLength: SIZE_MAX];
		puts("NO_CRASH");
	} @catch (id e) {
		printf("EXCEPTION:%s\n", object_getClassName(e));
	}

	objc_autoreleasePoolPop(pool);
	return 0;
}
