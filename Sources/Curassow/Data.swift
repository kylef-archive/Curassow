#if os(Linux)
import Glibc
#else
import Darwin.C
#endif

class Data {
  let bytes: UnsafeMutableRawPointer
  let capacity: Int

  init(capacity: Int) {
    self.bytes = UnsafeMutableRawPointer(malloc(capacity + 1))
//    bytes = UnsafeMutablePointer<Int8>(malloc(capacity + 1))
    self.capacity = capacity
  }

  deinit {
    free(bytes)
  }

  var characters: [CChar] {
    var data = [CChar](repeating: 0, count: capacity)
    memcpy(&data, bytes, data.count)
    return data
  }

  var string: String? {
    let pointer = bytes.bindMemory(to: CChar.self, capacity: capacity)
    return String(cString: pointer)
  }
}
