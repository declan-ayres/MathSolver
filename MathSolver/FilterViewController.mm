//
//  FilterViewController.mm
//  MathSolver
//
//  Created by D Ayres on 10/28/16.
//  Copyright © 2016 PredawnLabs. All rights reserved.
// #Attributions to GPU Image Filter by Brad Larson Link:https://github.com/BradLarson/GPUImage2

#import "FilterViewController.h"
#import <CoreImage/CoreImage.h>
#import "OpenCV_Wrapper.h"




@implementation FilterViewController


- (void)loadView
{
    CGRect mainScreenFrame = [[UIScreen mainScreen] applicationFrame];
    GPUImageView *primaryView = [[GPUImageView alloc] initWithFrame:mainScreenFrame];
    self.view = primaryView;
    
    backButton = [UIButton new];
    [backButton addTarget:self
                   action:@selector(dismissFilterViewController)
         forControlEvents:UIControlEventTouchUpInside];
    
    [backButton setTitle:@"Back"
                forState:UIControlStateNormal];
    
    [self.view addSubview:backButton];
    [backButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.view).offset(20.f);
        make.left.equalTo(self.view).offset(20.f);
    }];
    
    confirmButton = [UIButton new];
    [confirmButton addTarget:self
                      action:@selector(confirmButtonPressed)
            forControlEvents:UIControlEventTouchUpInside];
    
    [confirmButton setTitle:@"Use Photo"
                   forState:UIControlStateNormal];
    
    
    [self.view addSubview:confirmButton];
    [confirmButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self.view);
        make.bottom.equalTo(self.view).offset(-20.f);
    }];
    
    
    blurFilter = [GPUImageGaussianBlurFilter new];
    blurAdaptiveFilter = [[GPUImageAdaptiveThresholdFilter alloc] init];
    maskingFilter = [[GPUImageMaskFilter alloc] init];
    imageInvertFilter = [[GPUImageColorInvertFilter alloc] init];
    monoFilter = [[GPUImageMonochromeFilter alloc] init];
    opacityFilter = [[GPUImageOpacityFilter alloc] init];
    grayImageFilter = [[GPUImageGrayscaleFilter alloc] init];
    
    blurredImageCache = [NSCache new];
    myGroup = dispatch_group_create();
    blurQueue = dispatch_queue_create("Image Blur Queue", DISPATCH_QUEUE_SERIAL);
    blurAmountsBeingRendered = [NSMutableSet set];
    gaussianBlurRadius = 1.0;
    blurRadius = 8.0;
    
    
    imageSlider = [[UISlider alloc] initWithFrame:CGRectMake(25.0, mainScreenFrame.size.height - 80.0, mainScreenFrame.size.width - 50.0, 40.0)];
    [imageSlider addTarget:self action:@selector(sliderDidMove:) forControlEvents:UIControlEventValueChanged];
    
    imageSlider.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    imageSlider.minimumValue = 0.0;
    imageSlider.maximumValue = 3.0;
    imageSlider.value = 0.5;
    [imageSlider setContinuous: NO];
    
    [primaryView addSubview:imageSlider];
    
    self.ocv_wrapper = [[OpenCVWrapperClass alloc] init];
    
    
    [self updateView];
    
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    if (interfaceOrientation == UIInterfaceOrientationPortrait)
    {
        return YES;
    }
    return NO;
}


- (IBAction)updateSliderValue:(id)sender
{
    CGFloat midpoint = [(UISlider *)sender value];
    [(GPUImageTiltShiftFilter *)sepiaFilter setTopFocusLevel:midpoint - 0.1];
    [(GPUImageTiltShiftFilter *)sepiaFilter setBottomFocusLevel:midpoint + 0.1];
    
    [sourcePicture processImage];
}

- (IBAction)sliderDidMove:(UISlider *)sender {
    blurRadius = 10 * sender.value;
    NSLog(@"Blur radius = %f",blurRadius);
    [self asyncGenerateImageWithBlurAmount:blurRadius];
    [sourcePicture processImage];
}


#pragma mark -
#pragma mark Image filtering

//new clean version of cascadeGPUFilters

- (UIImage *) chainGPUFilters:(UIImage*) sourceImage flag: (BOOL) flag{
    
    NSLog(@"length of image entering gaussian blur = %lu",[UIImagePNGRepresentation(sourceImage) length]);
    
    GPUImageView *imageView = (GPUImageView *)self.view;
    
    
    
    GPUImagePicture *stillImageSource = [[GPUImagePicture alloc] initWithImage:sourceImage];
    
    
    blurFilter.blurRadiusInPixels = gaussianBlurRadius; //initialized to 1
    blurFilter.blurPasses = 1;
    
    blurAdaptiveFilter.blurRadiusInPixels = blurRadius;
    
    [stillImageSource addTarget:blurFilter];
    [blurFilter addTarget:blurAdaptiveFilter];
    [blurAdaptiveFilter addTarget:imageInvertFilter];
    [imageInvertFilter addTarget:grayImageFilter];
    
    
    
    
    [grayImageFilter useNextFrameForImageCapture];
    [grayImageFilter addTarget:imageView];
    [stillImageSource processImage];
    
    UIImage* im = [grayImageFilter imageFromCurrentFramebufferWithOrientation:UIImageOrientationUp];
    
    
    
    CGImageRef imageRef = im.CGImage;
    int height   = (int) CGImageGetHeight(imageRef);
    int width   = (int) CGImageGetWidth(imageRef);
    
    int bitsPerComponent = (int)CGImageGetBitsPerComponent(imageRef);
    int bitsPerPixel = 32;
    int bytesPerRow = bitsPerPixel/8*(int)width;
    
    float scaleFactor = [[UIScreen mainScreen] scale];
    
    if (self.ubyte_image_store != NULL) {
        free(self.ubyte_image_store);
    }
    
    self.ubyte_image_store = malloc((int)im.size.width*(int)im.size.height); //,1);
    
    if (strlen((char*)self.ubyte_image_store) == 0) {
        NSLog(@"Couldn't allocate memory for ubyte_image_store ?!...was trying to allocate %f bytes of memory",im.size.width*im.size.height);
    }
    CGColorSpaceRef colorSpaceRef = CGImageGetColorSpace(imageRef);
    
    CGBitmapInfo bitMapInfo = kCGBitmapByteOrder32Big | kCGImageAlphaNoneSkipFirst;
    
    
    
    NSLog(@"image width = %d, image height=%d, bitmapinfo = %d , colorspace = %@, bytesperrow = %d, bitpercomponent=%d, kCGImageAlphaNoneSkipLast =%d and  kCGBitmapByteOrder32Big %d and kCGBitmapByteOrder32Big = %d, and kCGImageAlphaNoneSkipFirst=%d and kCGImageAlphaPremultipliedFirst=%d, and kCGImageAlphaPremultipliedLast=%d, kCGImageAlphaOnly=%d,kCGImageAlphaNone=%d and scalefactor = 5f",width,height,bitMapInfo,colorSpaceRef,bytesPerRow,bitsPerComponent,kCGImageAlphaNoneSkipLast , kCGBitmapByteOrder32Big, kCGBitmapByteOrder32Big,kCGImageAlphaNoneSkipFirst,kCGImageAlphaPremultipliedFirst,kCGImageAlphaPremultipliedLast,kCGImageAlphaOnly,kCGImageAlphaNone,scaleFactor);
    CGContextRef context = CGBitmapContextCreate(NULL, width, height, bitsPerComponent, width*4, colorSpaceRef, bitMapInfo);
    
    CGColorSpaceRelease(colorSpaceRef);
    
    CGContextDrawImage(context, CGRectMake(0, 0, width, height),imageRef);
    
    unsigned char *bitmapData = (unsigned char *)CGBitmapContextGetData(context);
    NSLog(@"Length of bitmapdata = %ld",strlen((char*)bitmapData));
    
    CGContextRelease(context);
    
    
    NSData* pixelData = (__bridge NSData*) CGDataProviderCopyData(CGImageGetDataProvider(imageRef));
    
    unsigned char* pixelBytes = (unsigned char *) [pixelData bytes];
    NSLog(@"Got pixelbytes and it is %ld long = ",strlen((char *)pixelBytes));
    
    NSLog(@"width=%ld, height: %ld", CGImageGetWidth(imageRef),
          CGImageGetHeight(imageRef) );
    
    
    
    
    for(int y = 0; y < height; y++)
    {
        // get a pointer to the start of this scan line
        unsigned char *linePointer = &pixelBytes[y * width * 4];
        
        // step through the pixels one by one...
        for(int x = 0; x < width; x++)
        {
            //copy out every 4th pixel to ubyte_image_store
            int r, g, b;
            if(linePointer[3])
            {
                r = linePointer[2] * 255 / linePointer[3];
                
                self.ubyte_image_store[y* width+x] = r ;
            }
        }
    }
    
    
    
    
    self.gblurImage = im;
    self.grayImage = im;
    return im;
    
    
}



- (UIImage*) cascadeGPUFilters:(UIImage*) sourceImage:(BOOL) flag
{
    NSLog(@"length of image entering gaussian blur = %lu",[UIImagePNGRepresentation(sourceImage) length]);
    
    GPUImageView *imageView = (GPUImageView *)self.view;
    
    
    
    
    // pass the image through a brightness filter to darken a bit and a gaussianBlur filter to blur
    GPUImagePicture *stillImageSource = [[GPUImagePicture alloc] initWithImage:sourceImage];
    
    
    blurFilter.blurRadiusInPixels = gaussianBlurRadius; //initialized to 1
    blurFilter.blurPasses = 1;
    
    
    blurAdaptiveFilter.blurRadiusInPixels = blurRadius;
    
    
    
    [stillImageSource addTarget:blurFilter];
    
    [blurFilter addTarget:blurAdaptiveFilter];
    [blurAdaptiveFilter addTarget:imageInvertFilter];
    [imageInvertFilter addTarget:grayImageFilter];
    
    
    
    [grayImageFilter useNextFrameForImageCapture];
    [grayImageFilter addTarget:imageView];
    [stillImageSource processImage];
    
    
    UIImage* im = [grayImageFilter imageFromCurrentFramebufferWithOrientation:UIImageOrientationUp];
    
    
    
    
    CGImageRef imageRef = im.CGImage;
    int height   = CGImageGetHeight(imageRef);
    int width   = CGImageGetWidth(imageRef);
    
    int bitsPerComponent = (int)CGImageGetBitsPerComponent(imageRef);
    int bitsPerPixel = 32;
    int bytesPerRow = bitsPerPixel/8*(int)width;
    
    float scaleFactor = [[UIScreen mainScreen] scale];
    
    if (self.ubyte_image_store != NULL) {
        free(self.ubyte_image_store);
    }
    unsigned char *image_store = NULL;
    self.ubyte_image_store = calloc(im.size.width*im.size.height,1);
    
    
    
    
    CGColorSpaceRef colorSpaceRef = CGImageGetColorSpace(imageRef);
    
    
    CGBitmapInfo bitMapInfo = kCGBitmapByteOrder32Big | kCGImageAlphaNoneSkipFirst;
    
    CGColorRenderingIntent renderingIntent = kCGRenderingIntentDefault;
    
    
    NSLog(@"image width = %d, image height=%d, bitmapinfo = %d , colorspace = %@, bytesperrow = %d, bitpercomponent=%d, kCGImageAlphaNoneSkipLast =%d and  kCGBitmapByteOrder32Big %d and kCGBitmapByteOrder32Big = %d, and kCGImageAlphaNoneSkipFirst=%d and kCGImageAlphaPremultipliedFirst=%d, and kCGImageAlphaPremultipliedLast=%d, kCGImageAlphaOnly=%d,kCGImageAlphaNone=%d and scalefactor = 5f",width,height,bitMapInfo,colorSpaceRef,bytesPerRow,bitsPerComponent,kCGImageAlphaNoneSkipLast , kCGBitmapByteOrder32Big, kCGBitmapByteOrder32Big,kCGImageAlphaNoneSkipFirst,kCGImageAlphaPremultipliedFirst,kCGImageAlphaPremultipliedLast,kCGImageAlphaOnly,kCGImageAlphaNone,scaleFactor);
    CGContextRef context = CGBitmapContextCreate(NULL, width, height, bitsPerComponent, width*4, colorSpaceRef, bitMapInfo);
    
    
    CGColorSpaceRelease(colorSpaceRef);
    
    CGContextDrawImage(context, CGRectMake(0, 0, width, height),imageRef);
    
    unsigned char *bitmapData = (unsigned char *)CGBitmapContextGetData(context);
    NSLog(@"Length of bitmapdata = %ld",strlen(bitmapData));
    
    
    CGContextRelease(context);
    
    
    
    NSData* pixelData = (__bridge NSData*) CGDataProviderCopyData(CGImageGetDataProvider(imageRef));
    
    unsigned char* pixelBytes = (unsigned char *) [pixelData bytes];
    NSLog(@"Got pixelbytes and it is %ld long = ",strlen((char *)pixelBytes));
    
    NSLog(@"width=%ld, height: %ld", CGImageGetWidth(imageRef),
          CGImageGetHeight(imageRef) );
    
    
    
    
    for(int y = 0; y < height; y++)
    {
        // get a pointer to the start of this scan line
        unsigned char *linePointer = &pixelBytes[y * width * 4];
        
        // step through the pixels one by one...
        for(int x = 0; x < width; x++)
        {
            //copy out every 4th pixel to ubyte_image_store
            int r, g, b;
            if(linePointer[3])
            {
                r = linePointer[2] * 255 / linePointer[3];
                
                self.ubyte_image_store[y* width+x] = r ;
            }
        }
    }
    
    
    
    
    self.gblurImage = im;
    self.grayImage = im;
    return im;
}

- (UIImage *) grayImage :(UIImage *)inputImage
{
    NSLog(@"length of image entering grayimage = %lu",[UIImagePNGRepresentation(inputImage) length]);
    
    // Create a graphic context.
    UIGraphicsBeginImageContextWithOptions(inputImage.size, NO, 1.0);
    CGRect imageRect = CGRectMake(0, 0, inputImage.size.width, inputImage.size.height);
    
    // Draw the image with the luminosity blend mode.
    // On top of a white background, this will give a black and white image.
    [inputImage drawInRect:imageRect blendMode:kCGBlendModeLuminosity alpha:1.0];
    
    // Get the resulting image.
    UIImage *outputImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    NSLog(@"Size of gray image = width=%f and height = %f",outputImage.size.width,outputImage.size.height);
    NSLog(@"length of image leaving grayimage = %lu",[UIImagePNGRepresentation(outputImage) length]);
    
    return outputImage;
}

- (UIImage *)imageWithGaussianBlur:(UIImage *)image {
    
    NSLog(@"length of image entering gaussian blur = %lu",[UIImagePNGRepresentation(image) length]);
    
    
    // pass the image through a brightness filter to darken a bit and a gaussianBlur filter to blur
    GPUImagePicture *stillImageSource = [[GPUImagePicture alloc] initWithImage:image];
    
    blurFilter.blurRadiusInPixels = gaussianBlurRadius; //initialized to 1
    blurFilter.blurPasses = 1;
    
    [stillImageSource addTarget:blurFilter];
    
    
    
    [blurFilter useNextFrameForImageCapture];
    [stillImageSource processImage];
    UIImage* im = [blurFilter imageFromCurrentFramebufferWithOrientation:UIImageOrientationUp];
    NSLog(@"Size of blur image = width=%f and height = %f",im.size.width,im.size.height);
    NSLog(@"length of image leaving gaussian blur = %lu",[UIImagePNGRepresentation(im) length]);
    
    
    return im;
}



- (void) updateView
{
    CGRect mainScreenFrame = [[UIScreen mainScreen] applicationFrame];
    
    
    NSLog(@"Length of captured image in Filterview= %ld and image width and height = %f and %f",[UIImagePNGRepresentation(self.capturedImage.fullImage) length],self.capturedImage.fullImage.size.width,self.capturedImage.fullImage.size.height);
    
    [self chainGPUFilters:self.capturedImage.fullImage flag:YES];
    
}


-(UIImage *)cachedImageWithBlurAmount:(CGFloat)blur {
    return [blurredImageCache objectForKey:@(blur)];
}



-(void)asyncGenerateImageWithBlurAmount:(CGFloat)blur {
    // This image is already available.
    if([blurredImageCache objectForKey:@(blur)]) {
        [self imageIsAvailableWithBlur:blur];
        return;
    }
    // There's already a render going on for this. Just return.
    if([blurAmountsBeingRendered containsObject:@(blur)])
        return;
    
    // Start a render
    
    [blurAmountsBeingRendered addObject:@(blur)];
    dispatch_async(blurQueue, ^{
        blurRadius = blur ;
        blurAdaptiveFilter.blurRadiusInPixels = blur;
        
        [self chainGPUFilters:self.capturedImage.fullImage flag:YES];
        //after processing and adjusting for slider position, gblurImage is reset
        [blurredImageCache setObject:self.gblurImage forKey:@(blur)];
        
        [blurAmountsBeingRendered removeObject:@(blur)];
        semaphore = dispatch_semaphore_create(0);
        dispatch_async(dispatch_get_main_queue(), ^{
            
            dispatch_semaphore_signal(semaphore);
        });
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    });
    
    
    
    NSLog(@"result stored into blurredimageCache");
}

-(void)imageIsAvailableWithProperThreshold:(CGFloat)threshAmount {
    
    
    [blurAdaptiveFilter useNextFrameForImageCapture];
    [sourcePicture processImage];
    
    UIImage *img = [blurAdaptiveFilter imageFromCurrentFramebufferWithOrientation:UIImageOrientationUp];
    
}

-(void)imageIsAvailableWithBlur:(CGFloat)blurAmount {
    CGFloat smaller = blurRadius - fmodf(blurRadius, BLUR_STEP);
    CGFloat larger = smaller + BLUR_STEP;
    
    UIImage *sharperImage = [self cachedImageWithBlurAmount:smaller];
    UIImage *blurrier = [self cachedImageWithBlurAmount:larger];
    GPUImageView *imageView = (GPUImageView *)self.view;
    
    [blurFilter useNextFrameForImageCapture];
    [sourcePicture processImage];
    
    UIImage *img = [blurFilter imageFromCurrentFramebufferWithOrientation:UIImageOrientationUp];
    if(sharperImage && blurrier) {
        if(![img isEqual:sharperImage])
            img = sharperImage;
        if(![img isEqual:blurrier]) {
            img = blurrier;
        }
        imageView.alpha = (blurRadius - smaller) / BLUR_STEP;
        
    }
}





#pragma mark - Actions
- (void)dismissFilterViewController
{
    [self.delegate dismissFilterViewController:self ];
    
}

- (void)confirmButtonPressed
{
    
    [self emailPhoto: self.gblurImage];
    
    [self savePhotoToCameraRoll];
}



- (void)emailPhoto:(UIImage*) img
{
    NSString *emailTitle = @"FastttCamera Photo";
    NSString *messageBody = @"Check out my FastttCamera photo!";
    
    if ([MFMailComposeViewController canSendMail]) {
        MFMailComposeViewController *mailCompose = [MFMailComposeViewController new];
        mailCompose.mailComposeDelegate = self;
        [mailCompose setSubject:emailTitle];
        [mailCompose setMessageBody:messageBody isHTML:NO];
        [mailCompose addAttachmentData:UIImageJPEGRepresentation(img, 0.85f)
                              mimeType:@"image/jpeg"
                              fileName:@"fast_camera_photo.jpg"];
        
        [self presentViewController:mailCompose animated:YES completion:nil];
    } else {
        UIAlertView *alert =[[UIAlertView alloc] initWithTitle:@"Mail not configured"
                                                       message:@"Cannot share this photo without mail configured."
                                                      delegate:self
                                             cancelButtonTitle:@"OK"
                                             otherButtonTitles:nil];
        [alert show];
    }
}
- (void)savePhotoToCameraRoll
{
    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
    
    [library writeImageToSavedPhotosAlbum:[self.capturedImage.fullImage CGImage]
                              orientation:(ALAssetOrientation)[self.capturedImage.fullImage imageOrientation]
                          completionBlock:^(NSURL *assetURL, NSError *error){
                              if (error) {
                                  NSLog(@"Error saving photo: %@", error.localizedDescription);
                              } else {
                                  NSLog(@"Saved photo to saved photos album.");
                              }
                          }];
}


#pragma mark - MFMailComposeViewControllerDelegate

- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error
{
    [self dismissViewControllerAnimated:YES completion:nil];
    
    [self dismissFilterViewController];
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    [self dismissFilterViewController];
}



- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
 #pragma mark - Navigation
 */

@end
