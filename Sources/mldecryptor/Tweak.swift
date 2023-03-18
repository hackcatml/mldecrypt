import os
import Foundation
import kittymemswift

let BUFSIZE = 4096
var image_count: UInt32 = 0
var image_index: UInt32 = 0
var target_imgName: UnsafeMutablePointer<Int8>?

// https://github.com/lich4/personal_script/blob/master/Frida_script/ios_dump.js
func dumpstart(_ targetImgName: UnsafeMutablePointer<Int8>?) {
    os_log("[hackcatml] binary dump started")
    
    let dumpPath = "/var/mobile/Documents/" + URL(fileURLWithPath: Bundle.main.executablePath ?? "").lastPathComponent + ".decrypted"
    if FileManager.default.fileExists(atPath: dumpPath) {
        unlink(dumpPath)
    }
    
    let header: UnsafePointer<mach_header_64>  = _dyld_get_image_header(image_index).withMemoryRebound(to: mach_header_64.self, capacity: 1, { $0 })
    var imageHeaderPtr = UnsafeMutableRawPointer(mutating: header).advanced(by: MemoryLayout<mach_header_64>.stride)
    var command = imageHeaderPtr.assumingMemoryBound(to: load_command.self)
    var off = UInt32(MemoryLayout<mach_header_64>.stride)
    var offset_cryptoff: UInt32 = 0
    var offset_cryptsize: UInt32 = 0
    var offset_cryptid: UInt32 = 0
    var crypt_off: UInt32 = 0
    var crypt_size: UInt32 = 0

    let fd_dest = open(dumpPath, O_CREAT | O_RDWR, 0o644)
    guard fd_dest != -1 else {
        os_log("[hackcatml] cannot open %{public}s", dumpPath)
        return
    }
    defer { close(fd_dest) }
    
    if let targetImgName = targetImgName {
        let fd_src = open(targetImgName, O_RDONLY, 0)
        guard fd_src != -1 else {
            os_log("[hackcatml] cannot open %{public}s", String(cString: targetImgName))
            return
        }
        defer { close(fd_src) }
        
        var buf = [UInt8](repeating: 0, count: BUFSIZE)
        while read(fd_src, &buf, BUFSIZE) > 0 {
            write(fd_dest, &buf, BUFSIZE)
        }

        for _ in 0..<header.pointee.ncmds {
            if command.pointee.cmd == LC_ENCRYPTION_INFO_64 {
                offset_cryptoff = off + 0x8
                offset_cryptsize = off + 0xc
                offset_cryptid = off + 0x10
                crypt_off = KittyMemory.readU32(UnsafeMutableRawPointer(bitPattern: UInt(bitPattern: header) + UInt(offset_cryptoff)))
                crypt_size = KittyMemory.readU32(UnsafeMutableRawPointer(bitPattern: UInt(bitPattern: header) + UInt(offset_cryptsize)))
            }
            off += command.pointee.cmdsize
            imageHeaderPtr += Int(command.pointee.cmdsize)
            command = imageHeaderPtr.assumingMemoryBound(to: load_command.self)
        }
        
        var buff = [UInt8](repeating: 0, count: 4)
        // Don't have to nullify offset_cryptoff, offset_cryptsize
//        lseek(fd_dest, off_t(offset_cryptoff), SEEK_SET)
//        write(fd_dest, &buff, 4)
//
//        lseek(fd_dest, off_t(offset_cryptsize), SEEK_SET)
//        write(fd_dest, &buff, 4)
        
        lseek(fd_dest, off_t(offset_cryptid), SEEK_SET)
        write(fd_dest, &buff, 4)

        lseek(fd_dest, off_t(crypt_off), SEEK_SET)
        write(fd_dest, UnsafeMutableRawPointer(bitPattern:UInt(bitPattern: header) + UInt(crypt_off)), Int(crypt_size))

        os_log("[hackcatml] binary dump done at %{public}s", dumpPath)
    }
}

func imageObserver(_ mh: UnsafePointer<mach_header>?, _ vmaddr_slide: Int) -> Void {
    struct S {
        static var imageObserverImage_counter: UInt32 = 0
    }
    let image_name: UnsafeMutablePointer<Int8>? = UnsafeMutablePointer<Int8>(mutating: _dyld_get_image_name(S.imageObserverImage_counter))
    guard image_name != nil else {
        S.imageObserverImage_counter += 1
        return
    }
    S.imageObserverImage_counter += 1

    if String(cString: image_name!) == Bundle.main.executablePath! {
        image_index = S.imageObserverImage_counter - 1
        target_imgName = image_name
    }
    // Delay the dump, in order to wait for the image to be fully loaded into memory
    if(S.imageObserverImage_counter == image_count){
        dumpstart(target_imgName);
        sleep(3);
    }
    return
}

struct Tweak {
    static func ctor() {
        // Code goes here
        image_count = _dyld_image_count()
        _dyld_register_func_for_add_image(imageObserver)
    }
}

@_cdecl("jinx_entry")
func jinx_entry() {
    Tweak.ctor()
}
