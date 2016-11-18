//
//  AppDelegate.h
//  MathSolver
//
//  Created by D Ayres on 10/27/16.
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

