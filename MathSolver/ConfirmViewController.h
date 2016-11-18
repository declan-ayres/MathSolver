//
//  ConfirmViewController.h
//  MathSolver
//
//  Created by D Ayres on 10/27/16.
//

@import UIKit;
@class FastttCapturedImage;
@protocol ConfirmControllerDelegate;

@interface ConfirmViewController : UIViewController

@property (nonatomic, weak) id <ConfirmControllerDelegate> delegate;
@property (nonatomic, strong) FastttCapturedImage *capturedImage;
@property (nonatomic, assign) BOOL imagesReady;

@end

@protocol ConfirmControllerDelegate <NSObject>

- (void)dismissConfirmController:(ConfirmViewController *)controller;

@end

