//
//  AppDelegate.h
//  MathSolver
//
//  Created by B Ayres on 10/27/16.
//  Copyright © 2016 PredawnLabs. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>
#import "MathViewController.h"



@interface AppDelegate : UIResponder <UIApplicationDelegate> {
    MathViewController *rootViewController;
}

@property (strong, nonatomic) UIWindow *window;

@property (readonly, strong) NSPersistentContainer *persistentContainer;

- (void)saveContext;


@end

