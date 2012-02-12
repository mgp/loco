# Loco

Loco is an iOS library that attempts to acquire the device location using GPS whenever a significant location change, or change in cellular towers, is detected. By doing so it strikes a balance between accurately finding your **lo**cation and **co**nserving the battery of your device. Other features include allowing the application to force attempting to acquire the location using GPS at any time, a listener interface for easy notification of changes in location and other events, and pausing and resuming location of monitoring.

## API

### LocationManager

The `LocationManager` is responsible for monitoring changes in cellular towers and acquiring the location using GPS in response. It also handles prompting the user to authorize the application use to location services, acquiring the location using GPS anytime the application desires, and notifying registered listeners of changes in location and other events.

* `+ (LocationManager *) sharedInstance`: Returns the `LocationManager` singleton.
* `- (void) tryPromptAuthorization`: If the user has not already declined authorization, prompts the user to authorize the application use of location services.
* `- (void) forcePromptAuthorization`: Regardless of whether the user has already declined authorization, prompts the user to authorize the application use of location services.
* `- (void) pause`: If location access has been enabled, pauses monitoring for any changes in location.
* `- (void) resume`: If location access has been enabled but is paused, resumes monitoring for any changes in location.
* `- (void) forceAcquireLocation`: Attempts to acquire the device location using GPS instead of waiting for a change in cellular towers to trigger acquisition.

Additionally, the `LocationManager` has the following read-only properties:

* `LocationState locationState`: An enumeration defining the state of the `LocationManager`. See the values below.
* `CLLocation *location`: The last location acquired using GPS, or `nil` if no such location has been acquired yet.
* `BOOL isPaused`: Returns whether monitoring for any changes in location has been paused.
* `NSMutableArray *listeners`: The mutable array through which listeners can be registered or unregistered. See the description of the listener protocol below.

### LocationManagerState

The `LocationManagerState` enumeration specifies what the `LocationManager` is currently doing:

* `LocationStateInit`: The application has not prompted the user yet for authorization to use location services.
* `LocationStatePrompted`: The `LocationManager` is prompting the user to authorize the application use of location services.
* `LocationStateDenied`: The `LocationManager` is inactive because the user denied the application authorization to use location services.
* `LocationStateWaitingSignificantChange`: The `LocationManager` is waiting for a change in cellular towers.
* `LocationStateAcquiring`: The `LocationManager` is acquiring the device location using GPS.
* `LocationStatePaused`: Monitoring for any changes in location has been paused.

### LocationManagerListener

A protocol that can be adopted by any class that wants to be notified of changes in location or changes to the state of the `LocationManager`. All methods are marked `optional`. To register or unregister listeners, simply add or remove them from the `listeners` property of the `LocationManager` instance.

* `- (void) setLocation:(CLLocationCoordinate2D)coordinate`: Called whenever the `LocationManager` determines a new location using GPS.
* `- (void) setLocationState:(LocationState)locationState`: Called whenever the state of the `LocationManager` updates.
* `- (void) accessPrompted`: Called whenever the application prompts the user for authorization to use location services.
* `- (void) accessGranted`: Called if the user grants the application authorization to use location services.
* `- (void) accessDenied`: Called if the user denies the application authorization to use location services.
* `- (void) forceAcquireLocation`: Called if the application attempts to acquire the device location using GPS instead of waiting for a change in cellular towers.
* `- (void) significantChangeDetected:(CLLocation *)location`: Called whenever the `LocationManager` detects a change in cellular towers and will attempt to acquire the device location using GPS.
* `- (void) acquiringLocationFailed`: Called whenever the `LocationManager` could not acquire the device location using GPS.
* `- (void) acquiringLocationPaused`: Called whenever the application pauses monitoring for any changes in location.
* `- (void) acquiringLocationResumed`: Called whenever the application resumes monitoring for any changes in location.

## Demo Application

If you are looking to use Loco in your own application, simply copy `LocationManager.h`, `LocationManager.m`, and `LocationManagerListener.h` from the `loco` subdirectory into your project.

The other files in the repository are part of the XCode project `loco.xcodeproj`, which defines a simple application that demonstrates how Loco works. After authorizing the application use of location services, the application allows you to:

  * pause and resume monitoring for changes in cellular towers
  * force acquiring the location using GPS
  * watch your location update on the map
  * inspect which listener methods are called

