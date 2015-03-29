//
//  KZMachOSymbolTable.h
//
//  Created by Mike Kasianowicz on 3/29/15.
//  Copyright (c) 2015 Mike Kasianowicz. All rights reserved.
//

@import Foundation;

@interface KZMachOSymbolTable : NSObject
// initializes with 'main' address, loading whatever binary 'main' is in
-(instancetype)init;

// initialize with an address that exists of the binary to analyze (pass in function, variable, etc)
-(instancetype)initWithAddress:(const void*)address;


#ifdef _DLFCN_H_
// if we've imported dlfcn.h, expose this method
// otherwise, nobody needs it
-(instancetype)initWithDLInfo:(Dl_info)dlinfo;
#endif

// an array of symbols whose indirect pointer is nil
@property (nonatomic, readonly) NSArray *missingSymbols;
-(BOOL)containsSymbol:(NSString*)name;

-(const void*)addressForSymbol:(NSString*)name;
-(void)setAddress:(const void*)address forSymbol:(NSString*)name;
@end

@interface KZMachOSymbolTable (Classes)
// returns an array of class names that have no associated Class
@property (nonatomic, readonly) NSArray *missingClassNames;

// returns whether the reference pointer to this class is blank
-(BOOL)containsClassNamed:(NSString*)name;

-(Class)classNamed:(NSString*)name;

// will look up the class symbol and set it in the table
-(void)setClass:(Class)cls forName:(NSString *)name;
@end

// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
// !!!! only use this if you don't know what you're doing
// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
@interface KZMachOSymbolTable (ObjCRuntime)
// this will not only replace hard references but also runtime references
-(void)addClass:(Class)cls forName:(NSString*)name;
@end
