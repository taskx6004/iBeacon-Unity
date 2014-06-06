#include "UnityAppController.h"


@interface UnityAppController (ViewHandling)

// override this to tweak unity view hierarchy
// _unityView will be inited at this point
// you need to init _rootView and _rootController
- (void)createViewHierarchyImpl;

// override this only if you need customized unityview
- (UnityView*)initUnityViewImpl;

// you should not override these methods in usual case
- (void)createViewHierarchy;
- (void)releaseViewHierarchy;
- (UnityView*)initUnityView;
- (void)showGameUI;


- (void)orientUnity:(ScreenOrientation)orient;
- (void)updateOrientationFromController:(UIViewController*)controller;

@end
