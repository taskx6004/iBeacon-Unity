#include "UnityAppController+ViewHandling.h"
#include "UnityAppController+Rendering.h"

#include "UI/UnityView.h"
#include "UI/UnityViewControllerBase.h"

#include "iPhone_OrientationSupport.h"

// TEMP: ?
#include "UI/ActivityIndicator.h"
#include "UI/SplashScreen.h"
#include "UI/Keyboard.h"

extern bool _skipPresent;
extern bool _unityAppReady;



@implementation UnityAppController (ViewHandling)

- (void)createViewHierarchyImpl
{
	_rootView = _unityView;
	_rootController = [[UnityDefaultViewController alloc] init];
}
- (UnityView*)initUnityViewImpl
{
	return [[UnityView alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
}

- (void)createViewHierarchy
{
	AddViewControllerAllDefaultImpl([UnityDefaultViewController class]);

	NSAssert(_unityView != nil, @"_unityView should be inited at this point");
	NSAssert(_window != nil, @"_window should be inited at this point");

	[self createViewHierarchyImpl];
	NSAssert(_rootView != nil, @"createViewHierarchyImpl must assign _rootView");
	NSAssert(_rootController != nil, @"createViewHierarchyImpl must assign _rootController");

	_rootView.contentScaleFactor = [UIScreen mainScreen].scale;
	_rootView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

	_rootController.wantsFullScreenLayout = TRUE;
	_rootController.view = _rootView;
	if([_rootController isKindOfClass: [UnityViewControllerBase class]])
		[(UnityViewControllerBase*)_rootController assignUnityView:_unityView];

	[_window makeKeyAndVisible];
	[UIView setAnimationsEnabled:NO];

	// TODO: extract it?

	ShowSplashScreen(_window);

	NSNumber* style = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"Unity_LoadingActivityIndicatorStyle"];
	ShowActivityIndicator([SplashScreen Instance], style ? [style intValue] : -1 );
}
- (void)releaseViewHierarchy
{
	HideActivityIndicator();
	HideSplashScreen();
}

- (UnityView*)initUnityView
{
	_unityView = [self initUnityViewImpl];
	_unityView.contentScaleFactor = [UIScreen mainScreen].scale;
	_unityView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

	return _unityView;
}

- (void)showGameUI
{
	HideActivityIndicator();
	HideSplashScreen();

	// this is called after level was loaded, so orientation constraints or resolution might have changed
	[self updateOrientationFromController:_rootController];
	[_unityView recreateGLESSurface];

	[_window addSubview: _rootView];
	_window.rootViewController = _rootController;
	[_window bringSubviewToFront: _rootView];

	// why we set level ready only now:
	// surface recreate will try to repaint if this var is set (poking unity to do it)
	// but this frame now is actually the first one we want to process/draw
	// so all the recreateSurface before now (triggered by reorientation) should simply change extents

	_unityAppReady = true;

	// why we skip present:
	// this will be the first frame to draw, so Start methods will be called
	// and we want to properly handle resolution request in Start (which might trigger surface recreate)
	// NB: we want to draw right after showing window, to avoid black frame creeping in

	_skipPresent = true;
	UnityPlayerLoop();
	_skipPresent = false;
	[self repaint];


	[UIView setAnimationsEnabled:YES];
}

- (void)orientUnity:(ScreenOrientation)orient
{
	if(_unityAppReady)
		UnityFinishRendering();

	[CATransaction begin];
	{
		[KeyboardDelegate StartReorientation];
		[self onForcedOrientation:orient];
		[UIApplication sharedApplication].statusBarOrientation = ConvertToIosScreenOrientation(orient);
	}
	[CATransaction commit];

	[CATransaction begin];
	[KeyboardDelegate FinishReorientation];
	[CATransaction commit];
}

- (void)updateOrientationFromController:(UIViewController*)controller
{
	ScreenOrientation newOrient = ConvertToUnityScreenOrientation(controller.interfaceOrientation,0);
	UnitySetScreenOrientation(newOrient);
	AppController_RenderPluginMethodWithArg(@selector(onOrientationChange:), (id)newOrient);
	[self orientUnity:newOrient];
}

@end
