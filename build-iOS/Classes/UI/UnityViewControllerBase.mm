
#include "UnityViewControllerBase.h"
#include "iPhone_OrientationSupport.h"
#include "UI/UnityView.h"

#include "objc/runtime.h"


BOOL
ShouldAutorotateToInterfaceOrientation_DefaultImpl(id self_, SEL _cmd, UIInterfaceOrientation interfaceOrientation)
{
	EnabledOrientation targetAutorot = autorotPortrait;
	ScreenOrientation  targetRot = ConvertToUnityScreenOrientation(interfaceOrientation, &targetAutorot);
	ScreenOrientation  requestedOrientation = (ScreenOrientation)UnityRequestedScreenOrientation();

	if(requestedOrientation == autorotation)
		return UnityIsOrientationEnabled(targetAutorot);
	else
		return targetRot == requestedOrientation;
}

NSUInteger
SupportedInterfaceOrientations_DefaultImpl(id self_, SEL _cmd)
{
	NSUInteger ret = 0;

	if(UnityRequestedScreenOrientation() == autorotation)
	{
		if( UnityIsOrientationEnabled(autorotPortrait) )			ret |= (1 << UIInterfaceOrientationPortrait);
		if( UnityIsOrientationEnabled(autorotPortraitUpsideDown) )	ret |= (1 << UIInterfaceOrientationPortraitUpsideDown);
		if( UnityIsOrientationEnabled(autorotLandscapeLeft) )		ret |= (1 << UIInterfaceOrientationLandscapeRight);
		if( UnityIsOrientationEnabled(autorotLandscapeRight) )		ret |= (1 << UIInterfaceOrientationLandscapeLeft);
	}
	else
	{
		switch(UnityRequestedScreenOrientation())
		{
			case portrait:				ret = (1 << UIInterfaceOrientationPortrait);            break;
			case portraitUpsideDown:	ret = (1 << UIInterfaceOrientationPortraitUpsideDown);  break;
			case landscapeLeft:			ret = (1 << UIInterfaceOrientationLandscapeRight);      break;
			case landscapeRight:		ret = (1 << UIInterfaceOrientationLandscapeLeft);       break;
			default:					ret = (1 << UIInterfaceOrientationPortrait);            break;
		}
	}

	return ret;
}

BOOL
ShouldAutorotate_DefaultImpl(id self_, SEL _cmd)
{
	return (UnityRequestedScreenOrientation() == autorotation);
}

BOOL
PrefersStatusBarHidden_DefaultImpl(id self_, SEL _cmd)
{
	// we do not support changing styles from script, so we need read info.plist only once
	static BOOL _PrefersStatusBarHidden = YES;

	bool _PrefersStatusBarHiddenInited = false;
	if(!_PrefersStatusBarHiddenInited)
	{
		NSNumber* hidden = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"UIStatusBarHidden"];
		_PrefersStatusBarHidden = hidden ? [hidden boolValue] : YES;

		_PrefersStatusBarHiddenInited = true;
	}

	return _PrefersStatusBarHidden;
}

UIStatusBarStyle
PreferredStatusBarStyle_DefaultImpl(id self_, SEL _cmd)
{
	static UIStatusBarStyle _PreferredStatusBarStyle = UIStatusBarStyleDefault;

	bool _PreferredStatusBarStyleInited = false;
	if(!_PreferredStatusBarStyleInited)
	{
		// this will be called only on ios7, so no need to handle old enum values
		NSString* style = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"UIStatusBarStyle"];
		if(style && ([style isEqualToString:@"UIStatusBarStyleBlackOpaque"] || [style isEqualToString:@"UIStatusBarStyleBlackTranslucent"]))
		{
		#if UNITY_PRE_IOS7_SDK
			_PreferredStatusBarStyle = (UIStatusBarStyle)1;
		#else
			_PreferredStatusBarStyle = UIStatusBarStyleLightContent;
		#endif
		}
		_PreferredStatusBarStyleInited = true;
	}

	return _PreferredStatusBarStyle;
}

void
AddShouldAutorotateToImplIfNeeded(Class targetClass, ShouldAutorotateToFunc impl)
{
	if( UNITY_PRE_IOS6_SDK || !_ios60orNewer )
		class_addMethod( targetClass, @selector(shouldAutorotateToInterfaceOrientation:), (IMP)impl, "c12@0:4i8" );
}

void
AddShouldAutorotateToDefaultImplIfNeeded(Class targetClass)
{
	AddShouldAutorotateToImplIfNeeded(targetClass, &ShouldAutorotateToInterfaceOrientation_DefaultImpl);
}

void
AddOrientationSupportImpl(Class targetClass, SupportedInterfaceOrientationsFunc impl1, ShouldAutorotateFunc impl2, ShouldAutorotateToFunc impl3)
{
	AddShouldAutorotateToImplIfNeeded(targetClass, impl3);

	class_addMethod(targetClass, @selector(supportedInterfaceOrientations), (IMP)impl1, "I8@0:4");
	class_addMethod(targetClass, @selector(shouldAutorotate), (IMP)impl2, "c8@0:4");
}

void
AddOrientationSupportDefaultImpl(Class targetClass)
{
	AddOrientationSupportImpl(	targetClass,
								&SupportedInterfaceOrientations_DefaultImpl,
								&ShouldAutorotate_DefaultImpl,
								&ShouldAutorotateToInterfaceOrientation_DefaultImpl
							 );
}

void
AddStatusBarSupportImpl(Class targetClass, PrefersStatusBarHiddenFunc impl1, PreferredStatusBarStyleFunc impl2)
{
	class_addMethod(targetClass, @selector(prefersStatusBarHidden), (IMP)impl1, "c8@0:4");
	class_addMethod(targetClass, @selector(preferredStatusBarStyle), (IMP)impl2, "i8@0:4");
}
void
AddStatusBarSupportDefaultImpl(Class targetClass)
{
	AddStatusBarSupportImpl(targetClass, &PrefersStatusBarHidden_DefaultImpl, &PreferredStatusBarStyle_DefaultImpl);
}

void
AddViewControllerAllDefaultImpl(Class targetClass)
{
	AddOrientationSupportDefaultImpl(targetClass);
	AddStatusBarSupportDefaultImpl(targetClass);
}


@implementation UnityViewControllerBase
- (void)assignUnityView:(UnityView*)view_
{
	_unityView = view_;
}
- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
	[UIView setAnimationsEnabled:UnityUseAnimatedAutorotation()];

	ScreenOrientation orient = ConvertToUnityScreenOrientation(toInterfaceOrientation, 0);
	[_unityView willRotateTo:orient];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
	[self.view layoutSubviews];
	[_unityView didRotate];

	[UIView setAnimationsEnabled:YES];
}
@end

@implementation UnityDefaultViewController
@end


extern "C" void NotifyAutoOrientationChange()
{
	if([UIViewController respondsToSelector:@selector(attemptRotationToDeviceOrientation)])
		[UIViewController attemptRotationToDeviceOrientation];
}
