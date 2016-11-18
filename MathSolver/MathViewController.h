//
//  ViewController.h
//  MathSolver
//
//  Created by D Ayres on 10/27/16.
//

#import <UIKit/UIKit.h>
#import <FastttCamera/FastttCamera.h>
#import "ConfirmViewController.h"
#import "FilterViewController.h"
#import "GPUImage.h"

#define BLUR_STEP 2

@interface MathViewController:UIViewController <FastttCameraDelegate, ConfirmControllerDelegate,FilterViewControllerDelegate> {
    
    GPUImagePicture *sourcePicture;
    GPUImageOutput<GPUImageInput> *sepiaFilter, *sepiaFilter2;
    
    UIButton *takePhotoButton ;
    UIButton *flashButton ;
    UIButton *switchCameraButton ;
    UIButton *torchButton ;
    FastttCamera  *fastCamera ;
    ConfirmViewController *confirmController;
    FilterViewController  *filterViewController;
    
}





@end

