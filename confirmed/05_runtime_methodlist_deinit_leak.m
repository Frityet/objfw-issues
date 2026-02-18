#include <stdio.h>
#include <unistd.h>
#import <ObjFW/ObjFW.h>
#import <ObjFWRT/ObjFWRT.h>

static void
noop(id self, SEL _cmd)
{
	(void)self;
	(void)_cmd;
}

int
main(void)
{
	char className[128], selName[64];
	Class cls;

	snprintf(className, sizeof(className), "ReproClass_%ld", (long)getpid());
	cls = objc_allocateClassPair([OFObject class], className, 0);
	if (cls == Nil)
		return 1;
	objc_registerClassPair(cls);

	for (size_t i = 0; i < 10000; i++) {
		snprintf(selName, sizeof(selName), "x%zu", i);
		(void)class_addMethod(cls, sel_registerName(selName), (IMP)noop,
		    "v@:");
	}

	objc_deinit();
	return 0;
}
