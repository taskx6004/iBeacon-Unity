
#include "SplashScreen.h"
#include "UnityViewControllerBase.h"
#include "iPhone_OrientationSupport.h"
#include "iPhone_Common.h"
#import <Foundation/Foundation.h>

static SplashScreen*            _splash      = nil;
static SplashScreenController*  _controller  = nil;

// we will create and show splash before unity is inited, so we can use only plist settings
static bool     _canRotateToPortrait            = false;
static bool     _canRotateToPortraitUpsideDown  = false;
static bool     _canRotateToLandscapeLeft       = false;
static bool     _canRotateToLandscapeRight      = false;
static bool     _shouldAutorotate               = false;

static BOOL ShouldAutorotateToInterfaceOrientation_SplashImpl(id, SEL, UIInterfaceOrientation);

@implementation SplashScreen

- (id)initWithFrame:(CGRect)frame
{
    if( (self = [super initWithFrame:frame]) )
    {
        splashImageOrient = orientationUnknown;
    }
    return self;
}

- (void)unloadImage;
{
    if(self.image)
    {
        [self.image release];
        self.image = nil;
    }
}

- (void)updateOrientation:(ScreenOrientation)orient
{
    bool need2xSplash = [UIScreen mainScreen].scale > 1.0f;

    bool needOrientedSplash = false;
    bool needPortraitSplash = true;

	const char* ipadSuffix = "";
    if (UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPhone)
    {
        bool orientPortrait  = (orient == portrait || orient == portraitUpsideDown);
        bool orientLandscape = (orient == landscapeLeft || orient == landscapeRight);

        bool rotateToPortrait  = _canRotateToPortrait || _canRotateToPortraitUpsideDown;
        bool rotateToLandscape = _canRotateToLandscapeLeft || _canRotateToLandscapeRight;

		ipadSuffix = "~ipad";
        needOrientedSplash = true;
        if (orientPortrait && rotateToPortrait)
            needPortraitSplash = true;
        else if (orientLandscape && rotateToLandscape)
            needPortraitSplash = false;
        else if (rotateToPortrait)
            needPortraitSplash = true;
        else
            needPortraitSplash = false;
    }

	const char* portraitSuffix	= needOrientedSplash ? "-Portrait" : "";
	const char* landscapeSuffix	= needOrientedSplash ? "-Landscape" : "";
	const char* orientSuffix	= needPortraitSplash ? portraitSuffix : landscapeSuffix;
	const char* szSuffix		= need2xSplash ? "@2x" : "";
	const char* iOS7Suffix		= _ios70orNewer ? "-700" : "";

    if( UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone )
    {
        if([[UIScreen mainScreen] bounds].size.height == 568)
            orientSuffix = "-568h";
    }

    // we will use imageWithContentsOfFile so we need fully qualified path
    // we need to retain path because seems like imageWithContentsOfFile will be done on another thread
    // so we need to preserve path to be used with it until next runloop
	NSString* imageName = [NSString stringWithFormat:@"LaunchImage%s%s%s%s", iOS7Suffix, orientSuffix, szSuffix, ipadSuffix];
    NSString* imagePath = [[[[NSBundle mainBundle] pathForResource: imageName ofType: @"png"] retain] autorelease];

    [self unloadImage];
    self.image = [[UIImage imageWithContentsOfFile: imagePath] retain];

    splashImageOrient = orient;
}

+ (SplashScreen*)Instance
{
    return _splash;
}

@end

@implementation SplashScreenController

- (void)create:(UIWindow*)window
{
    NSArray* supportedOrientation = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"UISupportedInterfaceOrientations"];

    _shouldAutorotate               = [supportedOrientation count] > 1;
    _canRotateToPortrait            = [supportedOrientation containsObject: @"UIInterfaceOrientationPortrait"];
    _canRotateToPortraitUpsideDown  = [supportedOrientation containsObject: @"UIInterfaceOrientationPortraitUpsideDown"];
    _canRotateToLandscapeLeft       = [supportedOrientation containsObject: @"UIInterfaceOrientationLandscapeRight"];
    _canRotateToLandscapeRight      = [supportedOrientation containsObject: @"UIInterfaceOrientationLandscapeLeft"];

    _splash   = [[SplashScreen alloc] initWithFrame: [[UIScreen mainScreen] bounds]];
    _splash.contentScaleFactor = [UIScreen mainScreen].scale;

    if (UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPhone)
    {
        _splash.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _splash.autoresizesSubviews = YES;
    }
    self.view = _splash;

    self.wantsFullScreenLayout = TRUE;

    [window addSubview: _splash];
    window.rootViewController = self;
    [window bringSubviewToFront: _splash];

    ScreenOrientation orient = ConvertToUnityScreenOrientation(self.interfaceOrientation, 0);
    [_splash updateOrientation: orient];

    ScreenOrientation viewOrient = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone ? portrait : orient;
    OrientView(_splash, viewOrient);
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    if(UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPhone)
        [_splash updateOrientation: ConvertToUnityScreenOrientation(toInterfaceOrientation, 0)];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
        OrientView(_splash, portrait);
}

- (BOOL)shouldAutorotate
{
    return _shouldAutorotate;
}

- (NSUInteger)supportedInterfaceOrientations
{
    NSUInteger ret = 0;

    if(_canRotateToPortrait)              ret |= (1 << UIInterfaceOrientationPortrait);
    if(_canRotateToPortraitUpsideDown)    ret |= (1 << UIInterfaceOrientationPortraitUpsideDown);
    if(_canRotateToLandscapeLeft)         ret |= (1 << UIInterfaceOrientationLandscapeRight);
    if(_canRotateToLandscapeRight)        ret |= (1 << UIInterfaceOrientationLandscapeLeft);

    return ret;
}

+ (SplashScreenController*)Instance
{
    return _controller;
}

@end

void ShowSplashScreen(UIWindow* window)
{
    static bool _ClassInited = false;
    if(!_ClassInited)
    {
        AddShouldAutorotateToImplIfNeeded([SplashScreenController class], &ShouldAutorotateToInterfaceOrientation_SplashImpl);
        AddStatusBarSupportDefaultImpl([SplashScreenController class]);
        _ClassInited = true;
    }

    _controller = [[SplashScreenController alloc] init];
    [_controller create:window];
}

void HideSplashScreen()
{
    if(_splash)
    {
        [_splash removeFromSuperview];
        [_splash unloadImage];
        [_splash release];
        _splash = nil;
    }
    if(_controller)
    {
        [_controller release];
        _controller = nil;
    }
}

static BOOL
ShouldAutorotateToInterfaceOrientation_SplashImpl(id self_, SEL _cmd, UIInterfaceOrientation interfaceOrientation)
{
    switch(interfaceOrientation)
    {
        case UIInterfaceOrientationPortrait:            return _canRotateToPortrait;
        case UIInterfaceOrientationPortraitUpsideDown:  return _canRotateToPortraitUpsideDown;
        case UIInterfaceOrientationLandscapeRight:      return _canRotateToLandscapeLeft;
        case UIInterfaceOrientationLandscapeLeft:       return _canRotateToLandscapeRight;

        default:                                        return false;
    }

    return false;
}
