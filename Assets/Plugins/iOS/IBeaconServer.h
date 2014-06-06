//
//  IBeaconServer.h
//  ble_plugin
//
//  Created by Michael Hoffstaedter on 10.02.14.
//  Copyright (c) 2014 Michael Hoffstaedter. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import <CoreBluetooth/CoreBluetooth.h>

@interface IBeaconServer : NSObject <CBPeripheralManagerDelegate>
{
    BOOL shouldLog;
}


@property(strong,nonatomic) CLBeaconRegion *beaconRegion;
@property(strong,nonatomic) NSDictionary *beaconPeripheralData;
@property(strong,nonatomic) CBPeripheralManager *peripheralManager;

- (void) InitWithUUIDs:(NSUUID *)uuid andRegionIdentifer:(NSString *)ident andLogging:(bool)log andMajor:(int)major andMinor:(int)minor;
@end
