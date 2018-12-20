import Foundation
import VideoToolbox

extension VTCompressionSession {
    func copySupportedPropertyDictionary() -> [AnyHashable: Any] {
        var support: CFDictionary? = nil
        guard VTSessionCopySupportedPropertyDictionary(self, supportedPropertyDictionaryOut: &support) == noErr else {
            return [:]
        }
        guard let result: [AnyHashable: Any] = support as? [AnyHashable: Any] else {
            return [:]
        }
        return result
    }
}
