#include <substrate.h>
#include <dlfcn.h>
#import <UIKit/UIKit.h>

@interface UIKeyboardImpl : UIView
+ (UIEdgeInsets)deviceSpecificPaddingForInterfaceOrientation:(NSInteger)arg1 inputMode:(id)arg2;
+ (CGSize)defaultSizeForInterfaceOrientation:(UIInterfaceOrientation)arg1;
+ (CGSize)keyboardSizeForInterfaceOrientation:(UIInterfaceOrientation)arg1;
+ (CGSize)sizeForInterfaceOrientation:(UIInterfaceOrientation)arg1;
@end

static CGFloat ReScaleScreenWidth(UIInterfaceOrientation orientation) {
	CGSize s = UIScreen.mainScreen.bounds.size;
	CGFloat longSide  = MAX(s.width, s.height);
	CGFloat shortSide = MIN(s.width, s.height);
	if (UIInterfaceOrientationIsLandscape(orientation)) return longSide;
	if (UIInterfaceOrientationIsPortrait(orientation))  return shortSide;
	return s.width;
}

static CGSize ReScaleAdjustedSize(Class keyboardClass, CGSize original, UIInterfaceOrientation orientation) {
	UIUserInterfaceIdiom idiom = UIDevice.currentDevice.userInterfaceIdiom;

	if (idiom == UIUserInterfaceIdiomPhone) {
		return (CGSize){
			CGRectInset(UIScreen.mainScreen.bounds,
						[keyboardClass deviceSpecificPaddingForInterfaceOrientation:orientation inputMode:nil].left,
						0).size.width,
			original.height
		};
	}

	if (idiom == UIUserInterfaceIdiomPad) {
		// Force la largeur exacte de l’écran rescalé
		return (CGSize){ ReScaleScreenWidth(orientation), original.height };
	}

	return original;
}

%hook UIKeyboardImpl
+ (CGSize)defaultSizeForInterfaceOrientation:(UIInterfaceOrientation)arg1 {
	return ReScaleAdjustedSize(self, %orig, arg1);
}
+ (CGSize)keyboardSizeForInterfaceOrientation:(UIInterfaceOrientation)arg1 {
	return ReScaleAdjustedSize(self, %orig, arg1);
}
+ (CGSize)sizeForInterfaceOrientation:(UIInterfaceOrientation)arg1 {
	return ReScaleAdjustedSize(self, %orig, arg1);
}
%end

%hook UIKeyboardLayoutStar
- (void)setFrame:(CGRect)arg1 {
	UIInterfaceOrientation orient = UIApplication.sharedApplication.statusBarOrientation;
	CGSize correctSize = [UIKeyboardImpl keyboardSizeForInterfaceOrientation:orient];

	// On force la bonne taille + on force le relayout des touches
	CGRect fixed = (CGRect){ arg1.origin, correctSize };
	%orig(fixed);

	[self setNeedsLayout];
	[self layoutIfNeeded];
}
%end

%ctor {
	%init();
}
