//
//  RMessageView.m
//  RMessage
//
//  Created by Adonis Peralta on 12/7/15.
//  Copyright © 2015 Adonis Peralta. All rights reserved.
//

#import "RMessageView.h"
#import "HexColors.h"
#import "UIViewController+PPTopMostController.h"

static NSString *const RDesignFileName = @"RMessageDefaultDesign";

/** Animation constants */
static double const kRMessageAnimationDuration = 0.3f;
static double const kRMessageDisplayTime = 1.5f;
static double const kRMessageExtraDisplayTimePerPixel = 0.04f;

/** Contains the global design dictionary specified in the entire design RDesignFile */
static NSMutableDictionary *globalDesignDictionary;

@interface RMessageView () <UIGestureRecognizerDelegate>

/** 标题和副标题 */
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIView *textContainerView;

@property (nonatomic, strong) NSLayoutConstraint *titleSubtitleContainerViewLayoutGuideConstraint;

@property (nonatomic, strong) UIImageView *iconImageView;
@property (nonatomic, strong) UIImageView *backgroundImageView;

@property (nonatomic, strong) UIImage *iconImage;

/** Contains the appropriate design dictionary for the specified message view type */
@property (nonatomic, strong) NSDictionary *designDictionary;

/** The displayed title of this message */
@property (nonatomic, strong) NSString *title;

/** The displayed subtitle of this message view */
@property (nonatomic, strong) NSString *subtitle;

@property (nonatomic, strong) UIButton *button;

@property (nonatomic, strong) NSLayoutConstraint *buttonViewWidthConstraint;

/** The title of the added button */
@property (nonatomic, strong) NSString *buttonTitle;

/** The view controller this message is displayed in */
@property (nonatomic, strong) UIViewController *viewController;

/** The vertical space between the message view top to its view controller top */
@property (nonatomic, strong) NSLayoutConstraint *topToVCLayoutConstraint;

/** Callback block called after the user taps on the messageView */
@property (nonatomic, copy) void (^callback)(void);

@property (nonatomic, copy) void(^buttonCallback)(UIButton *button);

/** Callback block called after the messageView finishes presenting */
@property (nonatomic, copy) void (^presentingCompletionCallback)(void);

/** Callback block called after the messageView finishes dismissing */
@property (nonatomic, copy) void (^dismissCompletionCallback)(void);

/** The final constant value that should be set for the topToVCTopLayoutConstraint when animating */
@property (nonatomic, strong) NSLayoutConstraint *topToVCFinalConstraint;
@property (nonatomic, strong) NSLayoutConstraint *topToVCStartingConstraint;

@property (nonatomic, assign) CGFloat viewCornerRadius;
@property (nonatomic, assign) CGFloat iconRelativeCornerRadius;
@property (nonatomic, assign) RMessageType messageType;
@property (nonatomic, copy) NSString *customTypeName;

@property (nonatomic, assign) BOOL shouldBlurBackground;
@property (nonatomic, assign) BOOL dismissingEnabled;

/** The existence of this property is strictly to handle a UIAppearance bug where methods are
 called multiple times when they need not be. See: http://www.openradar.me/28827675 */
@property (nonatomic, assign) BOOL labelsHaveBeenSizedToFit;

@property (nonatomic, assign) BOOL disableSpringAnimationPadding;

/* The amount of vertical padding / height to add to RMessage's height so as to perform a spring animation without
   visually showing an empty gap due to the spring animation overbounce. This value changes dynamically due to
   iOS changing the overbounce dynamically according to view size. */
@property (nonatomic, assign) CGFloat springAnimationPadding;

@property (nonatomic, assign) BOOL springAnimationPaddingCalculated;

@end

@implementation RMessageView

#pragma mark - Class Methods

+ (NSError *)setupGlobalDesignDictionary
{
  if (!globalDesignDictionary) {
    NSString *path = [[NSBundle bundleForClass:[self class]] pathForResource:RDesignFileName ofType:@"json"];
    NSData *data = [NSData dataWithContentsOfFile:path];
    NSAssert(data != nil, @"Could not read RMessage config file from main bundle with name %@.json", RDesignFileName);
    if (!data) {
      NSString *configFileErrorMessage = [NSString stringWithFormat:@"There seems to be an error"
                                                                    @"with the %@ configuration file",
                                                                    RDesignFileName];
      return [NSError errorWithDomain:[NSBundle bundleForClass:[self class]].bundleIdentifier
                                 code:0
                             userInfo:@{ NSLocalizedDescriptionKey: configFileErrorMessage }];
    }
    globalDesignDictionary =
      [NSMutableDictionary dictionaryWithDictionary: [NSJSONSerialization JSONObjectWithData:data
                                        options:NSJSONReadingMutableContainers
                                          error:nil]];
  }
  return nil;
}

+ (void)addDesignsFromFileWithName:(NSString *)filename inBundle:(NSBundle *)bundle;
{
  [[self class] setupGlobalDesignDictionary];
  NSString *path = [bundle pathForResource:filename ofType:@"json"];
  if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
    NSDictionary *newDesignStyle =
      [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:path]
                                      options:NSJSONReadingMutableContainers
                                        error:nil];
    [globalDesignDictionary addEntriesFromDictionary:newDesignStyle];
  } else {
    NSAssert(NO, @"Error loading design file with name %@", filename);
  }
}

+ (UIViewController *)defaultViewController
{
  UIViewController *viewController = [UIViewController topMostController];
  if (!viewController) {
    viewController = [UIApplication sharedApplication].keyWindow.rootViewController;
  }
  return viewController;
}

+ (UIColor *)colorForString:(NSString *)string
{
  if (string) return [UIColor hx_colorWithHexRGBAString:string alpha:1.f];
  return nil;
}

/**
 Wrapper method to avoid getting a black color when passing a nil string to
 hx_colorWithHexRGBAString
 @param string A hex string representation of a color.
 @return nil or a color.
 */
+ (UIColor *)colorForString:(NSString *)string alpha:(CGFloat)alpha
{
  if (string) return [UIColor hx_colorWithHexRGBAString:string alpha:alpha];
  return nil;
}

#pragma mark - Get Image From Resource Bundle

+ (UIImage *)bundledImageNamed:(NSString *)name
{
  NSString *imagePath = [[NSBundle bundleForClass:[self class]] pathForResource:name ofType:nil];
  UIImage *image = [[UIImage alloc] initWithContentsOfFile:imagePath];
  if (!image) {
    image = [UIImage imageNamed:name];
  }
  return image;
}

+ (void)activateConstraints:(NSArray *)constraints inSuperview:(UIView *)superview
{
  if (!constraints || !superview) return;
  if (@available(iOS 8.0, *)) {
    [NSLayoutConstraint activateConstraints:constraints];
  } else {
    [superview addConstraints:constraints];
  }
}

+ (void)deActivateConstraints:(NSArray *)constraints inSuperview:(UIView *)superview
{
  if (!constraints || !superview) return;
  if (@available(iOS 8.0, *)) {
    [NSLayoutConstraint deactivateConstraints:constraints];
  } else {
    [superview removeConstraints:constraints];
  }
}

+ (void)activateConstraint:(NSLayoutConstraint *)constraint inSuperview:(UIView *)superview
{
  if (!constraint || !superview) return;
  if (@available(iOS 8.0, *)) {
    constraint.active = YES;
  } else {
    [superview addConstraint:constraint];
  }
}

+ (void)deActivateConstraint:(NSLayoutConstraint *)constraint inSuperview:(UIView *)superview
{
  if (!constraint || !superview) return;
  if (@available(iOS 8.0, *)) {
    constraint.active = NO;
  } else {
    [superview removeConstraint:constraint];
  }
}

#pragma mark - Instance Methods

- (instancetype)initWithDelegate:(id<RMessageViewProtocol>)delegate
                           title:(NSString *)title
                        subtitle:(NSString *)subtitle
                       iconImage:(UIImage *)iconImage
                            type:(RMessageType)messageType
                  customTypeName:(NSString *)customTypeName
                        duration:(NSTimeInterval)duration
                inViewController:(UIViewController *)viewController
                        callback:(void (^)(void))callback
                     buttonTitle:(NSString *)buttonTitle
                  buttonCallback:(void(^)(UIButton *button))buttonCallback
                      atPosition:(RMessagePosition)position
            canBeDismissedByUser:(BOOL)dismissingEnabled
{
  return [self initWithDelegate:delegate
                          title:title
                       subtitle:subtitle
                      iconImage:iconImage
                           type:messageType
                 customTypeName:customTypeName
                       duration:duration
               inViewController:viewController
                       callback:callback
           presentingCompletion:nil
              dismissCompletion:nil
                    buttonTitle:buttonTitle
                 buttonCallback:buttonCallback
                     atPosition:position
           canBeDismissedByUser:dismissingEnabled];
}

- (instancetype)initWithDelegate:(id<RMessageViewProtocol>)delegate
                           title:(NSString *)title
                        subtitle:(NSString *)subtitle
                       iconImage:(UIImage *)iconImage
                            type:(RMessageType)messageType
                  customTypeName:(NSString *)customTypeName
                        duration:(NSTimeInterval)duration
                inViewController:(UIViewController *)viewController
                        callback:(void (^)(void))callback
            presentingCompletion:(void (^)(void))presentingCompletionCallback
               dismissCompletion:(void (^)(void))dismissCompletionCallback
                     buttonTitle:(NSString *)buttonTitle
                  buttonCallback:(void(^)(UIButton *button))buttonCallback
                      atPosition:(RMessagePosition)position
            canBeDismissedByUser:(BOOL)dismissingEnabled
{
    self = [super init];
    if (self) {
        self.accessibilityIdentifier = @"RMessageView";
        _delegate = delegate;
        _title = title;
        _subtitle = subtitle;
        _iconImage = iconImage;
        _duration = duration;
        viewController ? _viewController = viewController : (_viewController = [[self class] defaultViewController]);
        _messagePosition = position;
        _callback = callback;
        _messageType = messageType;
        _customTypeName = customTypeName;
        
        _textContainerView = [[UIView alloc] init];
        
        _titleLabel = [[UILabel alloc] init];
        _titleLabel.text = title;
        
        _subtitleLabel = [[UILabel alloc] init];
        _subtitleLabel.text = subtitle;
        
        _button = [UIButton buttonWithType:UIButtonTypeCustom];
        _buttonTitle = buttonTitle;
        _buttonCallback = buttonCallback;
        
        _presentingCompletionCallback = presentingCompletionCallback;
        _dismissCompletionCallback = dismissCompletionCallback;
        _dismissingEnabled = dismissingEnabled;
        _springAnimationPadding = 5.f;
        
        NSError *designError = [self setupDesignDictionariesWithMessageType:_messageType customTypeName:customTypeName];
        if (designError) return nil;
        
        [self setupDesign];
        [self setupGestureRecognizers];
    }
    return self;
}

- (void)setMessageOpacity:(CGFloat)messageOpacity
{
  _messageOpacity = messageOpacity;
  self.alpha = _messageOpacity;
}

- (void)setTitleFont:(UIFont *)aTitleFont
{
  _titleFont = aTitleFont;
  [self.titleLabel setFont:_titleFont];
}

- (void)setTitleAlignment:(NSTextAlignment)titleAlignment
{
  _titleAlignment = titleAlignment;
  self.titleLabel.textAlignment = _titleAlignment;
}

- (void)setTitleTextColor:(UIColor *)aTextColor
{
  _titleTextColor = aTextColor;
  [self.titleLabel setTextColor:_titleTextColor];
}

- (void)setSubtitleFont:(UIFont *)subtitleFont
{
  _subtitleFont = subtitleFont;
  [self.subtitleLabel setFont:subtitleFont];
}

- (void)setSubtitleAlignment:(NSTextAlignment)subtitleAlignment
{
  _subtitleAlignment = subtitleAlignment;
  self.subtitleLabel.textAlignment = _subtitleAlignment;
}

- (void)setSubtitleTextColor:(UIColor *)subtitleTextColor
{
  _subtitleTextColor = subtitleTextColor;
  [self.subtitleLabel setTextColor:_subtitleTextColor];
}

- (void)setMessageIcon:(UIImage *)messageIcon
{
  _messageIcon = messageIcon;
  [self updateCurrentIconIfNeeded];
}

- (void)setErrorIcon:(UIImage *)errorIcon
{
  _errorIcon = errorIcon;
  [self updateCurrentIconIfNeeded];
}

- (void)setSuccessIcon:(UIImage *)successIcon
{
  _successIcon = successIcon;
  [self updateCurrentIconIfNeeded];
}

- (void)setWarningIcon:(UIImage *)warningIcon
{
  _warningIcon = warningIcon;
  [self updateCurrentIconIfNeeded];
}

- (void)updateCurrentIconIfNeeded
{
  switch (self.messageType) {
  case RMessageTypeNormal: {
    self.iconImageView.image = _messageIcon;
    break;
  }
  case RMessageTypeError: {
    self.iconImageView.image = _errorIcon;
    break;
  }
  case RMessageTypeSuccess: {
    self.iconImageView.image = _successIcon;
    break;
  }
  case RMessageTypeWarning: {
    self.iconImageView.image = _warningIcon;
    break;
  }
  default:
    break;
  }
}

- (NSError *)setupDesignDictionariesWithMessageType:(RMessageType)messageType customTypeName:(NSString *)customTypeName
{
  [[self class] setupGlobalDesignDictionary];
  NSString *messageTypeDesignString;
  switch (messageType) {
  case RMessageTypeNormal:
    messageTypeDesignString = @"normal";
    break;
  case RMessageTypeError:
    messageTypeDesignString = @"error";
    break;
  case RMessageTypeSuccess:
    messageTypeDesignString = @"success";
    break;
  case RMessageTypeWarning:
    messageTypeDesignString = @"warning";
    break;
  case RMessageTypeCustom:
    if (!customTypeName || [customTypeName isEqualToString:@""]) {
      return
        [NSError errorWithDomain:[NSBundle bundleForClass:[self class]].bundleIdentifier
                            code:0
                        userInfo:@{
                          NSLocalizedDescriptionKey: @"When specifying a type RMessageTypeCustom make sure to pass in "
                                                     @"a valid argument for customTypeName parameter. This string "
                                                     @"should match a Key in your custom design file."
                        }];
    }
    messageTypeDesignString = customTypeName;
    break;
  default:
    break;
  }

  _designDictionary = globalDesignDictionary[messageTypeDesignString];
  if (!_designDictionary) {
    return
      [NSError errorWithDomain:[NSBundle bundleForClass:[self class]].bundleIdentifier
                          code:0
                      userInfo:@{
                        NSLocalizedDescriptionKey: @"When specifying a type RMessageTypeCustom make sure to pass in a "
                                                   @"valid argument for customTypeName parameter. This string should "
                                                   @"match a Key in your custom design file."
                      }];
  }
  return nil;
}

- (void)setupDesign
{
  [self setupView];
  [self setupDesignDefaults];
  [self setupTextContainerView];
  [self setupImagesAndBackground];
  [self setupLabels];
  [self setupButton];
}

- (void)setupLayout
{
  self.translatesAutoresizingMaskIntoConstraints = NO;
//  if (!_title || !_subtitle) self.titleSubtitleVerticalSpacingConstraint.constant = 0;

  [self calculateSpringAnimationPadding];
  [self setupTitleSubtitleContainerViewLayoutGuideConstraint];
  [self setupFinalAnimationConstraints];

  // Add RMessage to superview and prepare the ending constraints
  if (!self.superview) [self.viewController.view addSubview:self];

  // Prepare the starting y position constraints
  [self setupStartingAnimationConstraints];

  NSAssert(self.superview != nil, @"instance must have a superview by this point");
  NSLayoutConstraint *centerXConstraint = [NSLayoutConstraint constraintWithItem:self
                                                                       attribute:NSLayoutAttributeCenterX
                                                                       relatedBy:NSLayoutRelationEqual
                                                                          toItem:self.superview
                                                                       attribute:NSLayoutAttributeCenterX
                                                                      multiplier:1.f
                                                                        constant:0.f];
  NSLayoutConstraint *leadingConstraint = [NSLayoutConstraint constraintWithItem:self
                                                                       attribute:NSLayoutAttributeLeading
                                                                       relatedBy:NSLayoutRelationEqual
                                                                          toItem:self.superview
                                                                       attribute:NSLayoutAttributeLeading
                                                                      multiplier:1.f
                                                                        constant:0.f];
  NSLayoutConstraint *trailingConstraint = [NSLayoutConstraint constraintWithItem:self
                                                                        attribute:NSLayoutAttributeTrailing
                                                                        relatedBy:NSLayoutRelationEqual
                                                                           toItem:self.superview
                                                                        attribute:NSLayoutAttributeTrailing
                                                                       multiplier:1.f
                                                                        constant:0.f];
    
  [[self class]
    activateConstraints:@[centerXConstraint, leadingConstraint, trailingConstraint,
                          self.titleSubtitleContainerViewLayoutGuideConstraint, self.topToVCLayoutConstraint]
            inSuperview:self.superview];
  if (self.shouldBlurBackground) {
    [self setupBlurBackground];
  }
}

- (void)setupTitleSubtitleContainerViewLayoutGuideConstraint {
  // Install a constraint that guarantees the title subtitle container view is properly spaced from the top layout guide
  // when animating from top or the bottom layout guide when animating from bottom
  if (self.messagePosition != RMessagePositionBottom) {
    self.titleSubtitleContainerViewLayoutGuideConstraint = [NSLayoutConstraint constraintWithItem:self.textContainerView
                                                                                        attribute:NSLayoutAttributeTop
                                                                                        relatedBy:NSLayoutRelationEqual
                                                                                           toItem:self.viewController.topLayoutGuide
                                                                                        attribute:NSLayoutAttributeBottom
                                                                                       multiplier:1.f
                                                                                         constant:10.f];

  } else {
    self.titleSubtitleContainerViewLayoutGuideConstraint = [NSLayoutConstraint constraintWithItem:self.textContainerView
                                                                                        attribute:NSLayoutAttributeBottom
                                                                                        relatedBy:NSLayoutRelationEqual
                                                                                           toItem:self.viewController.bottomLayoutGuide
                                                                                        attribute:NSLayoutAttributeTop
                                                                                       multiplier:1.f
                                                                                         constant:-10.f];
  }
  self.titleSubtitleContainerViewLayoutGuideConstraint.priority = 749;
}
- (void)setupBackgroundImageViewWithImage:(UIImage *)image
{
  _backgroundImageView = [[UIImageView alloc] initWithImage:image];
  _backgroundImageView.translatesAutoresizingMaskIntoConstraints = NO;
  _backgroundImageView.contentMode = UIViewContentModeScaleToFill;
  [self insertSubview:_backgroundImageView atIndex:0];
  NSArray *hConstraints = [NSLayoutConstraint constraintsWithVisualFormat:@"H:|-0-[backgroundImageView]-0-|"
                                                                  options:0
                                                                  metrics:nil
                                                                    views:@{
                                                                      @"backgroundImageView": _backgroundImageView
                                                                    }];
  NSArray *vConstraints = [NSLayoutConstraint constraintsWithVisualFormat:@"V:|-0-[backgroundImageView]-0-|"
                                                                  options:0
                                                                  metrics:nil
                                                                    views:@{
                                                                      @"backgroundImageView": _backgroundImageView
                                                                    }];
  [[self class] activateConstraints:hConstraints inSuperview:self];
  [[self class] activateConstraints:vConstraints inSuperview:self];
}

- (void)setupBlurBackground
{
  if (@available(iOS 8.0, *)) {
    UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    blurView.translatesAutoresizingMaskIntoConstraints = NO;
    [self insertSubview:blurView atIndex:0];
    NSArray *hConstraints = [NSLayoutConstraint constraintsWithVisualFormat:@"H:|-0-[blurBackgroundView]-0-|"
                                                                    options:0
                                                                    metrics:nil
                                                                      views:@{
                                                                              @"blurBackgroundView": blurView
                                                                              }];
    NSArray *vConstraints = [NSLayoutConstraint constraintsWithVisualFormat:@"V:|-0-[blurBackgroundView]-0-|"
                                                                    options:0
                                                                    metrics:nil
                                                                      views:@{
                                                                              @"blurBackgroundView": blurView
                                                                              }];
    [[self class] activateConstraints:hConstraints inSuperview:self];
    [[self class] activateConstraints:vConstraints inSuperview:self];
  }
}

- (void)executeMessageViewCallBack
{
  if (self.callback) self.callback();
}

- (void)setButton:(UIButton *)button
{
  if (button.superview) [button removeFromSuperview];
  if (_button.superview) [_button removeFromSuperview];
  _button = button;
  [self.textContainerView addSubview:_button];
  [self setupButtonConstraints];
}

- (void)executeMessageViewButtonCallBack
{
  if (self.buttonCallback) self.buttonCallback(self.button);
}

- (void)didMoveToWindow
{
  [super didMoveToWindow];
  if (self.duration == RMessageDurationEndless && self.superview && !self.window) {
    if (self.delegate && [self.delegate respondsToSelector:@selector(windowRemovedForEndlessDurationMessageView:)]) {
      [self.delegate windowRemovedForEndlessDurationMessageView:self];
    }
    [self dismiss];
  }
}

- (void)layoutSubviews
{
  [super layoutSubviews];
  if (self.iconRelativeCornerRadius > 0) {
    self.iconImageView.layer.cornerRadius = self.iconRelativeCornerRadius * self.iconImageView.bounds.size.width;
  }

  if (self.viewCornerRadius >= 0) {
    self.layer.cornerRadius = self.viewCornerRadius;
  }
}

- (void)setupDesignDefaults
{
  self.backgroundColor = nil;
  self.messageOpacity = 0.97f;
  _shouldBlurBackground = NO;
  _titleLabel.numberOfLines = 0;
  _titleLabel.lineBreakMode = NSLineBreakByWordWrapping;
  _titleLabel.font = [UIFont boldSystemFontOfSize:14.f];
  _titleLabel.textAlignment = NSTextAlignmentLeft;
  _titleLabel.textColor = [UIColor blackColor];
  _titleLabel.shadowColor = nil;
  _titleLabel.shadowOffset = CGSizeZero;
  _titleLabel.backgroundColor = nil;

  _subtitleLabel.numberOfLines = 0;
  _subtitleLabel.lineBreakMode = NSLineBreakByWordWrapping;
  _subtitleLabel.font = [UIFont boldSystemFontOfSize:12.f];
  _subtitleLabel.textAlignment = NSTextAlignmentLeft;
  _subtitleLabel.textColor = [UIColor darkGrayColor];
  _subtitleLabel.shadowColor = nil;
  _subtitleLabel.shadowOffset = CGSizeZero;
  _subtitleLabel.backgroundColor = nil;

  _button.titleLabel.font = [UIFont boldSystemFontOfSize:14.0];
//  _button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentRight;
  [_button setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
  _iconImageView.clipsToBounds = NO;
}

- (void)setupView
{
  if (_designDictionary[@"cornerRadius"] && [_designDictionary[@"cornerRadius"] isKindOfClass:[NSNumber class]]) {
    self.viewCornerRadius = [_designDictionary[@"cornerRadius"] floatValue];
    if (self.viewCornerRadius > 0) {
      self.clipsToBounds = YES;
    }
  }
}

- (void)setupImagesAndBackground
{
  UIColor *backgroundColor;
  if (_designDictionary[@"backgroundColor"] && _designDictionary[@"backgroundColorAlpha"]) {
    backgroundColor = [[self class] colorForString:_designDictionary[@"backgroundColor"]
                                     alpha:[_designDictionary[@"backgroundColorAlpha"] floatValue]];
  } else if (_designDictionary[@"backgroundColor"]) {
    backgroundColor = [[self class] colorForString:_designDictionary[@"backgroundColor"]];
  }

  if (backgroundColor) self.backgroundColor = backgroundColor;
  if (_designDictionary[@"opacity"]) {
    self.messageOpacity = [_designDictionary[@"opacity"] floatValue];
  }

  if ([_designDictionary[@"blurBackground"] floatValue] == 1) {
    _shouldBlurBackground = YES;
    /* As per apple docs when using UIVisualEffectView and blurring the superview of the blur view
    must have an opacity of 1.f */
    self.messageOpacity = 1.f;
  }

  if (!_iconImage && ([_designDictionary[@"iconImage"] length] > 0)) {
    _iconImage = [[self class] bundledImageNamed:_designDictionary[@"iconImage"]];
  }

  if (_iconImage) {
    _iconImageView = [[UIImageView alloc] initWithImage:_iconImage];
    if (_designDictionary[@"iconImageRelativeCornerRadius"]) {
      self.iconRelativeCornerRadius = [_designDictionary[@"iconImageRelativeCornerRadius"] floatValue];
      _iconImageView.clipsToBounds = YES;
    } else {
      self.iconRelativeCornerRadius = 0.f;
      _iconImageView.clipsToBounds = NO;
    }
    [self setupIconImageView];
  }

  UIImage *backgroundImage =
    [[self class] bundledImageNamed:_designDictionary[@"backgroundImage"]];
  if (backgroundImage) {
    backgroundImage = [backgroundImage resizableImageWithCapInsets:UIEdgeInsetsMake(0, 0, 0, 0)
                                                      resizingMode:UIImageResizingModeStretch];
    [self setupBackgroundImageViewWithImage:backgroundImage];
  }
}

- (void)setupLabels
{
  [self setupTextContainerView];
  [self setupTitleLabel];
  [self setupSubTitleLabel];
}

- (void)setupTextContainerView {
    [self.textContainerView addSubview:_titleLabel];
    [self.textContainerView addSubview:_subtitleLabel];
    [self.textContainerView addSubview:_button];
    [self setupTextContainerViewConstraints];
}

- (void)setupTitleLabel
{
  CGFloat titleFontSize = [_designDictionary[@"titleFontSize"] floatValue];
  NSString *titleFontName = _designDictionary[@"titleFontName"];
  if (titleFontName) {
    _titleLabel.font = [UIFont fontWithName:titleFontName size:titleFontSize];
  } else if (titleFontSize) {
    _titleLabel.font = [UIFont boldSystemFontOfSize:titleFontSize];
  }

  self.titleLabel.textAlignment = [self textAlignmentForString:_designDictionary[@"titleTextAlignment"]];

  UIColor *titleTextColor = [[self class] colorForString:_designDictionary[@"titleTextColor"]];
  _titleLabel.text = _title ? _title : @"";
  if (titleTextColor) _titleLabel.textColor = titleTextColor;

  UIColor *titleShadowColor = [[self class] colorForString:_designDictionary[@"titleShadowColor"]];
  if (titleShadowColor) _titleLabel.shadowColor = titleShadowColor;
  id titleShadowOffsetX = _designDictionary[@"titleShadowOffsetX"];
  id titleShadowOffsetY = _designDictionary[@"titleShadowOffsetY"];
  if (titleShadowOffsetX && titleShadowOffsetY) {
    _titleLabel.shadowOffset = CGSizeMake([titleShadowOffsetX floatValue], [titleShadowOffsetY floatValue]);
  }
    [self setupTitleConstraints];
}

- (void)setupSubTitleLabel
{
  id subTitleFontSizeValue = _designDictionary[@"subTitleFontSize"];
  if (!subTitleFontSizeValue) {
    subTitleFontSizeValue = _designDictionary[@"subtitleFontSize"];
  }

  CGFloat subTitleFontSize = [subTitleFontSizeValue floatValue];
  NSString *subTitleFontName = _designDictionary[@"subTitleFontName"];
  if (!subTitleFontName) {
    subTitleFontName = _designDictionary[@"subtitleFontName"];
  }

  if (subTitleFontName) {
    _subtitleLabel.font = [UIFont fontWithName:subTitleFontName size:subTitleFontSize];
  } else if (subTitleFontSize) {
    _subtitleLabel.font = [UIFont systemFontOfSize:subTitleFontSize];
  }

  self.subtitleLabel.textAlignment =
    [self textAlignmentForString:_designDictionary[@"subtitleTextAlignment"]];

  UIColor *subTitleTextColor = [[self class] colorForString:_designDictionary[@"subTitleTextColor"]];
  if (!subTitleTextColor) {
    subTitleTextColor = [[self class] colorForString:_designDictionary[@"subtitleTextColor"]];
  }
  if (!subTitleTextColor) {
    subTitleTextColor = _titleLabel.textColor;
  }

  _subtitleLabel.text = _subtitle ? _subtitle : @"";
  if (subTitleTextColor) _subtitleLabel.textColor = subTitleTextColor;

  UIColor *subTitleShadowColor = [[self class] colorForString:_designDictionary[@"subTitleShadowColor"]];
  if (!subTitleShadowColor) {
    subTitleShadowColor = [[self class] colorForString:_designDictionary[@"subtitleShadowColor"]];
  }

  if (subTitleShadowColor) _subtitleLabel.shadowColor = subTitleShadowColor;
  id subTitleShadowOffsetX = _designDictionary[@"subTitleShadowOffsetX"];
  id subTitleShadowOffsetY = _designDictionary[@"subTitleShadowOffsetY"];
  if (!subTitleShadowOffsetX) {
    subTitleShadowOffsetX = _designDictionary[@"subtitleShadowOffsetX"];
  }
  if (!subTitleShadowOffsetY) {
    subTitleShadowOffsetY = _designDictionary[@"subtitleShadowOffsetY"];
  }
  if (subTitleShadowOffsetX && subTitleShadowOffsetY) {
    _subtitleLabel.shadowOffset = CGSizeMake([subTitleShadowOffsetX floatValue], [subTitleShadowOffsetY floatValue]);
  }
    [self setupSubTitleConstraints];
}

- (void)setupButton
{
  if (!_button) return;
  CGFloat buttonTitleFontSize = [_designDictionary[@"buttonTitleFontSize"] floatValue];
  NSString *buttonTitleFontName = _designDictionary[@"buttonTitleFontName"];
  if (buttonTitleFontName) {
    _button.titleLabel.font = [UIFont fontWithName:buttonTitleFontName size:buttonTitleFontSize];
  } else if (buttonTitleFontSize) {
    _button.titleLabel.font = [UIFont systemFontOfSize:buttonTitleFontSize];
  }

  UIImage *buttonResizeableBackgroundImage = [[self class] bundledImageNamed:_designDictionary[@"buttonResizeableBackgroundImage"]];
    //不需要默认背景图
//  if (!buttonResizeableBackgroundImage) {
//    buttonResizeableBackgroundImage = [[self class] bundledImageNamed:@"NotificationButtonBackground.png"];
//  }
  if (buttonResizeableBackgroundImage) {
    UIImage *resizeableImage = [buttonResizeableBackgroundImage resizableImageWithCapInsets:UIEdgeInsetsMake(15.0, 12.0, 15.0, 11.0)];
    [_button setBackgroundImage:resizeableImage forState:UIControlStateNormal];
    _button.contentEdgeInsets = UIEdgeInsetsMake(0.0, 5.0, 0.0, 5.0);
  }

  [_button setTitle:_buttonTitle forState:UIControlStateNormal];
  UIColor *buttonTitleTextColor = [[self class] colorForString:_designDictionary[@"buttonTitleTextColor"]];
  if (buttonTitleTextColor) {
    [_button setTitleColor:buttonTitleTextColor forState:UIControlStateNormal];
  }

  UIColor *buttonTitleShadowColor = [[self class] colorForString:_designDictionary[@"buttonTitleShadowColor"]];
  if (buttonTitleShadowColor) {
    [_button setTitleShadowColor:buttonTitleShadowColor forState:UIControlStateNormal];
  }

  CGSize buttonTitleShadowOffset = CGSizeZero;
  if (_designDictionary[@"buttonTitleShadowOffsetX"]) {
    buttonTitleShadowOffset.width = [_designDictionary[@"buttonTitleShadowOffsetX"] floatValue];
  }
  if (_designDictionary[@"buttonTitleShadowOffsetY"]) {
    buttonTitleShadowOffset.height = [_designDictionary[@"buttonTitleShadowOffsetY"] floatValue];
  }
  if (buttonTitleShadowOffset.width != 0 || buttonTitleShadowOffset.height != 0) {
    _button.titleLabel.shadowOffset = buttonTitleShadowOffset;
  }

  [_button addTarget:self action:@selector(buttonTapped) forControlEvents:UIControlEventTouchUpInside];
  [_button sizeToFit];
  [self setupButtonConstraints];
}

- (void)setupTextContainerViewConstraints {
    _textContainerView.translatesAutoresizingMaskIntoConstraints = NO;
    
    CGFloat iconImageTrailing = 15;
    if (_iconImage) {
        iconImageTrailing = 15 + _iconImage.size.width + 15;
    }
    
    NSLayoutConstraint *containerViewLeading = [NSLayoutConstraint constraintWithItem:_textContainerView
                                                                         attribute:NSLayoutAttributeLeading
                                                                         relatedBy:NSLayoutRelationEqual
                                                                            toItem:self
                                                                         attribute:NSLayoutAttributeLeading
                                                                        multiplier:1.f
                                                                          constant:iconImageTrailing];
    
    NSLayoutConstraint *containerViewBottomSpacing = [NSLayoutConstraint constraintWithItem:_textContainerView
                                                                               attribute:NSLayoutAttributeBottom
                                                                               relatedBy:NSLayoutRelationLessThanOrEqual
                                                                                  toItem:self
                                                                               attribute:NSLayoutAttributeBottom
                                                                              multiplier:1.f
                                                                                constant:0.f];
    NSLayoutConstraint *containerViewTopSpacing = [NSLayoutConstraint constraintWithItem:_textContainerView
                                                                            attribute:NSLayoutAttributeTop
                                                                            relatedBy:NSLayoutRelationGreaterThanOrEqual
                                                                               toItem:self
                                                                            attribute:NSLayoutAttributeTop
                                                                           multiplier:1.f
                                                                             constant:0.f];
    
    NSLayoutConstraint *containerViewTrailing = [NSLayoutConstraint constraintWithItem:_textContainerView
                                                                          attribute:NSLayoutAttributeTrailing
                                                                          relatedBy:NSLayoutRelationEqual
                                                                             toItem:self
                                                                          attribute:NSLayoutAttributeTrailing
                                                                         multiplier:1.f
                                                                           constant:0];
    
    [self addSubview:_textContainerView];
    [[self class] activateConstraints:@[containerViewLeading, containerViewBottomSpacing, containerViewTopSpacing, containerViewTrailing] inSuperview:self];
    
}

- (void)setupTitleConstraints
{
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;

    NSLayoutConstraint *titleLabelLeading = [NSLayoutConstraint constraintWithItem:_titleLabel
                                                                         attribute:NSLayoutAttributeLeading
                                                                         relatedBy:NSLayoutRelationEqual
                                                                            toItem:self.textContainerView
                                                                         attribute:NSLayoutAttributeLeading
                                                                        multiplier:1.f
                                                                          constant:0];

    NSLayoutConstraint *titleLabelBottomSpacing = [NSLayoutConstraint constraintWithItem:_titleLabel
                                                                               attribute:NSLayoutAttributeBottom
                                                                               relatedBy:NSLayoutRelationLessThanOrEqual
                                                                                  toItem:self.textContainerView
                                                                               attribute:NSLayoutAttributeBottom
                                                                              multiplier:1.f
                                                                                constant:-10.f];
    NSLayoutConstraint *titleLabelTopSpacing = [NSLayoutConstraint constraintWithItem:_titleLabel
                                                                            attribute:NSLayoutAttributeTop
                                                                            relatedBy:NSLayoutRelationGreaterThanOrEqual
                                                                               toItem:self.textContainerView
                                                                            attribute:NSLayoutAttributeTop
                                                                           multiplier:1.f
                                                                             constant:10.f];
    
    
    
    NSLayoutConstraint *titleLabelTrailing = [NSLayoutConstraint constraintWithItem:_titleLabel
                                                                         attribute:NSLayoutAttributeTrailing
                                                                         relatedBy:NSLayoutRelationLessThanOrEqual
                                                                            toItem:self.button
                                                                         attribute:NSLayoutAttributeLeading
                                                                        multiplier:1.f
                                                                          constant:-10.f];
    
    [[self class] activateConstraints:@[titleLabelLeading, titleLabelBottomSpacing, titleLabelTopSpacing, titleLabelTrailing] inSuperview:self.textContainerView];
}

- (void)setupSubTitleConstraints
{
    _subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    NSLayoutConstraint *subtitlelLabelLeading = [NSLayoutConstraint constraintWithItem:_subtitleLabel
                                                                         attribute:NSLayoutAttributeLeading
                                                                         relatedBy:NSLayoutRelationEqual
                                                                            toItem:self.titleLabel
                                                                         attribute:NSLayoutAttributeLeading
                                                                        multiplier:1.f
                                                                          constant:0.f];
    NSLayoutConstraint *subtitlelLabelTrailing = [NSLayoutConstraint constraintWithItem:_subtitleLabel
                                                                                  attribute:NSLayoutAttributeTrailing
                                                                                  relatedBy:NSLayoutRelationEqual
                                                                                     toItem:self.textContainerView
                                                                                  attribute:NSLayoutAttributeTrailing
                                                                                 multiplier:1.f
                                                                                   constant:-15.f];

    NSLayoutConstraint *subtitlelLabelBottomSpacing = [NSLayoutConstraint constraintWithItem:_subtitleLabel
                                                                               attribute:NSLayoutAttributeBottom
                                                                               relatedBy:NSLayoutRelationEqual
                                                                                  toItem:self.textContainerView
                                                                               attribute:NSLayoutAttributeBottom
                                                                              multiplier:1.f
                                                                                constant:-10.f];
    
    NSLayoutConstraint *subtitlelLabelTopSpacing = [NSLayoutConstraint constraintWithItem:_subtitleLabel
                                                                            attribute:NSLayoutAttributeTop
                                                                            relatedBy:NSLayoutRelationEqual
                                                                               toItem:self.titleLabel
                                                                            attribute:NSLayoutAttributeBottom
                                                                           multiplier:1.f
                                                                             constant:5.f];
    
    [[self class] activateConstraints:@[subtitlelLabelLeading, subtitlelLabelTrailing, subtitlelLabelBottomSpacing, subtitlelLabelTopSpacing] inSuperview:self.textContainerView];
}

- (void)setupButtonConstraints
{
  _button.translatesAutoresizingMaskIntoConstraints = NO;

  NSLayoutConstraint *buttonViewCenterY = [NSLayoutConstraint constraintWithItem:_button
                                                                       attribute:NSLayoutAttributeCenterY
                                                                       relatedBy:NSLayoutRelationEqual
                                                                          toItem:self.titleLabel
                                                                       attribute:NSLayoutAttributeCenterY
                                                                      multiplier:1.f
                                                                        constant:0.f];
  NSLayoutConstraint *buttonViewTrailing = [NSLayoutConstraint constraintWithItem:_button
                                                                                attribute:NSLayoutAttributeTrailing
                                                                                relatedBy:NSLayoutRelationEqual
                                                                                   toItem:self.textContainerView
                                                                                attribute:NSLayoutAttributeTrailing
                                                                               multiplier:1.f
                                                                                 constant:-15.f];

  NSLayoutConstraint *buttonViewBottomSpacing = [NSLayoutConstraint constraintWithItem:_button
                                                                      attribute:NSLayoutAttributeBottom
                                                                      relatedBy:NSLayoutRelationLessThanOrEqual
                                                                         toItem:self.subtitleLabel
                                                                      attribute:NSLayoutAttributeTop
                                                                     multiplier:1.f
                                                                       constant:0.f];

  [[self class] activateConstraints:@[buttonViewCenterY, buttonViewTrailing, buttonViewBottomSpacing] inSuperview:self.textContainerView];
    
  [self resetButtonWidth];
}

- (void)setupIconImageView
{
  if (_designDictionary[@"iconImageTintColor"] &&
      [_designDictionary[@"iconImageTintColor"] isKindOfClass:[NSString class]]) {
    self.iconImageView.tintColor = [[self class]
                                    colorForString:_designDictionary[@"iconImageTintColor"]];
  }

  self.iconImageView.contentMode = UIViewContentModeScaleAspectFit;
  self.iconImageView.translatesAutoresizingMaskIntoConstraints = NO;

  NSLayoutConstraint *imgViewCenterY = [NSLayoutConstraint constraintWithItem:self.iconImageView
                                                                    attribute:NSLayoutAttributeCenterY
                                                                    relatedBy:NSLayoutRelationGreaterThanOrEqual
                                                                       toItem:self.textContainerView
                                                                    attribute:NSLayoutAttributeCenterY
                                                                   multiplier:1.f
                                                                     constant:0.f];
    
    CGFloat iconImageLeading = 0;
    if (_iconImage) {
        iconImageLeading = 15;
    }
    
  NSLayoutConstraint *imgViewLeading = [NSLayoutConstraint constraintWithItem:self.iconImageView
                                                                    attribute:NSLayoutAttributeLeading
                                                                    relatedBy:NSLayoutRelationGreaterThanOrEqual
                                                                       toItem:self
                                                                    attribute:NSLayoutAttributeLeading
                                                                   multiplier:1.f
                                                                     constant:iconImageLeading];

    
    NSLayoutConstraint *imgViewWidth = [NSLayoutConstraint constraintWithItem:self.iconImageView
                                                                    attribute:NSLayoutAttributeWidth
                                                                    relatedBy:NSLayoutRelationEqual
                                                                       toItem:nil
                                                                    attribute:NSLayoutAttributeNotAnAttribute
                                                                   multiplier:1.f
                                                                     constant:_iconImage.size.width];
    
  NSLayoutConstraint *imgViewHeight = [NSLayoutConstraint constraintWithItem:self.iconImageView
                                                                   attribute:NSLayoutAttributeHeight
                                                                   relatedBy:NSLayoutRelationLessThanOrEqual
                                                                      toItem:self.textContainerView
                                                                   attribute:NSLayoutAttributeHeight
                                                                  multiplier:1.f
                                                                    constant:0.f];
  
  [self addSubview:self.iconImageView];
  [[self class] activateConstraints:@[imgViewCenterY, imgViewLeading, imgViewWidth, imgViewHeight]
                        inSuperview:self];
}

- (void)setupGestureRecognizers
{
  UISwipeGestureRecognizer *gestureRecognizer =
    [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(didSwipeMessageView:)];
  [gestureRecognizer
   setDirection:(self.messagePosition == RMessagePositionBottom) ? UISwipeGestureRecognizerDirectionDown : UISwipeGestureRecognizerDirectionUp];
  [self addGestureRecognizer:gestureRecognizer];

  UITapGestureRecognizer *tapRecognizer =
    [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didTapMessageView:)];
  [self addGestureRecognizer:tapRecognizer];
}

#pragma mark - Gesture Recognizers

/* called after the following gesture depending on message position during initialization
 UISwipeGestureRecognizerDirectionUp when message position set to Top,
 UISwipeGestureRecognizerDirectionDown when message position set to bottom */
- (void)didSwipeMessageView:(UISwipeGestureRecognizer *)swipeGesture
{
  if (self.delegate && [self.delegate respondsToSelector:@selector(didSwipeMessageView:)]) {
    [self.delegate didSwipeMessageView:self];
  }
  if (self.dismissingEnabled) [self dismiss];
}

- (void)didTapMessageView:(UITapGestureRecognizer *)tapGesture
{
  if (self.delegate && [self.delegate respondsToSelector:@selector(didTapMessageView:)]) {
    [self.delegate didTapMessageView:self];
  }
  if (self.callback) self.callback();
  if (self.dismissingEnabled) [self dismiss];
}

#pragma mark - Presentation Methods

- (void)present
{
  [self animateMessage];

  if (self.duration == RMessageDurationAutomatic) {
    self.duration =
      kRMessageAnimationDuration + kRMessageDisplayTime + self.frame.size.height * kRMessageExtraDisplayTimePerPixel;
  }

  if (self.duration != RMessageDurationEndless) {
    dispatch_async(dispatch_get_main_queue(), ^{
      [self performSelector:@selector(dismiss) withObject:self afterDelay:self.duration];
    });
  }
}

- (void)calculateSpringAnimationPadding
{
  if (_designDictionary[@"disableSpringAnimationPadding"] &&
      [_designDictionary[@"disableSpringAnimationPadding"] isKindOfClass:[NSNumber class]]) {
    self.disableSpringAnimationPadding = [_designDictionary[@"disableSpringAnimationPadding"] boolValue];
  }

  if (self.disableSpringAnimationPadding) {
    self.springAnimationPadding = 0.f;
    self.springAnimationPaddingCalculated = YES;
    return;
  }

  // Tell the view to relayout
  [self layoutIfNeeded];
  // Base the spring animation padding on an estimated height considering we need the spring animation padding itself
  // to truly calculate the height of the view.
  self.springAnimationPadding = ceilf(self.bounds.size.height / 120) * 5;
  self.springAnimationPaddingCalculated = YES;
}

- (void)setupStartingAnimationConstraints
{
  NSAssert(self.superview != nil, @"instance must have a superview by this point");
  if (self.messagePosition != RMessagePositionBottom) {
    self.topToVCLayoutConstraint = [NSLayoutConstraint constraintWithItem:self.textContainerView
                                                                attribute:NSLayoutAttributeBottom
                                                                relatedBy:NSLayoutRelationEqual
                                                                   toItem:self.superview
                                                                attribute:NSLayoutAttributeTop
                                                               multiplier:1.f
                                                                 constant:0.f];
  } else {
    self.topToVCLayoutConstraint = [NSLayoutConstraint constraintWithItem:self.textContainerView
                                                                attribute:NSLayoutAttributeTop
                                                                relatedBy:NSLayoutRelationEqual
                                                                   toItem:self.superview
                                                                attribute:NSLayoutAttributeBottom
                                                               multiplier:1.f
                                                                 constant:0.f];
  }
  self.topToVCStartingConstraint = self.topToVCLayoutConstraint;
}

- (void)setupFinalAnimationConstraints
{
  NSAssert(self.springAnimationPaddingCalculated, @"spring animation padding must have been calculated by now!");
  id<UILayoutSupport> layoutGuide = nil;
  NSLayoutAttribute viewAttribute = 0;
  NSLayoutAttribute layoutGuideAttribute = 0;
  CGFloat springAnimationPadding = 0;

  if (self.messagePosition == RMessagePositionBottom) {
    viewAttribute = NSLayoutAttributeBottom;
    layoutGuide = self.viewController.bottomLayoutGuide;
    layoutGuideAttribute = NSLayoutAttributeBottom;
    springAnimationPadding = self.springAnimationPadding;
  } else {
    viewAttribute = NSLayoutAttributeTop;
    layoutGuide = self.viewController.topLayoutGuide;
    layoutGuideAttribute = NSLayoutAttributeTop;
    springAnimationPadding = -self.springAnimationPadding;
  }

  self.topToVCFinalConstraint = [NSLayoutConstraint constraintWithItem:self
                                                             attribute:viewAttribute
                                                             relatedBy:NSLayoutRelationEqual
                                                                toItem:layoutGuide
                                                             attribute:layoutGuideAttribute
                                                            multiplier:1.f
                                                              constant:springAnimationPadding];
  self.topToVCFinalConstraint.constant += [self customVerticalOffset];
}

- (void)animateMessage
{
  [self setupLayout];
  [self.superview layoutIfNeeded];
  dispatch_async(dispatch_get_main_queue(), ^{
    if (!self.shouldBlurBackground) self.alpha = 0.f;
    [UIView animateWithDuration:kRMessageAnimationDuration + 0.2f
                          delay:0.f
         usingSpringWithDamping:0.7
          initialSpringVelocity:0.f
                        options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionBeginFromCurrentState |
     UIViewAnimationOptionAllowUserInteraction
                     animations:^{
                       [[self class] deActivateConstraint:self.topToVCLayoutConstraint inSuperview:self.superview];
                       self.topToVCLayoutConstraint = self.topToVCFinalConstraint;
                       [[self class] activateConstraint:self.topToVCLayoutConstraint inSuperview:self.superview];
                       self.isPresenting = YES;
                       if ([self.delegate respondsToSelector:@selector(messageViewIsPresenting:)]) {
                         [self.delegate messageViewIsPresenting:self];
                       }
                       if (!self.shouldBlurBackground) self.alpha = self.messageOpacity;
                       [self.superview layoutIfNeeded];
                     }
                     completion:^(BOOL finished) {
                       self.isPresenting = NO;
                       self.messageIsFullyDisplayed = YES;
                       if ([self.delegate respondsToSelector:@selector(messageViewDidPresent:)]) {
                         [self.delegate messageViewDidPresent:self];
                       }
                       if (self.presentingCompletionCallback) self.presentingCompletionCallback();
                     }];
  });
}

- (void)dismiss
{
  [self dismissWithCompletion:nil];
}

- (void)dismissWithCompletion:(void (^)(void))completionBlock
{
  self.messageIsFullyDisplayed = NO;

  [self.superview layoutIfNeeded];
  dispatch_async(dispatch_get_main_queue(), ^{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(dismiss) object:self];

    [UIView animateWithDuration:kRMessageAnimationDuration
                     animations:^{
                       if (!self.shouldBlurBackground) self.alpha = 0.f;
                       [[self class] deActivateConstraint:self.topToVCLayoutConstraint inSuperview:self.superview];
                       self.topToVCLayoutConstraint = self.topToVCStartingConstraint;
                       [[self class] activateConstraint:self.topToVCLayoutConstraint inSuperview:self.superview];
                       [self.superview layoutIfNeeded];
                     }
                     completion:^(BOOL finished) {
                       [self removeFromSuperview];
                       if ([self.delegate respondsToSelector:@selector(messageViewDidDismiss:)]) {
                         [self.delegate messageViewDidDismiss:self];
                       }
                       if (self.dismissCompletionCallback) self.dismissCompletionCallback();
                       if (completionBlock) completionBlock();
                     }];
  });
}

- (void)resetButtonWidth {
    
    if (!_button) {
        return;
    }
    
    [[self class] deActivateConstraint:_buttonViewWidthConstraint inSuperview:self.textContainerView];
    
    CGFloat buttonWidth = 0;
    if (_button && (_button.imageView.image || _button.titleLabel.text.length > 0)) {
        [_button sizeToFit];
        buttonWidth = _button.bounds.size.width + 5;
    }
    
    _buttonViewWidthConstraint = [NSLayoutConstraint constraintWithItem:_button
                                                                       attribute:NSLayoutAttributeWidth
                                                                       relatedBy:NSLayoutRelationEqual
                                                                          toItem:nil
                                                                       attribute:NSLayoutAttributeNotAnAttribute
                                                                      multiplier:1.f
                                                                        constant:buttonWidth];
    
    [[self class] activateConstraints:@[_buttonViewWidthConstraint] inSuperview:self.textContainerView];
}

#pragma mark - Misc methods

- (void)buttonTapped
{
  if (self.buttonCallback) self.buttonCallback(self.button);
}

- (void)interfaceDidRotate
{
  if (self.isPresenting && self.dismissingEnabled) {
    // Cancel the previous dismissal restart dismissal clock
    dispatch_async(dispatch_get_main_queue(), ^{
      [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(dismiss) object:self];
      [self performSelector:@selector(dismiss) withObject:self afterDelay:self.duration];
    });
  }
}

/**
 Get the custom vertical offset from the delegate if any
 @return a custom vertical offset or 0.f
 */
- (CGFloat)customVerticalOffset
{
  CGFloat customVerticalOffset = 0.f;
  if (self.delegate && [self.delegate respondsToSelector:@selector(customVerticalOffsetForMessageView:)]) {
    customVerticalOffset = [self.delegate customVerticalOffsetForMessageView:self];
  }
  return customVerticalOffset;
}

- (NSTextAlignment)textAlignmentForString:(NSString *)textAlignment
{
  if ([textAlignment isEqualToString:@"left"]) {
    return NSTextAlignmentLeft;
  } else if ([textAlignment isEqualToString:@"right"]) {
    return NSTextAlignmentRight;
  } else if ([textAlignment isEqualToString:@"center"]) {
    return NSTextAlignmentCenter;
  } else if ([textAlignment isEqualToString:@"justified"]) {
    return NSTextAlignmentJustified;
  } else if ([textAlignment isEqualToString:@"natural"]) {
    return NSTextAlignmentNatural;
  } else {
    return NSTextAlignmentLeft;
  }
}

@end
