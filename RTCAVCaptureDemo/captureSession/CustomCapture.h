//
//  CustomCapture.h
//  RTCAVCaptureDemo
//
//  Created by weixu on 2017/3/29.
//  Copyright © 2017年 weixu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>


@interface CustomCapture : NSObject
@property(nonatomic, strong) AVCaptureSession *  captureSession;
@property(nonatomic, strong) dispatch_queue_t  frameQueue;
@property(nonatomic, readonly) BOOL canUseBackCamera;
@property(nonatomic, assign) BOOL useBackCamera;  // Defaults to NO.
@property(atomic, assign) BOOL isRunning;  // Whether the capture session is running.
@property(atomic, assign) BOOL hasStarted;  // Whether we have an unmatched start.

- (AVCaptureDevice *_Nullable)getActiveCaptureDevice;

- (nullable AVCaptureDevice *)frontCaptureDevice;
- (nullable AVCaptureDevice *)backCaptureDevice;

// Starts and stops the capture session asynchronously. We cannot do this
// synchronously without blocking a WebRTC thread.
- (void)start;
- (void)stop;


- (AVCaptureVideoPreviewLayer *_Nullable)getShowVideoLayer;
@end
