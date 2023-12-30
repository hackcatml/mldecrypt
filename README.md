# mldecrypt
iOS binary memory dump & backup ipa tool based on  [dump-ios](https://codeshare.frida.re/@lichao890427/dump-ios/)

# Usage
## App
![2023-12-30 10 46 36 AM](https://github.com/hackcatml/mldecrypt/assets/75507443/77dbc58e-a7f6-4282-8a9c-df18119b8053)

## Command
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

Dump or Dump & backup during runtime thanks to [opainject](https://github.com/opa334/opainject)
```
mldecrypt -r <bundleId>
mldecrypt -r -b <bundleId>
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
- [ZIPFoundation](https://github.com/weichsel/ZIPFoundation)
- [swift-progress-bar](https://github.com/nsscreencast/469-swift-command-line-progress-bar)
- [cda](https://github.com/ay-kay/cda)
- [opainject](https://github.com/opa334/opainject)
- [ProgressHUD](https://github.com/relatedcode/ProgressHUD)
