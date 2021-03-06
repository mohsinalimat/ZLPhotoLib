//
//  ZLPhotoPickerBrowserViewController.m
//  ZLAssetsPickerDemo
//
//  Created by 张磊 on 14-11-14.
//  Copyright (c) 2014年 com.zixue101.www. All rights reserved.
//

#import <AssetsLibrary/AssetsLibrary.h>
#import <objc/runtime.h>
#import "ZLPhotoPickerBrowserViewController.h"
#import "ZLPhotoPickerBrowserPhoto.h"
#import "ZLPhotoPickerDatas.h"
#import "UIView+ZLExtension.h"
#import "ZLPhotoPickerBrowserPhotoScrollView.h"
#import "ZLPhotoPickerCommon.h"
#import "ZLCollectionViewFlowLyout.h"
#import "UIImage+ZLPhotoLib.h"

static NSString *_cellIdentifier = @"collectionViewCell";

@interface ZLPhotoPickerBrowserViewController () <UIScrollViewDelegate,ZLPhotoPickerPhotoScrollViewDelegate,UICollectionViewDataSource,UICollectionViewDelegate>

// 控件
@property (weak,nonatomic) UILabel          *pageLabel;
@property (weak,nonatomic) UIButton         *deleleBtn;
@property (weak,nonatomic) UIButton         *backBtn;
@property (weak,nonatomic) UICollectionView *collectionView;

// 数据相关
// 单击时执行销毁的block
@property (nonatomic , copy) ZLPickerBrowserViewControllerTapDisMissBlock disMissBlock;
// 当前提供的分页数
@property (nonatomic , assign) NSInteger currentPage;
@end


@implementation ZLPhotoPickerBrowserViewController

#pragma mark - getter
#pragma mark photos
- (NSArray *)photos{
    if (!_photos) {
        _photos = [self getPhotos];
    }
    return _photos;
}

#pragma mark collectionView
- (UICollectionView *)collectionView{
    if (!_collectionView) {
        UICollectionViewFlowLayout *flowLayout = [[UICollectionViewFlowLayout alloc] init];
        flowLayout.minimumLineSpacing = ZLPickerColletionViewPadding;
        flowLayout.itemSize = self.view.size;
        flowLayout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
        
        UICollectionView *collectionView = [[UICollectionView alloc] initWithFrame:CGRectMake(0, 0, self.view.width + ZLPickerColletionViewPadding,self.view.height) collectionViewLayout:flowLayout];
        collectionView.showsHorizontalScrollIndicator = NO;
        collectionView.showsVerticalScrollIndicator = NO;
        collectionView.pagingEnabled = YES;
        collectionView.backgroundColor = [UIColor clearColor];
        collectionView.bounces = YES;
        collectionView.delegate = self;
        collectionView.dataSource = self;
        [collectionView registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:_cellIdentifier];
        
        [self.view addSubview:collectionView];
        self.collectionView = collectionView;
        
        _collectionView.translatesAutoresizingMaskIntoConstraints = NO;
        [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-0-[_collectionView]-x-|" options:0 metrics:@{@"x":@(-20)} views:@{@"_collectionView":_collectionView}]];
        [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-0-[_collectionView]-0-|" options:0 metrics:nil views:@{@"_collectionView":_collectionView}]];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(changeRotationDirection:) name:UIDeviceOrientationDidChangeNotification object:nil];
        
        self.pageLabel.hidden = NO;
        self.deleleBtn.hidden = !self.isEditing;
    }
    return _collectionView;
}

#pragma mark deleleBtn
- (UIButton *)deleleBtn{
    if (!_deleleBtn) {
        UIButton *deleleBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        deleleBtn.translatesAutoresizingMaskIntoConstraints = NO;
        deleleBtn.titleLabel.font = [UIFont systemFontOfSize:15];
        //        [deleleBtn setTitle:@"删除" forState:UIControlStateNormal];
        [deleleBtn setImage:[UIImage ml_imageFromBundleNamed:@"nav_delete_btn"] forState:UIControlStateNormal];
        
        // 设置阴影
        deleleBtn.layer.shadowColor = [UIColor blackColor].CGColor;
        deleleBtn.layer.shadowOffset = CGSizeMake(0, 0);
        deleleBtn.layer.shadowRadius = 3;
        deleleBtn.layer.shadowOpacity = 1.0;
        
        [deleleBtn addTarget:self action:@selector(delete) forControlEvents:UIControlEventTouchUpInside];
        deleleBtn.hidden = YES;
        [self.view addSubview:deleleBtn];
        self.deleleBtn = deleleBtn;
        
        NSString *widthVfl = @"H:[deleleBtn(deleteBtnWH)]-margin-|";
        NSString *heightVfl = @"V:|-margin-[deleleBtn(deleteBtnWH)]";
        NSDictionary *metrics = @{@"deleteBtnWH":@(50),@"margin":@(10)};
        NSDictionary *views = NSDictionaryOfVariableBindings(deleleBtn);
        
        [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:widthVfl options:0 metrics:metrics views:views]];
        [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:heightVfl options:0 metrics:metrics views:views]];
        
    }
    return _deleleBtn;
}

#pragma mark pageLabel
- (UILabel *)pageLabel{
    if (!_pageLabel) {
        UILabel *pageLabel = [[UILabel alloc] init];
        pageLabel.font = [UIFont systemFontOfSize:18];
        pageLabel.textAlignment = NSTextAlignmentCenter;
        pageLabel.userInteractionEnabled = NO;
        pageLabel.translatesAutoresizingMaskIntoConstraints = NO;
        pageLabel.backgroundColor = [UIColor clearColor];
        pageLabel.textColor = [UIColor whiteColor];
        [self.view addSubview:pageLabel];
        self.pageLabel = pageLabel;
        
        NSString *widthVfl = @"H:|-0-[pageLabel]-0-|";
        NSString *heightVfl = @"V:[pageLabel(ZLPickerPageCtrlH)]-20-|";
        NSDictionary *views = NSDictionaryOfVariableBindings(pageLabel);
        NSDictionary *metrics = @{@"ZLPickerPageCtrlH":@(ZLPickerPageCtrlH)};
        
        [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:widthVfl options:0 metrics:metrics views:views]];
        [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:heightVfl options:0 metrics:metrics views:views]];
        
    }
    return _pageLabel;
}

#pragma mark - Life cycle
- (void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    if (self.photos.count == 0) {
        NSAssert(self.dataSource, @"你没成为数据源代理");
    }
    // 初始化动画
    [self showToView];
}

- (void)showToView{
    _photos = [_photos copy];
    UIView *mainView = [[UIView alloc] init];
    mainView.backgroundColor = [UIColor blackColor];
    mainView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    mainView.frame = [UIScreen mainScreen].bounds;
    [[UIApplication sharedApplication].keyWindow addSubview:mainView];
    
    UIImageView *toImageView = nil;
    if(self.status == UIViewAnimationAnimationStatusZoom){
        if ([self isDataSourceElsePhotos]) {
            toImageView = (UIImageView *)[[self.dataSource photoBrowser:self photoAtIndexPath:self.currentIndexPath] toView];
        }else{
            toImageView = (UIImageView *)[self.photos[self.currentIndexPath.row] toView];
        }
    }
    
    if (![toImageView isKindOfClass:[UIImageView class]] && self.status != UIViewAnimationAnimationStatusFade) {
        assert(@"error: need toView `UIImageView` class.");
        return;
    }
    
    UIImageView *imageView = [[UIImageView alloc] init];
    imageView.userInteractionEnabled = YES;
    imageView.contentMode = UIViewContentModeScaleAspectFill;
    imageView.clipsToBounds = YES;
    [mainView addSubview:imageView];
    mainView.clipsToBounds = YES;
    
    UIImage *thumbImage = nil;
    if ([self isDataSourceElsePhotos]) {
        if ([self.photos[self.currentIndexPath.item] asset] == nil) {
            thumbImage = [[self.dataSource photoBrowser:self photoAtIndexPath:self.currentIndexPath] thumbImage];
        }else{
            thumbImage = [[self.dataSource photoBrowser:self photoAtIndexPath:self.currentIndexPath] photoImage];
        }
    }else{
        if ([self.photos[self.currentPage] asset] == nil) {
            thumbImage = [self.photos[self.currentIndexPath.item] thumbImage];
        }else{
            thumbImage = [self.photos[self.currentIndexPath.item] photoImage];
        }
    }
    
    if (self.status == UIViewAnimationAnimationStatusFade){
        imageView.image = thumbImage;
    }else{
        if (thumbImage == nil) {
            imageView.image = toImageView.image;
        }else{
            imageView.image = thumbImage;
        }
    }
    
    if (self.status == UIViewAnimationAnimationStatusFade){
        imageView.alpha = 0.0;
        imageView.frame = [self setMaxMinZoomScalesForCurrentBounds:imageView.image];
    }else if(self.status == UIViewAnimationAnimationStatusZoom){
        CGRect tempF = [toImageView.superview convertRect:toImageView.frame toView:[self getParsentView:toImageView]];
        if (self.navigationHeight) {
            tempF.origin.y += self.navigationHeight;
        }
        imageView.frame = tempF;
    }
    
    __block UIInterfaceOrientation orientation = self.interfaceOrientation;
    __weak typeof(self)weakSelf = self;
    self.disMissBlock = ^(NSInteger page){
        mainView.hidden = NO;
        mainView.alpha = 1.0;
        CGRect originalFrame = CGRectZero;
        [weakSelf dismissViewControllerAnimated:NO completion:nil];
        
        // 缩放动画
        if(self.status == UIViewAnimationAnimationStatusZoom){
            UIImage *thumbImage = nil;
            if ([weakSelf isDataSourceElsePhotos]) {
                if ([self.photos[self.currentPage] asset] == nil) {
                    thumbImage = [[weakSelf.dataSource photoBrowser:weakSelf photoAtIndexPath:[NSIndexPath indexPathForItem:page inSection:weakSelf.currentIndexPath.section]] thumbImage];
                }else{
                    thumbImage = [[weakSelf.dataSource photoBrowser:weakSelf photoAtIndexPath:[NSIndexPath indexPathForItem:page inSection:weakSelf.currentIndexPath.section]] photoImage];
                }
                
            }else{
                if ([weakSelf.photos[page] asset] == nil) {
                    thumbImage = [weakSelf.photos[page] thumbImage];
                }else{
                    thumbImage = [weakSelf.photos[page] photoImage];
                }
            }
            
            ZLPhotoPickerBrowserPhoto *photo = weakSelf.photos[page];
            if (thumbImage == nil) {
                imageView.image = [(UIImageView *)[photo toView] image];
            }else{
                imageView.image = thumbImage;
            }
            
            CGRect ivFrame = [weakSelf setMaxMinZoomScalesForCurrentBounds:thumbImage];
            if (!CGRectEqualToRect(ivFrame, CGRectZero)) {
                imageView.frame = ivFrame;
            }
            UIImageView *toImageView2 = nil;
            if ([weakSelf isDataSourceElsePhotos]) {
                toImageView2 = (UIImageView *)[[weakSelf.dataSource photoBrowser:weakSelf photoAtIndexPath:[NSIndexPath indexPathForItem:page inSection:weakSelf.currentIndexPath.section]] toView];
            }else{
                toImageView2 = (UIImageView *)[weakSelf.photos[page] toView];
            }
            
            originalFrame = [toImageView2.superview convertRect:toImageView2.frame toView:[weakSelf getParsentView:toImageView2]];
        }else{
            // 淡入淡出
            imageView.clipsToBounds = NO;
            UIImage *thumbImage = nil;
            if ([weakSelf isDataSourceElsePhotos]) {
                if ([self.photos[self.currentPage] asset] == nil) {
                    thumbImage = [[weakSelf.dataSource photoBrowser:weakSelf photoAtIndexPath:[NSIndexPath indexPathForItem:page inSection:weakSelf.currentIndexPath.section]] thumbImage];
                }else{
                    thumbImage = [[weakSelf.dataSource photoBrowser:weakSelf photoAtIndexPath:[NSIndexPath indexPathForItem:page inSection:weakSelf.currentIndexPath.section]] photoImage];
                }
                
            }else{
                if ([weakSelf.photos[page] asset] == nil) {
                    thumbImage = [weakSelf.photos[page] thumbImage];
                }else{
                    thumbImage = [weakSelf.photos[page] photoImage];
                }
            }
            
            ZLPhotoPickerBrowserPhoto *photo = weakSelf.photos[page];
            if (thumbImage == nil && [(UIImageView *)[photo toView] image] != nil) {
                imageView.image = [(UIImageView *)[photo toView] image];
            }
            
            CGRect ivFrame = [weakSelf setMaxMinZoomScalesForCurrentBounds:thumbImage];
            if (!CGRectEqualToRect(ivFrame, CGRectZero)) {
                imageView.frame = ivFrame;
            }
        }
        
        if (weakSelf.navigationHeight) {
            originalFrame.origin.y += weakSelf.navigationHeight;
        }
        
        [UIView animateWithDuration:0.35 animations:^{
            if (weakSelf.status == UIViewAnimationAnimationStatusFade){
                imageView.alpha = 0.0;
                mainView.alpha = 0.0;
            }else if(weakSelf.status == UIViewAnimationAnimationStatusZoom){
                mainView.backgroundColor = [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.0];
                imageView.frame = originalFrame;
            }
        } completion:^(BOOL finished) {
            imageView.alpha = 1.0;
            mainView.alpha = 1.0;
            [mainView removeFromSuperview];
            [imageView removeFromSuperview];
        }];
    };
    
    [weakSelf reloadData];
    [UIView animateWithDuration:0.35 animations:^{
        if (self.status == UIViewAnimationAnimationStatusFade){
            // 淡入淡出
            imageView.alpha = 1.0;
        }else if(self.status == UIViewAnimationAnimationStatusZoom){
            imageView.frame = [self setMaxMinZoomScalesForCurrentBounds:imageView.image];
        }
    } completion:^(BOOL finished) {
        mainView.hidden = YES;
    }];
}
- (CGRect)setMaxMinZoomScalesForCurrentBounds:(UIImage *)image{
    if (!([image isKindOfClass:[UIImage class]]) || image == nil) {
        if (!([image isKindOfClass:[UIImage class]])) {
            return CGRectZero;
        }
    }
    
    // Sizes
    CGSize boundsSize = [UIScreen mainScreen].bounds.size;
    CGSize imageSize = image.size;
    if (imageSize.width == 0 && imageSize.height == 0) {
        return CGRectZero;
    }
    
    CGFloat xScale = boundsSize.width / imageSize.width;    // the scale needed to perfectly fit the image width-wise
    CGFloat yScale = boundsSize.height / imageSize.height;  // the scale needed to perfectly fit the image height-wise
    CGFloat minScale = MIN(xScale, yScale);
//    CGFloat maxScale = MAX(xScale, yScale);
    // use minimum of these to allow the image to become fully visible
    // Image is smaller than screen so no zooming!
    if (xScale >= 1 && yScale >= 1) {
        minScale = MIN(xScale, yScale);
    }
    
    CGRect frameToCenter = CGRectZero;
//    if (xScale >= yScale) {
//        frameToCenter = CGRectMake(0, 0, imageSize.width * maxScale, imageSize.height * maxScale);
//        
//    }else {
        if (minScale >= 3) {
            minScale = 3;
        }
        frameToCenter = CGRectMake(0, 0, imageSize.width * minScale, imageSize.height * minScale);
//    }
    
    // Horizontally
    if (frameToCenter.size.width < boundsSize.width) {
        frameToCenter.origin.x = floorf((boundsSize.width - frameToCenter.size.width) / 2.0);
    } else {
        frameToCenter.origin.x = 0;
    }
    
    // Vertically
    if (frameToCenter.size.height < boundsSize.height) {
        frameToCenter.origin.y = floorf((boundsSize.height - frameToCenter.size.height) / 2.0);
    } else {
        frameToCenter.origin.y = 0;
    }
    
    return frameToCenter;
}


- (void)dealloc{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
}

#pragma mark - Get
#pragma mark getPhotos
- (NSArray *)getPhotos{
    NSMutableArray *photos = [NSMutableArray arrayWithArray:_photos];
    if ([self isDataSourceElsePhotos]) {
        NSInteger section = self.currentIndexPath.section;
        NSInteger rows = [self.dataSource photoBrowser:self numberOfItemsInSection:section];
        photos = [NSMutableArray arrayWithCapacity:rows];
        for (NSInteger i = 0; i < rows; i++) {
            [photos addObject:[self.dataSource photoBrowser:self photoAtIndexPath:[NSIndexPath indexPathForItem:i inSection:section]]];
        }
    }
    return photos;
}

#pragma mark get Controller.view
- (UIView *)getParsentView:(UIView *)view{
    if ([[view nextResponder] isKindOfClass:[UIViewController class]] || view == nil) {
        return view;
    }
    return [self getParsentView:view.superview];
}

- (id)getParsentViewController:(UIView *)view{
    if ([[view nextResponder] isKindOfClass:[UIViewController class]] || view == nil) {
        return [view nextResponder];
    }
    return [self getParsentViewController:view.superview];
}

#pragma mark - reloadData
#pragma mark - reloadData
- (void)reloadData{
    if (self.currentPage <= 0){
        self.currentPage = self.currentIndexPath.item;
    }else{
        --self.currentPage;
    }
    
    if (self.currentPage >= self.photos.count) {
        self.currentPage = self.photos.count - 1;
    }
    
    [self.collectionView reloadData];
    
    // 添加自定义View
    if ([self.delegate respondsToSelector:@selector(photoBrowserShowToolBarViewWithphotoBrowser:)]) {
        UIView *toolBarView = [self.delegate photoBrowserShowToolBarViewWithphotoBrowser:self];
        toolBarView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
        CGFloat width = self.view.width;
        CGFloat x = self.view.x;
        if (toolBarView.width) {
            width = toolBarView.width;
        }
        if (toolBarView.x) {
            x = toolBarView.x;
        }
        toolBarView.frame = CGRectMake(x, self.view.height - 44, width, 44);
        [self.view addSubview:toolBarView];
    }
    
    [self setPageLabelPage:self.currentPage];
    if (self.currentPage >= 0) {
        self.collectionView.contentOffset = CGPointMake(self.currentPage * self.collectionView.width, 0);
        if (self.currentPage == self.photos.count - 1 && self.photos.count > 1) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(00.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                self.collectionView.contentOffset = CGPointMake(self.currentPage * self.collectionView.width - ZLPickerColletionViewPadding, 0);
            });
        }
    }
}

- (UIColor *)randomColor{
    return [UIColor colorWithRed:arc4random_uniform(256)/255.0 green:arc4random_uniform(256)/255.0 blue:arc4random_uniform(256)/255.0 alpha:1.0];
}

- (NSInteger) collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section{
    if ([self isDataSourceElsePhotos]) {
        return [self.dataSource photoBrowser:self numberOfItemsInSection:self.currentIndexPath.section];
    }
    return self.photos.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath{
    
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:_cellIdentifier forIndexPath:indexPath];
    
    if (collectionView.isDragging) {
        cell.hidden = NO;
    }
    if (self.photos.count) {
        //        cell.backgroundColor = [UIColor clearColor];
        
        ZLPhotoPickerBrowserPhoto *photo = nil;
        
        if ([self isDataSourceElsePhotos]) {
            photo = [self.dataSource photoBrowser:self photoAtIndexPath:[NSIndexPath indexPathForItem:indexPath.item inSection:self.currentIndexPath.section]];
        }else{
            photo = self.photos[indexPath.item];
        }
        
        if([[cell.contentView.subviews lastObject] isKindOfClass:[UIView class]]){
            [[cell.contentView.subviews lastObject] removeFromSuperview];
        }
        
        CGRect tempF = [UIScreen mainScreen].bounds;
        
        UIView *scrollBoxView = [[UIView alloc] init];
        scrollBoxView.frame = tempF;
        scrollBoxView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
        [cell.contentView addSubview:scrollBoxView];
        
        ZLPhotoPickerBrowserPhotoScrollView *scrollView =  [[ZLPhotoPickerBrowserPhotoScrollView alloc] init];
        scrollView.sheet = self.sheet;
        // 为了监听单击photoView事件
        scrollView.frame = tempF;
        scrollView.tag = 101;
        scrollView.photoScrollViewDelegate = self;
        scrollView.photo = photo;
        __weak typeof(scrollBoxView)weakScrollBoxView = scrollBoxView;
        __weak typeof(self)weakSelf = self;
        if ([self.delegate respondsToSelector:@selector(photoBrowser:photoDidSelectView:atIndexPath:)]) {
            [[scrollBoxView subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];
            scrollView.callback = ^(id obj){
                [weakSelf.delegate photoBrowser:weakSelf photoDidSelectView:weakScrollBoxView atIndexPath:indexPath];
            };
        }
        
        [scrollBoxView addSubview:scrollView];
        scrollView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    }
    
    return cell;
}

- (NSUInteger)getRealPhotosCount{
    if ([self isDataSourceElsePhotos]) {
        return [self.dataSource photoBrowser:self numberOfItemsInSection:self.currentIndexPath.section];
    }
    return self.photos.count;
}


-(void)setPageLabelPage:(NSInteger)page{
    self.pageLabel.text = [NSString stringWithFormat:@"%ld / %ld",page + 1, self.photos.count];
}
#pragma mark - <UIScrollViewDelegate>
- (void)scrollViewDidScroll:(UIScrollView *)scrollView{
    CGRect tempF = self.collectionView.frame;
    NSInteger currentPage = (NSInteger)((scrollView.contentOffset.x / scrollView.frame.size.width) + 0.5);
    if (tempF.size.width < [UIScreen mainScreen].bounds.size.width){
        tempF.size.width = [UIScreen mainScreen].bounds.size.width;
    }
    
    if ([self isDataSourceElsePhotos]) {
        if ((currentPage < [self.dataSource photoBrowser:self numberOfItemsInSection:self.currentIndexPath.section] - 1) || self.photos.count == 1) {
            tempF.origin.x = 0;
        }else{
            tempF.origin.x = -ZLPickerColletionViewPadding;
        }
    }else{
        if ((currentPage < self.photos.count - 1) || self.photos.count == 1) {
            tempF.origin.x = 0;
        }else{
            tempF.origin.x = -ZLPickerColletionViewPadding;
        }
    }
    
    self.collectionView.frame = tempF;
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView{
    NSInteger currentPage = (NSInteger)(scrollView.contentOffset.x / (scrollView.frame.size.width));
    if (currentPage == self.photos.count - 2) {
        currentPage = roundf((scrollView.contentOffset.x) / (scrollView.frame.size.width));
    }
    
    if (currentPage == self.photos.count - 1 && currentPage != self.currentPage && [[[UIDevice currentDevice] systemVersion] doubleValue] >= 8.0) {
        self.collectionView.contentOffset = CGPointMake(self.collectionView.contentOffset.x + ZLPickerColletionViewPadding, 0);
    }
    self.currentPage = currentPage;
    [self setPageLabelPage:currentPage];
    
    if ([self.delegate respondsToSelector:@selector(photoBrowser:didCurrentPage:)]) {
        [self.delegate photoBrowser:self didCurrentPage:self.currentPage];
    }
}

#pragma mark - 展示控制器
- (void)showPickerVc:(UIViewController *)vc{
    __weak typeof(vc)weakVc = vc;
    if (weakVc != nil) {
        [weakVc presentViewController:self animated:NO completion:nil];
    }
}

#pragma mark - 删除照片
- (void)delete{
    // 准备删除
    if ([self.delegate respondsToSelector:@selector(photoBrowser:willRemovePhotoAtIndexPath:)]) {
        if(![self.delegate photoBrowser:self willRemovePhotoAtIndexPath:[NSIndexPath indexPathForItem:self.currentPage inSection:self.currentIndexPath.section]]){
            return ;
        }
    }
    
    UIAlertView *removeAlert = [[UIAlertView alloc]
                                initWithTitle:@"确定要删除此图片？"
                                message:nil
                                delegate:self
                                cancelButtonTitle:@"取消"
                                otherButtonTitles:@"确定", nil];
    [removeAlert show];
}

- (BOOL)isDataSourceElsePhotos{
    return self.dataSource != nil;
}

#pragma mark - <UIAlertViewDelegate>
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex{
    if (buttonIndex == 1) {
        NSInteger page = self.currentPage;
        if ([self.delegate respondsToSelector:@selector(photoBrowser:removePhotoAtIndexPath:)]) {
            [self.delegate photoBrowser:self removePhotoAtIndexPath:[NSIndexPath indexPathForItem:page inSection:self.currentIndexPath.section]];
        }
        
        if (self.photos.count > self.currentPage || self.dataSource != nil) {
            NSMutableArray *photos = [NSMutableArray arrayWithArray:self.photos];
            [photos removeObjectAtIndex:self.currentPage];
            self.photos = photos;
        }
        
        if (page >= self.photos.count) {
            self.currentPage--;
        }
        
        self.status = UIViewAnimationAnimationStatusFade;
        UICollectionViewCell *cell = [self.collectionView cellForItemAtIndexPath:[NSIndexPath indexPathForItem:page inSection:self.currentIndexPath.section]];
        if (cell) {
            if([[[cell.contentView subviews] lastObject] isKindOfClass:[UIView class]]){
                
                [UIView animateWithDuration:.35 animations:^{
                    [[[cell.contentView subviews] lastObject] setAlpha:0.0];
                } completion:^(BOOL finished) {
                    [self reloadData];
                }];
            }
        }
        
        if (self.photos.count < 1)
        {
            [[NSNotificationCenter defaultCenter] removeObserver:self];
            [self dismissViewControllerAnimated:YES completion:nil];
            [[UIApplication sharedApplication] setStatusBarHidden:NO];
        }
    }
}

- (void)changeRotationDirection:(NSNotification *)noti{
    
    UICollectionViewFlowLayout *flowLayout = [[UICollectionViewFlowLayout alloc] init];
    flowLayout.minimumLineSpacing = ZLPickerColletionViewPadding;
    flowLayout.itemSize = self.view.size;
    flowLayout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    
    self.collectionView.alpha = 0.0;
    [self.collectionView setCollectionViewLayout:flowLayout animated:NO];
    
    [self.collectionView scrollToItemAtIndexPath:[NSIndexPath indexPathForItem:self.currentPage inSection:0] atScrollPosition:UICollectionViewScrollPositionLeft animated:NO];
    
    UICollectionViewCell *currentCell = [self.collectionView cellForItemAtIndexPath:[NSIndexPath indexPathForItem:self.currentPage inSection:0]];
    for (UICollectionViewCell *cell in [self.collectionView visibleCells]) {
        ZLPhotoPickerBrowserPhotoScrollView *scrollView = (ZLPhotoPickerBrowserPhotoScrollView *)[cell.contentView viewWithTag:101];
        [scrollView setMaxMinZoomScalesForCurrentBounds];
        cell.hidden = ![cell isEqual:currentCell];
    }
    
    [UIView animateWithDuration:.5 animations:^{
        self.collectionView.alpha = 1.0;
    }];
}

#pragma mark - <PickerPhotoScrollViewDelegate>
- (void)pickerPhotoScrollViewDidSingleClick:(ZLPhotoPickerBrowserPhotoScrollView *)photoScrollView{
    if (self.disMissBlock) {
        
        if (self.photos.count == 1) {
            self.currentPage = 0;
        }
        self.disMissBlock(self.currentPage);
    }else{
        [self dismissViewControllerAnimated:YES completion:nil];
    }
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - showHeadPortrait 放大缩小一张图片的情况下（查看头像）
- (void)showHeadPortrait:(UIImageView *)toImageView{
    [self showHeadPortrait:toImageView originUrl:nil];
}

- (void)showHeadPortrait:(UIImageView *)toImageView originUrl:(NSString *)originUrl{
    UIView *mainView = [[UIView alloc] init];
    mainView.backgroundColor = [UIColor blackColor];
    mainView.frame = [UIScreen mainScreen].bounds;
    [[UIApplication sharedApplication].keyWindow addSubview:mainView];
    
    CGRect tempF = [toImageView.superview convertRect:toImageView.frame toView:[self getParsentView:toImageView]];
    UIImageView *imageView = [[UIImageView alloc] init];
    imageView.userInteractionEnabled = YES;
    imageView.frame = tempF;
    imageView.image = toImageView.image;
    imageView.contentMode = UIViewContentModeScaleAspectFit;
    [mainView addSubview:imageView];
    mainView.clipsToBounds = YES;
    
    [UIView animateWithDuration:.25 animations:^{
        imageView.frame = [UIScreen mainScreen].bounds;
    } completion:^(BOOL finished) {
        imageView.hidden = YES;
        
        ZLPhotoPickerBrowserPhoto *photo = [[ZLPhotoPickerBrowserPhoto alloc] init];
        photo.photoURL = [NSURL URLWithString:originUrl];
        photo.photoImage = toImageView.image;
        photo.thumbImage = toImageView.image;
        
        ZLPhotoPickerBrowserPhotoScrollView *scrollView = [[ZLPhotoPickerBrowserPhotoScrollView alloc] init];
        
        __weak typeof(ZLPhotoPickerBrowserPhotoScrollView *)weakScrollView = scrollView;
        scrollView.callback = ^(id obj){
            [weakScrollView removeFromSuperview];
            mainView.backgroundColor = [UIColor clearColor];
            imageView.hidden = NO;
            [UIView animateWithDuration:.25 animations:^{
                imageView.frame = tempF;
            } completion:^(BOOL finished) {
                [mainView removeFromSuperview];
            }];
        };
        scrollView.frame = [UIScreen mainScreen].bounds;
        scrollView.photo = photo;
        [mainView addSubview:scrollView];
    }];
}

@end