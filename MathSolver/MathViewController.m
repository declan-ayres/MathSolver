//
//  ViewController.m
//  MathSolver
//
//  Created by D Ayres on 10/27/16.
//  Copyright © 2016 PredawnLabs. All rights reserved.
//

#import "MathViewController.h"
#import <Masonry/Masonry.h>


@implementation MathViewController

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle


- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor blackColor];
    CGRect mainScreenFrame = [[UIScreen mainScreen] applicationFrame];

    UIView* primaryView = self.view ;
    
    
    fastCamera = [FastttCamera new];
    fastCamera.delegate = self;
    fastCamera.maxScaledDimension = 600.f;
    fastCamera.scalesImage = YES ;
    
    [self fastttAddChildViewController:fastCamera];
    
    [fastCamera.view mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(self.view);
        make.height.and.width.lessThanOrEqualTo(self.view.mas_width).with.priorityHigh();
        make.height.and.width.lessThanOrEqualTo(self.view.mas_height).with.priorityHigh();
        make.height.and.width.equalTo(self.view.mas_width).with.priorityLow();
        make.height.and.width.equalTo(self.view.mas_height).with.priorityLow();
    }];
    
    takePhotoButton = [UIButton new];
    [takePhotoButton addTarget:self
                             action:@selector(takePhotoButtonPressed)
                   forControlEvents:UIControlEventTouchUpInside];
    
    [takePhotoButton setTitle:@"Take Photo"
                          forState:UIControlStateNormal];
    
    [primaryView addSubview:takePhotoButton];
    [takePhotoButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self.view);
        make.bottom.equalTo(self.view).offset(-20.f);
    }];
    
    flashButton = [UIButton new];
    flashButton.titleLabel.textAlignment = NSTextAlignmentCenter;
    flashButton.titleLabel.numberOfLines = 0;
    [flashButton addTarget:self
                         action:@selector(flashButtonPressed)
               forControlEvents:UIControlEventTouchUpInside];
    
    [flashButton setTitle:@"Flash Off"
                      forState:UIControlStateNormal];
    
    [fastCamera setCameraFlashMode:FastttCameraFlashModeOff];
    
    [primaryView addSubview:flashButton];
    [flashButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.view).offset(20.f);
        make.left.equalTo(self.view).offset(20.f);
    }];
    
    switchCameraButton = [UIButton new];
    switchCameraButton.titleLabel.textAlignment = NSTextAlignmentCenter;
    switchCameraButton.titleLabel.numberOfLines = 0;
    [switchCameraButton addTarget:self
                                action:@selector(switchCameraButtonPressed)
                      forControlEvents:UIControlEventTouchUpInside];
    
    [switchCameraButton setTitle:@"Switch Camera"
                             forState:UIControlStateNormal];
    
    [fastCamera setCameraDevice:FastttCameraDeviceRear];
    
    [primaryView addSubview:switchCameraButton];
    [switchCameraButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.view).offset(20.f);
        make.right.equalTo(self.view).offset(-20.f);
        make.size.equalTo(flashButton);
    }];
    
    torchButton = [UIButton new];
    torchButton.titleLabel.textAlignment = NSTextAlignmentCenter;
    torchButton.titleLabel.numberOfLines = 0;
    [torchButton addTarget:self
                         action:@selector(torchButtonPressed)
               forControlEvents:UIControlEventTouchUpInside];
    
    [torchButton setTitle:@"Torch Off"
                      forState:UIControlStateNormal];
    
    [fastCamera setCameraTorchMode:FastttCameraTorchModeOff];
    [primaryView addSubview:torchButton];
    [torchButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.view).offset(20.f);
        make.left.equalTo(flashButton.mas_right).offset(20.f);
        make.right.equalTo(switchCameraButton.mas_left).offset(-20.f);
        make.size.equalTo(flashButton);
    }];
    
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    if (interfaceOrientation == UIInterfaceOrientationPortrait)
    {
        return YES;
    }
    return NO;
}


- (void)takePhotoButtonPressed
{
    NSLog(@"take photo button pressed");
    
    [fastCamera takePicture];
}

- (void)flashButtonPressed
{
    NSLog(@"flash button pressed");
    
    FastttCameraFlashMode flashMode;
    NSString *flashTitle;
    switch (fastCamera.cameraFlashMode) {
        case FastttCameraFlashModeOn:
            flashMode = FastttCameraFlashModeOff;
            flashTitle = @"Flash Off";
            break;
        case FastttCameraFlashModeOff:
        default:
            flashMode = FastttCameraFlashModeOn;
            flashTitle = @"Flash On";
            break;
    }
    if ([fastCamera isFlashAvailableForCurrentDevice]) {
        [fastCamera setCameraFlashMode:flashMode];
        [flashButton setTitle:flashTitle forState:UIControlStateNormal];
    }
}

- (void)torchButtonPressed
{
    NSLog(@"torch button pressed");
    
    FastttCameraTorchMode torchMode;
    NSString *torchTitle;
    switch (fastCamera.cameraTorchMode) {
        case FastttCameraTorchModeOn:
            torchMode = FastttCameraTorchModeOff;
            torchTitle = @"Torch Off";
            break;
        case FastttCameraTorchModeOff:
        default:
            torchMode = FastttCameraTorchModeOn;
            torchTitle = @"Torch On";
            break;
    }
    if ([fastCamera isTorchAvailableForCurrentDevice]) {
        [fastCamera setCameraTorchMode:torchMode];
        [torchButton setTitle:torchTitle forState:UIControlStateNormal];
    }
}

- (void)switchCameraButtonPressed
{
    NSLog(@"switch camera button pressed");
    
    FastttCameraDevice cameraDevice;
    switch (fastCamera.cameraDevice) {
        case FastttCameraDeviceFront:
            cameraDevice = FastttCameraDeviceRear;
            break;
        case FastttCameraDeviceRear:
        default:
            cameraDevice = FastttCameraDeviceFront;
            break;
    }
    if ([FastttCamera isCameraDeviceAvailable:cameraDevice]) {
        [fastCamera setCameraDevice:cameraDevice];
        if (![fastCamera isFlashAvailableForCurrentDevice]) {
            [flashButton setTitle:@"Flash Off" forState:UIControlStateNormal];
        }
    }
}



#pragma mark - IFTTTFastttCameraDelegate

- (void)cameraController:(id<FastttCameraInterface>)cameraController didFinishCapturingImage:(FastttCapturedImage *)capturedImage
{
    NSLog(@"A photo was taken");
    
    NSLog(@"Length of captured image = %ld and image width and height = %f and %f",[UIImagePNGRepresentation(capturedImage.fullImage) length],capturedImage.fullImage.size.width,capturedImage.fullImage.size.height);
    
    
    
    
    filterViewController = [FilterViewController new];
    filterViewController.capturedImage = capturedImage ;
    filterViewController.delegate = self ;
     
     
    UIView *flashView = [UIView new];
    flashView.backgroundColor = [UIColor colorWithWhite:0.9f alpha:1.f];
    flashView.alpha = 0.f;
    [self.view addSubview:flashView];
    [flashView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(fastCamera.view);
    }];
    
    [UIView animateWithDuration:0.15f
                          delay:0.f
                        options:UIViewAnimationOptionCurveEaseIn
                     animations:^{
                         flashView.alpha = 1.f;
                     }
                     completion:^(BOOL finished) {
                         
                         [self fastttAddChildViewController:filterViewController belowSubview:flashView];
                         
                         [filterViewController.view mas_makeConstraints:^(MASConstraintMaker *make) {
                             make.edges.equalTo(self.view);
                         }];
                         
                         [UIView animateWithDuration:0.15f
                                               delay:0.05f
                                             options:UIViewAnimationOptionCurveEaseOut
                                          animations:^{
                                              flashView.alpha = 0.f;
                                          }
                                          completion:^(BOOL finished2) {
                                              [flashView removeFromSuperview];
                                          }];
                     }];
    
    
    
}

- (void)cameraController:(id<FastttCameraInterface>)cameraController didFinishNormalizingCapturedImage:(FastttCapturedImage *)capturedImage
{
    NSLog(@"Photos are ready");
    
    confirmController.imagesReady = YES;
    NSLog(@"Captured image size width and height = %f and %f",capturedImage.fullImage.size.width,capturedImage.fullImage.size.height);
}

#pragma mark - FilterViewControllerDelegate

- (void)dismissFilterViewController:(FilterViewController *)controller
{
    [self fastttRemoveChildViewController:controller];
    
    filterViewController = nil;
}


#pragma mark - ConfirmControllerDelegate

- (void)dismissConfirmController:(ConfirmViewController *)controller
{
    [self fastttRemoveChildViewController:controller];
    
    confirmController = nil;
}

@end
