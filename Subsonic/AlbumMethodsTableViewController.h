//
//  AlbumMethodsTableViewController.h
//  Subsonic
//
//  Created by Erin Rasmussen on 3/22/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface AlbumMethodsTableViewController : UITableViewController{
    NSString *types[5];
    UIActivityIndicatorView *activityIndicator;
}
@property (nonatomic, strong) UIActivityIndicatorView *activityIndicator;

@end
