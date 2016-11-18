//
//  FilterViewController.h
//  MathSolver
//
//  Created by D Ayres on 10/28/16.
//  Copyright © 2016 PredawnLabs. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <FastttCamera/FastttCamera.h>
#import "ConfirmViewController.h"
#import "GPUImage.h"
#import <Masonry/Masonry.h>

@import AssetsLibrary;
@import MessageUI;

#define BLUR_STEP 2

@import AssetsLibrary;
@import MessageUI;


@class FastttCapturedImage;
@protocol ConfirmControllerDelegate;
@protocol FilterViewControllerDelegate ;



@interface FilterViewController:UIViewController <FastttCameraDelegate, ConfirmControllerDelegate,MFMailComposeViewControllerDelegate, UIAlertViewDelegate> {
    
    GPUImagePicture *sourcePicture;
    GPUImageOutput<GPUImageInput> *sepiaFilter, *sepiaFilter2;
    
    UISlider *imageSlider;
    UIButton *showResampledImage ;
    UIButton *takePhotoButton ;
    UIButton *flashButton ;
    UIButton *switchCameraButton ;
    UIButton *torchButton ;
    UIButton *backButton ;
    UIButton *confirmButton;
    
    FastttCamera  *fastCamera ;
    
    ConfirmViewController *confirmController;
    
    CGFloat blurRadius;
    CGFloat gaussianBlurRadius;
    
    GPUImageGaussianBlurFilter *blurFilter;
    GPUImageAdaptiveThresholdFilter *blurAdaptiveFilter ;
    GPUImageMaskFilter *maskingFilter ;
    GPUImageColorInvertFilter *imageInvertFilter;
    GPUImageMonochromeFilter  *monoFilter ;
    GPUImageOpacityFilter     *opacityFilter ;
    GPUImageGrayscaleFilter   *grayImageFilter;
    GPUImageRawDataOutput *rawDataOutput  ;
    GLubyte *outputBytes ;
    NSInteger bytesPerRow ;
    
    
    NSCache *blurredImageCache;
    dispatch_queue_t blurQueue;
    dispatch_group_t myGroup ;
    NSMutableSet *blurAmountsBeingRendered;
    dispatch_semaphore_t semaphore;
    
    
}

@property (nonatomic,strong) NSData *rawData ; 
@property (nonatomic) unsigned char *ubyte_image_store ;
@property (nonatomic,strong) UIImage *gblurImage;
@property (nonatomic,strong) UIImage *grayImage ;
@property (nonatomic,strong) UIImage *binImage ;
@property (nonatomic, weak) id <FilterViewControllerDelegate> delegate;
@property (nonatomic, strong) FastttCapturedImage *capturedImage;
@property (nonatomic, assign) BOOL imagesReady;

// Image filtering
- (void)setupDisplayFiltering;
- (void)setupImageFilteringToDisk;
- (void)setupImageResampling;
- (void)processGrayImage:(UIImage*) grayImage ;

- (IBAction)updateSliderValue:(id)sender;


@end

@protocol FilterViewControllerDelegate <NSObject>

- (void)dismissFilterViewController:(FilterViewController *)controller;

@end
