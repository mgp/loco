#import "LocationManager.h"

#import "LocationManagerListener.h"

@interface LocationManager()

- (void) startMonitoringSignificantChanges;
- (void) stopMonitoringSignificantChanges;
- (void) startAcquiringLocation;
- (void) stopAcquiringLocation;

@end

@implementation LocationManager

// Time in seconds significant changes are recognized after acquiring a location.
#define kMinSecondsSignificantChange 30
// Maximum time ago in seconds for a location to be considered recent.
#define kMaxSecondsRecentUpdate 30
// Maximum number of failed location update attempts until retrying later.
#define kMaxFailedUpdateAttempts 5
// Maximum number of seconds to keep the GPS on for.
#define kMaxGpsOnTime 15
// The desired accuracy of an acquired location.
#define kDesiredLocationAccuracy kCLLocationAccuracyNearestTenMeters
// The acceptable accuracy of an acquired location when the GPS timer expires.
#define kAcceptableLocationAccuracy kCLLocationAccuracyHundredMeters

#define LOCO_LOG 0

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

  manager.delegate = nil;
  [manager release];
  [acquiringLocation release];
  [significantChangeTimestamp release];

  [super dealloc];
}

+ (LocationManager *) sharedInstance {
  if (singleton == nil) {
    singleton = [[LocationManager alloc] init];
  }
  return singleton;
}

- (BOOL) locationHasMinimumAccuracy:(CLLocationAccuracy)minimumAccuracy {
  return (acquiringLocation.horizontalAccuracy <= minimumAccuracy);
}

- (void) finishAcquiringLocation {
  // The location we acquired is accurate enough, and is the new location.
  [location release];
  location = acquiringLocation;
  acquiringLocation = nil;
  
  for (NSObject<LocationManagerListener> *listener in listeners) {
    if ([listener respondsToSelector:@selector(setLocation:)]) {
      [listener setLocation:location];
    }
  }
}

- (void) acquiringLocationTimerExpired {
#if LOCO_LOG
  NSLog(@"Timer for acquiring location expired");
#endif
  
  if ((acquiringLocation == nil) ||
      ![self locationHasMinimumAccuracy:kAcceptableLocationAccuracy]) {
#if LOCO_LOG
    NSLog(@" No location acquired or location is not accurate");
#endif
    
    // The location we acquired is not accurate enough, so discard it.
    [acquiringLocation release];
    acquiringLocation = nil;
    
    for (NSObject<LocationManagerListener> *listener in listeners) {
      if ([listener respondsToSelector:@selector(acquiringLocationFailed)]) {
        [listener acquiringLocationFailed];
      }
    }
  } else  {
#if LOCO_LOG
    NSLog(@" Acquired location is accurate");
#endif
    [self finishAcquiringLocation];
  }

  // Switch back to monitoring significant location changes.
  [self stopAcquiringLocation];
  [self startMonitoringSignificantChanges];
}

- (void) cancelAcquiringLocationTimer {
  [NSObject
   cancelPreviousPerformRequestsWithTarget:self
   selector:@selector(acquiringLocationTimerExpired)
   object:nil];
}

- (void) startMonitoringSignificantChanges {
  locationState = LocationStateWaitingSignificantChange;
  [manager startMonitoringSignificantLocationChanges];  
}

- (void) startAcquiringLocationTimer {
  [self performSelector:@selector(acquiringLocationTimerExpired)
             withObject:nil
             afterDelay:kMaxGpsOnTime];
}

- (void) stopMonitoringSignificantChanges {
  [manager stopUpdatingLocation];
}

- (void) stopAcquiringLocation {
  [self cancelAcquiringLocationTimer];
  [manager stopUpdatingLocation];
  
  // The timestamp will be set after detecting a significant change in location.
  [significantChangeTimestamp release];
  significantChangeTimestamp = nil;
}

- (void) startAcquiringLocation {
  locationState = LocationStateAcquiring;
  failedUpdateAttempts = 0;
  
  manager.desiredAccuracy = kCLLocationAccuracyBest;
  manager.distanceFilter = kCLDistanceFilterNone;
  [manager startUpdatingLocation];
  
  // Do not use GPS forever.
  [self startAcquiringLocationTimer];
}

- (void) promptEnableLocationAccess {
  // Simply starting the location manager will prompt again.
  [manager startUpdatingLocation];
  
  locationState = LocationStatePrompted;
  for (NSObject<LocationManagerListener> *listener in listeners) {
    if ([listener respondsToSelector:@selector(accessPrompted)]) {
      [listener accessPrompted];
    }
  }
}

- (void) tryPromptAuthorization {
  if (locationState == LocationStateInit) {
    [self promptEnableLocationAccess];
  }
}

- (void) forcePromptAuthorization {
  if ((locationState == LocationStateInit) ||
      (locationState == LocationStateDenied)) {
    [self promptEnableLocationAccess];
  }
}

#pragma mark CLLocationManagerDelegate methods.

- (void) locationManager:(CLLocationManager *)managerParam
     didUpdateToLocation:(CLLocation *)newLocation
            fromLocation:(CLLocation *)oldLocation {
  if ((locationState == LocationStateInit) ||
      (locationState == LocationStateDenied) ||
      (locationState == LocationStatePaused)) {
#if LOCO_LOG
    NSLog(@"Updated location when locationState=%d", locationState);
#endif
    return;
  }
  
  failedUpdateAttempts = 0;
  if (locationState == LocationStatePrompted) {
#if LOCO_LOG
    NSLog(@"Updated location when locationState=Prompted");
#endif
    
    // If got an update, then location access was granted.
    [self startAcquiringLocation];
    
    for (NSObject<LocationManagerListener> *listener in listeners) {
      if ([listener respondsToSelector:@selector(accessGranted)]) {
        [listener accessGranted];
      }
    }
    return;
  }

  if (locationState == LocationStateWaitingSignificantChange) {
#if LOCO_LOG
    NSLog(@"Updated location when locationState=WaitingSignificantChange");
#endif
    
    if (location != nil) {
      // Ignore change if acquired location using GPS recently.
      NSTimeInterval secondsSinceExactLocation = [newLocation.timestamp
                                                  timeIntervalSinceDate:location.timestamp];
      if (secondsSinceExactLocation < kMinSecondsSignificantChange) {
#if LOCO_LOG
        NSLog(@" Significant change timestamp is too recent, discarding update");
#endif
        return;
      }
    }
    
    // Exact location is found comparing to current significant change timestamp.
    NSAssert(significantChangeTimestamp == nil, @"Timestamp already assigned");
    significantChangeTimestamp = [newLocation.timestamp retain];
    // Get a more accurate location.
    [self stopMonitoringSignificantChanges];
    [self startAcquiringLocation];

    for (NSObject<LocationManagerListener> *listener in listeners) {
      if ([listener respondsToSelector:@selector(significantChangeDetected:)]) {
        [listener significantChangeDetected:newLocation];
      }
    }
    return;
  }
  
  if (locationState == LocationStateAcquiring) {
#if LOCO_LOG
    NSLog(@"Updated location when locationState=Acquiring");
#endif
    
    if (significantChangeTimestamp == nil) {
      // If acquiring the first location, it must be recent.
      NSTimeInterval locationAgeInSeconds = [[NSDate date]
                                             timeIntervalSinceDate:newLocation.timestamp];
      if (locationAgeInSeconds >= kMaxSecondsRecentUpdate) {
#if LOCO_LOG
        NSLog(@" First acquired location timestamp is stale, discarding update");
#endif
        return;
      }
    } else {
      // If not the first location, it must follow the significant location change.
      if ([newLocation.timestamp
           compare:significantChangeTimestamp] != NSOrderedDescending) {
#if LOCO_LOG
        NSLog(@" Next acquired location timestamp is stale, discarding update");
#endif
        return;
      }
    }

    // The horizontalAccuracy does not use the CLLocationAccuracy constants. If
    // negative, it is invalid, and not kCLLocationAccuracyBest.
    if (newLocation.horizontalAccuracy < 0) {
#if LOCO_LOG
      NSLog(@" Accuracy is too low, discarding update");
#endif
      return;
    }
    
    if ((acquiringLocation == nil) ||
        (newLocation.horizontalAccuracy <= acquiringLocation.horizontalAccuracy)) {
#if LOCO_LOG
      NSLog(@" Updated location has better accuracy, replacing acquired location");
#endif
      
      [acquiringLocation release];
      acquiringLocation = [newLocation retain];
      
      if ([self locationHasMinimumAccuracy:kDesiredLocationAccuracy]) {
#if LOCO_LOG
        NSLog(@" Acquired location is accurate, monitoring significant location changes again");
#endif
        
        // Switch back to monitoring significant location changes.
        [self stopAcquiringLocation];
        [self startMonitoringSignificantChanges];

        [self finishAcquiringLocation];
      }
    }
    return;
  }
}

- (void) locationManager:(CLLocationManager *)managerParam
        didFailWithError:(NSError *)error {
  if ((locationState == LocationStateInit) ||
      (locationState == LocationStateDenied) ||
      (locationState == LocationStateWaitingSignificantChange) ||
      (locationState == LocationStatePaused)) {
    NSLog(@"Failed to update location when locationState=%d", locationState);
  }
  
  if (locationState == LocationStatePrompted) {
#if LOCO_LOG
    NSLog(@"Failed to update location when locationState=Prompted");
#endif
    
    if (error.code == kCLErrorDenied) {
#if LOCO_LOG
      NSLog(@" User denied application authorization to location services");
#endif
      
      // The user denied the application authorization to use location services.
      [self stopAcquiringLocation];

      locationState = LocationStateDenied;
      for (NSObject<LocationManagerListener> *listener in listeners) {
        if ([listener respondsToSelector:@selector(accessDenied)]) {
          [listener accessDenied];
        }
      }
    } else {
      // Location access was granted, but acquisition failed.
      [self startAcquiringLocation];
      
      for (NSObject<LocationManagerListener> *listener in listeners) {
        if ([listener respondsToSelector:@selector(accessGranted)]) {
          [listener accessGranted];
        }
      }
    }
    return;
  }

  if (locationState == LocationStateAcquiring) {
#if LOCO_LOG
    NSLog(@"Failed to update location when locationState=Acquiring");
#endif
    
    ++failedUpdateAttempts;

    if (failedUpdateAttempts >= kMaxFailedUpdateAttempts) {
#if LOCO_LOG
      NSLog(@" Too many failures, monitoring significant location changes again");
#endif
      
      // Failed too many times to acquire the location again, so stop for now.
      [self stopAcquiringLocation];
      [self startMonitoringSignificantChanges];

      for (NSObject<LocationManagerListener> *listener in listeners) {
        if ([listener respondsToSelector:@selector(acquiringLocationFailed)]) {
          [listener acquiringLocationFailed];
        }
      }
    }
  }
}

- (void) pause {
  if ((locationState == LocationStateInit) || 
      (locationState == LocationStatePrompted) ||
      (locationState == LocationStateDenied) ||
      (locationState == LocationStatePaused)) {
    return;
  }
  
  if (locationState == LocationStateWaitingSignificantChange) {
    [self stopMonitoringSignificantChanges];
  } else if (locationState == LocationStateAcquiring) {
    [self stopAcquiringLocation];
  }

  locationState = LocationStatePaused;
  for (NSObject<LocationManagerListener> *listener in listeners) {
    if ([listener respondsToSelector:@selector(acquiringLocationPaused)]) {
      [listener acquiringLocationPaused];
    }
  }
}

- (void) resume {
  if (locationState == LocationStatePaused) {
    [self startAcquiringLocation];

    for (NSObject<LocationManagerListener> *listener in listeners) {
      if ([listener respondsToSelector:@selector(acquiringLocationResumed)]) {
        [listener acquiringLocationResumed];
      }
    }
  }
}

- (void) forceAcquireLocation {
  if (locationState == LocationStateWaitingSignificantChange) {
    [self stopMonitoringSignificantChanges];
    [self startAcquiringLocation];
    
    for (NSObject<LocationManagerListener> *listener in listeners) {
      if ([listener respondsToSelector:@selector(forceAcquireLocation)]) {
        [listener forceAcquireLocation];
      }
    }
  }
}

@end
