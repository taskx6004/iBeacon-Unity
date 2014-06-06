
#include "UnityView.h"
#include "UnityAppController.h"
#include "iPhone_OrientationSupport.h"
#include "Unity/GlesHelper.h"
#include "Unity/DisplayManager.h"

@implementation UnityView
{
	CGSize 				_surfaceSize;
	ScreenOrientation 	_curOrientation;

	BOOL				_recreateView;
}
- (id)initWithFrame:(CGRect)frame
{
	if( (self = [super initWithFrame:frame]) )
	{
		self.multipleTouchEnabled = YES;
		self.exclusiveTouch = YES;

		_surfaceSize = frame.size;
	}
	return self;
}
- (void)layoutSubviews
{
	if (_surfaceSize.width != self.bounds.size.width || _surfaceSize.height != self.bounds.size.height)
	{
		_surfaceSize  = self.bounds.size;
		_recreateView = YES;
	}

	[super layoutSubviews];
}

- (void)willRotateTo:(ScreenOrientation)orientation
{
	_curOrientation = orientation;
	AppController_RenderPluginMethodWithArg(@selector(onOrientationChange:), (id)_curOrientation);
	UnitySetScreenOrientation(_curOrientation);

	[[NSNotificationCenter defaultCenter] postNotificationName:kUnityViewWillRotate object:self];
}
- (void)didRotate
{
	if(_recreateView)
	{
		// we are not inside repaint so we need to draw second time ourselves
		[self recreateGLESSurface];
		UnityPlayerLoop();
	}

	[[NSNotificationCenter defaultCenter] postNotificationName:kUnityViewDidRotate object:self];
}


- (ScreenOrientation)contentOrientation
{
	return _curOrientation;
}

- (void)recreateGLESSurfaceIfNeeded
{
	unsigned requestedW, requestedH;	UnityGetRenderingResolution(&requestedW, &requestedH);
	int requestedMSAA = UnityGetDesiredMSAASampleCount(MSAA_DEFAULT_SAMPLE_COUNT);

	if(		GetMainDisplay()->surface.use32bitColor != UnityUse32bitDisplayBuffer()
		||	GetMainDisplay()->surface.use24bitDepth != UnityUse24bitDepthBuffer()
		||	requestedW != GetMainDisplay()->surface.targetW || requestedH != GetMainDisplay()->surface.targetH
		||	(_supportsMSAA && requestedMSAA != GetMainDisplay()->surface.msaaSamples)
		||	_recreateView == YES
	  )
	{
		[self recreateGLESSurface];
	}
}

- (void)recreateGLESSurface
{
	extern bool _glesContextCreated;
	extern bool _unityAppReady;
	extern bool _skipPresent;

	if(_glesContextCreated)
	{
		unsigned requestedW, requestedH;
		UnityGetRenderingResolution(&requestedW, &requestedH);

		RenderingSurfaceParams params =
		{
			UnityGetDesiredMSAASampleCount(MSAA_DEFAULT_SAMPLE_COUNT),
			requestedW, requestedH,
			UnityUse32bitDisplayBuffer(), UnityUse24bitDepthBuffer(), false
		};

		AppController_RenderPluginMethodWithArg(@selector(onBeforeMainDisplaySurfaceRecreate:), (id)&params);
		[GetMainDisplay() recreateSurface:params];
		AppController_RenderPluginMethod(@selector(onAfterMainDisplaySurfaceRecreate));

		if(_unityAppReady)
		{
			// seems like ios sometimes got confused about abrupt swap chain destroy
			// draw 2 times to fill both buffers
			// present only once to make sure correct image goes to CA
			// if we are calling this from inside repaint, second draw and present will be done automatically
			_skipPresent = true;
			{
				SetupUnityDefaultFBO(&GetMainDisplay()->surface);
				UnityPlayerLoop();
				UnityFinishRendering();
			}
			_skipPresent = false;
		}
	}

	_recreateView = NO;
}

- (void)touchesBegan:(NSSet*)touches withEvent:(UIEvent*)event
{
	UnitySendTouchesBegin(touches, event);
}
- (void)touchesEnded:(NSSet*)touches withEvent:(UIEvent*)event
{
	UnitySendTouchesEnded(touches, event);
}
- (void)touchesCancelled:(NSSet*)touches withEvent:(UIEvent*)event
{
	UnitySendTouchesCancelled(touches, event);
}
- (void)touchesMoved:(NSSet*)touches withEvent:(UIEvent*)event
{
	UnitySendTouchesMoved(touches, event);
}

@end
