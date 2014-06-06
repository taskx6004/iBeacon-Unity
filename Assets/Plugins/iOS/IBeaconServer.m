//
//  IBeaconServer.m
//  ble_plugin
//
//  Created by Michael Hoffstaedter on 10.02.14.
//  Copyright (c) 2014 Michael Hoffstaedter. All rights reserved.
//

#import "IBeaconServer.h"

@implementation IBeaconServer

- (void) InitWithUUIDs:(NSUUID *)uuid andRegionIdentifer:(NSString *)ident andLogging:(bool)log andMajor:(int)major andMinor:(int)minor {
    shouldLog = log;
    self.beaconRegion = [[CLBeaconRegion alloc] initWithProximityUUID:uuid major:major minor:minor identifier:ident];
    if (shouldLog) {
        NSLog(@"Initialised IBeaconServer with region %@, uuid %@, major %d and minor %d",ident,uuid,major,minor);
    }
}

- (void) StartTransmit {
    self.beaconPeripheralData = [self.beaconRegion peripheralDataWithMeasuredPower:nil];
    self.peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self queue:nil options:nil];
}

- (void) StopTransmit {
    [self.peripheralManager stopAdvertising];
    NSLog(@"IOS: Stopping advertisement");
}

- (void) peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral {
    if (peripheral.state == CBPeripheralManagerStatePoweredOn) {
        if (shouldLog) {
            NSLog(@"IOS: Starting to advertise");
        }
        [self.peripheralManager startAdvertising:self.beaconPeripheralData];
    } else if (peripheral.state == CBPeripheralManagerStatePoweredOff) {
        if (shouldLog) {
            NSLog(@"IOS: Stopping advertisement");
        }
        [self.peripheralManager stopAdvertising];
    }
}
@end

IBeaconServer *currentServer = nil;

void InitBeaconServer(char * uuid, char * regionIdent, bool shouldLog, int major, int minor) {
    currentServer = [IBeaconServer alloc];
    NSString *nsuuid = [NSString stringWithUTF8String:uuid];
    NSString *ident = [NSString stringWithUTF8String:regionIdent];
    [currentServer InitWithUUIDs:[[NSUUID alloc] initWithUUIDString:nsuuid] andRegionIdentifer:ident andLogging:shouldLog andMajor:major andMinor:minor];
}

void Transmit(bool shouldtransmit) {
    if (shouldtransmit) {
        [currentServer StartTransmit];
    } else {
        [currentServer StopTransmit];
    }
}