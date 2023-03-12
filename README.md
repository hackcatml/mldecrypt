# mldecrypt
iOS binary memory dump & backup ipa tool based on  [dump-ios](https://codeshare.frida.re/@lichao890427/dump-ios/)

# Usage
Show installed applications:
```
mldecrypt list
```

Only dump binary:
```
mldecrypt <bundleId>
```

Dump binary & backup ipa:
```
mldecrypt -b <bundleId>
```

# Build
1. Need to install [Jinx framework](https://github.com/Paisseon/Jinx)<br>
2. Copy all the modules from the `module` directory to the `theos include` directory
```
cp -R module/* ~/theos/include/
```
3. make
```
make clean && make package
```

# Credits
- [dump-ios](https://codeshare.frida.re/@lichao890427/dump-ios/)
- [Jinx](https://github.com/Paisseon/Jinx)
- [KittyMemory](https://github.com/MJx0/KittyMemory)
- [Zip](https://github.com/marmelroy/Zip.git)
- [swift-progress-bar](https://github.com/nsscreencast/469-swift-command-line-progress-bar)
- [cda](https://github.com/ay-kay/cda)
