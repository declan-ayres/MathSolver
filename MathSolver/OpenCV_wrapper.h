//
//  OpenCV_wrapper.h
//  MathSolver
//
//  Created by D Ayres on 10/30/16.
//  Copyright © 2016 PredawnLabs. All rights reserved.
//

#ifndef OpenCV_wrapper_h
#define OpenCV_wrapper_h

#import <Foundation/Foundation.h>


@interface OpenCVWrapperClass : NSObject
- (UIImage* )getValidContours:(unsigned char*) rawData:(int) width:(int) height;
@end





#endif /* OpenCV_wrapper_h */

