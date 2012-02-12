#import "ViewController.h"

typedef enum {
  LocationEventTypeSetLocationState,
  LocationEventTypeSetLocation,
  LocationEventTypeAccessPrompted,
  LocationEventTypeAccessGranted,
  LocationEventTypeForceAcquireBestLocation,
  LocationEventTypeAccessDenied,
  LocationEventTypeAcquiringLocationFailed,
  LocationEventTypeAcquiringLocationPaused,
  LocationEventTypeAcquiringLocationResumed,
} LocationEventType;

@interface LocationEvent : NSObject {
@private
  LocationEventType type;
  NSString *subtitle;
  NSDate *date;
}

@property (nonatomic, readonly) LocationEventType type;
@property (nonatomic, readonly) NSString *subtitle;

- (id) initWithType:(LocationEventType)type subtitle:(NSString *)subtitle;

- (NSString *) title;

@end


@implementation LocationEvent

@synthesize type;
@synthesize subtitle;

- (id) initWithType:(LocationEventType)typeParam
           subtitle:(NSString *)subtitleParam {
  self = [super init];
  if (self) {
    type = typeParam;
  }
  return self;
}

- (NSString *) title {
  switch (type) {
    default:
      break;
  }
  return nil;
}

@end


@implementation ViewController

#pragma mark - View lifecycle

- (id) init {
  self = [super initWithStyle:UITableViewStyleGrouped];
  return self;
}

- (void) viewDidLoad {
  [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
}

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
  return 1;
}

- (NSInteger) tableView:(UITableView *)tableView
  numberOfRowsInSection:(NSInteger)section {
  return 1;
}

- (UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  static NSString *CellIdentifier = @"CellIdentifier";
  UITableViewCell *cell = [self.tableView
                           dequeueReusableCellWithIdentifier:CellIdentifier];
  if (cell == nil) {
    cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                   reuseIdentifier:CellIdentifier]
            autorelease];
  }
  
  // The most recent is the last element in the array.
  NSUInteger index = [events count] - 1 - indexPath.row;
  LocationEvent *event = [events objectAtIndex:index];
  cell.textLabel.text = [event title];
  cell.detailTextLabel.text = event.subtitle;
  return cell;
}

#pragma mark - LocationManagerListener methods.

- (void) addLocationEvent:(LocationEvent *)event {
  [events addObject:event];
  [self.tableView
   insertRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath
                                                    indexPathForRow:0
                                                    inSection:0]]
   withRowAnimation:UITableViewRowAnimationLeft];
}

- (void) addLocationEventWithType:(LocationEventType)type
                         subtitle:(NSString *)subtitle {
  LocationEvent *event = [[LocationEvent alloc] initWithType:type
                                                    subtitle:subtitle];
  [self addLocationEvent:event];
  [event release];
}

- (void) addLocationEventWithType:(LocationEventType)type {
  [self addLocationEventWithType:type subtitle:nil];
}

- (NSString *) stringFromLocationState:(LocationState)locationState {
  switch (locationState) {
    case LocationStateUnknown:
      return @"LocationStateUnknown";
    case LocationStatePrompted:
      return @"LocationStatePrompted";
    case LocationStateDenied:
      return @"LocationStateDenied";
    case LocationStateWaitingSignificantChange:
      return @"LocationStateWaitingSignificantChange";
    case LocationStateAcquiringBest:
      return @"LocationStateAcquiringBest";
    case LocationStateAcquiringBestFailed:
      return @"LocationStateAcquiringBestFailed";
    default:
      break;
  }
  return nil;
}

- (NSString *) stringFromCoordinate:(CLLocationCoordinate2D)coordinate {
  return [NSString stringWithFormat:@"lat=%f, lon=%f",
          coordinate.latitude,
          coordinate.longitude];
}

- (void) setLocationState:(LocationState)locationState {
  NSString *subtitle = [self stringFromLocationState:locationState];
  [self addLocationEventWithType:LocationEventTypeSetLocationState
                        subtitle:subtitle];
}

- (void) setLocation:(CLLocationCoordinate2D)coordinate {
  NSString *subtitle = [self stringFromCoordinate:coordinate];
  [self addLocationEventWithType:LocationEventTypeSetLocation
                        subtitle:subtitle];
}

- (void) accessPrompted {
  [self addLocationEventWithType:LocationEventTypeAccessPrompted];
}

- (void) accessGranted {
  [self addLocationEventWithType:LocationEventTypeAccessGranted];
}

- (void) forceAcquireBestLocation {
  [self addLocationEventWithType:LocationEventTypeForceAcquireBestLocation];
}

- (void) staleSignificantChangeDetected:(CLLocation *)location {
  NSString *subtitle = [self stringFromCoordinate:location.coordinate];
  
}

- (void) currentSignificantChangeDetected:(CLLocation *)location {
  NSString *subtitle = [self stringFromCoordinate:location.coordinate];
  
}

- (void) staleFirstLocationFound:(CLLocation *)location {
  NSString *subtitle = [self stringFromCoordinate:location.coordinate];
  
}

- (void) currentFirstLocationFound:(CLLocation *)location {
  NSString *subtitle = [self stringFromCoordinate:location.coordinate];
  
}

- (void) staleNextLocationFound:(CLLocation *)location {
  NSString *subtitle = [self stringFromCoordinate:location.coordinate];
  
}

- (void) currentNextLocationFound:(CLLocation *)location {
  NSString *subtitle = [self stringFromCoordinate:location.coordinate];
  
}

- (void) accessDenied {
  [self addLocationEventWithType:LocationEventTypeAccessDenied];
}

- (void) acquiringLocationFailed {
  [self addLocationEventWithType:LocationEventTypeAcquiringLocationFailed];
}

- (void) acquiringLocationPaused {
  [self addLocationEventWithType:LocationEventTypeAcquiringLocationPaused];
}

- (void) acquiringLocationResumed {
  [self addLocationEventWithType:LocationEventTypeAcquiringLocationResumed];
}

@end
