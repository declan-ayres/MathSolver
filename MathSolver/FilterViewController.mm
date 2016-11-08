//
//  FilterViewController.m
//  MathSolver
//
//  Created by B Ayres on 10/28/16.
//  Copyright © 2016 PredawnLabs. All rights reserved.
//

#import "FilterViewController.h"
#import <CoreImage/CoreImage.h>
#import "OpenCV_Wrapper.h"




@implementation UIImage (NegativeImage)

- (UIImage *)negativeImage
{
    // get width and height as integers, since we'll be using them as
    // array subscripts, etc, and this'll save a whole lot of casting
    CGSize size = self.size;
    int width = size.width;
    int height = size.height;
    
    // Create a suitable RGB+alpha bitmap context in BGRA colour space
    CGColorSpaceRef colourSpace = CGImageGetColorSpace(self.CGImage);
    NSLog(@"Color space = %@",colourSpace);
    NSLog(@"Image width and height = %d and %d and length of image as received in neg image = %lu",width,height,[UIImagePNGRepresentation(self) length]);
    //CGColorSpaceCreateDeviceRGB();
    unsigned char *memoryPool = (unsigned char *)calloc(width*height*4, 1);
    CGContextRef context = CGBitmapContextCreate(memoryPool, width, height, 8, width * 4, colourSpace, kCGBitmapByteOrder32Big | kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(colourSpace);
    
    // draw the current image to the newly created context
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), [self CGImage]);
    // run through every pixel, a scan line at a time...
    for(int y = 0; y < height; y++)
    {
        // get a pointer to the start of this scan line
        unsigned char *linePointer = &memoryPool[y * width * 4];
        
        // step through the pixels one by one...
        for(int x = 0; x < width; x++)
        {
            // get RGB values. We're dealing with premultiplied alpha
            // here, so we need to divide by the alpha channel (if it
            // isn't zero, of course) to get uninflected RGB. We
            // multiply by 255 to keep precision while still using
            // integers
            int r, g, b;
            if(linePointer[3])
            {
                r = linePointer[0] * 255 / linePointer[3];
                g = linePointer[1] * 255 / linePointer[3];
                b = linePointer[2] * 255 / linePointer[3];
            }
            else
                r = g = b = 0;
            
            // perform the colour inversion
            r = 255 - r;
            g = 255 - g;
            b = 255 - b;
            
            // multiply by alpha again, divide by 255 to undo the
            // scaling before, store the new values and advance
            // the pointer we're reading pixel data from
            linePointer[0] = r * linePointer[3] / 255;
            linePointer[1] = g * linePointer[3] / 255;
            linePointer[2] = b * linePointer[3] / 255;
            linePointer += 4;
        }
    }
    
    // get a CG image from the context, wrap that into a
    // UIImage
    CGImageRef cgImage = CGBitmapContextCreateImage(context);
    UIImage *returnImage = [UIImage imageWithCGImage:cgImage];
    NSLog(@"Length of negative image = %ld and image width and height = %f and %f",[UIImagePNGRepresentation(returnImage) length],returnImage.size.width,returnImage.size.height);
    
    // clean up
    CGImageRelease(cgImage);
    CGContextRelease(context);
    free(memoryPool);
    
    // and return
    return returnImage;
}

@end

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
    
    //if (!self.capturedImage.isNormalized) {
    //    confirmButton.enabled = NO;
    //}
    
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
    //[imageSlider addTarget:self action:@selector(updateSliderValue:) forControlEvents:UIControlEventValueChanged];
    [imageSlider addTarget:self action:@selector(sliderDidMove:) forControlEvents:UIControlEventValueChanged];
    
    imageSlider.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    imageSlider.minimumValue = 0.0;
    imageSlider.maximumValue = 3.0;
    imageSlider.value = 0.5;
    [imageSlider setContinuous: NO];

    [primaryView addSubview:imageSlider];
    
    self.ocv_wrapper = [[OpenCVWrapperClass alloc] init];
    
    
    [self updateView];
//    [self setupDisplayFiltering];
    //[self setupImageResampling];
    //[self setupImageFilteringToDisk];
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
    //CGFloat smaller = blurRadius - fmodf(blurRadius, BLUR_STEP);
    //[self asyncGenerateImageWithBlurAmount:smaller];
    //CGFloat larger = smaller + BLUR_STEP;
    //[self asyncGenerateImageWithBlurAmount:larger];
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
        //outputBytes = (GLubyte *)malloc(width * height * 4);
        
        int bitsPerComponent = (int)CGImageGetBitsPerComponent(imageRef);
        int bitsPerPixel = 32;
        int bytesPerRow = bitsPerPixel/8*(int)width;
        
        float scaleFactor = [[UIScreen mainScreen] scale];
        
        if (self.ubyte_image_store != NULL) {
            free(self.ubyte_image_store);
        }
        //unsigned char *image_store = NULL; //calloc(im.size.width*im.size.height*4,1) ;
        self.ubyte_image_store = malloc((int)im.size.width*(int)im.size.height); //,1);
    
        if (strlen((char*)self.ubyte_image_store) == 0) {
          NSLog(@"Couldn't allocate memory for ubyte_image_store ?!...was trying to allocate %f bytes of memory",im.size.width*im.size.height);
        }
        CGColorSpaceRef colorSpaceRef = CGImageGetColorSpace(imageRef);
        
        CGBitmapInfo bitMapInfo = kCGBitmapByteOrder32Big | kCGImageAlphaNoneSkipFirst;
        //CGColorRenderingIntent renderingIntent = kCGRenderingIntentDefault;
        
        
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
                    //                g = linePointer[1] * 255 / linePointer[3];
                    //                b = linePointer[0] * 255 / linePointer[3];
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
    
    
   
    //[blurFilter addTarget:imageView];//what's this , is this in the right place, but it works !

   /* UIImage* grayIm ;
    
    if (flag) {
        grayIm = [self grayImage:sourceImage];
    }else {
        grayIm = sourceImage;
    }
    */
    // pass the image through a brightness filter to darken a bit and a gaussianBlur filter to blur
    GPUImagePicture *stillImageSource = [[GPUImagePicture alloc] initWithImage:sourceImage];
    
    
    blurFilter.blurRadiusInPixels = gaussianBlurRadius; //initialized to 1
    blurFilter.blurPasses = 1;
    //[blurFilter addTarget:stillImageSource];
    //[stillImageSource addTarget:blurFilter];
    
    blurAdaptiveFilter.blurRadiusInPixels = blurRadius;
   // [blurFilter addTarget:blurAdaptiveFilter];
    
   // [blurFilter addTarget:imageInvertFilter];
   // [stillImageSource addTarget:grayImageFilter];
    
    
    [stillImageSource addTarget:blurFilter];
   // [grayImageFilter addTarget:blurFilter];
//    [stillImageSource addTarget:blurFilter];
    [blurFilter addTarget:blurAdaptiveFilter];
    [blurAdaptiveFilter addTarget:imageInvertFilter];
    [imageInvertFilter addTarget:grayImageFilter];
  
//    opacityFilter.opacity = 0;
//    [imageInvertFilter addTarget:opacityFilter];
    
//    [opacityFilter addTarget:imageView];
    //[monoFilter addTarget:imageView];
   
    
    /* everything rawdataOutput related -- not in use
    //rawdataoutput
    [grayImageFilter addTarget:rawDataOutput];
    
    __unsafe_unretained GPUImageRawDataOutput * weakOutput = rawDataOutput;
    [rawDataOutput setNewFrameAvailableBlock:^{
        [weakOutput lockFramebufferForReading];
        outputBytes = [weakOutput rawBytesForImage];
        bytesPerRow = [weakOutput bytesPerRowInOutput];
        self.rawData = [NSData dataWithBytes:outputBytes length:sourceImage.size.height*bytesPerRow];
        NSLog(@"Bytes per row: %ld", (unsigned long)bytesPerRow);
        for (unsigned int yIndex = 0; yIndex < 10; yIndex++)
        {
            for (unsigned int xIndex = 0; xIndex < 10; xIndex++)
            {
                NSLog(@"Byte at (%d, %d): %d, %d, %d, %d", xIndex, yIndex, outputBytes[yIndex * bytesPerRow + xIndex * 4], outputBytes[yIndex * bytesPerRow + xIndex * 4 + 1], outputBytes[yIndex * bytesPerRow + xIndex * 4 + 2], outputBytes[yIndex * bytesPerRow + xIndex * 4 + 3]);
            }
        }
        [weakOutput unlockFramebufferAfterReading];
    }];
    
    */
    
    //[imageInvertFilter addTarget:imageView];
    //[imageInvertFilter useNextFrameForImageCapture];
   // [grayImageFilter addTarget:imageView];
    
//    [opacityFilter useNextFrameForImageCapture];
    
    //[monoFilter useNextFrameForImageCapture];
    
    [grayImageFilter useNextFrameForImageCapture];
    [grayImageFilter addTarget:imageView];
    [stillImageSource processImage];
    //UIImage* im = [imageInvertFilter imageFromCurrentFramebufferWithOrientation:UIImageOrientationUp];
    
    UIImage* im = [grayImageFilter imageFromCurrentFramebufferWithOrientation:UIImageOrientationUp];
    
    //UIImage* im = [monoFilter imageFromCurrentFramebufferWithOrientation:UIImageOrientationUp];
    //UIImage* im = [opacityFilter imageFromCurrentFramebufferWithOrientation:UIImageOrientationUp];
    
    //UIImage* im = [opacityFilter imageByFilteringImage:grayIm];
    
   // NSLog(@"Size of blur image = width=%f and height = %f",im.size.width,im.size.height);
   // NSLog(@"length of image leaving gaussian blur = %lu",[UIImagePNGRepresentation(im) length]);
    
    //postprocess gray image stripping 1,2,3 pixels from each RGBA keeping only the 4th pixel, and stuffing the 4th into an UByte array. This is the equivalent of cvtColor 8UC1
    
    
    
    
    
    CGImageRef imageRef = im.CGImage;
    int height   = CGImageGetHeight(imageRef);
    int width   = CGImageGetWidth(imageRef);
    //outputBytes = (GLubyte *)malloc(width * height * 4);
    
    int bitsPerComponent = (int)CGImageGetBitsPerComponent(imageRef);
    int bitsPerPixel = 32;
    int bytesPerRow = bitsPerPixel/8*(int)width;
    
    float scaleFactor = [[UIScreen mainScreen] scale];
    
    if (self.ubyte_image_store != NULL) {
        free(self.ubyte_image_store);
    }
    unsigned char *image_store = NULL; //calloc(im.size.width*im.size.height*4,1) ;
    self.ubyte_image_store = calloc(im.size.width*im.size.height,1);
    //memset(image_store,'\0',(im.size.width*im.size.height*4));
    
    
    //CGColorSpaceRef colorSpaceRef = CGColorSpaceCreateDeviceRGB();
    CGColorSpaceRef colorSpaceRef = CGImageGetColorSpace(imageRef);
    
    //CGBitmapInfo bitMapInfo = CGImageGetBitmapInfo(imageRef);
    CGBitmapInfo bitMapInfo = kCGBitmapByteOrder32Big | kCGImageAlphaNoneSkipFirst;
//    CGBitmapInfo bitMapInfo  = kCGImageAlphaPremultipliedFirst ;
    CGColorRenderingIntent renderingIntent = kCGRenderingIntentDefault;
    
    
    NSLog(@"image width = %d, image height=%d, bitmapinfo = %d , colorspace = %@, bytesperrow = %d, bitpercomponent=%d, kCGImageAlphaNoneSkipLast =%d and  kCGBitmapByteOrder32Big %d and kCGBitmapByteOrder32Big = %d, and kCGImageAlphaNoneSkipFirst=%d and kCGImageAlphaPremultipliedFirst=%d, and kCGImageAlphaPremultipliedLast=%d, kCGImageAlphaOnly=%d,kCGImageAlphaNone=%d and scalefactor = 5f",width,height,bitMapInfo,colorSpaceRef,bytesPerRow,bitsPerComponent,kCGImageAlphaNoneSkipLast , kCGBitmapByteOrder32Big, kCGBitmapByteOrder32Big,kCGImageAlphaNoneSkipFirst,kCGImageAlphaPremultipliedFirst,kCGImageAlphaPremultipliedLast,kCGImageAlphaOnly,kCGImageAlphaNone,scaleFactor);
    CGContextRef context = CGBitmapContextCreate(NULL, width, height, bitsPerComponent, width*4, colorSpaceRef, bitMapInfo);
    //CGContextRef context = CGBitmapContextCreate(NULL, width,
    //                                             height,
    //                                            bitsPerComponent,
    //                                            0,
    //                                           CGImageGetColorSpace(imageRef),
    //                                           kCGBitmapByteOrderDefault | kCGImageAlphaPremultipliedFirst);
    
    CGColorSpaceRelease(colorSpaceRef);
    
    CGContextDrawImage(context, CGRectMake(0, 0, width, height),imageRef);
    
    unsigned char *bitmapData = (unsigned char *)CGBitmapContextGetData(context);
    NSLog(@"Length of bitmapdata = %ld",strlen(bitmapData));
    
    //CGImageRef tmpThumbImage = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    //im = [UIImage imageWithCGImage:tmpThumbImage];
    //CGImageRelease(tmpThumbImage);
    

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
//                g = linePointer[1] * 255 / linePointer[3];
//                b = linePointer[0] * 255 / linePointer[3];
                self.ubyte_image_store[y* width+x] = r ;
            }
        }
    }

    
    
    
    self.gblurImage = im;
    self.grayImage = im;
    return im;
}
- (UIImage *) doBinarize:(UIImage *)sourceImage:(BOOL) flag
{
    //first off, try to grayscale the image using iOS core Image routine
    //we did grayscaling already, and also smoothed the image with a GuassianBlur, now binarize it
    //UIImage * grayScaledImg = [self grayImage:sourceImage];
    
    NSLog(@"length of image as received in doBinarize = %lu",[UIImagePNGRepresentation(sourceImage) length]);
    sourcePicture = [[GPUImagePicture alloc] initWithImage:sourceImage];
    //GPUImageAdaptiveThresholdFilter *stillImageFilter = [[GPUImageAdaptiveThresholdFilter alloc] init];
    blurAdaptiveFilter.blurRadiusInPixels = blurRadius;
    //    stillImageFilter.blurSize = 8.0;
    
    GPUImageView *imageView = (GPUImageView *)self.view;
    [blurAdaptiveFilter addTarget:imageView];//what's this , is this in the right place, but it works !
    
    [blurAdaptiveFilter useNextFrameForImageCapture];
    [sourcePicture addTarget:blurAdaptiveFilter];
    [sourcePicture processImage];
    
    //UIImage *retImage = [stillImageFilter imageFromCurrentlyProcessedOutput];
    UIImage *retImage = [blurAdaptiveFilter imageFromCurrentFramebufferWithOrientation:UIImageOrientationUp];
    if (flag) {
        return retImage ;
    }
    UIImage *negImage = [retImage negativeImage];
    
   // [blurAdaptiveFilter imageByFilteringImage:negImage];
    sourcePicture = [[GPUImagePicture alloc] initWithImage:negImage];
    [sourcePicture addTarget:(GPUImageView *) self.view];
   // [blurAdaptiveFilter useNextFrameForImageCapture];
   // [sourcePicture addTarget:blurAdaptiveFilter];
    [sourcePicture processImage];
   // retImage = [blurAdaptiveFilter imageFromCurrentFramebufferWithOrientation:UIImageOrientationUp];
    
//    [imageSource addTarget:blurAdaptiveFilter];
    NSLog(@"length of image leaving doBinarize = %lu",[UIImagePNGRepresentation(negImage) length]);
    
    return negImage;
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
    //[blurFilter addTarget:stillImageSource];
    [stillImageSource addTarget:blurFilter];
    
   // GPUImageBrightnessFilter *brightnessFilter = [[GPUImageBrightnessFilter alloc] init];
    //[brightnessFilter setBrightness:-0.15f];
    
    //[blurFilter addTarget:brightnessFilter];
    
    //GPUImageView *imageView = (GPUImageView *)self.view;
    
    //[blurFilter addTarget:imageView];//what's this , is this in the right place, but it works !
    
    [blurFilter useNextFrameForImageCapture];
    [stillImageSource processImage];
    //    return [brightnessFilter imageFromCurrentlyProcessedOutputWithOrientation:UIImageOrientationUp];
    UIImage* im = [blurFilter imageFromCurrentFramebufferWithOrientation:UIImageOrientationUp];
    NSLog(@"Size of blur image = width=%f and height = %f",im.size.width,im.size.height);
    NSLog(@"length of image leaving gaussian blur = %lu",[UIImagePNGRepresentation(im) length]);
    
    
    return im;
}

- (void) processGrayImage:(UIImage*) grayScaledImg {
    
    //guassianblur the image i.e. smooth it out
    UIImage *blurImage = [self imageWithGaussianBlur:grayScaledImg];
    
    //finally binarize the grayscale, smoothed image
    UIImage *binarizedImage = [self doBinarize:blurImage:NO];
    // we are doing negativeImage as part of binarized image
    //UIImage *my_negativeImage = [binarizedImage negativeImage];
    //UIImage *my_negativeImage = [binarizedImage negativeImage];
    self.gblurImage = binarizedImage;
}

- (void) processImage:(UIImage*) img {
    // gray scale the image
    //UIImage *my_negativeImage ;
        UIImage * grayScaledImg = [self grayImage:img];
            
            
        //guassianblur the image i.e. smooth it out
        UIImage *blurImage = [self imageWithGaussianBlur:grayScaledImg];
            
        //finally binarize the grayscale, smoothed image
        blurRadius = 8.0 ;
        UIImage *binarizedImage = [self doBinarize:blurImage:YES];
    

        // we are doing negativeImage as part of binarized image
        UIImage *my_negativeImage = [binarizedImage negativeImage];
            
        sourcePicture = [[GPUImagePicture alloc] initWithImage:my_negativeImage];
    
    
    
        self.gblurImage = my_negativeImage;
        self.grayImage = grayScaledImg ;
    
        NSLog(@"Length of blur image = %ld and image width and height = %f and %f",[UIImagePNGRepresentation(self.gblurImage) length],self.gblurImage.size.width,self.gblurImage.size.height);
            
//    UIImage *my_negativeImage = [binarizedImage negativeImage];
//    sourcePicture = [[GPUImagePicture alloc] initWithImage:my_negativeImage];
    
    
    //and now resample the image applying brightness filter - commented because the image quality is not affected by the brightness filter...instead we process the binarized image directly
    
   // GPUImageBrightnessFilter *passthroughFilter = [[GPUImageBrightnessFilter alloc] init];
//    [passthroughFilter forceProcessingAtSize:CGSizeMake(640.0, 480.0)];
   // [passthroughFilter forceProcessingAtSize:binarizedImage.size];
   // [sourcePicture addTarget:passthroughFilter];
   // [passthroughFilter useNextFrameForImageCapture];
    

    
    
    
    // gblurImage = binarizedImage ;
    //must add target view to show new image without filter
    [sourcePicture addTarget:(GPUImageView *) self.view];
    [sourcePicture processImage];
    
}

- (void) updateView
{
    CGRect mainScreenFrame = [[UIScreen mainScreen] applicationFrame];
    
    //NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    
    //NSString *documentsDirectory = [paths objectAtIndex:0];
    //NSString *filePath = [documentsDirectory stringByAppendingPathComponent:@"Lambeau-filtered1.png"];
    
    //UIImage * inputImage = [UIImage imageWithData: UIImagePNGRepresentation(self.capturedImage.fullImage )];
    
    NSLog(@"Length of captured image in Filterview= %ld and image width and height = %f and %f",[UIImagePNGRepresentation(self.capturedImage.fullImage) length],self.capturedImage.fullImage.size.width,self.capturedImage.fullImage.size.height);
    
    //[self cascadeGPUFilters:self.capturedImage.fullImage :YES];
    [self chainGPUFilters:self.capturedImage.fullImage flag:YES];
    UIImage* tImg =[self.ocv_wrapper getValidContours:self.ubyte_image_store:self.gblurImage.size.width:self.gblurImage.size.height];
    self.gblurImage = tImg ; //self.gblurImage;
    
    // [self processImage:self.capturedImage.fullImage];
    
    //use the negativeImage we got after binarizing and notting and extract contours
    
    //UIImage* tImg = [self.ocv_wrapper getValidContours:self.gblurImage];
    //self.gblurImage = tImg;
    
    //sepiaFilter = [[GPUImageTiltShiftFilter alloc] init];
    //    sepiaFilter = [[GPUImageSobelEdgeDetectionFilter alloc] init];
    
    //GPUImageView *imageView = (GPUImageView *)self.view;
    //    [sepiaFilter forceProcessingAtSize:imageView.sizeInPixels]; // This is now needed to make the filter run at the smaller output size
    //[sepiaFilter forceProcessingAtSize:CGSizeMake(mainScreenFrame.size.width, mainScreenFrame.size.height-90)];
    //[blurFilter forceProcessingAtSize:CGSizeMake(mainScreenFrame.size.width, mainScreenFrame.size.height-90)];
    
    
    //[sourcePicture addTarget:blurFilter];
    //[sepiaFilter addTarget:imageView];
    
    //[sourcePicture processImage];
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
        //[self processGrayImage:(UIImage*) self.grayImage ];
        //[self cascadeGPUFilters:self.capturedImage.fullImage:NO];
        [self chainGPUFilters:self.capturedImage.fullImage flag:YES];
        //after processing and adjusting for slider position, gblurImage is reset
        [blurredImageCache setObject:self.gblurImage forKey:@(blur)];
        //UIImage *result = [blurAdaptiveFilter imageByFilteringImage:self.gblurImage];
        [blurAmountsBeingRendered removeObject:@(blur)];
        semaphore = dispatch_semaphore_create(0);
        dispatch_async(dispatch_get_main_queue(), ^{
          //  [self imageIsAvailableWithProperThreshold:blur];
            dispatch_semaphore_signal(semaphore);
        });
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
        //   [self imageIsAvailableWithBlur:blurFilter.blurRadiusInPixels];
    });
    
    
    
    NSLog(@"result stored into blurredimageCache");
}

-(void)imageIsAvailableWithProperThreshold:(CGFloat)threshAmount {
    /// CGFloat larger = smaller + BLUR_STEP;
    
    //UIImage *sharperImage = [self cachedImageWithBlurAmount:threshAmount];
    //GPUImageView *imageView = (GPUImageView *)self.view;
    
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
      //  [blurFilter imageByFilteringImage:img];
    }
}




- (void)setupDisplayFiltering;
{
//    UIImage *inputImage = [UIImage imageNamed:@"WID-small.jpg"]; // The WID.jpg example is greater than 2048 pixels tall, so it fails on older devices
    UIImage * inputImage = [UIImage imageWithData: UIImagePNGRepresentation(self.capturedImage.fullImage )];
    CGRect mainScreenFrame = [[UIScreen mainScreen] applicationFrame];
    
    
    sourcePicture = [[GPUImagePicture alloc] initWithImage:inputImage smoothlyScaleOutput:YES];
    sepiaFilter = [[GPUImageTiltShiftFilter alloc] init];
    //    sepiaFilter = [[GPUImageSobelEdgeDetectionFilter alloc] init];
    
    GPUImageView *imageView = (GPUImageView *)self.view;
    //[sepiaFilter forceProcessingAtSize:imageView.sizeInPixels]; // This is now needed to make the filter run at the smaller output size
    [sepiaFilter forceProcessingAtSize:CGSizeMake(mainScreenFrame.size.width, mainScreenFrame.size.height-90)];
    [sourcePicture addTarget:sepiaFilter];
    [sepiaFilter addTarget:imageView];
    
    [sourcePicture processImage];
    
}

- (void)setupImageFilteringToDisk;
{
    // Set up a manual image filtering chain
    NSURL *inputImageURL = [[NSBundle mainBundle] URLForResource:@"Lambeau" withExtension:@"jpg"];
    
    //    GPUImagePicture *stillImageSource = [[GPUImagePicture alloc] initWithImage:inputImage];
    GPUImagePicture *stillImageSource = [[GPUImagePicture alloc] initWithURL:inputImageURL];
    
    GPUImageSepiaFilter *stillImageFilter = [[GPUImageSepiaFilter alloc] init];
    GPUImageVignetteFilter *vignetteImageFilter = [[GPUImageVignetteFilter alloc] init];
    vignetteImageFilter.vignetteEnd = 0.6;
    vignetteImageFilter.vignetteStart = 0.4;
    
    [stillImageSource addTarget:stillImageFilter];
    [stillImageFilter addTarget:vignetteImageFilter];
    
    [vignetteImageFilter useNextFrameForImageCapture];
    [stillImageSource processImage];
    
    NSError *error = nil;
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    
    @autoreleasepool {
        UIImage *currentFilteredImage = [vignetteImageFilter imageFromCurrentFramebuffer];
        
        NSData *dataForPNGFile = UIImagePNGRepresentation(currentFilteredImage);
        if (![dataForPNGFile writeToFile:[documentsDirectory stringByAppendingPathComponent:@"Lambeau-filtered1.png"] options:NSAtomicWrite error:&error])
        {
            NSLog(@"Error: Couldn't save image 1");
        }
        dataForPNGFile = nil;
        currentFilteredImage = nil;
    }
    
    // Do a simpler image filtering
    //    GPUImageSketchFilter *stillImageFilter2 = [[GPUImageSketchFilter alloc] init];
    //    GPUImageSobelEdgeDetectionFilter *stillImageFilter2 = [[GPUImageSobelEdgeDetectionFilter alloc] init];
    //    GPUImageAmatorkaFilter *stillImageFilter2 = [[GPUImageAmatorkaFilter alloc] init];
    //    GPUImageUnsharpMaskFilter *stillImageFilter2 = [[GPUImageUnsharpMaskFilter alloc] init];
    GPUImageSepiaFilter *stillImageFilter2 = [[GPUImageSepiaFilter alloc] init];
    NSLog(@"Second image filtering");
    UIImage *inputImage = [UIImage imageNamed:@"Lambeau.jpg"];
    UIImage *quickFilteredImage = [stillImageFilter2 imageByFilteringImage:inputImage];
    
    // Write images to disk, as proof
    NSData *dataForPNGFile2 = UIImagePNGRepresentation(quickFilteredImage);
    
    if (![dataForPNGFile2 writeToFile:[documentsDirectory stringByAppendingPathComponent:@"Lambeau-filtered2.png"] options:NSAtomicWrite error:&error])
    {
        NSLog(@"Error: Couldn't save image 2");
    }
}

// resampling is a mathematical technique used to upsample (increase the size of the image) or downsample (decrease the size of the image)
- (void)setupImageResampling;
{
    UIImage *inputImage = [UIImage imageNamed:@"Lambeau.jpg"];
    GPUImagePicture *stillImageSource = [[GPUImagePicture alloc] initWithImage:inputImage];
    
    // Linear downsampling
    GPUImageBrightnessFilter *passthroughFilter = [[GPUImageBrightnessFilter alloc] init];
    [passthroughFilter forceProcessingAtSize:CGSizeMake(640.0, 480.0)];
    [stillImageSource addTarget:passthroughFilter];
    [passthroughFilter useNextFrameForImageCapture];
    [stillImageSource processImage];
    UIImage *nearestNeighborImage = [passthroughFilter imageFromCurrentFramebuffer];
    
    // Lanczos downsampling
    [stillImageSource removeAllTargets];
    GPUImageLanczosResamplingFilter *lanczosResamplingFilter = [[GPUImageLanczosResamplingFilter alloc] init];
    [lanczosResamplingFilter forceProcessingAtSize:CGSizeMake(640.0, 480.0)];
    [stillImageSource addTarget:lanczosResamplingFilter];
    [lanczosResamplingFilter useNextFrameForImageCapture];
    [stillImageSource processImage];
    UIImage *lanczosImage = [lanczosResamplingFilter imageFromCurrentFramebuffer];
    
    // Trilinear downsampling
    GPUImagePicture *stillImageSource2 = [[GPUImagePicture alloc] initWithImage:inputImage smoothlyScaleOutput:YES];
    GPUImageBrightnessFilter *passthroughFilter2 = [[GPUImageBrightnessFilter alloc] init];
    [passthroughFilter2 forceProcessingAtSize:CGSizeMake(640.0, 480.0)];
    [stillImageSource2 addTarget:passthroughFilter2];
    [passthroughFilter2 useNextFrameForImageCapture];
    [stillImageSource2 processImage];
    UIImage *trilinearImage = [passthroughFilter2 imageFromCurrentFramebuffer];
    
    NSData *dataForPNGFile1 = UIImagePNGRepresentation(nearestNeighborImage);
    NSData *dataForPNGFile2 = UIImagePNGRepresentation(lanczosImage);
    NSData *dataForPNGFile3 = UIImagePNGRepresentation(trilinearImage);
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    
    NSError *error = nil;
    if (![dataForPNGFile1 writeToFile:[documentsDirectory stringByAppendingPathComponent:@"Lambeau-Resized-NN.png"] options:NSAtomicWrite error:&error])
    {
        return;
    }
    
    if (![dataForPNGFile2 writeToFile:[documentsDirectory stringByAppendingPathComponent:@"Lambeau-Resized-Lanczos.png"] options:NSAtomicWrite error:&error])
    {
        return;
    }
    
    if (![dataForPNGFile3 writeToFile:[documentsDirectory stringByAppendingPathComponent:@"Lambeau-Resized-Trilinear.png"] options:NSAtomicWrite error:&error])
    {
        return;
    }
}



#pragma mark - Actions
- (void)dismissFilterViewController
{
    [self.delegate dismissFilterViewController:self ];
                                                
    //filterViewController = nil;
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

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end

