//
//  OpenCV_Wrapper.mm
//  MathSolver
//
//  Created by B Ayres on 10/29/16.
//  Copyright © 2016 PredawnLabs. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <CoreImage/CoreImage.h>

#import "OpenCV_wrapper.h"
#import "opencv_cpp.hpp"
#include "opencv2/opencv.hpp"




@interface OpenCVWrapperClass ()
- (cv::Mat) cvMatFromUIImage:(UIImage*) image;
- (cv::Mat) cvMatGrayFromUIImage:(UIImage*) image;
- (UIImage *) UIImageFromCVMat:(cv::Mat) cvMat;
//@end

//@interface OpenCVWrapperClass ()
@property (nonatomic) contours_class contours;
@end

@implementation OpenCVWrapperClass

//- (UIImage *)getValidContours:(UIImage*) image {
- (UIImage *)getValidContours:(unsigned char*) rawData:(int) width:(int)height {
    self.contours = *(new contours_class);
    //vector<vector<cv::Point>> v = self.contours.getContours([self cvMatGrayFromUIImage:image]);
    cv::Mat img_with_contours_drawn = self.contours.getContours([self cvMatGrayFromUIImage:rawData:width:height]);


   /* NSMutableArray *validContours = [[NSMutableArray alloc] init];
    for (int row=0;row<v.size();row++) {
        int thisvsize = (int) v[row].size();
        for (int col=0;col<thisvsize;col++) {
          [validContours addObject:([NSNumber numberWithFloat:v[row][col].x],[NSNumber numberWithFloat:v[row][col].y])];
        }
    }
    */
    
    return [self UIImageFromCVMat:(cv::Mat) img_with_contours_drawn];
    //NSLog(@"Validcontours = %@",validContours);
    
}


//class opencv_wrapper {
//    cv::Mat cvMatFromUiimage(UIImage* image);
//    cv::Mat cvMatGrayFromUIImage(UIImage *image);
//};

- (cv::Mat) cvMatFromUIImage:(UIImage* )image {
    
        CGColorSpaceRef colorSpace = CGImageGetColorSpace(image.CGImage);
        CGFloat cols = image.size.width;
        CGFloat rows = image.size.height;
        
        cv::Mat cvMat(rows, cols, CV_8UC1); // 8 bits per component, 4 channels (color channels + alpha)
        
        CGContextRef contextRef = CGBitmapContextCreate(cvMat.data,                 // Pointer to  data
                                                        cols,                       // Width of bitmap
                                                        rows,                       // Height of bitmap
                                                        8,                          // Bits per component
                                                        cvMat.step[0],              // Bytes per row
                                                        colorSpace,                 // Colorspace
                                                        kCGImageAlphaNoneSkipLast |
                                                        kCGBitmapByteOrderDefault); // Bitmap info flags
        
        CGContextDrawImage(contextRef, CGRectMake(0, 0, cols, rows), image.CGImage);
        CGContextRelease(contextRef);
        
        return cvMat;
}






- (cv::Mat) cvMatGrayFromUIImage:(unsigned char *) rawData:(int) width:(int)height
{
 /*   CGColorSpaceRef colorSpace = CGImageGetColorSpace(image.CGImage);
   // CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGFloat cols = image.size.width;
    CGFloat rows = image.size.height;
    
    
    cv::Mat cvMat(rows, cols*4, CV_8U); // 8 bits per component, 1 channels
    NSLog(@"Bits per component per row = %zu and color space = %@",CGImageGetBitsPerComponent(image.CGImage),colorSpace);
    CGContextRef contextRef = CGBitmapContextCreate(cvMat.data,                 // Pointer to data
                                                    cols,                       // Width of bitmap
                                                    rows,                       // Height of bitmap
                                                    CGImageGetBitsPerComponent(image.CGImage),  // Bits per component
                                                    cvMat.step[0]*4,              // Bytes per row
                                                    colorSpace,                 // Colorspace
                                                    kCGImageAlphaPremultipliedLast |kCGBitmapByteOrder32Big);
//                                                    kCGBitmapByteOrderDefault); // Bitmap info flags
    
    CGColorSpaceRelease(colorSpace);
    //CGImageRef _imageReference = CGImageCreateCopy(image.CGImage);
    CGDataProviderRef imgDataProvider = CGDataProviderCreateWithCFData((CFDataRef)UIImagePNGRepresentation(image));
    
    CGImageRef imageRef = CGImageCreateWithPNGDataProvider(imgDataProvider, NULL, true, kCGRenderingIntentDefault);
    

    CGContextDrawImage(contextRef, CGRectMake(0, 0, cols, rows), image.CGImage);
    CGContextRelease(contextRef);
    
    UIImageToMat(image,cvMat);
    */
    
    /*
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(image.
                                                      CGImage);
    NSLog(@"Bits per component per row = %zu and color space = %@",CGImageGetBitsPerComponent(image.CGImage),colorSpace);
    
    CGFloat cols = image.size.width, rows = image.size.height;
    CGContextRef contextRef;
    CGBitmapInfo bitmapInfo = kCGImageAlphaPremultipliedLast;
    if (CGColorSpaceGetModel(colorSpace) == 0)
    {
        cv::Mat cvMat(rows, cols, CV_8UC1);
        //8 bits per component, 1 channel
        bitmapInfo = kCGImageAlphaNone;
        //if (!alphaExist)
        //    bitmapInfo = kCGImageAlphaNone;
        contextRef = CGBitmapContextCreate(cvMat.data, cvMat.cols, cvMat.rows,
                                           8,
                                           cvMat.step[0], colorSpace,
                                           bitmapInfo);
        CGContextDrawImage(contextRef, CGRectMake(0, 0, cols, rows),
                           image.CGImage);
        CGContextRelease(contextRef);
        CGColorSpaceRelease(colorSpace);
        return cvMat;
    }
    else
    {
        cv::Mat cvMat(rows, cols, CV_8UC4, Scalar(1,2,3,4)); // 8 bits per component, 4 channels
        //if (!alphaExist)
        size_t bpp = CGImageGetBitsPerComponent(image.CGImage);
        size_t bpr = CGImageGetBytesPerRow(image.CGImage);
        NSLog(@"bpp and bpr = %ld and %ld",bpp,bpr);
        bitmapInfo = kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrderDefault;
        contextRef = CGBitmapContextCreate(cvMat.data, cvMat.cols, cvMat.rows,
                                           CGImageGetBitsPerComponent(image.CGImage),
                                           CGImageGetBytesPerRow(image.CGImage), colorSpace,
                                           bitmapInfo);
        CGContextDrawImage(contextRef, CGRectMake(0, 0, cols, rows),
                           image.CGImage);
        CGContextRelease(contextRef);
        CGColorSpaceRelease(colorSpace);
        
        //cv::Mat gray(cvMat.size(), CV_8UC1);
        //cv::cvtColor( cvMat, gray, CV_BGRA2GRAY );
        
        return cvMat;
    }
     */
    
    cv::Mat cvMat(height , width , CV_8UC1,  rawData);//, Mat::AUTO_STEP);
   // cv::Mat cvMat = cv::imdecode(Mat(1, (int)[rawData length], CV_8UC1, (void*)rawData.bytes), CV_LOAD_IMAGE_UNCHANGED);

    return cvMat;
}

- (UIImage *) UIImageFromCVMat:(cv::Mat) cvMat
{
    NSData *data = [NSData dataWithBytes:cvMat.data length:cvMat.elemSize()*cvMat.total()];
    CGColorSpaceRef colorSpace;
    
    if (cvMat.elemSize() == 1) {
        colorSpace = CGColorSpaceCreateDeviceGray();
    } else {
        colorSpace = CGColorSpaceCreateDeviceRGB();
    }
    
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    
    // Creating CGImage from cv::Mat
    CGImageRef imageRef = CGImageCreate(cvMat.cols,                                 //width
                                        cvMat.rows,                                 //height
                                        8,                                          //bits per component
                                        8 * cvMat.elemSize(),                       //bits per pixel
                                        cvMat.step[0],                            //bytesPerRow
                                        colorSpace,                                 //colorspace
                                        kCGImageAlphaNone|kCGBitmapByteOrderDefault,// bitmap info
                                        provider,                                   //CGDataProviderRef
                                        NULL,                                       //decode
                                        false,                                      //should interpolate
                                        kCGRenderingIntentDefault                   //intent
                                        );
    
    
    // Getting UIImage from CGImage
    UIImage *finalImage = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);
    
    return finalImage;
}

@end

