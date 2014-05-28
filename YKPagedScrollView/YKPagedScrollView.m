//
//  YKPagedScrollView.m
//  YKPagedScrollView
//
//  Created by Yoshiki Kurihara on 2013/10/04.
//  Copyright (c) 2013年 Yoshiki Kurihara. All rights reserved.
//

#import "YKPagedScrollView.h"

#define kYKPagedScrollViewAdvancedLengthFactor 4
#define kYKPagedScrollViewNumberOfLazyLoading 1

@interface YKPagedScrollView ()

@property (nonatomic, strong) NSMutableSet *reusablePages;
@property (nonatomic, assign) NSInteger numberOfPage;

@end

@implementation YKPagedScrollView

@synthesize delegate = delegate_;

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self _initialize];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self _initialize];
    }
    return self;
}

- (void)setDataSource:(id<YKPagedScrollViewDataSource>)dataSource {
    _dataSource = dataSource;
    // Set bounds
    _scrollView.frame = [self rectForPage];
}

- (void)setFrame:(CGRect)frame {
    [super setFrame:frame];
    _scrollView.frame = [self rectForPage];
    [self reloadData];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    if (_infinite) {
        [self relocateContentOffset];
    }
    
    NSArray *indexes = [self indexesForPage];
    
    NSMutableSet *visiblePages = [NSMutableSet set];
    for (NSNumber *i in indexes) {
        NSInteger index = [i integerValue];
        UIView *page = [self pageAtIndex:index];
        page.tag = index;
        page.frame = [self rectForPageAtIndex:index];
        [_scrollView addSubview:page];
        [visiblePages addObject:page];
    }
    
    // remove current visible pages temporary.
    [_visiblePages minusSet:visiblePages];
    
    // now _visiblePages has only reusable pages.
    NSSet *reusablePages = _visiblePages;
    for (UIView *reusablePage in reusablePages) {
        [reusablePage removeFromSuperview];
    }
    [_reusablePages unionSet:reusablePages];
    
    // set new visible pages.
    _visiblePages = visiblePages;
}

#pragma mark - Private methods

- (void)_initialize {
    _numberOfPage = 0;
    _reusablePages = [NSMutableSet set];
    _visiblePages = [NSMutableSet set];
    _direction = YKPagedScrollViewDirectionHorizontal; // default
    _infinite = NO; // default
    _pagingEnabled = YES; // default

    _scrollView = [[UIScrollView alloc] initWithFrame:self.bounds];
    _scrollView.delegate = self;
    _scrollView.showsHorizontalScrollIndicator = NO;
    _scrollView.showsVerticalScrollIndicator = NO;
    _scrollView.pagingEnabled = _pagingEnabled;
    _scrollView.clipsToBounds = NO;
    [self addSubview:_scrollView];

    [self reloadData];
}

- (NSArray *)indexesForPage {
    NSMutableArray *indexes = @[].mutableCopy;
    int startIndex = [self startIndex];
    int endIndex = [self endIndex];
    for (int i = startIndex; i <= endIndex; i++) {
        [indexes addObject:@(i)];
    }
    return indexes;
}

- (int)originalStartIndex {
    int startIndex = ((_direction == YKPagedScrollViewDirectionHorizontal)
                      ? (int)(_scrollView.contentOffset.x / [self rectForPage].size.width)
                      : (int)(_scrollView.contentOffset.y / [self rectForPage].size.height));
    return startIndex;
}

- (int)startIndex {
    int originalStartIndex = [self originalStartIndex];
    int startIndex = 0;
    if (_infinite) {
        startIndex = MAX(originalStartIndex - [self numberOfLazyLoading], 0);
    } else {
        if (originalStartIndex == 0) {
            startIndex = originalStartIndex;
        } else {
            startIndex = MAX(originalStartIndex - [self numberOfLazyLoading], 0);
        }
    }
    return startIndex;
}

- (int)endIndex {
    int originalStartIndex = [self originalStartIndex];
    int endIndex;
    if (_infinite) {
        endIndex = originalStartIndex + [self numberOfLazyLoading];
    } else {
        if (originalStartIndex == 0) {
            endIndex = originalStartIndex + [self numberOfLazyLoading];
        } else if (originalStartIndex == [self numberOfPage] - 2) {
            endIndex = originalStartIndex + [self numberOfLazyLoading] - 1;
        } else if (originalStartIndex == [self numberOfPage] - 1) {
            endIndex = originalStartIndex;
        } else {
            endIndex = originalStartIndex + [self numberOfLazyLoading];
        }
    }
    return endIndex;
}

- (UIView *)pageAtIndex:(NSInteger)index {
    UIView *page = [self visiblePageAtIndex:index];
    if (page != nil) {
        [page removeFromSuperview];
        return page;
    } else {
        NSInteger externalIndex = [self convertIndexFromInternalIndex:index];
        UIView *page = [self.dataSource pagedScrollView:self viewForPageAtIndex:externalIndex];
        return page;
    }
}

- (NSInteger)convertIndexFromInternalIndex:(NSInteger)index {
    return ((index < _numberOfPage)
            ? index
            : index % _numberOfPage);
}

- (CGRect)rectForPage {
    if ([self.dataSource respondsToSelector:@selector(rectForPage)]) {
        return [self.dataSource rectForPage];
    } else {
        return self.bounds;
    }
}

- (CGRect)rectForPageAtIndex:(NSInteger)index {
    if (_direction == YKPagedScrollViewDirectionHorizontal) {
        return (CGRect){
            .origin = (CGPoint){ [self rectForPage].size.width * index, 0.0f },
            .size = [self rectForPage].size,
        };
    } else {
        return (CGRect){
            .origin = (CGPoint){ 0.0f, [self rectForPage].size.height * index },
            .size = [self rectForPage].size,
        };
    }
}

- (UIView *)visiblePageAtIndex:(NSInteger)index {
    UIView *page = nil;
    for (UIView *_page in [_visiblePages allObjects]) {
        if (_page.tag == index) {
            page = _page;
            break;
        }
    }
    return page;
}

- (void)relocateContentOffset {
    if (_direction == YKPagedScrollViewDirectionHorizontal) {
        CGFloat offsetX = _scrollView.contentOffset.x;
        CGFloat maxX = [self rectForPage].size.width * _numberOfPage * (kYKPagedScrollViewAdvancedLengthFactor - 1);
        CGFloat minX = [self rectForPage].size.width * _numberOfPage;
        
        if (offsetX >= maxX) {
            _scrollView.contentOffset = (CGPoint){
                [self rectForPage].size.width * _numberOfPage * ((int)kYKPagedScrollViewAdvancedLengthFactor/2) + abs(offsetX - maxX),
                0.0f
            };
        } else if (offsetX <= minX) {
            offsetX += [self _contentOffset].x;
            _scrollView.contentOffset = (CGPoint){
                [self rectForPage].size.width * _numberOfPage * ((int)kYKPagedScrollViewAdvancedLengthFactor/2) + abs(offsetX - minX),
                0.0f
            };
        }
    } else {
        CGFloat offsetY = _scrollView.contentOffset.y;
        CGFloat maxY = [self rectForPage].size.height * _numberOfPage * (kYKPagedScrollViewAdvancedLengthFactor - 1);
        CGFloat minY = [self rectForPage].size.height * _numberOfPage;
        
        if (offsetY >= maxY) {
            _scrollView.contentOffset = (CGPoint){
                0.0f,
                [self rectForPage].size.height * _numberOfPage * ((int)kYKPagedScrollViewAdvancedLengthFactor/2) + abs(offsetY - maxY)
            };
        } else if (offsetY <= minY) {
            offsetY += [self _contentOffset].y;
            _scrollView.contentOffset = (CGPoint){
                0.0f,
                [self rectForPage].size.height * _numberOfPage * ((int)kYKPagedScrollViewAdvancedLengthFactor/2) + abs(offsetY - minY)
            };
        }
    }
}

- (NSInteger)numberOfLazyLoading {
    NSInteger num = 0;
    if ([self.dataSource respondsToSelector:@selector(numberOfPagesForLazyLoading)]) {
        num = [self.dataSource numberOfPagesForLazyLoading];
    } else {
        num = kYKPagedScrollViewNumberOfLazyLoading;
    }
    return (num > _numberOfPage) ? _numberOfPage : num;
}

- (CGSize)_contentSize {
    if (_infinite) {
        if (_direction == YKPagedScrollViewDirectionHorizontal) {
            return (CGSize){
                [self rectForPage].size.width * _numberOfPage * kYKPagedScrollViewAdvancedLengthFactor,
                [self rectForPage].size.height,
            };
        } else {
            return (CGSize){
                [self rectForPage].size.width,
                [self rectForPage].size.height * _numberOfPage * kYKPagedScrollViewAdvancedLengthFactor,
            };
        }
    } else {
        if (_direction == YKPagedScrollViewDirectionHorizontal) {
            return (CGSize){
                [self rectForPage].size.width * _numberOfPage,
                [self rectForPage].size.height,
            };
        } else {
            return (CGSize){
                [self rectForPage].size.width,
                [self rectForPage].size.height * _numberOfPage,
            };
        }
    }
}

- (CGPoint)_contentOffset {
    if (_infinite) {
        if (_direction == YKPagedScrollViewDirectionHorizontal) {
            return (CGPoint){
                [self rectForPage].size.width * _numberOfPage * ((int)kYKPagedScrollViewAdvancedLengthFactor/2),
                0.0f
            };
        } else {
            return (CGPoint){
                0.0f,
                [self rectForPage].size.height * _numberOfPage * ((int)kYKPagedScrollViewAdvancedLengthFactor/2),
            };
        }
    } else {
        return (CGPoint){
            0.0f,
            0.0f
        };
    }
}

- (void)pageDidChangeToIndex:(NSNumber *)index {
    if ([self.delegate respondsToSelector:@selector(pagedScrollView:pageDidChangeTo:)]) {
        [self.delegate pagedScrollView:self pageDidChangeTo:[index integerValue]];
    }
}

- (void)pageDidChangeToNext {
    if ([self.delegate respondsToSelector:@selector(pagedScrollView:pageDidChangeTo:)]) {
        [self.delegate pagedScrollView:self pageDidChangeTo:[self nextIndex]];
    }
}

- (void)pageDidChangeToPrevious {
    if ([self.delegate respondsToSelector:@selector(pagedScrollView:pageDidChangeTo:)]) {
        [self.delegate pagedScrollView:self pageDidChangeTo:[self previousIndex]];
    }
}

- (void)pageWillChange {
    if ([self.delegate respondsToSelector:@selector(pagedScrollView:pageWillChangeFrom:)]) {
        [self.delegate pagedScrollView:self pageWillChangeFrom:[self currentIndex]];
    }
}

#pragma mark - Public methods

- (void)setDelegate:(id<YKPagedScrollViewDelegate>)delegate {
    [_scrollView setDelegate:self];
    if (delegate_ != delegate) {
        delegate_ = delegate;
    }
}

- (void)setPagingEnabled:(BOOL)pagingEnabled {
    _pagingEnabled = pagingEnabled;
    _scrollView.pagingEnabled = _pagingEnabled;
}

- (void)reloadData {
    for (UIView *page in [_visiblePages allObjects]) {
        [page removeFromSuperview];
    }
    
    [_reusablePages removeAllObjects];
    [_visiblePages removeAllObjects];
    
    _numberOfPage = [self.dataSource numberOfPagesInPagedScrollView];
    _scrollView.contentSize = [self _contentSize];
    _scrollView.contentOffset = [self _contentOffset];
}

- (UIView *)dequeueReusablePage {
    UIView *reusablePage = [_reusablePages anyObject];
    if (reusablePage != nil) {
        [_reusablePages removeObject:reusablePage];
        return reusablePage;
    } else {
        return nil;
    }
}

- (NSArray *)storedPages {
    NSMutableArray *pages = @[].mutableCopy;
    [pages addObjectsFromArray:[_visiblePages allObjects]];
    [pages addObjectsFromArray:[_reusablePages allObjects]];
    return pages;
}

- (NSInteger)currentIndex {
    int index = [self originalStartIndex];
    return [self convertIndexFromInternalIndex:index];
}

- (NSInteger)nextIndex {
    NSInteger currentIndex = [self currentIndex];
    if (currentIndex == [self numberOfPage] - 1) {
        return 0;
    } else {
        return currentIndex + 1;
    }
}

- (NSInteger)previousIndex {
    NSInteger currentIndex = [self currentIndex];
    if (currentIndex == 0) {
        return [self numberOfPage];
    } else {
        return currentIndex - 1;
    }
}

- (UIView *)currentPage {
    return [self visiblePageAtIndex:[self startIndex]];
}

- (void)scrollToIndex:(NSInteger)index animated:(BOOL)animated {
    if ([self currentIndex] == index) return;
    [self performSelector:@selector(pageWillChange) withObject:nil afterDelay:0.0f];
    NSInteger toIndex = [self originalStartIndex] + (index - [self currentIndex]);
    [_scrollView scrollRectToVisible:[self rectForPageAtIndex:toIndex] animated:animated];
    [self performSelector:@selector(pageDidChangeToIndex:) withObject:@(index) afterDelay:0.1f];
}

- (void)scrollToNextPageAnimated:(BOOL)animated {
    if (!_infinite && [self currentIndex] == _numberOfPage - 1) return;
    NSInteger nextPageIndex = [self originalStartIndex] + 1;
    [self performSelector:@selector(pageWillChange) withObject:nil afterDelay:0.0f];
    [_scrollView scrollRectToVisible:[self rectForPageAtIndex:nextPageIndex] animated:animated];
    [self performSelector:@selector(pageDidChangeToNext) withObject:nil afterDelay:0.1f];
}

- (void)scrollToPreviousPageAnimated:(BOOL)animated {
    if (!_infinite && [self currentIndex] == 0) return;
    NSInteger previousPageIndex = [self originalStartIndex] - 1;
    [self performSelector:@selector(pageWillChange) withObject:nil afterDelay:0.0f];
    [_scrollView scrollRectToVisible:[self rectForPageAtIndex:previousPageIndex] animated:animated];
    [self performSelector:@selector(pageDidChangeToPrevious) withObject:nil afterDelay:0.1f];
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    [self pageDidChangeToIndex:@([self currentIndex])];
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    [self pageWillChange];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    [self setNeedsLayout];
}

#pragma mark - UIView hit test

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if ([self pointInside:point withEvent:event]) {
        CGPoint newPoint = CGPointZero;
        newPoint.x = point.x - _scrollView.frame.origin.x + _scrollView.contentOffset.x;
        newPoint.y = point.y - _scrollView.frame.origin.y + _scrollView.contentOffset.y;
        if ([_scrollView pointInside:newPoint withEvent:event]) {
            return [_scrollView hitTest:newPoint withEvent:event];
        }
        return _scrollView;
    }
    return nil;
}

@end
