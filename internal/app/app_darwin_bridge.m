#import <Cocoa/Cocoa.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>

void runNativeApp(void) {
  @autoreleasepool {
    [NSApplication sharedApplication];
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];

    NSRect frame = NSMakeRect(120, 120, 1280, 800);
    NSUInteger style = NSWindowStyleMaskTitled |
                      NSWindowStyleMaskClosable |
                      NSWindowStyleMaskMiniaturizable |
                      NSWindowStyleMaskResizable;

    NSWindow *window = [[NSWindow alloc] initWithContentRect:frame
                                                   styleMask:style
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    [window setTitle:@"TreeSize Mac (Bootstrap)"];

    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    if (device != nil) {
      MTKView *metalView = [[MTKView alloc] initWithFrame:frame device:device];
      [metalView setEnableSetNeedsDisplay:YES];
      [window setContentView:metalView];
    }

    [window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
    [NSApp run];
  }
}
