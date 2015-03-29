//
//  KZMachOSegment.h
//
//  Created by Mike Kasianowicz on 3/29/15.
//  Copyright (c) 2015 Mike Kasianowicz. All rights reserved.
//

@import Foundation;
@import MachO;

@class KZMachOSection;
// mostly internal datastructures
@interface KZMachOSegment : NSObject
@property (nonatomic) NSString *name;
@property (nonatomic) const void *address;
@property (nonatomic) UInt64 size;
@property (nonatomic) NSArray *sections;

-(KZMachOSection*)sectionNamed:(NSString*)name;
-(KZMachOSection*)sectionContainingAddress:(const void*)address;

+(instancetype)segmentFromCommand:(struct segment_command*)command withBaseAddress:(const void*)baseAddress;
+(instancetype)segmentFromCommand64:(struct segment_command_64*)command withBaseAddress:(const void*)baseAddress;

@end

@interface KZMachOSection : NSObject
@property (nonatomic) NSString *name;
@property (nonatomic) const void *address;
@property (nonatomic) UInt64 size;

-(BOOL)containsAddress:(const void*)address;

+(instancetype)sectionFromStruct:(struct section*)csection withBaseAddress:(const void*)baseAddress;
+(instancetype)sectionFromStruct64:(struct section_64*)csection withBaseAddress:(const void*)baseAddress;
@end
