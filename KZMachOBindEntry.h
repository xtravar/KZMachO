//
//  KZMachOBindEntry.h
//
//  Created by Mike Kasianowicz on 3/29/15.
//  Copyright (c) 2015 Mike Kasianowicz. All rights reserved.
//

@import Foundation;

// this is a mostly-internal class that parses the Mach-O binding table
@interface KZMachOBindEntry : NSObject
@property (nonatomic) NSInteger segmentIndex;

@property (nonatomic) NSInteger flags;

@property (nonatomic) UInt64 offset;

@property (nonatomic) NSInteger type;

@property (nonatomic) NSInteger libraryOrdinal;

@property (nonatomic) NSString *symbolName;

@property (nonatomic) SInt64 addend;

@property (nonatomic, readonly, getter=isWeakImport) BOOL weakImport;
@property (nonatomic, readonly, getter=isNonWeakDefinition) BOOL nonWeakDefinition;

+(NSArray*)entriesFromStream:(NSInputStream*)stream pointerSize:(NSInteger)pointerSize;
@end

