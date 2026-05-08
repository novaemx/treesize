#import <Cocoa/Cocoa.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#include <string.h>

@interface TreeDataSource : NSObject <NSOutlineViewDataSource, NSOutlineViewDelegate>
@property(nonatomic, strong) NSDictionary *rootNode;
@property(nonatomic, assign) long long totalSize;
@end

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
  NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
  fmt.dateStyle = NSDateFormatterShortStyle;
  fmt.timeStyle = NSDateFormatterShortStyle;
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

static TreeDataSource *gDataSource;

static NSTableColumn *MakeColumn(NSString *identifier, NSString *title, CGFloat width) {
  NSTableColumn *col = [[NSTableColumn alloc] initWithIdentifier:identifier];
  col.title = title;
  col.width = width;
  col.minWidth = width * 0.7;
  return col;
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
      rootNode = @{ @"name" : @"(empty)", @"size" : @0, @"children" : @[] };
    }

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
    [window setTitle:@"TreeSize"];

    NSView *content = [[NSView alloc] initWithFrame:frame];
    [content setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [window setContentView:content];

    NSTextField *pathLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(16, frame.size.height - 34, frame.size.width - 32, 18)];
    [pathLabel setEditable:NO];
    [pathLabel setBezeled:NO];
    [pathLabel setDrawsBackground:NO];
    [pathLabel setAutoresizingMask:NSViewWidthSizable | NSViewMinYMargin];
    NSString *rootPath = rootNode[@"path"] ?: @"";
    [pathLabel setStringValue:[NSString stringWithFormat:@"Root: %@", rootPath]];
    [content addSubview:pathLabel];

    NSSplitView *splitView = [[NSSplitView alloc] initWithFrame:NSMakeRect(0, 0, frame.size.width, frame.size.height - 44)];
    [splitView setVertical:NO];
    [splitView setDividerStyle:NSSplitViewDividerStyleThin];
    [splitView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];

    NSScrollView *scrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 0, frame.size.width, frame.size.height - 164)];
    [scrollView setHasVerticalScroller:YES];
    [scrollView setHasHorizontalScroller:YES];

    NSOutlineView *outlineView = [[NSOutlineView alloc] initWithFrame:scrollView.bounds];
    [outlineView setUsesAlternatingRowBackgroundColors:YES];

    NSTableColumn *nameColumn = MakeColumn(@"name", @"Name", 420);
    [outlineView addTableColumn:nameColumn];
    [outlineView addTableColumn:MakeColumn(@"size", @"Size", 140)];
    [outlineView addTableColumn:MakeColumn(@"files", @"Files", 90)];
    [outlineView addTableColumn:MakeColumn(@"folders", @"Folders", 90)];
    [outlineView addTableColumn:MakeColumn(@"percent", @"% of Parent", 110)];
    [outlineView addTableColumn:MakeColumn(@"modified", @"Last Modified", 160)];
    [outlineView setOutlineTableColumn:nameColumn];

    gDataSource = [[TreeDataSource alloc] init];
    gDataSource.rootNode = rootNode;
    gDataSource.totalSize = [rootNode[@"size"] longLongValue];

    [outlineView setDataSource:gDataSource];
    [outlineView setDelegate:gDataSource];
    [outlineView reloadData];
    [outlineView expandItem:nil expandChildren:NO];

    [scrollView setDocumentView:outlineView];
    [splitView addArrangedSubview:scrollView];

    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    NSView *bottomPane = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, frame.size.width, 120)];
    [bottomPane setAutoresizingMask:NSViewWidthSizable | NSViewMaxYMargin];

    NSTextField *summaryLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(16, 92, frame.size.width - 32, 18)];
    [summaryLabel setEditable:NO];
    [summaryLabel setBezeled:NO];
    [summaryLabel setDrawsBackground:NO];
    [summaryLabel setAutoresizingMask:NSViewWidthSizable | NSViewMinYMargin];
    [summaryLabel setStringValue:[NSString stringWithFormat:@"Total: %@ | Files: %lld | Folders: %lld",
                                                            [gDataSource humanReadableSize:gDataSource.totalSize],
                                                            [rootNode[@"fileCount"] longLongValue],
                                                            [rootNode[@"folderCount"] longLongValue]]];
    [bottomPane addSubview:summaryLabel];

    if (device != nil) {
      MTKView *metalView = [[MTKView alloc] initWithFrame:NSMakeRect(16, 8, frame.size.width - 32, 76) device:device];
      [metalView setEnableSetNeedsDisplay:YES];
      [metalView setAutoresizingMask:NSViewWidthSizable | NSViewMinYMargin];
      [bottomPane addSubview:metalView];
    }

    [splitView addArrangedSubview:bottomPane];
    [splitView adjustSubviews];
    [content addSubview:splitView];

    [window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
    [NSApp run];
  }
}
