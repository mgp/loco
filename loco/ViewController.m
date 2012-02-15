#import "ViewController.h"

#import <MapKit/MapKit.h>

typedef enum {
  LocationEventTypeSetLocation,
  LocationEventTypeAccessPrompted,
  LocationEventTypeAccessGranted,
  LocationEventTypeAccessDenied,
  LocationEventTypeForceAcquireLocation,
  LocationEventTypeSignificantChangeDetected,
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
    case LocationEventTypeSetLocation:
      return @"SetLocation";
    case LocationEventTypeAccessPrompted:
      return @"AccessPrompted";
    case LocationEventTypeAccessGranted:
      return @"AccessGranted";
    case LocationEventTypeAccessDenied:
      return @"AccessDenied";
    case LocationEventTypeForceAcquireLocation:
      return @"ForceAcquireLocation";
    case LocationEventTypeSignificantChangeDetected:
      return @"SignificantChangeDetected";
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
  button.frame = CGRectMake(0, 10, 300, kButtonHeight);
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
  return [events count];
}

- (NSString *) tableView:(UITableView *)tableView
 titleForHeaderInSection:(NSInteger)section {
  return @"Location Events";
}

- (NSString *) tableView:(UITableView *)tableView
 titleForFooterInSection:(NSInteger)section {
  if ([events count] == 0) {
    return @"No events yet";
  }
  return nil;
}

- (NSString *) stringFromLocation:(CLLocation *)location {
  CLLocationCoordinate2D coordinate = location.coordinate;
  return [NSString stringWithFormat:@"lat=%f, lon=%f",
          coordinate.latitude,
          coordinate.longitude];
}

- (NSString *) stringFromLocationState:(LocationState)locationState {
  switch (locationState) {
    case LocationStateInit:
      return @"Init";
    case LocationStatePrompted:
      return @"Prompted";
    case LocationStateDenied:
      return @"Denied";
    case LocationStateWaitingSignificantChange:
      return @"WaitingSignificantChange";
    case LocationStateAcquiring:
      return @"Acquiring";
    case LocationStatePaused:
      return @"Paused";
    default:
      break;
  }
  return nil;
}

- (UITableViewCell *) cellForStatusAtRow:(NSUInteger)row {
  static NSString *CellIdentifier = @"StatusCellIdentifier";
  UITableViewCell *cell = [self.tableView
                           dequeueReusableCellWithIdentifier:CellIdentifier];
  if (cell == nil) {
    cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
                                   reuseIdentifier:CellIdentifier]
            autorelease];
    // TODO: set font sizes
  }
  
  switch (row) {
    case 0:
      cell.textLabel.text = @"State";
      cell.detailTextLabel.text = [self
                                   stringFromLocationState:locationManager.locationState];
      break;
    case 1:
      cell.textLabel.text = @"Coords";
      cell.detailTextLabel.text = [self
                                   stringFromLocation:locationManager.location];
      break;
    default:
      break;
  }
  return cell;
}

- (UITableViewCell *) cellForEventAtRow:(NSUInteger)row {
  static NSString *CellIdentifier = @"EventCellIdentifier";
  UITableViewCell *cell = [self.tableView
                           dequeueReusableCellWithIdentifier:CellIdentifier];
  if (cell == nil) {
    cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                   reuseIdentifier:CellIdentifier]
            autorelease];
    cell.textLabel.font = [UIFont boldSystemFontOfSize:13];
    cell.detailTextLabel.font = [UIFont systemFontOfSize:11];
  }
  
  // The most recent event is the last element in the array.
  NSUInteger index = [events count] - 1 - row;
  LocationEvent *event = [events objectAtIndex:index];
  cell.textLabel.text = [event title];
  cell.detailTextLabel.text = event.subtitle;
  return cell;
}

- (UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  switch (indexPath.section) {
    case 0:
      return [self cellForStatusAtRow:indexPath.row];
    case 1:
      return [self cellForEventAtRow:indexPath.row];
    default:
      break;
  }
  return nil;
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

- (void) setLocation:(CLLocation *)location {
  NSString *subtitle = [self stringFromLocation:location];
  [self addLocationEventWithType:LocationEventTypeSetLocation
                        subtitle:subtitle];
}

- (void) accessPrompted {
  [self addLocationEventWithType:LocationEventTypeAccessPrompted];
}

- (void) accessGranted {
  [self addLocationEventWithType:LocationEventTypeAccessGranted];
}

- (void) accessDenied {
  [self addLocationEventWithType:LocationEventTypeAccessDenied];
}

- (void) forceAcquireLocation {
  [self addLocationEventWithType:LocationEventTypeForceAcquireLocation];
}

- (void) significantChangeDetected:(CLLocation *)location {
  NSString *subtitle = [self stringFromLocation:location];
  [self addLocationEventWithType:LocationEventTypeSignificantChangeDetected
                        subtitle:subtitle];
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
