//
//  KZMachOSegment.m
//
//  Created by Mike Kasianowicz on 3/29/15.
//  Copyright (c) 2015 Mike Kasianowicz. All rights reserved.
//

#import "KZMachOSegment.h"
@import MachO;

static NSString *safeStr(const char *str, int size);
#define SAFE_STR_FROM_ARRAY(array) safeStr(array, sizeof(array))

@implementation KZMachOSegment
+(instancetype)segmentFromCommand:(struct segment_command*)command withBaseAddress:(const void *)baseAddress {
    KZMachOSegment *retval = [self new];
    retval.address = command->fileoff + baseAddress;
    retval.size = command->filesize;
    retval.name = SAFE_STR_FROM_ARRAY(command->segname);

    NSMutableArray *sections = [NSMutableArray new];
    struct section *csections = (void*)command + sizeof(struct segment_command);
    for(uint32_t i = 0; i < command->nsects; i++) {
        typeof(csections) csection = &csections[i];
        [sections addObject:[KZMachOSection sectionFromStruct:csection withBaseAddress:baseAddress]];
    }
    retval.sections = sections;
    return retval;
}

+(instancetype)segmentFromCommand64:(struct segment_command_64*)command withBaseAddress:(const void *)baseAddress {
    KZMachOSegment *retval = [self new];
    retval.address = command->fileoff + baseAddress;
    retval.size = command->filesize;
    retval.name = SAFE_STR_FROM_ARRAY(command->segname);

    NSMutableArray *sections = [NSMutableArray new];
    struct section_64 *csections = (void*)command + sizeof(struct segment_command_64);
    for(uint32_t i = 0; i < command->nsects; i++) {
        typeof(csections) csection = &csections[i];
        [sections addObject:[KZMachOSection sectionFromStruct64:csection withBaseAddress:baseAddress]];
    }
    retval.sections = sections;
    return retval;
}

-(KZMachOSection*)sectionNamed:(NSString *)name {
    NSUInteger index = [_sections indexOfObjectPassingTest:^BOOL(KZMachOSection *obj, NSUInteger idx, BOOL *stop) {
        return [name isEqualToString:obj.name];
    }];
    return index == NSNotFound ? nil : _sections[index];
}

-(KZMachOSection*)sectionContainingAddress:(const void *)address {
    ptrdiff_t diff = address - _address;
    if(diff < 0 || diff > _size) {
        return nil;
    }

    for(KZMachOSection *section in _sections) {
        if([section containsAddress:address]) {
            return section;
        }
    }
    return nil;
}

-(NSString*)debugDescription {
    return _name;
}
@end

@implementation KZMachOSection
+(instancetype)sectionFromStruct:(struct section*)csection withBaseAddress:(const void*)baseAddress {
    KZMachOSection *retval = [KZMachOSection new];
    retval.name = SAFE_STR_FROM_ARRAY(csection->sectname);
    retval.address = csection->offset + baseAddress;
    retval.size = csection->size;
    return retval;
}

+(instancetype)sectionFromStruct64:(struct section_64*)csection withBaseAddress:(const void*)baseAddress {
    KZMachOSection *retval = [KZMachOSection new];
    retval.name = SAFE_STR_FROM_ARRAY(csection->sectname);
    retval.address = csection->offset + baseAddress;
    retval.size = csection->size;
    return retval;
}

-(BOOL)containsAddress:(const void *)address {
    ptrdiff_t diff = address - _address;
    if(diff >= 0 && diff < _size) {
        return YES;
    }
    return NO;
}

-(NSString*)debugDescription {
    return _name;
}

@end

static NSString *safeStr(const char *str, int size) {
    char safetyFirst[size+1];
    safetyFirst[size] = 0;
    strncpy(safetyFirst, str, size);
    return @(safetyFirst);
}
