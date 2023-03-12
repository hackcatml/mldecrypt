import Foundation

// https://gist.github.com/brennanMKE/5aee405d371808bddab33469b4ad1e22
public struct Filesystem {
    private let fm: FileManager

    public static var `default`: Filesystem = {
        Filesystem()
    }()

    public init(fileManager: FileManager = FileManager.default) {
        self.fm = fileManager
    }

    /// Copy a directory recursively from source to destination.
    /// - Parameters:
    ///   - sourcePath: source path
    ///   - destinationPath: destination path
    ///   - followSymlinks: follow symlinks which go outside of the destination's scope
    /// - Throws: fileystem failures
    public func copyDirectory(sourcePath: String, destinationPath: String, followSymlinks: Bool = true) throws {
        try fm.copyItem(atPath: sourcePath, toPath: destinationPath)
        if followSymlinks {
            try replaceSymlinks(at: destinationPath, below: destinationPath)
        }
    }

    // MARK: - Private -
    private func replaceSymlinks(at currentDirectoryPath: String, below rootDirectoryPath: String) throws {
        var isDir: ObjCBool = false
        let exists = fm.fileExists(atPath: currentDirectoryPath, isDirectory: &isDir)
        guard exists && isDir.boolValue else {
            return
        }

        // 1) replace symlinked directory at path
        // 2) replace symlinks files in directory at path
        // 3) recurse into every directory
        let currentDirectoryURL = URL(fileURLWithPath: currentDirectoryPath, isDirectory: true)
        if let destinationURL = resolvedSymlink(at: currentDirectoryURL) {
            if !isPath(destinationURL.path, below: rootDirectoryPath) {
                try replaceSymlink(at: currentDirectoryPath, with: destinationURL.path)
            }
        }

        try fm.contentsOfDirectory(atPath: currentDirectoryPath).forEach { itemName in
            let subpath = resolve(relativePath: itemName, to: currentDirectoryURL)
            let itemURL = URL(fileURLWithPath: subpath)

            if let destinationURL = resolvedSymlink(at: itemURL),
               !isPath(destinationURL.path, below: rootDirectoryPath) {
                try replaceSymlink(at: itemURL.path, with: destinationURL.path)
            }

            if itemURL.hasDirectoryPath {
                try replaceSymlinks(at: itemURL.path, below: rootDirectoryPath)
            }
        }
    }

    private func resolvedSymlink(at itemURL: URL) -> URL? {
        let resolvedURL = itemURL.resolvingSymlinksInPath()
        guard resolvedURL != itemURL else {
            return nil
        }
        return resolvedURL
    }

    private func isPath(_ path: String, below rootDirectoryPath: String) -> Bool {
        let result = path.hasPrefix(rootDirectoryPath)
        return result
    }

    private func resolve(relativePath: String, isDirectory: Bool = true, to directoryURL: URL) -> String {
        let result = URL(fileURLWithPath: relativePath, isDirectory: isDirectory, relativeTo: directoryURL).path
        return result
    }

    private func replaceSymlink(at path: String, with regularFilePath: String) throws {
        try fm.removeItem(atPath: path)
        try fm.copyItem(atPath: regularFilePath, toPath: path)
    }
}
