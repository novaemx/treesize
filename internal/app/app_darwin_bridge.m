#import <Cocoa/Cocoa.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#include <string.h>

@interface TreeDataSource : NSObject <NSOutlineViewDataSource, NSOutlineViewDelegate>
@property(nonatomic, strong) NSDictionary *rootNode;
@property(nonatomic, assign) long long totalSize;
@end

@interface AppController : NSObject
- (void)chooseDirectory:(id)sender;
- (void)rescan:(id)sender;
@end

static TreeDataSource *gDataSource;
static AppController *gController;
static NSOutlineView *gOutlineView;
static NSTextField *gPathLabel;
static NSTextField *gSummaryLabel;
static NSTextField *gStatusLabel;
static NSProgressIndicator *gProgressIndicator;
static NSButton *gChooseButton;
static NSButton *gRescanButton;
static NSWindow *gWindow;
static NSString *gLastSelectedPath;
static BOOL gScanInProgress = NO;

static NSDictionary *EmptyRootNodeForPath(NSString *path);
static void SetStatusMessage(NSString *message);
static void SetScanning(BOOL scanning);
static void ApplyRootNode(NSDictionary *rootNode);
static void PresentDirectoryPicker(void);
static void StartScanForPath(NSString *path);
static void PresentError(NSString *title, NSString *message);

@implementation TreeDataSource

- (NSArray *)childrenForItem:(id)item {
  NSDictionary *node = item == nil ? self.rootNode : (NSDictionary *)item;
  NSArray *children = node[@"children"];
  if (![children isKindOfClass:[NSArray class]]) {
    return @[];
  }
  return children;
}

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item {
  return [[self childrenForItem:item] count];
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item {
  NSArray *children = [self childrenForItem:item];
  if (index < 0 || index >= (NSInteger)[children count]) {
    return nil;
  }
  return children[(NSUInteger)index];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
  return [[self childrenForItem:item] count] > 0;
}

- (NSString *)humanReadableSize:(long long)size {
  double value = (double)size;
  NSArray<NSString *> *units = @[ @"B", @"KB", @"MB", @"GB", @"TB", @"PB" ];
  NSUInteger idx = 0;
  while (value >= 1024.0 && idx + 1 < units.count) {
    value /= 1024.0;
    idx++;
  }
  return [NSString stringWithFormat:@"%.2f %@", value, units[idx]];
}

- (NSString *)formattedDateFromUnix:(long long)unixTime {
  if (unixTime <= 0) {
    return @"-";
  }
  NSDate *date = [NSDate dateWithTimeIntervalSince1970:unixTime];
  static NSDateFormatter *fmt = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    fmt = [[NSDateFormatter alloc] init];
    fmt.dateStyle = NSDateFormatterShortStyle;
    fmt.timeStyle = NSDateFormatterShortStyle;
  });
  return [fmt stringFromDate:date];
}

- (id)outlineView:(NSOutlineView *)outlineView
    objectValueForTableColumn:(NSTableColumn *)tableColumn
                        byItem:(id)item {
  NSDictionary *node = (NSDictionary *)item;
  NSString *identifier = tableColumn.identifier;
  long long size = [node[@"size"] longLongValue];

  if ([identifier isEqualToString:@"name"]) {
    return node[@"name"] ?: @"(unknown)";
  }
  if ([identifier isEqualToString:@"size"]) {
    return [self humanReadableSize:size];
  }
  if ([identifier isEqualToString:@"files"]) {
    return [NSString stringWithFormat:@"%lld", [node[@"fileCount"] longLongValue]];
  }
  if ([identifier isEqualToString:@"folders"]) {
    return [NSString stringWithFormat:@"%lld", [node[@"folderCount"] longLongValue]];
  }
  if ([identifier isEqualToString:@"percent"]) {
    if (self.totalSize <= 0) {
      return @"0.0 %";
    }
    double pct = ((double)size * 100.0) / (double)self.totalSize;
    return [NSString stringWithFormat:@"%.1f %%", pct];
  }
  if ([identifier isEqualToString:@"modified"]) {
    return [self formattedDateFromUnix:[node[@"modTimeUnix"] longLongValue]];
  }

  return @"";
}

@end

@implementation AppController

- (void)chooseDirectory:(id)sender {
  (void)sender;
  PresentDirectoryPicker();
}

- (void)rescan:(id)sender {
  (void)sender;
  if (gLastSelectedPath.length == 0) {
    PresentDirectoryPicker();
    return;
  }
  StartScanForPath(gLastSelectedPath);
}

@end

static NSTableColumn *MakeColumn(NSString *identifier, NSString *title, CGFloat width) {
  NSTableColumn *col = [[NSTableColumn alloc] initWithIdentifier:identifier];
  col.title = title;
  col.width = width;
  col.minWidth = width * 0.7;
  return col;
}

static NSDictionary *EmptyRootNodeForPath(NSString *path) {
  NSString *safePath = path ?: @"";
  NSString *name = @"(No Selection)";
  if (safePath.length > 0) {
    NSString *last = [safePath lastPathComponent];
    name = last.length == 0 ? safePath : last;
  }
  return @{
    @"name": name,
    @"path": safePath,
    @"size": @0,
    @"fileCount": @0,
    @"folderCount": @0,
    @"modTimeUnix": @0,
    @"children": @[]
  };
}

static void SetStatusMessage(NSString *message) {
  [gStatusLabel setStringValue:message ?: @"Ready"];
}

static void SetScanning(BOOL scanning) {
  gScanInProgress = scanning;
  [gChooseButton setEnabled:!scanning];
  [gRescanButton setEnabled:(!scanning && gLastSelectedPath.length > 0)];
  if (scanning) {
    [gProgressIndicator startAnimation:nil];
  } else {
    [gProgressIndicator stopAnimation:nil];
  }
}

static void ApplyRootNode(NSDictionary *rootNode) {
  NSDictionary *safeRoot = rootNode;
  if (![safeRoot isKindOfClass:[NSDictionary class]]) {
    safeRoot = EmptyRootNodeForPath(gLastSelectedPath ?: @"");
  }

  gDataSource.rootNode = safeRoot;
  gDataSource.totalSize = [safeRoot[@"size"] longLongValue];

  NSString *rootPath = safeRoot[@"path"] ?: @"";
  [gPathLabel setStringValue:(rootPath.length > 0
                                ? [NSString stringWithFormat:@"Root: %@", rootPath]
                                : @"Root: Not selected")];

  [gSummaryLabel setStringValue:[NSString stringWithFormat:@"Total: %@ | Files: %lld | Folders: %lld",
                                                          [gDataSource humanReadableSize:gDataSource.totalSize],
                                                          [safeRoot[@"fileCount"] longLongValue],
                                                          [safeRoot[@"folderCount"] longLongValue]]];

  [gOutlineView reloadData];
  [gOutlineView expandItem:nil expandChildren:NO];
}

static void PresentError(NSString *title, NSString *message) {
  NSAlert *alert = [[NSAlert alloc] init];
  alert.alertStyle = NSAlertStyleCritical;
  alert.messageText = title ?: @"Error";
  alert.informativeText = message ?: @"Unknown error";
  if (gWindow != nil) {
    [alert beginSheetModalForWindow:gWindow completionHandler:nil];
  } else {
    [alert runModal];
  }
}

static void StartScanForPath(NSString *path) {
  if (path.length == 0 || gScanInProgress) {
    return;
  }

  gLastSelectedPath = [path copy];
  SetScanning(YES);
  SetStatusMessage([NSString stringWithFormat:@"Scanning %@...", path]);

  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    NSString *executablePath = [[[NSProcessInfo processInfo] arguments] firstObject];
    if (executablePath.length == 0) {
      dispatch_async(dispatch_get_main_queue(), ^{
        SetScanning(NO);
        SetStatusMessage(@"Ready");
        PresentError(@"Scan failed", @"Could not determine executable path.");
      });
      return;
    }

    NSTask *task = [[NSTask alloc] init];
    task.executableURL = [NSURL fileURLWithPath:executablePath];
    task.arguments = @[ @"scan-json", path ];

    NSPipe *stdoutPipe = [NSPipe pipe];
    NSPipe *stderrPipe = [NSPipe pipe];
    task.standardOutput = stdoutPipe;
    task.standardError = stderrPipe;

    NSError *launchError = nil;
    if (![task launchAndReturnError:&launchError]) {
      dispatch_async(dispatch_get_main_queue(), ^{
        SetScanning(NO);
        SetStatusMessage(@"Ready");
        PresentError(@"Scan failed", launchError.localizedDescription ?: @"Unable to launch scanner.");
      });
      return;
    }

    NSData *stdoutData = [[stdoutPipe fileHandleForReading] readDataToEndOfFile];
    NSData *stderrData = [[stderrPipe fileHandleForReading] readDataToEndOfFile];
    [task waitUntilExit];

    if (task.terminationStatus != 0) {
      NSString *stderrText = [[NSString alloc] initWithData:stderrData encoding:NSUTF8StringEncoding];
      if (stderrText.length == 0) {
        stderrText = [NSString stringWithFormat:@"Scanner exited with code %d.", task.terminationStatus];
      }
      dispatch_async(dispatch_get_main_queue(), ^{
        SetScanning(NO);
        SetStatusMessage(@"Ready");
        PresentError(@"Scan failed", stderrText);
      });
      return;
    }

    NSError *jsonError = nil;
    id parsed = [NSJSONSerialization JSONObjectWithData:stdoutData options:0 error:&jsonError];
    if (![parsed isKindOfClass:[NSDictionary class]]) {
      NSString *reason = jsonError.localizedDescription ?: @"Scanner output was invalid.";
      dispatch_async(dispatch_get_main_queue(), ^{
        SetScanning(NO);
        SetStatusMessage(@"Ready");
        PresentError(@"Scan failed", reason);
      });
      return;
    }

    NSDictionary *rootNode = (NSDictionary *)parsed;
    dispatch_async(dispatch_get_main_queue(), ^{
      ApplyRootNode(rootNode);
      SetScanning(NO);
      SetStatusMessage(@"Scan complete");
    });
  });
}

static void PresentDirectoryPicker(void) {
  if (gScanInProgress) {
    return;
  }

  NSOpenPanel *panel = [NSOpenPanel openPanel];
  panel.canChooseDirectories = YES;
  panel.canChooseFiles = NO;
  panel.allowsMultipleSelection = NO;
  panel.prompt = @"Scan";
  panel.message = @"Select the disk or folder you want to analyze.";
  if (gLastSelectedPath.length > 0) {
    panel.directoryURL = [NSURL fileURLWithPath:gLastSelectedPath];
  }

  [panel beginSheetModalForWindow:gWindow
                completionHandler:^(NSModalResponse result) {
                  if (result != NSModalResponseOK || panel.URL == nil) {
                    return;
                  }
                  StartScanForPath(panel.URL.path);
                }];
}

static void InstallMainMenu(void) {
  NSMenu *menubar = [[NSMenu alloc] initWithTitle:@"MainMenu"];

  NSMenuItem *appMenuItem = [[NSMenuItem alloc] initWithTitle:@"App" action:nil keyEquivalent:@""];
  [menubar addItem:appMenuItem];
  NSMenu *appMenu = [[NSMenu alloc] initWithTitle:@"App"];
  NSString *appName = [[NSProcessInfo processInfo] processName];
  NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"Quit %@", appName]
                                                     action:@selector(terminate:)
                                              keyEquivalent:@"q"];
  [appMenu addItem:quitItem];
  [appMenuItem setSubmenu:appMenu];

  NSMenuItem *fileMenuItem = [[NSMenuItem alloc] initWithTitle:@"File" action:nil keyEquivalent:@""];
  [menubar addItem:fileMenuItem];
  NSMenu *fileMenu = [[NSMenu alloc] initWithTitle:@"File"];

  NSMenuItem *chooseItem = [[NSMenuItem alloc] initWithTitle:@"Select Directory..."
                                                       action:@selector(chooseDirectory:)
                                                keyEquivalent:@"o"];
  [chooseItem setTarget:gController];
  [fileMenu addItem:chooseItem];

  NSMenuItem *rescanItem = [[NSMenuItem alloc] initWithTitle:@"Rescan"
                                                       action:@selector(rescan:)
                                                keyEquivalent:@"r"];
  [rescanItem setTarget:gController];
  [fileMenu addItem:rescanItem];

  [fileMenuItem setSubmenu:fileMenu];
  [NSApp setMainMenu:menubar];
}

void runNativeAppWithTreeJSON(const char *treeJSON) {
  @autoreleasepool {
    NSData *jsonData = treeJSON == NULL ? nil : [NSData dataWithBytes:treeJSON length:strlen(treeJSON)];
    NSDictionary *rootNode = nil;
    if (jsonData != nil) {
      id parsed = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
      if ([parsed isKindOfClass:[NSDictionary class]]) {
        rootNode = (NSDictionary *)parsed;
      }
    }

    if (rootNode == nil) {
      rootNode = EmptyRootNodeForPath(@"");
    }

    [NSApplication sharedApplication];
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    gController = [[AppController alloc] init];
    InstallMainMenu();

    NSRect frame = NSMakeRect(120, 120, 1280, 820);
    NSUInteger style = NSWindowStyleMaskTitled |
                      NSWindowStyleMaskClosable |
                      NSWindowStyleMaskMiniaturizable |
                      NSWindowStyleMaskResizable;

    gWindow = [[NSWindow alloc] initWithContentRect:frame
                                          styleMask:style
                                            backing:NSBackingStoreBuffered
                                              defer:NO];
    [gWindow setTitle:@"TreeSize"];

    NSView *content = [[NSView alloc] initWithFrame:frame];
    [content setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [gWindow setContentView:content];

    NSView *header = [[NSView alloc] initWithFrame:NSMakeRect(0, frame.size.height - 70, frame.size.width, 70)];
    [header setAutoresizingMask:NSViewWidthSizable | NSViewMinYMargin];

    gChooseButton = [[NSButton alloc] initWithFrame:NSMakeRect(16, 36, 130, 26)];
    [gChooseButton setTitle:@"Select Directory..."];
    [gChooseButton setBezelStyle:NSBezelStyleRounded];
    [gChooseButton setTarget:gController];
    [gChooseButton setAction:@selector(chooseDirectory:)];
    [header addSubview:gChooseButton];

    gRescanButton = [[NSButton alloc] initWithFrame:NSMakeRect(154, 36, 86, 26)];
    [gRescanButton setTitle:@"Rescan"];
    [gRescanButton setBezelStyle:NSBezelStyleRounded];
    [gRescanButton setTarget:gController];
    [gRescanButton setAction:@selector(rescan:)];
    [gRescanButton setEnabled:NO];
    [header addSubview:gRescanButton];

    gProgressIndicator = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(252, 39, 16, 16)];
    [gProgressIndicator setStyle:NSProgressIndicatorStyleSpinning];
    [gProgressIndicator setDisplayedWhenStopped:NO];
    [header addSubview:gProgressIndicator];

    gStatusLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(276, 38, frame.size.width - 292, 18)];
    [gStatusLabel setEditable:NO];
    [gStatusLabel setBezeled:NO];
    [gStatusLabel setDrawsBackground:NO];
    [gStatusLabel setAutoresizingMask:NSViewWidthSizable | NSViewMinYMargin];
    [header addSubview:gStatusLabel];

    gPathLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(16, 12, frame.size.width - 32, 18)];
    [gPathLabel setEditable:NO];
    [gPathLabel setBezeled:NO];
    [gPathLabel setDrawsBackground:NO];
    [gPathLabel setAutoresizingMask:NSViewWidthSizable | NSViewMinYMargin];
    [header addSubview:gPathLabel];

    [content addSubview:header];

    NSSplitView *splitView = [[NSSplitView alloc] initWithFrame:NSMakeRect(0, 0, frame.size.width, frame.size.height - 74)];
    [splitView setVertical:NO];
    [splitView setDividerStyle:NSSplitViewDividerStyleThin];
    [splitView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];

    NSScrollView *scrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 0, frame.size.width, frame.size.height - 194)];
    [scrollView setHasVerticalScroller:YES];
    [scrollView setHasHorizontalScroller:YES];

    gOutlineView = [[NSOutlineView alloc] initWithFrame:scrollView.bounds];
    [gOutlineView setUsesAlternatingRowBackgroundColors:YES];

    NSTableColumn *nameColumn = MakeColumn(@"name", @"Name", 420);
    [gOutlineView addTableColumn:nameColumn];
    [gOutlineView addTableColumn:MakeColumn(@"size", @"Size", 140)];
    [gOutlineView addTableColumn:MakeColumn(@"files", @"Files", 90)];
    [gOutlineView addTableColumn:MakeColumn(@"folders", @"Folders", 90)];
    [gOutlineView addTableColumn:MakeColumn(@"percent", @"% of Parent", 110)];
    [gOutlineView addTableColumn:MakeColumn(@"modified", @"Last Modified", 160)];
    [gOutlineView setOutlineTableColumn:nameColumn];

    gDataSource = [[TreeDataSource alloc] init];
    gDataSource.rootNode = EmptyRootNodeForPath(@"");
    gDataSource.totalSize = 0;

    [gOutlineView setDataSource:gDataSource];
    [gOutlineView setDelegate:gDataSource];
    [gOutlineView reloadData];
    [gOutlineView expandItem:nil expandChildren:NO];

    [scrollView setDocumentView:gOutlineView];
    [splitView addArrangedSubview:scrollView];

    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    NSView *bottomPane = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, frame.size.width, 120)];
    [bottomPane setAutoresizingMask:NSViewWidthSizable | NSViewMaxYMargin];

    gSummaryLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(16, 92, frame.size.width - 32, 18)];
    [gSummaryLabel setEditable:NO];
    [gSummaryLabel setBezeled:NO];
    [gSummaryLabel setDrawsBackground:NO];
    [gSummaryLabel setAutoresizingMask:NSViewWidthSizable | NSViewMinYMargin];
    [bottomPane addSubview:gSummaryLabel];

    if (device != nil) {
      MTKView *metalView = [[MTKView alloc] initWithFrame:NSMakeRect(16, 8, frame.size.width - 32, 76) device:device];
      [metalView setEnableSetNeedsDisplay:YES];
      [metalView setAutoresizingMask:NSViewWidthSizable | NSViewMinYMargin];
      [bottomPane addSubview:metalView];
    }

    [splitView addArrangedSubview:bottomPane];
    [splitView adjustSubviews];
    [content addSubview:splitView];

    ApplyRootNode(rootNode);
    SetStatusMessage(@"Select a disk or folder to start scanning.");
    SetScanning(NO);

    [gWindow makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
    [NSApp run];
  }
}
