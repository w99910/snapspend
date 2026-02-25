// PaddleOcrPlugin.mm
// Flutter MethodChannel bridge for PaddleOCR on iOS

// clang-format off
#import <opencv2/opencv.hpp>
#import <opencv2/imgcodecs/ios.h>
// clang-format on

#import "PaddleOcrPlugin.h"
#include "pipeline.h"
#include <string>
#include <vector>
#include <mutex>

@interface PaddleOcrPlugin ()
@property (nonatomic, assign) Pipeline *pipeline;
@property (nonatomic, assign) BOOL isInitialized;
@end

static std::mutex sPipelineMutex;

@implementation PaddleOcrPlugin

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
    FlutterMethodChannel *channel =
        [FlutterMethodChannel methodChannelWithName:@"com.example.snapspend/paddle_ocr"
                                    binaryMessenger:[registrar messenger]];
    PaddleOcrPlugin *instance = [[PaddleOcrPlugin alloc] init];
    [registrar addMethodCallDelegate:instance channel:channel];
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _pipeline = nullptr;
        _isInitialized = NO;
    }
    return self;
}

- (void)dealloc {
    [self releasePipeline];
}

- (void)handleMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result {
    if ([@"init" isEqualToString:call.method]) {
        [self handleInit:call result:result];
    } else if ([@"runOCR" isEqualToString:call.method]) {
        [self handleRunOCR:call result:result];
    } else if ([@"release" isEqualToString:call.method]) {
        [self handleRelease:result];
    } else {
        result(FlutterMethodNotImplemented);
    }
}

- (void)handleInit:(FlutterMethodCall *)call result:(FlutterResult)result {
    if (_isInitialized) {
        result(@YES);
        return;
    }

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @try {
            NSDictionary *args = call.arguments;
            NSString *detModel = args[@"detModel"];
            NSString *recModel = args[@"recModel"];
            NSString *clsModel = args[@"clsModel"];
            NSString *configPath = args[@"configPath"];
            NSString *labelPath = args[@"labelPath"];

            // Resolve paths - if they start with "assets/", look in the Flutter bundle
            std::string detModelPath = [self resolveAssetPath:detModel];
            std::string recModelPath = [self resolveAssetPath:recModel];
            std::string clsModelPath = [self resolveAssetPath:clsModel];
            std::string configFilePath = [self resolveAssetPath:configPath];
            std::string labelFilePath = [self resolveAssetPath:labelPath];

            NSLog(@"PaddleOCR: Initializing pipeline...");
            NSLog(@"PaddleOCR: det=%s", detModelPath.c_str());
            NSLog(@"PaddleOCR: rec=%s", recModelPath.c_str());
            NSLog(@"PaddleOCR: cls=%s", clsModelPath.c_str());
            NSLog(@"PaddleOCR: config=%s", configFilePath.c_str());
            NSLog(@"PaddleOCR: label=%s", labelFilePath.c_str());

            std::lock_guard<std::mutex> lock(sPipelineMutex);

            self->_pipeline = new Pipeline(
                detModelPath,
                clsModelPath,
                recModelPath,
                "LITE_POWER_HIGH",
                1,
                configFilePath,
                labelFilePath
            );

            self->_isInitialized = YES;
            NSLog(@"PaddleOCR: Pipeline initialized successfully");

            dispatch_async(dispatch_get_main_queue(), ^{
                result(@YES);
            });
        } @catch (NSException *exception) {
            NSLog(@"PaddleOCR init error: %@", exception.reason);
            dispatch_async(dispatch_get_main_queue(), ^{
                result([FlutterError errorWithCode:@"INIT_ERROR"
                                           message:exception.reason
                                           details:nil]);
            });
        }
    });
}

- (void)handleRunOCR:(FlutterMethodCall *)call result:(FlutterResult)result {
    if (!_isInitialized || _pipeline == nullptr) {
        result([FlutterError errorWithCode:@"NOT_INITIALIZED"
                                   message:@"PaddleOCR pipeline not initialized. Call init() first."
                                   details:nil]);
        return;
    }

    NSString *imagePath = call.arguments[@"imagePath"];
    if (imagePath == nil || imagePath.length == 0) {
        result([FlutterError errorWithCode:@"INVALID_ARGUMENT"
                                   message:@"imagePath is required"
                                   details:nil]);
        return;
    }

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @try {
            std::string imgPath = std::string([imagePath UTF8String]);
            NSLog(@"PaddleOCR: Processing image: %s", imgPath.c_str());

            cv::Mat srcimg = cv::imread(imgPath);
            if (srcimg.empty()) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    result([FlutterError errorWithCode:@"IMAGE_ERROR"
                                               message:@"Failed to read image"
                                               details:imagePath]);
                });
                return;
            }

            std::vector<std::string> res_txt;
            std::string outputPath = imgPath + "_result.jpg";

            {
                std::lock_guard<std::mutex> lock(sPipelineMutex);
                self->_pipeline->Process(srcimg, outputPath, res_txt);
            }

            // Parse results: res_txt contains pairs of [text, score, text, score, ...]
            NSMutableArray *results = [NSMutableArray array];
            for (size_t i = 0; i + 1 < res_txt.size(); i += 2) {
                NSString *text = [NSString stringWithUTF8String:res_txt[i].c_str()];
                NSString *scoreStr = [NSString stringWithUTF8String:res_txt[i + 1].c_str()];
                double score = [scoreStr doubleValue];

                [results addObject:@{
                    @"text": text ?: @"",
                    @"score": @(score),
                }];
            }

            NSLog(@"PaddleOCR: Got %lu results from image", (unsigned long)results.count);

            dispatch_async(dispatch_get_main_queue(), ^{
                result(results);
            });
        } @catch (NSException *exception) {
            NSLog(@"PaddleOCR runOCR error: %@", exception.reason);
            dispatch_async(dispatch_get_main_queue(), ^{
                result([FlutterError errorWithCode:@"OCR_ERROR"
                                           message:exception.reason
                                           details:nil]);
            });
        }
    });
}

- (void)handleRelease:(FlutterResult)result {
    [self releasePipeline];
    result(@YES);
}

- (void)releasePipeline {
    std::lock_guard<std::mutex> lock(sPipelineMutex);
    if (_pipeline != nullptr) {
        delete _pipeline;
        _pipeline = nullptr;
    }
    _isInitialized = NO;
    NSLog(@"PaddleOCR: Pipeline released");
}

/// Resolve an asset path by copying from the Flutter bundle to a writable
/// directory.  PaddleLite's model loader cannot read files that live inside
/// the signed App.framework bundle, so we must copy them out first.
- (std::string)resolveAssetPath:(NSString *)path {
    if (path == nil) return "";

    // If it's already an absolute path and the file exists outside the bundle, use it
    if ([path hasPrefix:@"/"]) {
        if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
            return std::string([path UTF8String]);
        }
    }

    // Locate the file inside the Flutter assets bundle
    NSString *key = [FlutterDartProject lookupKeyForAsset:path];
    NSString *bundlePath = [[NSBundle mainBundle] pathForResource:key ofType:nil];
    if (bundlePath == nil) {
        NSLog(@"PaddleOCR: asset not found in bundle for key: %@", path);
        return std::string([path UTF8String]);
    }

    // Build a destination path under Library/Caches/ppocr/
    NSString *cachesDir = [NSSearchPathForDirectoriesInDomains(
                              NSCachesDirectory, NSUserDomainMask, YES) firstObject];
    NSString *ppocrDir = [cachesDir stringByAppendingPathComponent:@"ppocr"];

    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:ppocrDir]) {
        [fm createDirectoryAtPath:ppocrDir
      withIntermediateDirectories:YES
                       attributes:nil
                            error:nil];
    }

    NSString *filename = [bundlePath lastPathComponent];
    NSString *destPath = [ppocrDir stringByAppendingPathComponent:filename];

    // Copy only if the destination doesn't already exist (or is out-of-date)
    if (![fm fileExistsAtPath:destPath]) {
        NSError *err = nil;
        BOOL ok = [fm copyItemAtPath:bundlePath toPath:destPath error:&err];
        if (!ok) {
            NSLog(@"PaddleOCR: failed to copy %@ → %@: %@", bundlePath, destPath, err);
            // Fall back to the bundle path (will likely still crash, but log helps)
            return std::string([bundlePath UTF8String]);
        }
        NSLog(@"PaddleOCR: copied %@ → %@", filename, destPath);
    }

    return std::string([destPath UTF8String]);
}

@end
