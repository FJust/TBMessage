//
//  ViewController.m
//  TBMessageDemo
//
//  Created by JustLee on 2019/1/18.
//  Copyright © 2019 JustLee. All rights reserved.
//

#import "ViewController.h"
#import "RMessage.h"
#import "RMessageView.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    [self showAlert];
    
}

- (void)showAlert {
    [RMessage showNotificationInViewController:self
                                         title:@"推送"
                                      subtitle:@"推送内容"
                                     iconImage:nil
                                          type:RMessageTypeCustom
                                customTypeName:@"pop-message"
                                      duration:3
                                      callback:nil
                                   buttonTitle:@"按钮"
                                buttonCallback:nil
                                    atPosition:RMessagePositionNavBarOverlay
                          canBeDismissedByUser:YES];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self showAlert];
    });
}

@end
