
//
//  UIButton+TBAddition.m
//  Stock
//
//  Created by 董恭甫 on 2017/5/16.
//  Copyright © 2017年 com.tigerbrokers. All rights reserved.
//

#import "UIButton+TBAddition.h"

@implementation UIButton (TBAddition)

- (void)relayoutWithType:(TBButtonType)type
{
    [self relayoutWithType:type margin:4];
}

- (void)relayoutWithType:(TBButtonType)type margin:(CGFloat)margin
{
    [self relayoutWithType:type margin:margin state:UIControlStateNormal];
}

- (void)relayoutWithType:(TBButtonType)type margin:(CGFloat)margin state:(UIControlState)state
{
    UIImage *normalImage = [self imageForState:state];
    NSString *normalTitle = [self titleForState:state];
    
    if ((!normalImage || !normalTitle || !self.titleLabel.font) && type != TBButtonTypeDefault) {
        return;
    }
    
    CGSize titleSize = [normalTitle boundingRectWithSize:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX)
                                                 options:NSStringDrawingUsesLineFragmentOrigin
                                              attributes:@{NSFontAttributeName : self.titleLabel.font}
                                                 context:nil].size;
    
    // 矫正label
    // 比如当开始设置button宽度一定，而文字内容过多的时候，会出现文字被挤压，这时候来计算edge偏移的时候会不居中
    // 所以需要来个矫正，主要用于垂直布局的时候
    CGFloat correctLabelWidth = (titleSize.width - self.titleLabel.bounds.size.width) / 2.0;
    
    switch (type) {
        case TBButtonTypeDefault:
        {
            self.titleEdgeInsets = UIEdgeInsetsZero;
            self.imageEdgeInsets = UIEdgeInsetsZero;
        }
            break;
            
        case TBButtonTypeHorizontalImageTitle:
        {
            self.titleEdgeInsets = UIEdgeInsetsMake(0, 0, 0, -1 * margin / 2.0);
            self.imageEdgeInsets = UIEdgeInsetsMake(0, -1 * margin / 2.0, 0, 0);
        }
            break;
            
        case TBButtonTypeHorizontalTitleImage:
        {
            self.titleEdgeInsets = UIEdgeInsetsMake(0, -1 * (normalImage.size.width + margin / 2.0),
                                                    0,       normalImage.size.width + margin / 2.0);
            self.imageEdgeInsets = UIEdgeInsetsMake(0,       titleSize.width + margin / 2.0,
                                                    0, -1 * (titleSize.width + margin / 2.0));
        }
            break;
            
        case TBButtonTypeVerticalImageTitle:
        {
            self.imageEdgeInsets = UIEdgeInsetsMake(-1 * (titleSize.height + margin) / 2.0,
                                                    titleSize.width / 2.0 - correctLabelWidth,
                                                    (titleSize.height + margin) / 2.0,
                                                    -1 *  titleSize.width / 2.0 - correctLabelWidth);
            
            self.titleEdgeInsets = UIEdgeInsetsMake(     (normalImage.size.height + margin) / 2.0,
                                                    -1 *  normalImage.size.width / 2.0 - correctLabelWidth,
                                                    -1 * (normalImage.size.height + margin) / 2.0,
                                                    normalImage.size.width / 2.0 - correctLabelWidth);
        }
            break;
            
        case TBButtonTypeVerticalTitleImage:
        {
            self.titleEdgeInsets = UIEdgeInsetsMake(-1 * (normalImage.size.height + margin) / 2.0,
                                                    -1 *  normalImage.size.width / 2.0 - correctLabelWidth,
                                                    (normalImage.size.height + margin) / 2.0,
                                                    normalImage.size.width / 2.0 - correctLabelWidth);
            
            self.imageEdgeInsets = UIEdgeInsetsMake(     (titleSize.height + margin) / 2.0,
                                                    titleSize.width / 2.0 - correctLabelWidth,
                                                    -1 * (titleSize.height + margin) / 2.0,
                                                    -1 *  titleSize.width / 2.0 - correctLabelWidth);
        }
            break;
            
        default:
            break;
    }
}

- (void)blockEnable
{
    self.enabled = NO;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.enabled = YES;
    });
}


@end
