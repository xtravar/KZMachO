//
//  KZMachOBindEntry.m
//
//  Created by Mike Kasianowicz on 3/29/15.
//  Copyright (c) 2015 Mike Kasianowicz. All rights reserved.
//

#import "KZMachOBindEntry.h"
@import MachO;

@interface NSInputStream (LEB128)
-(uint64_t)kz_readULEB128;
-(NSString*)kz_readCString;
@end


@implementation KZMachOBindEntry
-(BOOL)isWeakImport {
    return (_flags & BIND_SYMBOL_FLAGS_WEAK_IMPORT) != 0;
}

-(BOOL)isNonWeakDefinition {
    return (_flags & BIND_SYMBOL_FLAGS_NON_WEAK_DEFINITION) != 0;
}

-(instancetype)copy {
    KZMachOBindEntry *retval = [KZMachOBindEntry new];
    retval.segmentIndex = self.segmentIndex;
    retval.offset = self.offset;
    retval.type = self.type;
    retval.libraryOrdinal = self.libraryOrdinal;
    retval.symbolName = self.symbolName;
    retval.addend = self.addend;
    return retval;
}

+(NSArray*)entriesFromStream:(NSInputStream *)stream pointerSize:(NSInteger)pointerSize {
    // <seg-index, seg-offset, type, symbol-library-ordinal, symbol-name, addend>
    NSMutableArray *retval = [NSMutableArray new];
    KZMachOBindEntry *entry = [KZMachOBindEntry new];
    for(;;) {
        uint8_t byte;
        NSInteger readLength = [stream read:&byte maxLength:1];
        // depending, I presume, on alignment, you can get a DONE or EOF
        if(readLength != 1) {
            return [retval copy];
        }

        uint8_t opcode = byte & BIND_OPCODE_MASK;
        uint8_t imm = byte & BIND_IMMEDIATE_MASK;

        // sNSLog(@"opcode %x", (int)opcode);
        switch(opcode) {
            case BIND_OPCODE_SET_DYLIB_ORDINAL_IMM:
                entry.libraryOrdinal = imm;
                break;

            case BIND_OPCODE_SET_DYLIB_ORDINAL_ULEB:
                entry.libraryOrdinal = (NSInteger)[stream kz_readULEB128];
                break;

            case BIND_OPCODE_SET_DYLIB_SPECIAL_IMM:
                if(imm != 0) {
                    imm = imm | BIND_OPCODE_MASK;
                }
                entry.libraryOrdinal = imm;
                break;

            case BIND_OPCODE_SET_SYMBOL_TRAILING_FLAGS_IMM:
                entry.flags = imm;
                entry.symbolName = [stream kz_readCString];
                break;

            case BIND_OPCODE_SET_TYPE_IMM:
                NSAssert(imm == BIND_TYPE_POINTER, @"non-pointer binding not supported");
                entry.type = imm;
                break;

            case BIND_OPCODE_SET_ADDEND_SLEB:
                [NSException raise:@"KZMachOBindEntry" format:@"Unsupported"];
                break;

            case BIND_OPCODE_SET_SEGMENT_AND_OFFSET_ULEB:
                entry.segmentIndex = imm;
                entry.offset = [stream kz_readULEB128];
                break;

            case BIND_OPCODE_ADD_ADDR_ULEB:
                entry.offset += [stream kz_readULEB128];
                break;

            case BIND_OPCODE_DO_BIND:
                [retval addObject:entry];
                entry = [entry copy];
                entry.offset += pointerSize;
                break;

            case BIND_OPCODE_DO_BIND_ADD_ADDR_ULEB:
                [retval addObject:entry];
                entry = [entry copy];
                entry.offset += [stream kz_readULEB128] + pointerSize;
                break;

            case BIND_OPCODE_DO_BIND_ADD_ADDR_IMM_SCALED:

                [retval addObject:entry];
                entry = [entry copy];
                entry.offset += imm * pointerSize + pointerSize;
                break;

            case BIND_OPCODE_DO_BIND_ULEB_TIMES_SKIPPING_ULEB: {
                uint64_t count = [stream kz_readULEB128];
                uint64_t skip = [stream kz_readULEB128];
                for(uint64_t i = 0; i < count; i++) {
                    [retval addObject:entry];
                    entry = [entry copy];
                    entry.offset += pointerSize;
                    entry.offset += skip;
                }
                break;
            }
                
            case BIND_OPCODE_DONE:
                return [retval copy];
        }
    }
}
@end


@implementation NSInputStream (LEB128)
-(uint64_t)kz_readULEB128 {
    uint64_t retval = 0;
    int bits = 0;

    uint8_t byte;
    for(;;) {
        NSInteger readValue = [self read:&byte maxLength:sizeof(byte)];
        NSAssert(readValue == 1, @"unexpected end of stream");

        retval = retval | ((uint64_t)(byte & 0x7F) << (uint64_t)bits);

        if(!(byte & 0x80)) {
            break;
        }

        bits += 7;
        NSAssert(bits < 64, @"encoded int too long");
    }

    return retval;
}

-(NSString*)kz_readCString {
    NSMutableString *retval = [NSMutableString new];

    for(;;) {
        uint8_t ch;
        NSInteger readValue = [self read:&ch maxLength:sizeof(ch)];
        NSAssert(readValue == 1, @"unexpected end of stream");

        if(ch == 0) {
            break;
        }
        unichar wch = ch;

        [retval appendString:[NSString stringWithCharacters:&wch length:1]];
    }
    return [retval copy];
}
@end

