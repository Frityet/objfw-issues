#include <stdio.h>
#import <ObjFW/ObjFW.h>

int
main(void)
{
	void *pool = objc_autoreleasePoolPush();
	OFMutableZIPArchiveEntry *entry = [OFMutableZIPArchiveEntry entryWithFileName: @"file.txt"];
	OFMutableZIPArchiveEntry *copy;

	entry.extraField = [OFData dataWithItems: "EXTRA" count: 5];
	entry.fileComment = @"COMMENT";
	copy = [entry mutableCopy];

	printf("orig_comment_class=%s\n", object_getClassName(entry.fileComment));
	printf("copy_comment_class=%s\n", object_getClassName(copy.fileComment));
	printf("copy_extra_class=%s\n", object_getClassName(copy.extraField));
	if ([copy.fileComment isKindOfClass: [OFString class]])
		printf("copy_comment=%s\n", copy.fileComment.UTF8String);
	else
		puts("copy_comment_not_string");

	objc_release(copy);
	objc_autoreleasePoolPop(pool);
	return 0;
}
