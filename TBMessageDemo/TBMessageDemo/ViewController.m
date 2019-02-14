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

+ (void)load {
    [RMessage addDesignsFromFileWithName:@"PopMessageDesigns" inBundle:[NSBundle mainBundle]];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    [self showAlert];
    
}

- (void)showAlert {
    
    UIWindow *windowForTip = [[UIApplication sharedApplication] keyWindow];
    if(windowForTip.windowLevel != UIWindowLevelNormal){
        for(UIWindow *window in [UIApplication sharedApplication].windows){
            if(window.hidden == NO && window.windowLevel == UIWindowLevelNormal){
                windowForTip = window;
                break;
            }
        }
    }
    
    // 将RMessageView显示在新的vc上，实现遮罩功能
    UIViewController *messageViewController = [[UIViewController alloc] init];
    if (!messageViewController.view.superview) {
        messageViewController.view.frame = windowForTip.bounds;
        [windowForTip addSubview:messageViewController.view];
    }
    
    [RMessage showNotificationInViewController:messageViewController
                                         title:@"推送"
                                      subtitle:@"推送内容佛挡杀佛是否是的发送到发送到发送到发送到钱塘江南报关单非得更高如果出"
                                     iconImage:[UIImage imageNamed:@"item_abnormal_stock"]
                                          type:RMessageTypeCustom
                                customTypeName:@"pop-message"
                                      duration:3
                                      callback:nil
                                   buttonTitle:@"今日提示一次"
                                buttonCallback:nil
                                    atPosition:RMessagePositionNavBarOverlay
                          canBeDismissedByUser:YES];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self showAlert];
    });
}

@end
