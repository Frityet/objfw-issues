#include <stdio.h>
#include <stdint.h>
#include <string.h>
#import <ObjFW/ObjFW.h>
#import <ObjFWRT/ObjFWRT.h>

@interface EvilStream: OFStream
@end

@implementation EvilStream
- (bool)lowlevelIsAtEndOfStream
{
	return false;
}

- (size_t)lowlevelReadIntoBuffer: (void *)buffer length: (size_t)length
{
	(void)length;
	((char *)buffer)[0] = 'A';
	return 1;
}
@end

static Ivar
findIvar(Class cls, const char *name)
{
	unsigned int count = 0;
	Ivar *ivars = class_copyIvarList(cls, &count);
	Ivar found = NULL;

	for (unsigned int i = 0; i < count; i++) {
		if (strcmp(ivar_getName(ivars[i]), name) == 0) {
			found = ivars[i];
			break;
		}
	}

	OFFreeMemory(ivars);
	return found;
}

static void
setIvarBytes(id obj, Class cls, const char *name, const void *value, size_t size)
{
	Ivar iv = findIvar(cls, name);
	if (iv == NULL) {
		fprintf(stderr, "missing ivar %s\n", name);
		return;
	}

	memcpy((char *)obj + ivar_getOffset(iv), value, size);
}

int
main(void)
{
	void *pool = objc_autoreleasePoolPush();
	EvilStream *stream = [[EvilStream alloc] init];
	char *mem = OFAllocMemory(1, 1);
	size_t huge = SIZE_MAX;
	bool waiting = true;

	setIvarBytes(stream, [OFStream class], "_readBufferMemory", &mem,
	    sizeof(mem));
	setIvarBytes(stream, [OFStream class], "_readBuffer", &mem,
	    sizeof(mem));
	setIvarBytes(stream, [OFStream class], "_readBufferLength", &huge,
	    sizeof(huge));
	setIvarBytes(stream, [OFStream class], "_waitingForDelimiter", &waiting,
	    sizeof(waiting));

	@try {
		(void)[stream tryReadLine];
		puts("NO_CRASH");
	} @catch (id e) {
		printf("EXCEPTION:%s\n", object_getClassName(e));
	}

	objc_release(stream);
	objc_autoreleasePoolPop(pool);
	return 0;
}
