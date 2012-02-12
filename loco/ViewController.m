#import "ViewController.h"

#import <MapKit/MapKit.h>

typedef enum {
  LocationEventTypeSetLocationState,
  LocationEventTypeSetLocation,
  LocationEventTypeAccessPrompted,
  LocationEventTypeAccessGranted,
  LocationEventTypeForceAcquireBestLocation,
  LocationEventTypeStaleSignificantChangeDetected,
  LocationEventTypeCurrentSignificantChangeDetected,
  LocationEventTypeStaleAccurateLocationFound,
  LocationEventTypeCurrentAccurateLocationFound,
  LocationEventTypeAccessDenied,
  LocationEventTypeAcquiringLocationFailed,
  LocationEventTypeAcquiringLocationPaused,
  LocationEventTypeAcquiringLocationResumed,
} LocationEventType;

#define kButtonHeight 40

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
    case LocationEventTypeSetLocationState:
      return @"SetLocationState";
    case LocationEventTypeSetLocation:
      return @"SetLocation";
    case LocationEventTypeAccessPrompted:
      return @"AccessPrompted";
    case LocationEventTypeAccessGranted:
      return @"AccessGranted";
    case LocationEventTypeForceAcquireBestLocation:
      return @"ForceAcquireBestLocation";
    case LocationEventTypeStaleSignificantChangeDetected:
      return @"StaleSignificantChangeDetected";
    case LocationEventTypeCurrentSignificantChangeDetected:
      return @"CurrentSignificantChangeDetected";
    case LocationEventTypeStaleAccurateLocationFound:
      return @"StaleAccurateLocationFound";
    case LocationEventTypeCurrentAccurateLocationFound:
      return @"CurrentAccurateLocationFound";
    case LocationEventTypeAccessDenied:
      return @"LocationEventTypeAccessDenied";
    case LocationEventTypeAcquiringLocationFailed:
      return @"AcquiringLocationFailed";
    case LocationEventTypeAcquiringLocationPaused:
      return @"AcquiringLocationPaused";
    case LocationEventTypeAcquiringLocationResumed:
      return @"AcquiringLocationResumed";
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
  if (self) {
    locationManager = [[LocationManager sharedInstance] retain];
    events = [[NSMutableArray alloc] init];
  }
  return self;
}

- (void) dealloc {
  [locationManager release];
  [events release];
  
  [tableViewHeader release];
  [mapView release];
  
  [super dealloc];
}

- (void) pause {
  [locationManager pause];
}

- (void) resume {
  [locationManager resume];
}

- (void) removeTableViewHeader {
  [tableViewHeader removeFromSuperview];
  [tableViewHeader release];
  tableViewHeader = nil;
}

- (void) showStartTableHeader {
  [self removeTableViewHeader];
  
  // Create the button.
  UIButton *button = [UIButton buttonWithType:UIButtonTypeRoundedRect];
  [button addTarget:self
             action:@selector(resume)
   forControlEvents:UIControlEventTouchUpInside];
  [button setTitle:@"Start" forState:UIControlStateNormal];

  // Show the button in the table header.
  CGSize buttonSize = button.frame.size;
  tableViewHeader =
      [[UIView alloc]
       initWithFrame:CGRectMake(0, 0, 320, buttonSize.height)];
  [tableViewHeader addSubview:button];
}

- (void) viewDidLoad {
  [super viewDidLoad];
  
  self.title = @"Loco Demo";
  [self showStartTableHeader];
}

- (void) showMapTableHeader {
  [self removeTableViewHeader];
  
  // Create the map.
  mapView = [[MKMapView alloc]
             initWithFrame:CGRectMake(kButtonHeight + 10, 10, 300, 300)];
  
  // Create the Pause button.
  UIButton *pauseButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
  [pauseButton addTarget:self
                  action:@selector(pause)
        forControlEvents:UIControlEventTouchUpInside];
  pauseButton.frame = CGRectMake(0, 10, 145, kButtonHeight);
  [pauseButton setTitle:@"Pause" forState:UIControlStateNormal];
  
  // Create the resume button.
  UIButton *resumeButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
  [resumeButton addTarget:self
                   action:@selector(resume)
         forControlEvents:UIControlEventTouchUpInside];
  resumeButton.frame = CGRectMake(0, 165, 145, kButtonHeight);
  [resumeButton setTitle:@"Resume" forState:UIControlStateNormal];
  
  // Add everything to the table header.
  tableViewHeader = [[UIView alloc]
                     initWithFrame:CGRectMake(0, 0, 320, kButtonHeight + 310)];
  [tableViewHeader addSubview:mapView];
  [tableViewHeader addSubview:pauseButton];
  [tableViewHeader addSubview:resumeButton];
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
    cell.textLabel.font = [UIFont boldSystemFontOfSize:13];
    cell.detailTextLabel.font = [UIFont systemFontOfSize:11];
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
  [self addLocationEventWithType:LocationEventTypeStaleSignificantChangeDetected
                        subtitle:subtitle];
}

- (void) currentSignificantChangeDetected:(CLLocation *)location {
  NSString *subtitle = [self stringFromCoordinate:location.coordinate];
  [self
   addLocationEventWithType:LocationEventTypeCurrentSignificantChangeDetected
   subtitle:subtitle];
}

- (void) staleAccurateLocationFound:(CLLocation *)location {
  NSString *subtitle = [self stringFromCoordinate:location.coordinate];
  [self addLocationEventWithType:LocationEventTypeStaleAccurateLocationFound
                        subtitle:subtitle];
}

- (void) currentAccurateLocationFound:(CLLocation *)location {
  NSString *subtitle = [self stringFromCoordinate:location.coordinate];
  [self addLocationEventWithType:LocationEventTypeCurrentAccurateLocationFound
                        subtitle:subtitle];
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
