//
//  CustomCapture.m
//  RTCAVCaptureDemo
//
//  Created by weixu on 2017/3/29.
//  Copyright © 2017年 weixu. All rights reserved.
//

#import "CustomCapture.h"
#import <UIKit/UIKit.h>
#import "RTCDispatcher.h"

typedef NS_ENUM(NSInteger, VideoRotation) {
    kVideoRotation_0 = 0,
    kVideoRotation_90 = 90,
    kVideoRotation_180 = 180,
    kVideoRotation_270 = 270
};

@interface CustomCapture () <AVCaptureVideoDataOutputSampleBufferDelegate>
@property (nonatomic, strong) AVCaptureDeviceInput *frontCameraInput;
@property (nonatomic, strong) AVCaptureDeviceInput *backCameraInput;
@property (nonatomic, strong) AVCaptureVideoDataOutput *videoDataOutput;
@property (nonatomic, assign) VideoRotation rotation;
@property (nonatomic, assign) BOOL hasRetriedOnFatalError;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;

@end

@implementation CustomCapture

- (instancetype)init
{
    self = [super init];
    if (self) {
        if (![self setupCaptureSession]) {
            return nil;
        }
        
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        [center addObserver:self
                   selector:@selector(deviceOrientationDidChange:)
                       name:UIDeviceOrientationDidChangeNotification
                     object:self.captureSession];
        [center addObserver:self
                   selector:@selector(handleCaptureSessionInterruption:)
                       name:AVCaptureSessionWasInterruptedNotification
                     object:self.captureSession];
        [center addObserver:self
                   selector:@selector(handleCaptureSessionInterruptionEnded:)
                       name:AVCaptureSessionInterruptionEndedNotification
                     object:self.captureSession];
        [center addObserver:self
                   selector:@selector(handleApplicationDidBecomeActive:)
                       name:UIApplicationDidBecomeActiveNotification
                     object:[UIApplication sharedApplication]];
        
        [center addObserver:self
                   selector:@selector(handleCaptureSessionRuntimeError:)
                       name:AVCaptureSessionRuntimeErrorNotification
                     object:self.captureSession];
        [center addObserver:self
                   selector:@selector(handleCaptureSessionDidStartRunning:)
                       name:AVCaptureSessionDidStartRunningNotification
                     object:self.captureSession];
        [center addObserver:self
                   selector:@selector(handleCaptureSessionDidStopRunning:)
                       name:AVCaptureSessionDidStopRunningNotification
                     object:self.captureSession];

    }
    return self;
}

- (BOOL)setupCaptureSession {
    AVCaptureSession *captureSession = [[AVCaptureSession alloc] init];
    captureSession.usesApplicationAudioSession = NO;
    // Add the output.
    AVCaptureVideoDataOutput *videoDataOutput = [self videoDataOutput];
    if (![captureSession canAddOutput:videoDataOutput]) {
        NSLog(@"Video data output unsupported.");
        return NO;
    }
    [captureSession addOutput:videoDataOutput];
    
    // Get the front and back cameras. If there isn't a front camera
    // give up.
    AVCaptureDeviceInput *frontCameraInput = [self frontCameraInput];
    AVCaptureDeviceInput *backCameraInput = [self backCameraInput];
    if (!frontCameraInput) {
        NSLog(@"No front camera for capture session.");
        return NO;
    }
    
    // Add the inputs.
    if (![captureSession canAddInput:frontCameraInput] ||
        (backCameraInput && ![captureSession canAddInput:backCameraInput])) {
        NSLog(@"Session does not support capture inputs.");
        return NO;
    }
    AVCaptureDeviceInput *input = self.useBackCamera ? backCameraInput : frontCameraInput;
    [captureSession addInput:input];
    
    self.captureSession = captureSession;
    [self setUpVideoLayer:captureSession];
    return YES;
}

- (void)setUpVideoLayer:(AVCaptureSession *)session {
    self.previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:session];
    [self.previewLayer setBackgroundColor:[[UIColor blackColor] CGColor]];
    [self.previewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
}


#pragma mark -
#pragma mark public fun

- (AVCaptureVideoPreviewLayer *)getShowVideoLayer{
    if (self.previewLayer) {
        return self.previewLayer;
    }
    return nil;
}

- (AVCaptureDevice *)getActiveCaptureDevice {
    return self.useBackCamera ? _backCameraInput.device : _frontCameraInput.device;
}

- (nullable AVCaptureDevice *)frontCaptureDevice {
    return _frontCameraInput.device;
}

- (nullable AVCaptureDevice *)backCaptureDevice {
    return _backCameraInput.device;
}

- (dispatch_queue_t)frameQueue {
    if (!_frameQueue) {
        _frameQueue =
        dispatch_queue_create("org.webrtc.avfoundationvideocapturer.video", DISPATCH_QUEUE_SERIAL);
        dispatch_set_target_queue(self.frameQueue,
                                  dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0));
    }
    return _frameQueue;
}

// Called from WebRTC thread.
- (void)start {
    if (self.hasStarted) {
        return;
    }
    self.hasStarted = YES;
    [RTCDispatcher
     dispatchAsyncOnType:RTCDispatcherTypeCaptureSession
     block:^{
         // Default to portrait orientation on iPhone. This will be reset in
         // updateOrientation unless orientation is unknown/faceup/facedown.
         _rotation = kVideoRotation_90;

         [self updateOrientation];
         [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];

         AVCaptureSession *captureSession = self.captureSession;
         [captureSession startRunning];
     }];
}

// Called from same thread as start.
- (void)stop {
    if (!self.hasStarted) {
        return;
    }
    self.hasStarted = NO;
    // Due to this async block, it's possible that the ObjC object outlives the
    // C++ one. In order to not invoke functions on the C++ object, we set
    // hasStarted immediately instead of dispatching it async.
    [RTCDispatcher
     dispatchAsyncOnType:RTCDispatcherTypeCaptureSession
     block:^{
         [_videoDataOutput setSampleBufferDelegate:nil queue:nil];
         [self.captureSession stopRunning];
         [[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];
     }];
}


#pragma mark -
#pragma mark NSNotification

- (void)deviceOrientationDidChange:(NSNotification *)notification {
    [RTCDispatcher dispatchAsyncOnType:RTCDispatcherTypeCaptureSession
                                 block:^{
                                     [self updateOrientation];
                                 }];
}

- (void)updateOrientation {
    switch ([UIDevice currentDevice].orientation) {
        case UIDeviceOrientationPortrait:
            _rotation = kVideoRotation_90;
            break;
        case UIDeviceOrientationPortraitUpsideDown:
            _rotation = kVideoRotation_270;
            break;
        case UIDeviceOrientationLandscapeLeft:
            _rotation =
            self.useBackCamera ? kVideoRotation_0 : kVideoRotation_180;
            break;
        case UIDeviceOrientationLandscapeRight:
            _rotation =
            self.useBackCamera ? kVideoRotation_180 : kVideoRotation_0;
            break;
        case UIDeviceOrientationFaceUp:
        case UIDeviceOrientationFaceDown:
        case UIDeviceOrientationUnknown:
            // Ignore.
            break;
    }
}


- (void)handleCaptureSessionInterruption:(NSNotification *)notification {
    NSString *reasonString = nil;

    NSNumber *reason = notification.userInfo[AVCaptureSessionInterruptionReasonKey];
    if (reason) {
        switch (reason.intValue) {
            case AVCaptureSessionInterruptionReasonVideoDeviceNotAvailableInBackground:
                reasonString = @"VideoDeviceNotAvailableInBackground";
                break;
            case AVCaptureSessionInterruptionReasonAudioDeviceInUseByAnotherClient:
                reasonString = @"AudioDeviceInUseByAnotherClient";
                break;
            case AVCaptureSessionInterruptionReasonVideoDeviceInUseByAnotherClient:
                reasonString = @"VideoDeviceInUseByAnotherClient";
                break;
            case AVCaptureSessionInterruptionReasonVideoDeviceNotAvailableWithMultipleForegroundApps:
                reasonString = @"VideoDeviceNotAvailableWithMultipleForegroundApps";
                break;
        }
    }
    
    NSLog(@"%@", reasonString);
}

- (void)handleCaptureSessionInterruptionEnded:(NSNotification *)notification {
    NSLog(@"Capture session interruption ended.");
}

- (void)handleApplicationDidBecomeActive:(NSNotification *)notification {
    [RTCDispatcher dispatchAsyncOnType:RTCDispatcherTypeCaptureSession
                                 block:^{
                                     if (self.hasStarted && !self.captureSession.isRunning) {
                                         NSLog(@"Restarting capture session on active.");
                                         [self.captureSession startRunning];
                                     }
                                 }];
}

- (void)handleCaptureSessionRuntimeError:(NSNotification *)notification {
    NSError *error = [notification.userInfo objectForKey:AVCaptureSessionErrorKey];
    NSLog(@"Capture session runtime error: %@", error);
    
    [RTCDispatcher dispatchAsyncOnType:RTCDispatcherTypeCaptureSession
                                 block:^{
                                     if (error.code == AVErrorMediaServicesWereReset) {
                                         [self handleNonFatalError];
                                     } else {
                                         [self handleFatalError];
                                     }
                                     [self handleFatalError];

                                 }];
}


- (void)handleNonFatalError {
    [RTCDispatcher dispatchAsyncOnType:RTCDispatcherTypeCaptureSession
                                 block:^{
                                     if (self.hasStarted) {
                                         NSLog(@"Restarting capture session after error.");
                                         [self.captureSession startRunning];
                                     }
                                 }];
}

- (void)handleFatalError {
    [RTCDispatcher
     dispatchAsyncOnType:RTCDispatcherTypeCaptureSession
     block:^{
         if (!_hasRetriedOnFatalError) {
             NSLog(@"Attempting to recover from fatal capture error.");
             [self handleNonFatalError];
             _hasRetriedOnFatalError = YES;
         } else {
             NSLog(@"Previous fatal error recovery failed.");
         }
     }];
}

- (void)handleCaptureSessionDidStartRunning:(NSNotification *)notification {
    NSLog(@"Capture session started.");
    
    self.isRunning = YES;
    [RTCDispatcher dispatchAsyncOnType:RTCDispatcherTypeCaptureSession
                                 block:^{
                                     // If we successfully restarted after an unknown error,
                                     // allow future retries on fatal errors.
                                     _hasRetriedOnFatalError = NO;
                                 }];
}

- (void)handleCaptureSessionDidStopRunning:(NSNotification *)notification {
    NSLog(@"Capture session stopped.");
    self.isRunning = NO;
}

#pragma mark AVCaptureVideoDataOutputSampleBufferDelegate

- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection {
    NSParameterAssert(captureOutput == _videoDataOutput);
    if (!self.hasStarted) {
        return;
    }
    //_capturer->CaptureSampleBuffer(sampleBuffer, _rotation);
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput
  didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection {
    NSLog(@"Dropped sample buffer.");
}

#pragma mark -
#pragma mark get && set


// Called from any thread (likely main thread).
- (void)setUseBackCamera:(BOOL)useBackCamera {
    if (!_canUseBackCamera) {
        if (useBackCamera) {

        }
        return;
    }
    @synchronized(self) {
        if (self.useBackCamera == useBackCamera) {
            return;
        }
        self.useBackCamera = useBackCamera;
        [self updateSessionInputForUseBackCamera:useBackCamera];
    }
}

//切换摄像头
- (void)updateSessionInputForUseBackCamera:(BOOL)useBackCamera {
    [RTCDispatcher dispatchAsyncOnType:RTCDispatcherTypeCaptureSession
                                 block:^{
                                     [self.captureSession beginConfiguration];
                                     AVCaptureDeviceInput *oldInput = _backCameraInput;
                                     AVCaptureDeviceInput *newInput = _frontCameraInput;
                                     if (useBackCamera) {
                                         oldInput = _frontCameraInput;
                                         newInput = _backCameraInput;
                                     }
                                     if (oldInput) {
                                         // Ok to remove this even if it's not attached. Will be no-op.
                                         [self.captureSession removeInput:oldInput];
                                     }
                                     if (newInput) {
                                         [self.captureSession addInput:newInput];
                                     }
                                     [self updateOrientation];
                                     [self.captureSession commitConfiguration];
                                 }];
}

- (AVCaptureVideoDataOutput *)videoDataOutput {
    if (!_videoDataOutput) {
        // Make the capturer output NV12. Ideally we want I420 but that's not
        // currently supported on iPhone / iPad.
        AVCaptureVideoDataOutput *videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
        videoDataOutput.videoSettings = @{
                                          (NSString *)
                                          // TODO(denicija): Remove this color conversion and use the original capture format directly.
                                          kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
                                          };
        videoDataOutput.alwaysDiscardsLateVideoFrames = NO;
        [videoDataOutput setSampleBufferDelegate:self queue:self.frameQueue];
        _videoDataOutput = videoDataOutput;
    }
    return _videoDataOutput;
}

- (AVCaptureDevice *)videoCaptureDeviceForPosition:(AVCaptureDevicePosition)position {
    for (AVCaptureDevice *captureDevice in [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo]) {
        if (captureDevice.position == position) {
            return captureDevice;
        }
    }
    return nil;
}

- (AVCaptureDeviceInput *)frontCameraInput {
    if (!_frontCameraInput) {
        AVCaptureDevice *frontCameraDevice =
        [self videoCaptureDeviceForPosition:AVCaptureDevicePositionFront];

        if (!frontCameraDevice) {
            NSLog(@"Failed to find front capture device.");
            return nil;
        }
        NSError *error = nil;
        AVCaptureDeviceInput *frontCameraInput =
        [AVCaptureDeviceInput deviceInputWithDevice:frontCameraDevice error:&error];
        if (!frontCameraInput) {
            NSLog(@"Failed to create front camera input: %@", error.localizedDescription);
            return nil;
        }
        _frontCameraInput = frontCameraInput;
    }
    return _frontCameraInput;
}

- (AVCaptureDeviceInput *)backCameraInput {
    if (!_backCameraInput) {
        AVCaptureDevice *backCameraDevice =
        [self videoCaptureDeviceForPosition:AVCaptureDevicePositionBack];
        if (!backCameraDevice) {
            NSLog(@"Failed to find front capture device.");
            return nil;
        }
        NSError *error = nil;
        AVCaptureDeviceInput *backCameraInput =
        [AVCaptureDeviceInput deviceInputWithDevice:backCameraDevice error:&error];
        if (!backCameraInput) {
            NSLog(@"Failed to create front camera input: %@", error.localizedDescription);
            return nil;
        }
        _backCameraInput = backCameraInput;
    }
    return _backCameraInput;
}




- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}
@end
