//
//  LatexWebViewManager.h
//  SKB
//
//  Created by Apple on 2025/10/13.
//  Copyright © 2025 junjie. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LatexWebViewManager : NSObject <WKScriptMessageHandler>

@property (nonatomic, strong, readonly) WKWebView *webView;

/// 单例
+ (instancetype)sharedManager;

/// 渲染一组 LaTeX 公式
- (void)renderFormulas:(NSArray<NSString *> *)latexArray
            completion:(void(^)(NSArray<UIImage *> *images))completion;

@end


NS_ASSUME_NONNULL_END
