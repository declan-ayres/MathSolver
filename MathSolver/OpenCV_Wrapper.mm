//
//  OpenCV_Wrapper.mm
//  MathSolver
//
//  Created by D Ayres on 10/29/16.
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


@property (nonatomic) contours_class contours;
@end

@implementation OpenCVWrapperClass

- (UIImage *)getValidContours:(unsigned char*) rawData:(int) width:(int)height {
    self.contours = *(new contours_class);
    cv::Mat img_with_contours_drawn = self.contours.getContours([self cvMatGrayFromUIImage:rawData:width:height]);


    return [self UIImageFromCVMat:(cv::Mat) img_with_contours_drawn];

    
}



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
    
    cv::Mat cvMat(height , width , CV_8UC1,  rawData);

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

