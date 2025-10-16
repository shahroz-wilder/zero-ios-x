//
// Copyright 2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.
//

import Foundation

class ImageDataCache {
    static let shared = ImageDataCache()
    
    private init() { }
    
    private let queue = DispatchQueue(label: "com.app.imageDataCache", attributes: .concurrent)
    private var imageDataCache: [String: Data] = [:]
    
    func store(_ data: Data, forKey key: String) {
        queue.async(flags: .barrier) { [weak self] in
            self?.imageDataCache[key] = data
        }
    }
    
    func retrieve(forKey key: String) -> Data? {
        var result: Data?
        queue.sync {
            result = imageDataCache[key]
        }
        return result
    }
}
