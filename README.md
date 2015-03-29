# KZMachO
Some files for hacking mach binaries in memory.  This has not been thorougly tested.  Use at your own risk.

A blog post explaining more in-depth might happen later.

What appears to work:
* Monkey-patching classes and string symbols into iOS 7 on the simulator
* Swizzling class references on an iOS 8 device

What doesn't appear to work:
* Swizzling string symbols (you can only add them)


# Example 1: Adding classes
```
KZMachOSymbolTable *symtab = [KZMachOSymbolTable new];

if([UIDevice currentDevice].systemVersion.intValue == 7) {
    // this not only fixes soft references to the class, but hard references
    [symtab addClass:[KZUIAlertController class] forName:@"UIAlertController"];
    [symtab addClass:[KZUIAlertAction class] forName:@"UIAlertAction"];

    // under iOS 7, even if we called objc_allocateClassPair, alertControllerClass would be nil
    Class alertControllerClass = [UIAlertController class];
    // it's not nil and neither is NSClassFromString("UIAlertController")

    // under iOS 7, this controller would normally be nil.  it is not.
    UIAlertController *controller = [UIAlertController new];

}
```

#Example 2: Adding string symbols
```
// sometimes string constants are missing - for example, iOS 6 cannot have UIFontTextStyleBody
// the best thing you could do in iOS 6 is swizzle in preferredFontForTextStyle: and #define UIFontTextStyleBody
// until...
[symtab setAddress:&MyUIFontTextStyleBody forSymbol:@"_UIFontTextStyleBody"];
UIFont *bodyFont = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
```
