//
//  Demangle.swift
//  SwiftLightweightResolver
//
//  Created by Igor Belov on 23.03.2025.
//

import Foundation

@_silgen_name("swift_demangle")
func swift_demangle(
    _ mangledName: UnsafePointer<CChar>,
    _ mangledNameLength: UInt,
    _ outputBuffer: UnsafeMutablePointer<CChar>?,
    _ outputBufferSize: UnsafeMutablePointer<UInt>?,
    _ flags: UInt32
) -> UnsafeMutablePointer<CChar>?

func demangleSwiftSymbol(_ symbol: String) -> String {
    symbol.withCString { cStr in
        let length = UInt(strlen(cStr))
        if let demangledPtr = swift_demangle(cStr, length, nil, nil, 0) {
            defer { free(demangledPtr) }
            return String(cString: demangledPtr)
        } else {
            return symbol
        }
    }
}
