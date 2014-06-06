#import <UIKit/UIKit.h>

#include "RegisterClasses.h"
#include "RegisterMonoModules.h"

// Hack to work around iOS SDK 4.3 linker problem
// we need at least one __TEXT, __const section entry in main application .o files
// to get this section emitted at right time and so avoid LC_ENCRYPTION_INFO size miscalculation
static const int constsection = 0;

void UnityInitTrampoline();

// WARNING: this MUST be c decl (NSString ctor will be called after +load, so we cant really change its value)
const char* AppControllerClassName = "UnityAppController";


int main(int argc, char* argv[])
{
	NSAutoreleasePool* pool = [NSAutoreleasePool new];

	UnityInitTrampoline();
	if(!UnityParseCommandLine(argc, argv))
		return -1;

	RegisterMonoModules();
	NSLog(@"-> registered mono modules %p\n", &constsection);

	UIApplicationMain(argc, argv, nil, [NSString stringWithUTF8String:AppControllerClassName]);

	[pool release];
	return 0;
}
