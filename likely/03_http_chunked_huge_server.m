#include <stdio.h>
#import <ObjFW/ObjFW.h>

@interface ProbeDelegate: OFObject <OFApplicationDelegate, OFHTTPServerDelegate>
{
	OFHTTPServer *_server;
	size_t _requests;
}
@end

@implementation ProbeDelegate
- (void)stopLater
{
	printf("STOP requests=%zu\n", _requests);
	[OFApplication terminate];
}

- (void)applicationDidFinishLaunching: (OFNotification *)notification
{
	OFArray OF_GENERIC(OFString *) *args = [OFApplication arguments];
	uint16_t port = 18183;
	(void)notification;

	if (args.count >= 1)
		port = (uint16_t)((OFString *)args[0]).unsignedLongLongValue;

	_server = [[OFHTTPServer alloc] init];
	_server.host = @"127.0.0.1";
	_server.port = port;
	_server.delegate = self;
	[_server start];

	printf("LISTENING %u\n", port);
	fflush(stdout);

	[OFTimer scheduledTimerWithTimeInterval: 2.0
					    target: self
					  selector: @selector(stopLater)
					   repeats: false];
}

-      (void)server: (OFHTTPServer *)server
  didReceiveRequest: (OFHTTPRequest *)request
	requestBody: (OFStream *)requestBody
	   response: (OFHTTPResponse *)response
{
	(void)server;
	(void)requestBody;
	_requests++;
	printf("REQUEST_RECEIVED method=%u\n", (unsigned int)request.method);
	fflush(stdout);
	@try {
		[response writeString: @"OK"];
	} @catch (id e) {
		(void)e;
	}
}

-           (void)server: (OFHTTPServer *)server
  didEncounterException: (id)exception
		request: (OFHTTPRequest *)request
	       response: (OFHTTPResponse *)response
{
	(void)server;
	(void)request;
	(void)response;
	printf("SERVER_EXCEPTION %s\n", object_getClassName(exception));
	fflush(stdout);
}
@end

OF_APPLICATION_DELEGATE(ProbeDelegate)
