#import <Cocoa/Cocoa.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#include <signal.h>
#include <string.h>

@interface TreeDataSource : NSObject <NSOutlineViewDataSource, NSOutlineViewDelegate>
@property(nonatomic, strong) NSDictionary *rootNode;
@property(nonatomic, assign) long long totalSize;
@end

@interface AppController : NSObject
- (void)chooseDirectory:(id)sender;
- (void)rescan:(id)sender;
- (void)stopScan:(id)sender;
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
static NSButton *gStopButton;
static NSWindow *gWindow;
static NSString *gLastSelectedPath;
static BOOL gScanInProgress = NO;
static NSTask *gActiveScanTask;
static NSInteger gPermissionDeniedCount = 0;
static BOOL gHasPromptedForFullDiskAccess = NO;

static NSDictionary *EmptyRootNodeForPath(NSString *path);
static void SetStatusMessage(NSString *message);
static void SetScanning(BOOL scanning);
static void ApplyRootNode(NSDictionary *rootNode);
static void PresentDirectoryPicker(void);
static void StartScanForPath(NSString *path);
static void PresentError(NSString *title, NSString *message);
static void ProcessScanStreamLine(NSString *line);
static NSString *HumanReadableDuration(long long elapsedMS);
static NSButton *MakeToolbarButton(NSString *title,
                                   NSString *symbolName,
                                   SEL action,
                                   CGFloat x,
                                   CGFloat width);
static void PromptForFullDiskAccessIfNeeded(void);
static NSTableCellView *MakeNameCellView(void);
static NSTableCellView *MakeTextCellView(NSString *identifier, NSTextAlignment alignment);
static NSTableCellView *MakePercentCellView(void);

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

- (NSView *)outlineView:(NSOutlineView *)outlineView
    viewForTableColumn:(NSTableColumn *)tableColumn
                  item:(id)item {
  NSDictionary *node = (NSDictionary *)item;
  NSString *identifier = tableColumn.identifier;
  long long size = [node[@"size"] longLongValue];

  if ([identifier isEqualToString:@"name"]) {
    NSTableCellView *cell = [outlineView makeViewWithIdentifier:@"NameCell" owner:nil];
    if (cell == nil) {
      cell = MakeNameCellView();
    }

    NSView *barView = [cell viewWithTag:1001];
    NSTextField *textField = cell.textField;
    NSImageView *imageView = cell.imageView;
    CGFloat ratio = self.totalSize <= 0 ? 0.0 : MIN(1.0, MAX(0.0, (CGFloat)size / (CGFloat)self.totalSize));
    NSRect bounds = cell.bounds;
    CGFloat width = floor(MAX(0.0, (bounds.size.width - 12.0) * ratio));
    barView.frame = NSMakeRect(6, 4, width, MAX(0.0, bounds.size.height - 8));
    barView.hidden = width <= 1.0;
    textField.stringValue = node[@"name"] ?: @"(unknown)";
    if ([node[@"isDir"] boolValue]) {
      imageView.image = [NSImage imageNamed:NSImageNameFolder];
    } else {
      imageView.image = [NSImage imageNamed:NSImageNameMultipleDocuments];
    }
    return cell;
  }

  if ([identifier isEqualToString:@"percent"]) {
    NSTableCellView *cell = [outlineView makeViewWithIdentifier:@"PercentCell" owner:nil];
    if (cell == nil) {
      cell = MakePercentCellView();
    }

    NSView *fillView = [cell viewWithTag:2001];
    NSTextField *label = cell.textField;
    double pct = self.totalSize <= 0 ? 0.0 : ((double)size * 100.0) / (double)self.totalSize;
    CGFloat fraction = (CGFloat)MIN(1.0, MAX(0.0, pct / 100.0));
    NSRect bounds = cell.bounds;
    fillView.frame = NSMakeRect(1, 1, floor((bounds.size.width - 2.0) * fraction), MAX(0.0, bounds.size.height - 2));
    label.stringValue = [NSString stringWithFormat:@"%.1f %%", pct];
    return cell;
  }

  NSTextAlignment alignment = ([identifier isEqualToString:@"modified"] || [identifier isEqualToString:@"name"]) ? NSTextAlignmentLeft : NSTextAlignmentRight;
  NSString *cellIdentifier = [@"TextCell-" stringByAppendingString:identifier];
  NSTableCellView *cell = [outlineView makeViewWithIdentifier:cellIdentifier owner:nil];
  if (cell == nil) {
    cell = MakeTextCellView(cellIdentifier, alignment);
  }

  if ([identifier isEqualToString:@"size"] || [identifier isEqualToString:@"allocated"]) {
    cell.textField.stringValue = [self humanReadableSize:size];
  } else if ([identifier isEqualToString:@"files"]) {
    cell.textField.stringValue = [NSString stringWithFormat:@"%lld", [node[@"fileCount"] longLongValue]];
  } else if ([identifier isEqualToString:@"folders"]) {
    cell.textField.stringValue = [NSString stringWithFormat:@"%lld", [node[@"folderCount"] longLongValue]];
  } else if ([identifier isEqualToString:@"modified"]) {
    cell.textField.stringValue = [self formattedDateFromUnix:[node[@"modTimeUnix"] longLongValue]];
  } else {
    cell.textField.stringValue = @"";
  }

  return cell;
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

- (void)stopScan:(id)sender {
  (void)sender;
  if (gActiveScanTask != nil && gScanInProgress) {
    [gActiveScanTask terminate];
  }
}

@end

static NSTableColumn *MakeColumn(NSString *identifier, NSString *title, CGFloat width) {
  NSTableColumn *col = [[NSTableColumn alloc] initWithIdentifier:identifier];
  col.title = title;
  col.width = width;
  col.minWidth = width * 0.7;
  return col;
}

static NSTableCellView *MakeNameCellView(void) {
  NSTableCellView *cell = [[NSTableCellView alloc] initWithFrame:NSMakeRect(0, 0, 100, 24)];
  cell.identifier = @"NameCell";
  cell.wantsLayer = YES;

  NSView *barView = [[NSView alloc] initWithFrame:NSMakeRect(6, 4, 0, 16)];
  barView.tag = 1001;
  barView.wantsLayer = YES;
  barView.layer.backgroundColor = [[NSColor colorWithRed:0.52 green:0.56 blue:0.62 alpha:0.24] CGColor];
  barView.layer.cornerRadius = 4.0;
  barView.autoresizingMask = NSViewWidthSizable;
  [cell addSubview:barView positioned:NSWindowBelow relativeTo:nil];

  NSImageView *imageView = [[NSImageView alloc] initWithFrame:NSMakeRect(8, 4, 16, 16)];
  imageView.imageScaling = NSImageScaleProportionallyDown;
  cell.imageView = imageView;
  [cell addSubview:imageView];

  NSTextField *label = [[NSTextField alloc] initWithFrame:NSMakeRect(30, 2, 260, 20)];
  label.editable = NO;
  label.bezeled = NO;
  label.drawsBackground = NO;
  label.font = [NSFont systemFontOfSize:12 weight:NSFontWeightSemibold];
  label.lineBreakMode = NSLineBreakByTruncatingMiddle;
  label.autoresizingMask = NSViewWidthSizable;
  cell.textField = label;
  [cell addSubview:label];

  return cell;
}

static NSTableCellView *MakeTextCellView(NSString *identifier, NSTextAlignment alignment) {
  NSTableCellView *cell = [[NSTableCellView alloc] initWithFrame:NSMakeRect(0, 0, 100, 24)];
  cell.identifier = identifier;
  NSTextField *label = [[NSTextField alloc] initWithFrame:NSMakeRect(6, 2, 120, 20)];
  label.editable = NO;
  label.bezeled = NO;
  label.drawsBackground = NO;
  label.alignment = alignment;
  label.font = [NSFont monospacedDigitSystemFontOfSize:12 weight:NSFontWeightMedium];
  label.textColor = [NSColor labelColor];
  label.autoresizingMask = NSViewWidthSizable;
  cell.textField = label;
  [cell addSubview:label];
  return cell;
}

static NSTableCellView *MakePercentCellView(void) {
  NSTableCellView *cell = [[NSTableCellView alloc] initWithFrame:NSMakeRect(0, 0, 120, 24)];
  cell.identifier = @"PercentCell";
  cell.wantsLayer = YES;
  cell.layer.backgroundColor = [[NSColor colorWithWhite:0.22 alpha:0.6] CGColor];
  cell.layer.cornerRadius = 4.0;

  NSView *fillView = [[NSView alloc] initWithFrame:NSMakeRect(1, 1, 0, 22)];
  fillView.tag = 2001;
  fillView.wantsLayer = YES;
  CAGradientLayer *gradient = [CAGradientLayer layer];
  gradient.colors = @[ (id)[[NSColor colorWithRed:0.45 green:0.36 blue:0.96 alpha:0.96] CGColor],
                       (id)[[NSColor colorWithRed:0.21 green:0.49 blue:1.0 alpha:0.96] CGColor] ];
  gradient.startPoint = CGPointMake(0, 0.5);
  gradient.endPoint = CGPointMake(1, 0.5);
  gradient.cornerRadius = 3.0;
  gradient.frame = fillView.bounds;
  fillView.layer = gradient;
  fillView.autoresizingMask = NSViewHeightSizable;
  [cell addSubview:fillView positioned:NSWindowBelow relativeTo:nil];

  NSTextField *label = [[NSTextField alloc] initWithFrame:NSMakeRect(4, 2, 112, 20)];
  label.editable = NO;
  label.bezeled = NO;
  label.drawsBackground = NO;
  label.alignment = NSTextAlignmentCenter;
  label.font = [NSFont monospacedDigitSystemFontOfSize:12 weight:NSFontWeightSemibold];
  label.textColor = [NSColor whiteColor];
  label.autoresizingMask = NSViewWidthSizable;
  cell.textField = label;
  [cell addSubview:label];
  return cell;
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
  [gStopButton setEnabled:scanning];
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

static NSString *HumanReadableDuration(long long elapsedMS) {
  long long totalSeconds = elapsedMS / 1000;
  long long minutes = totalSeconds / 60;
  long long seconds = totalSeconds % 60;
  if (minutes > 0) {
    return [NSString stringWithFormat:@"%lldm %02llds", minutes, seconds];
  }
  return [NSString stringWithFormat:@"%llds", seconds];
}

static void PromptForFullDiskAccessIfNeeded(void) {
  if (gPermissionDeniedCount <= 0 || gHasPromptedForFullDiskAccess) {
    return;
  }

  gHasPromptedForFullDiskAccess = YES;
  NSAlert *alert = [[NSAlert alloc] init];
  alert.alertStyle = NSAlertStyleInformational;
  alert.messageText = @"Full Disk Access recommended";
  alert.informativeText = [NSString stringWithFormat:@"TreeSize skipped %ld protected folder(s). To measure disk usage more accurately, grant Full Disk Access in System Settings.", (long)gPermissionDeniedCount];
  [alert addButtonWithTitle:@"Open Settings"];
  [alert addButtonWithTitle:@"Later"];

  void (^handler)(NSModalResponse) = ^(NSModalResponse response) {
    if (response == NSAlertFirstButtonReturn) {
      NSURL *url = [NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"];
      if (url != nil) {
        [[NSWorkspace sharedWorkspace] openURL:url];
      }
    }
  };

  if (gWindow != nil) {
    [alert beginSheetModalForWindow:gWindow completionHandler:handler];
  } else {
    handler([alert runModal]);
  }
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
    gActiveScanTask = task;
    task.executableURL = [NSURL fileURLWithPath:executablePath];
    task.arguments = @[ @"scan-json-stream", path ];

    NSPipe *stdoutPipe = [NSPipe pipe];
    NSPipe *stderrPipe = [NSPipe pipe];
    task.standardOutput = stdoutPipe;
    task.standardError = stderrPipe;

    NSFileHandle *stdoutHandle = [stdoutPipe fileHandleForReading];
    __block NSMutableData *lineBuffer = [NSMutableData data];
    stdoutHandle.readabilityHandler = ^(NSFileHandle *handle) {
      NSData *chunk = [handle availableData];
      if (chunk.length == 0) {
        return;
      }

      [lineBuffer appendData:chunk];
      const char *bytes = (const char *)lineBuffer.bytes;
      NSUInteger start = 0;
      for (NSUInteger i = 0; i < lineBuffer.length; i++) {
        if (bytes[i] != '\n') {
          continue;
        }
        NSData *lineData = [lineBuffer subdataWithRange:NSMakeRange(start, i - start)];
        NSString *line = [[NSString alloc] initWithData:lineData encoding:NSUTF8StringEncoding];
        if (line.length > 0) {
          dispatch_async(dispatch_get_main_queue(), ^{
            ProcessScanStreamLine(line);
          });
        }
        start = i + 1;
      }

      if (start > 0) {
        NSData *remaining = [lineBuffer subdataWithRange:NSMakeRange(start, lineBuffer.length - start)];
        [lineBuffer setData:remaining];
      }
    };

    task.terminationHandler = ^(NSTask *terminatedTask) {
      stdoutHandle.readabilityHandler = nil;
      NSData *stderrData = [[stderrPipe fileHandleForReading] readDataToEndOfFile];
      __block NSString *stderrText = [[NSString alloc] initWithData:stderrData encoding:NSUTF8StringEncoding];

      dispatch_async(dispatch_get_main_queue(), ^{
        gActiveScanTask = nil;
        SetScanning(NO);

        if (terminatedTask.terminationStatus != 0) {
          if (terminatedTask.terminationStatus == SIGTERM || terminatedTask.terminationStatus == SIGINT) {
            SetStatusMessage(@"Scan stopped");
            PromptForFullDiskAccessIfNeeded();
            return;
          }
          if (stderrText.length == 0) {
            stderrText = [NSString stringWithFormat:@"Scanner exited with code %d.", terminatedTask.terminationStatus];
          }
          SetStatusMessage(@"Scan failed");
          PresentError(@"Scan failed", stderrText);
          return;
        }

        if (lineBuffer.length > 0) {
          NSString *lastLine = [[NSString alloc] initWithData:lineBuffer encoding:NSUTF8StringEncoding];
          if (lastLine.length > 0) {
            ProcessScanStreamLine(lastLine);
          }
        }
      });
    };

    NSError *launchError = nil;
    if (![task launchAndReturnError:&launchError]) {
      dispatch_async(dispatch_get_main_queue(), ^{
        gActiveScanTask = nil;
        SetScanning(NO);
        SetStatusMessage(@"Ready");
        PresentError(@"Scan failed", launchError.localizedDescription ?: @"Unable to launch scanner.");
      });
      return;
    }

    [task waitUntilExit];
  });
}

static void ProcessScanStreamLine(NSString *line) {
  NSData *data = [line dataUsingEncoding:NSUTF8StringEncoding];
  if (data.length == 0) {
    return;
  }

  NSError *jsonError = nil;
  id parsed = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
  if (![parsed isKindOfClass:[NSDictionary class]]) {
    return;
  }

  NSDictionary *event = (NSDictionary *)parsed;
  NSDictionary *root = [event[@"root"] isKindOfClass:[NSDictionary class]] ? event[@"root"] : nil;
  NSString *type = [event[@"type"] isKindOfClass:[NSString class]] ? event[@"type"] : @"";
  NSString *status = [event[@"status"] isKindOfClass:[NSString class]] ? event[@"status"] : @"";
  long long elapsedMS = [event[@"elapsedMs"] longLongValue];
  gPermissionDeniedCount = [event[@"denied"] integerValue];

  if (root != nil) {
    ApplyRootNode(root);
  }

  if (status.length > 0) {
    if ([type isEqualToString:@"progress"]) {
      NSString *suffix = gPermissionDeniedCount > 0 ? [NSString stringWithFormat:@" | %ld protected", (long)gPermissionDeniedCount] : @"";
      SetStatusMessage([NSString stringWithFormat:@"%@ - %@%@", status, HumanReadableDuration(elapsedMS), suffix]);
    } else if ([type isEqualToString:@"cancelled"]) {
      SetStatusMessage(status);
      PromptForFullDiskAccessIfNeeded();
    } else {
      SetStatusMessage(status);
      PromptForFullDiskAccessIfNeeded();
    }
  }
}

static NSButton *MakeToolbarButton(NSString *title,
                                   NSString *symbolName,
                                   SEL action,
                                   CGFloat x,
                                   CGFloat width) {
  NSButton *button = [[NSButton alloc] initWithFrame:NSMakeRect(x, 36, width, 28)];
  [button setTitle:title];
  [button setBezelStyle:NSBezelStyleTexturedRounded];
  [button setTarget:gController];
  [button setAction:action];
  if (@available(macOS 11.0, *)) {
    NSImage *icon = [NSImage imageWithSystemSymbolName:symbolName accessibilityDescription:title];
    if (icon != nil) {
      [button setImage:icon];
      [button setImagePosition:NSImageLeading];
      [button setContentTintColor:[NSColor labelColor]];
    }
  }
  return button;
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

    NSMenuItem *aboutItem = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"About %@", appName]
                     action:@selector(orderFrontStandardAboutPanel:)
                   keyEquivalent:@""];
    [aboutItem setTarget:NSApp];
    [appMenu addItem:aboutItem];
    [appMenu addItem:[NSMenuItem separatorItem]];

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

  NSMenuItem *stopItem = [[NSMenuItem alloc] initWithTitle:@"Stop Scan"
                                                     action:@selector(stopScan:)
                                              keyEquivalent:@"."];
  [stopItem setTarget:gController];
  [fileMenu addItem:stopItem];

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
    [gWindow setTitleVisibility:NSWindowTitleVisible];
    [gWindow setToolbarStyle:NSWindowToolbarStyleUnified];
    [gWindow setTitlebarAppearsTransparent:NO];

    NSView *content = [[NSView alloc] initWithFrame:frame];
    [content setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [gWindow setContentView:content];

    NSVisualEffectView *header = [[NSVisualEffectView alloc] initWithFrame:NSMakeRect(0, frame.size.height - 72, frame.size.width, 72)];
    [header setMaterial:NSVisualEffectMaterialHeaderView];
    [header setBlendingMode:NSVisualEffectBlendingModeWithinWindow];
    [header setState:NSVisualEffectStateActive];
    [header setAutoresizingMask:NSViewWidthSizable | NSViewMinYMargin];

    gChooseButton = MakeToolbarButton(@"Select", @"externaldrive", @selector(chooseDirectory:), 16, 110);
    [header addSubview:gChooseButton];

    gRescanButton = MakeToolbarButton(@"Rescan", @"arrow.clockwise", @selector(rescan:), 134, 100);
    [gRescanButton setEnabled:NO];
    [header addSubview:gRescanButton];

    gStopButton = MakeToolbarButton(@"Stop", @"stop.circle", @selector(stopScan:), 242, 88);
    [gStopButton setEnabled:NO];
    [header addSubview:gStopButton];

    gProgressIndicator = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(342, 41, 16, 16)];
    [gProgressIndicator setStyle:NSProgressIndicatorStyleSpinning];
    [gProgressIndicator setDisplayedWhenStopped:NO];
    [header addSubview:gProgressIndicator];

    gStatusLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(364, 39, frame.size.width - 380, 18)];
    [gStatusLabel setEditable:NO];
    [gStatusLabel setBezeled:NO];
    [gStatusLabel setDrawsBackground:NO];
    [gStatusLabel setTextColor:[NSColor secondaryLabelColor]];
    [gStatusLabel setFont:[NSFont systemFontOfSize:12 weight:NSFontWeightMedium]];
    [gStatusLabel setAutoresizingMask:NSViewWidthSizable | NSViewMinYMargin];
    [header addSubview:gStatusLabel];

    gPathLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(16, 12, frame.size.width - 32, 18)];
    [gPathLabel setEditable:NO];
    [gPathLabel setBezeled:NO];
    [gPathLabel setDrawsBackground:NO];
    [gPathLabel setTextColor:[NSColor tertiaryLabelColor]];
    [gPathLabel setFont:[NSFont systemFontOfSize:12 weight:NSFontWeightRegular]];
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
    [gOutlineView setRowHeight:28.0];
    [gOutlineView setFloatsGroupRows:NO];

    NSTableColumn *nameColumn = MakeColumn(@"name", @"Name", 420);
    [gOutlineView addTableColumn:nameColumn];
    [gOutlineView addTableColumn:MakeColumn(@"size", @"Size", 140)];
    [gOutlineView addTableColumn:MakeColumn(@"allocated", @"Allocated", 140)];
    [gOutlineView addTableColumn:MakeColumn(@"files", @"Files", 90)];
    [gOutlineView addTableColumn:MakeColumn(@"folders", @"Folders", 90)];
    [gOutlineView addTableColumn:MakeColumn(@"percent", @"% of Parent (Allocated)", 160)];
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
    NSVisualEffectView *bottomPane = [[NSVisualEffectView alloc] initWithFrame:NSMakeRect(0, 0, frame.size.width, 120)];
    [bottomPane setMaterial:NSVisualEffectMaterialContentBackground];
    [bottomPane setBlendingMode:NSVisualEffectBlendingModeWithinWindow];
    [bottomPane setState:NSVisualEffectStateActive];
    [bottomPane setAutoresizingMask:NSViewWidthSizable | NSViewMaxYMargin];

    gSummaryLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(16, 92, frame.size.width - 32, 18)];
    [gSummaryLabel setEditable:NO];
    [gSummaryLabel setBezeled:NO];
    [gSummaryLabel setDrawsBackground:NO];
    [gSummaryLabel setFont:[NSFont monospacedDigitSystemFontOfSize:12 weight:NSFontWeightSemibold]];
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
