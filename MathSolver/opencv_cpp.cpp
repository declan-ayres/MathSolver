//
//  opencv_cpp.cpp
//  MathSolver
//
//  Created by D Ayres on 10/30/16.
//  Copyright © 2016 PredawnLabs. All rights reserved.
//

#include "opencv_cpp.hpp"


class comparator{
public:
    bool operator()(vector<Point> c1,vector<Point>c2){
        
        return boundingRect( Mat(c1)).x<boundingRect( Mat(c2)).x;
        
    }
    
};

void contours_class::extractContours(Mat& image,vector< vector<Point> > contours_poly){
    
    //Sort contorus by x value going from left to right
    sort(contours_poly.begin(),contours_poly.end(),comparator());
    
    
    //Loop through all contours to extract
    for( int i = 0; i< contours_poly.size(); i++ ){
        
        Rect r = boundingRect( Mat(contours_poly[i]) );
        
        
        Mat mask = Mat::zeros(image.size(), CV_8UC1);
        //Draw mask onto image
        drawContours(mask, contours_poly, i, Scalar(255), CV_FILLED);
        
        //Check for equal sign (2 dashes on top of each other) and merge
        if(i+1<contours_poly.size()){
            Rect r2 = boundingRect( Mat(contours_poly[i+1]) );
            if(abs(r2.x-r.x)<20){
                //Draw mask onto image
                drawContours(mask, contours_poly, i+1, Scalar(255), CV_FILLED);
                i++;
                int minX = min(r.x,r2.x);
                int minY = min(r.y,r2.y);
                int maxX =  max(r.x+r.width,r2.x+r2.width);
                int maxY = max(r.y+r.height,r2.y+r2.height);
                r = Rect(minX,minY,maxX - minX,maxY-minY);
                
            }
        }
        //Copy
        Mat extractPic;
        //Extract the character using the mask
        image.copyTo(extractPic,mask);
        Mat resizedPic = extractPic(r);
        
       
        image=resizedPic.clone();
        
        
        
    }
}


cv::Mat contours_class::getContours(cv::Mat img)
{
    
    
    
    cv::Mat img2 = img.clone();
    
    
    std::vector<cv::Point> points;
    cv::Mat_<uchar>::iterator it = img.begin<uchar>();
    cv::Mat_<uchar>::iterator end = img.end<uchar>();
    for (; it != end; ++it)
        if (*it)
            points.push_back(it.pos());
    
    cv::RotatedRect box = cv::minAreaRect(cv::Mat(points));
    
    double angle = box.angle;
    if (angle < -45.)
        angle += 90.;
    
    cv::Point2f vertices[4];
    box.points(vertices);
    for(int i = 0; i < 4; ++i)
        cv::line(img, vertices[i], vertices[(i + 1) % 4], cv::Scalar(255, 0, 0), 1, CV_AA);
    
    
    
    cv::Mat rot_mat = cv::getRotationMatrix2D(box.center, angle, 1);
    
    cv::Mat rotated;
    cv::warpAffine(img2, rotated, rot_mat, img.size(), cv::INTER_CUBIC);
    
    
    
    cv::Size box_size = box.size;
    if (box.angle < -45.)
        std::swap(box_size.width, box_size.height);
    cv::Mat cropped;
    
    
    cv::getRectSubPix(rotated, box_size, box.center, cropped);
    
    
    Mat cropped2=cropped.clone();
    cvtColor(cropped2,cropped2,CV_GRAY2RGB);
    
    Mat cropped3 = cropped.clone();
    cvtColor(cropped3,cropped3,CV_GRAY2RGB);
    
    vector<vector<cv::Point> > contours;
    vector<Vec4i> hierarchy;
    
    /// Find contours
    
    cv:: findContours( cropped, contours, hierarchy, CV_RETR_EXTERNAL, CV_CHAIN_APPROX_TC89_KCOS,cv::Point(0, 0) );
    
    
    
    /// Approximate contours to polygons + get bounding rects and circles
    vector<vector<cv::Point> > contours_poly( contours.size() );
    vector<Rect> boundRect( contours.size() );
    vector<Point2f>center( contours.size() );
    vector<float>radius( contours.size() );
    
    
    //Get poly contours
    for( int i = 0; i < contours.size(); i++ )
    {
        approxPolyDP( Mat(contours[i]), contours_poly[i], 3, true );
    }
    
    
    //Get only important contours, merge contours that are within another
    vector<vector<cv::Point> > validContours;
    printf("Contours poly size = %ld and number of contours = %ld\n",contours_poly.size(), contours.size());

    for (int i=0;i<contours_poly.size();i++){
        Rect r = boundingRect(Mat(contours_poly[i]));
        if(r.area()<50) {
            printf("Here and continuing because area less than 50\n");
            continue;
        }
        bool inside = false;
        for(int j=0;j<contours_poly.size();j++){
            if(j==i) continue;
            
            Rect r2 = boundingRect(Mat(contours_poly[j]));
            if(r2.area()<100||r2.area()<r.area())continue;
            if(r.x>r2.x&&r.x+r.width<r2.x+r2.width&&
               r.y>r2.y&&r.y+r.height<r2.y+r2.height){
                printf("Here and inside is true because area less than 50\n");

                inside = true;
            }
        }
        if(inside)continue;
        validContours.push_back(contours_poly[i]);
    }
    
    
    //Get bounding rects
    for(int i=0;i<validContours.size();i++){
        boundRect[i] = boundingRect( Mat(validContours[i]) );
    }
    
    
    
    //Display - We will diplay elsewhere in objc cocoa touch code
    
         Scalar color = Scalar(0,255,0);
        for( int i = 0; i< validContours.size(); i++ )
        {
            if(boundRect[i].area()<100)continue;
            drawContours( cropped2, validContours, i, color, 1, 8, vector<Vec4i>(), 0, Point() );
            rectangle( cropped2, boundRect[i].tl(), boundRect[i].br(),color, 2, 8, 0 );
        }
    
    
    
    
    extractContours(cropped3,validContours);
    return cropped3;
    

    
}



