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
@property (nonatomic, readonly) NSDate *date;

- (id) initWithType:(LocationEventType)type subtitle:(NSString *)subtitle;

- (NSString *) title;

@end


@implementation LocationEvent

@synthesize type;
@synthesize subtitle;
@synthesize date;

- (id) initWithType:(LocationEventType)typeParam
           subtitle:(NSString *)subtitleParam {
  self = [super init];
  if (self) {
    type = typeParam;
    subtitle = [subtitleParam retain];
    date = [[NSDate alloc] init];
  }
  return self;
}

- (void) dealloc {
  [subtitle release];
  [date release];
  [super dealloc];
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

typedef enum {
  TableSectionStatus,
  TableSectionEvents,
} TableSection;

typedef enum {
  InfoRowState,
  InfoRowCoords,
} InfoRow;

#define kHeaderElementMargin 10

#pragma mark - View lifecycle

- (id) init {
  self = [super initWithStyle:UITableViewStyleGrouped];
  if (self) {
    locationManager = [[LocationManager sharedInstance] retain];
    [locationManager.listeners addObject:self];
    lastState = locationManager.locationState;
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

- (void) promptAuthorizationButtonPressed {
  [locationManager forcePromptAuthorization];
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
             action:@selector(promptAuthorizationButtonPressed)
   forControlEvents:UIControlEventTouchUpInside];
  button.frame = CGRectMake(0, 10, 300, kButtonHeight);
  [button setTitle:@"Prompt Authorization" forState:UIControlStateNormal];

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

- (void) pauseButtonPressed {
  [locationManager pause];
}

- (void) resumeButtonPressed {
  [locationManager resume];
}

- (void) forceAcquireLocationButtonPressed {
  [locationManager forceAcquireLocation];
}

- (void) showMapTableHeader {
  [self removeTableViewHeader];
  
  // Create the map.
  CGFloat topOffset = 0;
  mapView = [[MKMapView alloc] initWithFrame:CGRectMake(10, topOffset, 300, 300)];
  
  // Create the Pause button.
  topOffset += (300 + kHeaderElementMargin);
  UIButton *pauseButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
  [pauseButton addTarget:self
                  action:@selector(pauseButtonPressed)
        forControlEvents:UIControlEventTouchUpInside];
  pauseButton.frame = CGRectMake(10, topOffset, 145, kButtonHeight);
  [pauseButton setTitle:@"Pause" forState:UIControlStateNormal];
  
  // Create the resume button.
  UIButton *resumeButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
  [resumeButton addTarget:self
                   action:@selector(resumeButtonPressed)
         forControlEvents:UIControlEventTouchUpInside];
  resumeButton.frame = CGRectMake(165, topOffset, 145, kButtonHeight);
  [resumeButton setTitle:@"Resume" forState:UIControlStateNormal];
  
  // Create the Force Acquire Location button.
  topOffset += (kButtonHeight + kHeaderElementMargin);
  UIButton *forceAcquireButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
  [forceAcquireButton addTarget:self
                         action:@selector(forceAcquireLocationButtonPressed)
               forControlEvents:UIControlEventTouchUpInside];
  forceAcquireButton.frame = CGRectMake(10, topOffset, 300, kButtonHeight);
  [forceAcquireButton setTitle:@"Force Acquire Location" forState:UIControlStateNormal];
  
  // Add everything to the table header.
  CGFloat headerHeight = topOffset + kButtonHeight;
  tableViewHeader = [[UIView alloc]
                     initWithFrame:CGRectMake(0, 0, 320, headerHeight)];
  [tableViewHeader addSubview:mapView];
  [tableViewHeader addSubview:pauseButton];
  [tableViewHeader addSubview:resumeButton];
  [tableViewHeader addSubview:forceAcquireButton];
  
  [mapView release];
}

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
  return 2;
}

- (NSInteger) tableView:(UITableView *)tableView
  numberOfRowsInSection:(NSInteger)section {
  switch (section) {
    case TableSectionStatus:
      return 2;
    case TableSectionEvents:
      return [events count];
    default:
      break;
  }
  return 0;
}

- (NSString *) tableView:(UITableView *)tableView
 titleForHeaderInSection:(NSInteger)section {
  switch (section) {
    case TableSectionStatus:
      return @"Status";
    case TableSectionEvents:
      return @"Events";
    default:
      break;
  }
  return nil;
}

- (NSString *) tableView:(UITableView *)tableView
 titleForFooterInSection:(NSInteger)section {
  if ((section == TableSectionEvents) && ([events count] == 0)) {
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
    case InfoRowState:
      cell.textLabel.text = @"State";
      cell.detailTextLabel.text = [self
                                   stringFromLocationState:locationManager.locationState];
      break;
    case InfoRowCoords:
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
    case TableSectionStatus:
      return [self cellForStatusAtRow:indexPath.row];
    case TableSectionEvents:
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

- (void) updateState {
  LocationState newState = locationManager.locationState;
  if (newState != lastState) {
    lastState = newState;
    NSArray *indexPaths = [NSArray arrayWithObject:[NSIndexPath
                                                    indexPathForRow:0
                                                    inSection:0]];
    [self.tableView reloadRowsAtIndexPaths:indexPaths
                          withRowAnimation:UITableViewRowAnimationFade];
  }
}

- (void) setLocation:(CLLocation *)location {
  NSString *subtitle = [self stringFromLocation:location];
  [self addLocationEventWithType:LocationEventTypeSetLocation
                        subtitle:subtitle];
  [self updateState];
}

- (void) accessPrompted {
  [self addLocationEventWithType:LocationEventTypeAccessPrompted];
  [self updateState];
}

- (void) accessGranted {
  [self addLocationEventWithType:LocationEventTypeAccessGranted];
  [self updateState];
}

- (void) accessDenied {
  [self addLocationEventWithType:LocationEventTypeAccessDenied];
  [self updateState];
}

- (void) forceAcquireLocation {
  [self addLocationEventWithType:LocationEventTypeForceAcquireLocation];
  [self updateState];
}

- (void) significantChangeDetected:(CLLocation *)location {
  NSString *subtitle = [self stringFromLocation:location];
  [self addLocationEventWithType:LocationEventTypeSignificantChangeDetected
                        subtitle:subtitle];
  [self updateState];
}

- (void) acquiringLocationFailed {
  [self addLocationEventWithType:LocationEventTypeAcquiringLocationFailed];
  [self updateState];
}

- (void) acquiringLocationPaused {
  [self addLocationEventWithType:LocationEventTypeAcquiringLocationPaused];
  [self updateState];
}

- (void) acquiringLocationResumed {
  [self addLocationEventWithType:LocationEventTypeAcquiringLocationResumed];
  [self updateState];
}

@end
