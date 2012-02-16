// Demo program. For best results in the iPhone simulator, choose the
// "Freeway Drive" option under "Debug" > "Location" and wait for significant
// changes in location to be found. (This can take up to five or ten minutes,
// unfortunately.)

#import <UIKit/UIKit.h>
#import <MapKit/MapKit.h>

#import "LocationManager.h"
#import "LocationManagerListener.h"

@class LocationManager;
@class MKMapView;

@interface ViewController : UITableViewController<LocationManagerListener, MKMapViewDelegate> {
  LocationManager *locationManager;
  LocationState lastState;
  NSMutableArray *events;
  NSDateFormatter *dateFormatter;
  
  MKMapView *mapView;
  MKPointAnnotation *deviceLocation;
  MKPinAnnotationView *deviceLocationPin;
}

@end
