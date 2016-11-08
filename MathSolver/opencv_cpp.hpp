//
//  opencv_cpp.hpp
//  MathSolver
//
//  Created by B Ayres on 10/30/16.
//  Copyright © 2016 PredawnLabs. All rights reserved.
//

#ifndef opencv_cpp_hpp
#define opencv_cpp_hpp

#import <opencv2/opencv.hpp>

#include <iostream>

#ifdef _CH_
#pragma package <opencv>
#endif

#ifndef _EiC

//#include "highgui.h"
//#include "ml.h"
#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>
#endif

using namespace std;
using namespace cv;

class contours_class {
public:
    void extractContours(Mat& image,vector< vector<cv::Point> > contours_poly);
    //vector<vector<cv::Point> > getContours(cv::Mat img) ;
    cv::Mat getContours(cv::Mat img) ;

};


#endif /* opencv_cpp_hpp */


