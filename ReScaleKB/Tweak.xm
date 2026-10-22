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

static CGSize ReScaleCorrectSize(Class cls, CGSize original, UIInterfaceOrientation orient) {
	if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPhone) {
		return (CGSize){
			CGRectInset(UIScreen.mainScreen.bounds,
				[cls deviceSpecificPaddingForInterfaceOrientation:orient inputMode:nil].left, 0).size.width,
			original.height
		};
	}
	// iPad : on force la largeur de l’écran rescalé
	return (CGSize){ ReScaleScreenWidth(orient), original.height };
}

%hook UIKeyboardImpl

// === Méthodes de classe (taille demandée) ===
+ (CGSize)defaultSizeForInterfaceOrientation:(UIInterfaceOrientation)arg1 {
	return ReScaleCorrectSize(self, %orig, arg1);
}
+ (CGSize)keyboardSizeForInterfaceOrientation:(UIInterfaceOrientation)arg1 {
	return ReScaleCorrectSize(self, %orig, arg1);
}
+ (CGSize)sizeForInterfaceOrientation:(UIInterfaceOrientation)arg1 {
	return ReScaleCorrectSize(self, %orig, arg1);
}

// === Méthode d’instance (la plus importante) ===
- (void)setFrame:(CGRect)frame {
	UIInterfaceOrientation orient = UIApplication.sharedApplication.statusBarOrientation;
	CGSize correct = [[self class] keyboardSizeForInterfaceOrientation:orient];
	CGRect fixed = (CGRect){ frame.origin, correct };
	%orig(fixed);
}

%end

%hook UIKeyboardLayoutStar
- (void)setFrame:(CGRect)arg1 {
	UIInterfaceOrientation orient = UIApplication.sharedApplication.statusBarOrientation;
	CGSize correct = [UIKeyboardImpl keyboardSizeForInterfaceOrientation:orient];
	CGRect fixed = (CGRect){ arg1.origin, correct };
	%orig(fixed);

	// Force le recalcul des touches
	[self setNeedsLayout];
	[self layoutIfNeeded];
}
%end

%ctor {
	%init();
}
