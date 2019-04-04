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
#import "UIButton+TBAddition.h"
#import "Masonry.h"

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
    
    UILabel *label = [[UILabel alloc] init];
    label.text = @"";
    [self.view addSubview:label];
    
    
    [label mas_makeConstraints:^(MASConstraintMaker *make) {
        make.leading.equalTo(@50);
        make.top.equalTo(@100);
    }];
    
    UILabel *label1 = [[UILabel alloc] init];
    label1.text = @"xxxxx";
    [self.view addSubview:label1];
    
    [label1 mas_makeConstraints:^(MASConstraintMaker *make) {
        make.leading.equalTo(label);
        make.top.lessThanOrEqualTo(label.mas_bottom);
    }];
    
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
    
    RMessageView *messageView = [[RMessageView alloc] initWithDelegate:[RMessage sharedMessage]
                                                                 title:nil
                                                              subtitle:@"发的说法是的方式豆腐啥的发斯蒂芬退换货iuiuyiz与体育体育涂一涂土洋结合建国门内"
                                                             iconImage:[UIImage imageNamed:@"item_abnormal_stock"]
                                                                  type:RMessageTypeCustom
                                                        customTypeName:@"pop-message"
                                                              duration:4
                                                      inViewController:messageViewController
                                                              callback:nil
                                                  presentingCompletion:nil
                                                     dismissCompletion:nil
                                                           buttonTitle:@""
                                                        buttonCallback:^(UIButton *button) {
                                                            [button setSelected:YES];
                                                            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                                                                [RMessage dismissActiveNotification];
                                                            });
                                                        }
                                                            atPosition:RMessagePositionNavBarOverlay
                                                  canBeDismissedByUser:YES];
    
//    [messageView.button setBackgroundImage:nil forState:UIControlStateNormal];
//    [messageView.button setImage:[UIImage imageNamed:@"icon_stockAlert_select"] forState:UIControlStateNormal];
//    [messageView.button setImage:[UIImage imageNamed:@"icon_stockAlert_selected"] forState:UIControlStateSelected];
//    [messageView.button relayoutWithType:TBButtonTypeHorizontalTitleImage margin:5];
//    [messageView resetButtonWidth];
    [RMessage prepareNotificationForPresentation:messageView];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self showAlert];
    });
}

@end
