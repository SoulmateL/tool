//
//  LatexWebViewManager.m
//  SKB
//
//  Created by Apple on 2025/10/14.
//

#import "LatexWebViewManager.h"
#import <WebKit/WebKit.h>
#import <SDWebImage/SDImageCache.h>

@interface LatexWebViewManager () <WKScriptMessageHandler>

@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic, assign) BOOL isKatexReady;

// 线程安全队列
@property (nonatomic) dispatch_queue_t syncQueue;

// batchId -> completion
@property (nonatomic, strong) NSMutableDictionary<NSString *, void(^)(NSArray<UIImage *> *images)> *completionMap;
// batchId -> latex array (未缓存的)
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSArray<NSString *> *> *pendingLatex;
// batchId -> timeout timer
@property (nonatomic, strong) NSMutableDictionary<NSString *, dispatch_source_t> *timeoutMap;

// 并发控制
@property (nonatomic, strong) NSMutableArray<NSString *> *taskQueue;
@property (nonatomic, assign) NSUInteger maxConcurrentBatches;
@property (nonatomic, assign) NSUInteger runningBatches;

@end

@implementation LatexWebViewManager

+ (instancetype)sharedManager {
    static LatexWebViewManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[LatexWebViewManager alloc] initPrivate];
    });
    return manager;
}

- (instancetype)initPrivate {
    if (self = [super init]) {
        _syncQueue = dispatch_queue_create("com.skb.latexwm.queue", DISPATCH_QUEUE_SERIAL);
        _completionMap = [NSMutableDictionary dictionary];
        _pendingLatex = [NSMutableDictionary dictionary];
        _timeoutMap = [NSMutableDictionary dictionary];
        _taskQueue = [NSMutableArray array];
        _maxConcurrentBatches = 2;
        _runningBatches = 0;
        
        WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
        WKUserContentController *userController = [[WKUserContentController alloc] init];
        [userController addScriptMessageHandler:self name:@"katexHandler"];
        [userController addScriptMessageHandler:self name:@"katexReadyHandler"];
        config.userContentController = userController;
        
        _webView = [[WKWebView alloc] initWithFrame:CGRectMake(0, 0, 1, 1) configuration:config];
        _webView.backgroundColor = [UIColor clearColor];
        _webView.opaque = NO;
        _webView.scrollView.scrollEnabled = NO;
        
        NSURL *htmlURL = [[NSBundle mainBundle] URLForResource:@"LaTex2Img" withExtension:@"html"];
        NSURL *baseURL = [htmlURL URLByDeletingLastPathComponent];
        [_webView loadFileURL:htmlURL allowingReadAccessToURL:baseURL];
    }
    return self;
}

#pragma mark - Public Interface

- (void)renderFormulas:(NSArray<NSString *> *)latexArray
            completion:(void(^)(NSArray<UIImage *> *images))completion {
    if (!latexArray.count || !completion) return;
    
    dispatch_async(self.syncQueue, ^{
        if (!self.isKatexReady) {
            NSLog(@"❌ KaTeX 环境未就绪");
            return;
        }
        
        NSString *batchId = [NSString stringWithFormat:@"batch_%@", NSUUID.UUID.UUIDString];
        self.completionMap[batchId] = [completion copy];
        
        // 先检查缓存
        NSMutableArray<UIImage *> *cachedImages = [NSMutableArray arrayWithCapacity:latexArray.count];
        NSMutableArray<NSString *> *pendingLatex = [NSMutableArray array];
        
        for (NSString *latex in latexArray) {
            NSString *cacheKey = [self cacheKeyForLatex:latex scale:2];
//            UIImage *img = [[SDImageCache sharedImageCache] imageFromCacheForKey:cacheKey];
            UIImage *img = nil;
            if (img) {
                [cachedImages addObject:img];
            } else {
                [cachedImages addObject:(id)[NSNull null]];
                [pendingLatex addObject:latex];
            }
        }
        
        // 全部命中
        if (pendingLatex.count == 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion([cachedImages copy]);
            });
            [self.completionMap removeObjectForKey:batchId];
            return;
        }
        
        self.pendingLatex[batchId] = [pendingLatex copy];
        
        // 加入任务队列
        [self.taskQueue addObject:batchId];
        [self tryExecuteNextBatch];
    });
}

- (void)cancelBatch:(NSString *)batchId {
    dispatch_async(self.syncQueue, ^{
        [self cleanupBatch:batchId];
    });
}

#pragma mark - Private

- (void)tryExecuteNextBatch {
    dispatch_async(self.syncQueue, ^{
        if (self.runningBatches >= self.maxConcurrentBatches) return;
        if (!self.taskQueue.count) return;
        
        NSString *batchId = self.taskQueue.firstObject;
        [self.taskQueue removeObjectAtIndex:0];
        self.runningBatches++;
        
        NSArray<NSString *> *pending = self.pendingLatex[batchId];
        if (!pending) {
            [self batchFinished:batchId images:@[]];
            return;
        }
        
        NSError *error = nil;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:pending options:0 error:&error];
        if (error) {
            NSLog(@"❌ JSON 序列化失败: %@", error);
            [self batchFinished:batchId images:@[]];
            return;
        }
        NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        // 再把反斜杠和单引号做转义
        jsonString = [jsonString stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
        jsonString = [jsonString stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"];

        NSString *js = [NSString stringWithFormat:@"renderFormulasBatch('%@', '%@', 2)", batchId, jsonString];
        
        // 启动超时 timer
        dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.syncQueue);
        dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, 15*NSEC_PER_SEC), DISPATCH_TIME_FOREVER, 0);
        dispatch_source_set_event_handler(timer, ^{
            NSLog(@"⚠️ Batch %@ 超时", batchId);
            [self batchFinished:batchId images:@[]];
        });
        dispatch_resume(timer);
        self.timeoutMap[batchId] = timer;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.webView evaluateJavaScript:js completionHandler:^(id result, NSError *err) {
                if (err) {
                    NSLog(@"❌ JS 调用失败: %@", err);
                    dispatch_async(self.syncQueue, ^{
                        [self batchFinished:batchId images:@[]];
                    });
                }
            }];
        });
    });
}

- (void)batchFinished:(NSString *)batchId images:(NSArray<UIImage *> *)images {
    dispatch_async(self.syncQueue, ^{
        void (^completion)(NSArray<UIImage *> *) = self.completionMap[batchId];
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(images);
            });
        }
        [self cleanupBatch:batchId];
        self.runningBatches--;
        [self tryExecuteNextBatch];
    });
}

- (void)cleanupBatch:(NSString *)batchId {
    [self.completionMap removeObjectForKey:batchId];
    [self.pendingLatex removeObjectForKey:batchId];
    dispatch_source_t timer = self.timeoutMap[batchId];
    if (timer) {
        dispatch_source_cancel(timer);
        [self.timeoutMap removeObjectForKey:batchId];
    }
}

- (NSString *)cacheKeyForLatex:(NSString *)latex scale:(NSUInteger)scale {
    return [NSString stringWithFormat:@"%@_scale%lu", latex, (unsigned long)scale];
}

#pragma mark - WKScriptMessageHandler

- (void)userContentController:(WKUserContentController *)userContentController
      didReceiveScriptMessage:(WKScriptMessage *)message {
    if ([message.name isEqualToString:@"katexReadyHandler"]) {
        self.isKatexReady = [message.body boolValue];
        NSLog(@"✅ KaTeX 环境加载完成");
        return;
    }
    
    if ([message.name isEqualToString:@"katexHandler"]) {
        NSDictionary *payload = message.body;
        NSString *batchId = payload[@"batchId"];
        NSArray *results = payload[@"results"];
        if (!batchId || ![results isKindOfClass:[NSArray class]]) return;
        
        NSArray<NSString *> *pending = self.pendingLatex[batchId];
        if (!pending) return;
        
        NSMutableArray<UIImage *> *generated = [NSMutableArray arrayWithCapacity:pending.count];
        for (NSDictionary *item in results) {
            NSString *latex = item[@"latex"];
            NSString *base64 = item[@"base64"];
            if (![base64 isKindOfClass:[NSString class]]) continue;
            
            NSString *cleanBase64 = [[base64 componentsSeparatedByString:@","].lastObject copy];
            NSData *data = [[NSData alloc] initWithBase64EncodedString:cleanBase64 options:0];
            UIImage *img = [UIImage imageWithData:data];
            if (img) {
                NSString *cacheKey = [self cacheKeyForLatex:latex scale:2];
                [[SDImageCache sharedImageCache] storeImage:img forKey:cacheKey completion:nil];
                [generated addObject:img];
            }
        }
        
        // 按 pending 顺序填充
        NSMutableArray<UIImage *> *finalImages = [NSMutableArray arrayWithCapacity:pending.count];
        for (NSString *latex in pending) {
            NSString *cacheKey = [self cacheKeyForLatex:latex scale:2];
            UIImage *img = [[SDImageCache sharedImageCache] imageFromCacheForKey:cacheKey];
            [finalImages addObject:img ?: [UIImage new]];
        }
        
        [self batchFinished:batchId images:[finalImages copy]];
    }
}

@end
