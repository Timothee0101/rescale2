#include <substrate.h>
#include <dlfcn.h>
#import <UIKit/UIKit.h>

@interface UIKeyboardImpl : UIView
+ (UIEdgeInsets)deviceSpecificPaddingForInterfaceOrientation:(NSInteger)arg1 inputMode:(id)arg2;
+ (CGSize)defaultSizeForInterfaceOrientation:(UIInterfaceOrientation)arg1;
+ (CGSize)keyboardSizeForInterfaceOrientation:(UIInterfaceOrientation)arg1;
+ (CGSize)sizeForInterfaceOrientation:(UIInterfaceOrientation)arg1;
+ (UIKeyboardImpl *)activeInstance;
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
	// iPad → largeur de l’écran rescalé (12.9")
	return (CGSize){ ReScaleScreenWidth(orient), original.height };
}

static void ForceKeyboardFrame(void) {
	UIKeyboardImpl *kbd = [UIKeyboardImpl activeInstance];
	if (!kbd) return;

	UIInterfaceOrientation orient = UIApplication.sharedApplication.statusBarOrientation;
	CGSize correct = [UIKeyboardImpl keyboardSizeForInterfaceOrientation:orient];

	CGRect current = kbd.frame;
	CGRect fixed = (CGRect){ current.origin, correct };

	if (!CGSizeEqualToSize(current.size, correct)) {
		kbd.frame = fixed;
		[kbd setNeedsLayout];
		[kbd layoutIfNeeded];
	}

	// Force aussi le layout star s’il existe
	for (UIView *sub in kbd.subviews) {
		if ([sub isKindOfClass:NSClassFromString(@"UIKeyboardLayoutStar")]) {
			sub.frame = (CGRect){ sub.frame.origin, correct };
			[sub setNeedsLayout];
			[sub layoutIfNeeded];
		}
	}
}

%hook UIKeyboardImpl

+ (CGSize)defaultSizeForInterfaceOrientation:(UIInterfaceOrientation)arg1 {
	return ReScaleCorrectSize(self, %orig, arg1);
}
+ (CGSize)keyboardSizeForInterfaceOrientation:(UIInterfaceOrientation)arg1 {
	return ReScaleCorrectSize(self, %orig, arg1);
}
+ (CGSize)sizeForInterfaceOrientation:(UIInterfaceOrientation)arg1 {
	return ReScaleCorrectSize(self, %orig, arg1);
}

- (void)setFrame:(CGRect)frame {
	UIInterfaceOrientation orient = UIApplication.sharedApplication.statusBarOrientation;
	CGSize correct = [[self class] keyboardSizeForInterfaceOrientation:orient];
	%orig((CGRect){ frame.origin, correct });
}

%end

%hook UIKeyboardLayoutStar
- (void)setFrame:(CGRect)arg1 {
	UIInterfaceOrientation orient = UIApplication.sharedApplication.statusBarOrientation;
	CGSize correct = [UIKeyboardImpl keyboardSizeForInterfaceOrientation:orient];
	%orig((CGRect){ arg1.origin, correct });
	[self setNeedsLayout];
	[self layoutIfNeeded];
}
%end

%ctor {
	%init();

	// Force le frame juste après l’apparition du clavier (le moment crucial sur iPadOS 17)
	[[NSNotificationCenter defaultCenter] addObserverForName:UIKeyboardWillShowNotification
													  object:nil
													   queue:[NSOperationQueue mainQueue]
												  usingBlock:^(NSNotification *note) {
		dispatch_async(dispatch_get_main_queue(), ^{
			ForceKeyboardFrame();
		});
	}];

	[[NSNotificationCenter defaultCenter] addObserverForName:UIKeyboardDidShowNotification
													  object:nil
													   queue:[NSOperationQueue mainQueue]
												  usingBlock:^(NSNotification *note) {
		dispatch_async(dispatch_get_main_queue(), ^{
			ForceKeyboardFrame();
		});
	}];
}
