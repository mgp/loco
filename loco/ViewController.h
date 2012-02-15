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
  
  MKMapView *mapView;
  MKPointAnnotation *deviceLocation;
  MKPinAnnotationView *deviceLocationPin;
}

@end
