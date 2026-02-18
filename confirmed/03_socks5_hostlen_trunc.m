#include <stdio.h>
#import <ObjFW/ObjFW.h>

@interface ProbeDelegate: OFObject <OFApplicationDelegate>
@end

@implementation ProbeDelegate
- (void)applicationDidFinishLaunching: (OFNotification *)notification
{
	OFArray OF_GENERIC(OFString *) *args = [OFApplication arguments];
	OFString *portArg, *lenArg;
	OFTCPSocket *socket;
	OFMutableString *host;
	uint16_t port;
	size_t len;

	(void)notification;

	if (args.count != 2) {
		fprintf(stderr, "usage: 03_socks5_hostlen_trunc <proxy-port> <len>\n");
		[OFApplication terminateWithStatus: 2];
		return;
	}

	portArg = args[0];
	lenArg = args[1];
	port = (uint16_t)portArg.unsignedLongLongValue;
	len = (size_t)lenArg.unsignedLongLongValue;

	host = [OFMutableString string];
	for (size_t i = 0; i < len; i++)
		[host appendString: @"a"];

	socket = [OFTCPSocket socket];
	socket.SOCKS5Host = @"127.0.0.1";
	socket.SOCKS5Port = port;

	@try {
		[socket connectToHost: host port: 80];
		puts("CONNECT_OK");
	} @catch (id e) {
		printf("EXCEPTION:%s\n", object_getClassName(e));
	}

	@try {
		[socket close];
	} @catch (id e) {
		(void)e;
	}

	[OFApplication terminate];
}
@end

OF_APPLICATION_DELEGATE(ProbeDelegate)
