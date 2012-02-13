#import "LocationManager.h"

#import "LocationManagerListener.h"

@implementation LocationManager

// Time in seconds significant changes are recognized after an exact location is acquired.
#define kMinSecondsSignificantChange 30
// Maximum time ago in seconds for a location to be considered recent.
#define kMaxSecondsRecentUpdate 30
// Maximum number of failed location update attempts until retrying later.
#define kMaxFailedUpdateAttempts 5
// TODO
#define kMaxGpsOnTime 15

@synthesize locationState;
@synthesize location;
@synthesize listeners;

static LocationManager *singleton;

- (id) init {
  self = [super init];
  if (self) {
    locationState = LocationStateInit;
    listeners = [[NSMutableArray alloc] init];

    manager = [[CLLocationManager alloc] init];
    manager.delegate = self;
    failedUpdateAttempts = 0;
  }
  return self;
}

- (void) dealloc {
  [location release];
  [listeners release];

  [manager release];
  [significantChangeTimestamp release];

  [super dealloc];
}

+ (LocationManager *) sharedInstance {
  if (singleton == nil) {
    singleton = [[LocationManager alloc] init];
  }
  return singleton;
}

- (void) setLocationState:(LocationState)locationStateParam {
  locationState = locationStateParam;
  for (NSObject<LocationManagerListener> *listener in listeners) {
    if ([listener respondsToSelector:@selector(setLocationState:)]) {
      [listener setLocationState:locationState];
    }
  }
}

- (void) stopAcquiringLocation {
  for (NSObject<LocationManagerListener> *listener in listeners) {
    if ([listener respondsToSelector:@selector(setLocation:)]) {
      [listener setLocation:location];
    }
  }
  NSLog(@"New location found, lat=%f, lon=%f",
        location.coordinate.latitude,
        location.coordinate.longitude);
  
  // Switch back to monitoring significant location changes.
  [manager stopUpdatingLocation];
  [self setLocationState:LocationStateWaitingSignificantChange];
  [manager startMonitoringSignificantLocationChanges];
}

- (void) acquiringLocationTimerExpired {
  [self stopAcquiringLocation];
}

- (void) cancelAcquiringAccurateLocationTimer {
  [NSObject
   cancelPreviousPerformRequestsWithTarget:self
   selector:@selector(acquiringLocationTimerExpired)
   object:nil];
}

- (void) startAcquiringLocationTimer {
  [self performSelector:@selector(acquiringLocationTimerExpired)
             withObject:nil
             afterDelay:kMaxGpsOnTime];
}

- (void) startAcquiringAccurateLocation {
  manager.desiredAccuracy = kCLLocationAccuracyBest;
  manager.distanceFilter = kCLDistanceFilterNone;
  [manager startUpdatingLocation];
  
  // Do not use GPS forever.
  [self startAcquiringLocationTimer];
}

- (void) promptEnableLocationAccess {
  // Simply starting the location manager will prompt again.
  [self setLocationState:LocationStatePrompted];
  [self startAcquiringAccurateLocation];
  
  for (NSObject<LocationManagerListener> *listener in listeners) {
    if ([listener respondsToSelector:@selector(accessPrompted)]) {
      [listener accessPrompted];
    }
  }
}

- (void) tryPromptEnableLocationAccess {
  if (locationState == LocationStateInit) {
    [self promptEnableLocationAccess];
  }
}

- (void) forcePromptEnableLocationAccess {
  if ((locationState == LocationStateInit) ||
      (locationState == LocationStateDenied)) {
    [self promptEnableLocationAccess];
  }
}

- (void) updateToLocation:(CLLocation *)newLocation {
  // The horizontalAccuracy does not use the CLLocationAccuracy constants. If
  // negative, it is invalid, and not kCLLocationAccuracyBest.
  if (newLocation.horizontalAccuracy < 0) {
    return;
  }
  
  if ((location == nil) ||
      (newLocation.horizontalAccuracy < location.horizontalAccuracy)) {
    location = newLocation;
    
    // Less than ten meters is sufficiently close.
    if (location.horizontalAccuracy < kCLLocationAccuracyNearestTenMeters) {
      [self cancelAcquiringAccurateLocationTimer];
      [self stopAcquiringLocation];
    }
  }
}

#pragma mark CLLocationManagerDelegate methods.

- (void) locationManager:(CLLocationManager *)managerParam
     didUpdateToLocation:(CLLocation *)newLocation
            fromLocation:(CLLocation *)oldLocation {
  if ((locationState == LocationStateInit) ||
      (locationState == LocationStateDenied) ||
      (locationState == LocationStatePaused)) {
    NSLog(@"Got new location when locationState=%d", locationState);
  }
  
  failedUpdateAttempts = 0;
  if (locationState == LocationStatePrompted) {
    [self setLocationState:LocationStateAcquiring];

    for (NSObject<LocationManagerListener> *listener in listeners) {
      if ([listener respondsToSelector:@selector(accessGranted)]) {
        [listener accessGranted];
      }
    }

    // Already attempting to acquire location using GPS.
    return;
  }

  if (locationState == LocationStateWaitingSignificantChange) {
    if (location != nil) {
      // Ignore change if acquired location using GPS recently.
      NSTimeInterval secondsSinceExactLocation = [newLocation.timestamp
                                                  timeIntervalSinceDate:location.timestamp];
      if (secondsSinceExactLocation < kMinSecondsSignificantChange) {
        return;
      }
    }
    
    for (NSObject<LocationManagerListener> *listener in listeners) {
      if ([listener respondsToSelector:@selector(currentSignificantChangeDetected:)]) {
        [listener significantChangeDetected:newLocation];
      }
    }
    
    // Exact location is found comparing to current significant change timestamp.
    [significantChangeTimestamp release];
    significantChangeTimestamp = [newLocation.timestamp retain];

    [manager stopMonitoringSignificantLocationChanges];
    
    // Get a more accurate location.
    [self startAcquiringAccurateLocation];
    [self setLocationState:LocationStateAcquiring];
    return;
  }
  
  if (locationState == LocationStateAcquiring) {
    if (significantChangeTimestamp == nil) {
      // Acquiring the first location; make it recent.
      NSTimeInterval locationAgeInSeconds = [[NSDate date]
                                             timeIntervalSinceDate:newLocation.timestamp];
      if (locationAgeInSeconds < kMaxSecondsRecentUpdate) {
        [self updateToLocation:newLocation];
      } else {
        NSLog(@"First location with GPS is stale");
      }
    } else {
      // Wait for a location acquired after the significant location change.
      if ([newLocation.timestamp
           compare:significantChangeTimestamp] == NSOrderedDescending) {
        [self updateToLocation:newLocation];
      } else {
        NSLog(@"Next location with GPS is stale");
      }
    }
  }
}

- (void) locationManager:(CLLocationManager *)managerParam
        didFailWithError:(NSError *)error {
  if (isPaused) {
    return;
  }
  if (locationState == LocationStateDenied) {
    NSLog(@"Failed to acquire location when access denied");
    return;
  }
  
  if (error.code == kCLErrorDenied) {
    for (NSObject<LocationManagerListener> *listener in locationManagerListeners) {
      if ([listener respondsToSelector:@selector(accessDenied)]) {
        [listener accessDenied];
      }
    }

    // The user denied location access, so stop attempting to acquire it.
    [self setLocationState:LocationStateDenied];
    [manager stopUpdatingLocation];
    
    UIAlertView *alert =
        [[UIAlertView alloc]
         initWithTitle:@"Location Access Recommended"
         message:@"Your location is needed to show nearby plans and provide a location for your own plans. "
                 @"Visit the Settings tab to enable."
         delegate:nil
         cancelButtonTitle:@"Okay"
         otherButtonTitles:nil];
    [alert show];
    [alert release];
    return;
  }
  
  if (locationState == LocationStatePrompted) {
    // Location access was granted, but acquisition failed.
    [self setLocationState:LocationStateAcquiringBest];
    
    for (NSObject<LocationManagerListener> *listener in locationManagerListeners) {
      if ([listener respondsToSelector:@selector(accessGranted)]) {
        [listener accessGranted];
      }
    }
  }

  // Failing to get a significant change in location is ignored. 
  if (locationState == LocationStateAcquiringBest) {
    for (NSObject<LocationManagerListener> *listener in locationManagerListeners) {
      if ([listener respondsToSelector:@selector(acquiringLocationFailed)]) {
        [listener acquiringLocationFailed];
      }
    }

    ++failedUpdateAttempts;
    if (failedUpdateAttempts >= kMaxFailedUpdateAttempts) {
      // Failed too many times to acquire the location again, so stop for now.
      failedUpdateAttempts = 0;
      [self setLocationState:LocationStateAcquiringBestFailed];
      [manager stopUpdatingLocation];
    }
  }
}

- (void) pause {
  if ((locationState == LocationStateInit) || 
      (locationState == LocationStatePrompted) ||
      (locationState == LocationStateDenied)) {
    return;
  }
  NSAssert(!isPaused, @"LocationManager is already paused");
  isPaused = YES;
  
  if (locationState == LocationStateWaitingSignificantChange) {
    [manager stopMonitoringSignificantLocationChanges];
    for (NSObject<LocationManagerListener> *listener in locationManagerListeners) {
      if ([listener respondsToSelector:@selector(acquiringLocationPaused)]) {
        [listener acquiringLocationPaused];
      }
    }
  } else if ((locationState == LocationStateAcquiringBest) ||
             (locationState == LocationStateAcquiringBestFailed)) {
    [manager stopUpdatingLocation];
    for (NSObject<LocationManagerListener> *listener in locationManagerListeners) {
      if ([listener respondsToSelector:@selector(acquiringLocationPaused)]) {
        [listener acquiringLocationPaused];
      }
    }
  }
}

- (void) resume {
  if ((locationState == LocationStateUnknown) || 
      (locationState == LocationStatePrompted) ||
      (locationState == LocationStateDenied)) {
    return;
  }
  NSAssert(isPaused, @"LocationManager was not paused");
  isPaused = NO;
  
  if (locationState == LocationStateWaitingSignificantChange) {
    [manager startMonitoringSignificantLocationChanges];
    
    for (NSObject<LocationManagerListener> *listener in locationManagerListeners) {
      if ([listener respondsToSelector:@selector(acquiringLocationResumed)]) {
        [listener acquiringLocationResumed];
      }
    }
  } else if ((locationState == LocationStateAcquiringBest) ||
             (locationState == LocationStateAcquiringBestFailed)) {
    failedUpdateAttempts = 0;
    [self startAcquiringAccurateLocation];
    locationState = LocationStateAcquiringBest;
    
    for (NSObject<LocationManagerListener> *listener in locationManagerListeners) {
      if ([listener respondsToSelector:@selector(acquiringLocationResumed)]) {
        [listener acquiringLocationResumed];
      }
    }
  }
}

- (void) forceAcquireBestLocation {
  if (locationState == LocationStateWaitingSignificantChange)) {
    [exactLocationTimestamp release];
    exactLocationTimestamp = nil;
    
    [manager stopMonitoringSignificantLocationChanges];
    
    // Get a more accurate location.
    [self startAcquiringAccurateLocation];
    
    for (NSObject<LocationManagerListener> *listener in locationManagerListeners) {
      if ([listener respondsToSelector:@selector(forceAcquireBestLocation)]) {
        [listener forceAcquireBestLocation];
      }
    }
    [self setLocationState:LocationStateAcquiringBest];
  }
}

@end
