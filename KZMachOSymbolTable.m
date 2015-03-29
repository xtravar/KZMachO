//
//  KZMachOSymbolTable.m
//
//  Created by Mike Kasianowicz on 3/29/15.
//  Copyright (c) 2015 Mike Kasianowicz. All rights reserved.
//

#import "KZMachOSymbolTable.h"
#import "KZMachOBindEntry.h"
#import "KZMachOSegment.h"

#import <dlfcn.h>
@import ObjectiveC;
@import MachO;

#define DATA_SECT_OBJC_CLASSREFS @"__objc_classrefs"
#define DATA_SECT_LA_SYMBOL_PTR @"__la_symbol_ptr"
#define DATA_SECT_NL_SYMBOL_PTR @"__nl_symbol_ptr"
// I don't actually know what 'got' is, but it seems to crop up sometimes
#define DATA_SECT_GOT @"__got"

// our default lookup
extern int main();

@implementation KZMachOSymbolTable {
    const void *_baseOffset;

    NSDictionary *_symbolsToReferences;
}

//MARK: initializers
-(instancetype)init {
    return [self initWithAddress:main];
}

-(instancetype)initWithAddress:(const void *)address {
    Dl_info dlinfo;
    if (dladdr(address, &dlinfo) == 0 || dlinfo.dli_fbase == NULL) {
        return nil;
    }
    return [self initWithDLInfo:dlinfo];
}

-(instancetype)initWithDLInfo:(Dl_info)dlinfo {
    self = [super init];
    if(self) {
        _baseOffset = dlinfo.dli_fbase;

        if((*((uint32_t*)_baseOffset) != MH_MAGIC)) {
            [self _readImage64];
        } else {
            [self _readImage32];
        }
    }
    return self;
}

//MARK: internal parsing
-(void)_readImage32 {
    struct mach_header * header = (struct mach_header*)_baseOffset;
    NSAssert(header->magic == MH_MAGIC, @"Unexpected magic value");

    [self _processCommands:header->ncmds atOffset:_baseOffset + sizeof(*header)];
}

-(void)_readImage64 {
    struct mach_header_64 * header =  (struct mach_header_64*)_baseOffset;
    NSAssert(header->magic == MH_MAGIC_64, @"Unexpected magic value");

    [self _processCommands:header->ncmds atOffset:_baseOffset + sizeof(*header)];
}


-(void)_processCommands:(uint32_t)numberOfCommands atOffset:(const void*)offset{
    NSMutableArray *segments = [NSMutableArray new];
    // save these for after - need the segments completely loaded
    NSMutableArray *dyldInfos = [NSMutableArray new];

    struct load_command * cmd = (struct load_command *)offset;
    for(int i = 0; i < numberOfCommands; i++) {
        switch(cmd->cmd) {
            case LC_SEGMENT:
                [segments addObject:[KZMachOSegment segmentFromCommand:(void*)cmd
                                                         withBaseAddress:_baseOffset]];
                break;

            case LC_SEGMENT_64:
                [segments addObject:[KZMachOSegment segmentFromCommand64:(void*)cmd
                                                         withBaseAddress:_baseOffset]];
                break;

            case LC_DYLD_INFO:
            case LC_DYLD_INFO_ONLY:
                [dyldInfos addObject:[NSValue valueWithPointer:cmd]];
                break;

            default:
                break;
        }
        cmd = (struct load_command *)((uint8_t *)cmd + cmd->cmdsize);
    }

    for(NSValue *dyldInfo in dyldInfos) {
        [self _processDyldInfoCommand:dyldInfo.pointerValue withSegments:segments];
    }
}

-(void)_processDyldInfoCommand:(struct dyld_info_command*)cmd withSegments:(NSArray*)segments {
    NSMutableDictionary *symbolsToReferences = [NSMutableDictionary new];

    // making this a stream just makes life that much easier
    NSData *data = [NSData dataWithBytesNoCopy:(void*)_baseOffset + cmd->bind_off
                                        length:cmd->bind_size
                                  freeWhenDone:NO];
    NSInputStream *stream = [NSInputStream inputStreamWithData:data];
    [stream open];

    NSArray *array = [KZMachOBindEntry entriesFromStream:stream pointerSize:sizeof(void*)];
    for (KZMachOBindEntry *entry in array) {
        KZMachOSegment *segment = segments[entry.segmentIndex];
        // be VERY selective about what pointers we allow modifying
        if(![segment.name isEqualToString:@(SEG_DATA)]) {
            continue;
        }

        const void *ptr = segment.address + entry.offset;
        KZMachOSection *section = [segment sectionContainingAddress:ptr];
        if([section.name isEqualToString:DATA_SECT_OBJC_CLASSREFS]) {
        } else if([section.name isEqualToString:DATA_SECT_NL_SYMBOL_PTR]) {
        } else if([section.name isEqualToString:DATA_SECT_GOT]) {
        } else {
            NSLog(@"%@ - %@", entry.symbolName, section.name);
            continue;
        }

        symbolsToReferences[entry.symbolName] = [NSValue valueWithPointer:ptr];
    }
    [stream close];

    _symbolsToReferences = [symbolsToReferences copy];
}
//MARK: public API

-(NSArray*)missingSymbols {
    NSMutableArray *retval = [NSMutableArray new];
    for(NSString *name in _symbolsToReferences) {
        void **pPtr = [_symbolsToReferences[name] pointerValue];
        if(*pPtr == NULL) {
            [retval addObject:name];
        }
    }
    return [retval copy];
}

-(BOOL)containsSymbol:(NSString*)name {
    return [self addressForSymbol:name] != NULL;
}

-(const void*)addressForSymbol:(NSString*)name {
    const void **pPtr = [_symbolsToReferences[name] pointerValue];
    return *pPtr;
}

-(void)setAddress:(const void*)address forSymbol:(NSString*)name {
    NSValue *value = _symbolsToReferences[name];
    if(!value) {
        return;
    }
    const void **pPtr = value.pointerValue;
    *pPtr = address;
}
@end

@implementation KZMachOSymbolTable (Objects)
-(id)objectNamed:(NSString *)name {
    name = [@"_" stringByAppendingString:name];
    return (__bridge id)[self addressForSymbol:name];
}

-(void)setObject:(id)object forName:(NSString*)name {
    name = [@"_" stringByAppendingString:name];
    [self setAddress:(__bridge void*)object forSymbol:name];
}

@end

@implementation KZMachOSymbolTable (Classes)
//MARK: public API
-(NSArray*)missingClassNames {
    NSArray *missingSymbols = self.missingSymbols;

    NSMutableArray *classNames = [NSMutableArray new];
    for(NSString *symbol in missingSymbols) {
        if([symbol hasPrefix:@"_OBJC_CLASS_$_"]) {
            [classNames addObject:[symbol substringFromIndex:@"_OBJC_CLASS_$_".length]];
        }
    }
    return [classNames copy];
}

-(BOOL)containsClassNamed:(NSString *)name {
    name = [@"_OBJC_CLASS_$_" stringByAppendingString:name];
    return [self containsSymbol:name];
}

-(Class)classNamed:(NSString *)name {
    name = [@"_OBJC_CLASS_$_" stringByAppendingString:name];
    Class cls = [self addressForSymbol:name];
    return cls;
}

-(void)setClass:(Class)cls forName:(NSString *)name {
    name = [@"_OBJC_CLASS_$_" stringByAppendingString:name];
    [self setAddress:(__bridge void*)cls forSymbol:name];
}
@end

@implementation KZMachOSymbolTable (ObjCRuntime)
-(void)addClass:(Class)baseClass forName:(NSString *)name {
    NSAssert(![self containsClassNamed:name], @"class already exists");
    Class cls = objc_allocateClassPair(baseClass, name.UTF8String, 0);
    [self setClass:cls forName:name];
}
@end
