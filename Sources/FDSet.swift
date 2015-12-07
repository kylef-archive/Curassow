#if os(Linux)
import Glibc
#else
import Darwin.C
#endif


func fdZero(inout set: fd_set) {
  set.fds_bits = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
}


func fdSet(descriptor: Int32, inout _ set: fd_set) {
  let intOffset = Int32(descriptor / 16)
  let bitOffset = Int32(descriptor % 16)
  let mask: Int32 = 1 << bitOffset

  switch intOffset {
    case 0: set.fds_bits.0 = set.fds_bits.0 | mask
    case 1: set.fds_bits.1 = set.fds_bits.1 | mask
    case 2: set.fds_bits.2 = set.fds_bits.2 | mask
    case 3: set.fds_bits.3 = set.fds_bits.3 | mask
    case 4: set.fds_bits.4 = set.fds_bits.4 | mask
    case 5: set.fds_bits.5 = set.fds_bits.5 | mask
    case 6: set.fds_bits.6 = set.fds_bits.6 | mask
    case 7: set.fds_bits.7 = set.fds_bits.7 | mask
    case 8: set.fds_bits.8 = set.fds_bits.8 | mask
    case 9: set.fds_bits.9 = set.fds_bits.9 | mask
    case 10: set.fds_bits.10 = set.fds_bits.10 | mask
    case 11: set.fds_bits.11 = set.fds_bits.11 | mask
    case 12: set.fds_bits.12 = set.fds_bits.12 | mask
    case 13: set.fds_bits.13 = set.fds_bits.13 | mask
    case 14: set.fds_bits.14 = set.fds_bits.14 | mask
    case 15: set.fds_bits.15 = set.fds_bits.15 | mask
    default: break
  }
}

func fdIsSet(descriptor: Int32, inout _ set: fd_set) -> Bool {
  let intOffset = Int32(descriptor / 32)
  let bitOffset = Int32(descriptor % 32)
  let mask = Int32(1 << bitOffset)

  switch intOffset {
    case 0: return set.fds_bits.0 & mask != 0
    case 1: return set.fds_bits.1 & mask != 0
    case 2: return set.fds_bits.2 & mask != 0
    case 3: return set.fds_bits.3 & mask != 0
    case 4: return set.fds_bits.4 & mask != 0
    case 5: return set.fds_bits.5 & mask != 0
    case 6: return set.fds_bits.6 & mask != 0
    case 7: return set.fds_bits.7 & mask != 0
    case 8: return set.fds_bits.8 & mask != 0
    case 9: return set.fds_bits.9 & mask != 0
    case 10: return set.fds_bits.10 & mask != 0
    case 11: return set.fds_bits.11 & mask != 0
    case 12: return set.fds_bits.12 & mask != 0
    case 13: return set.fds_bits.13 & mask != 0
    case 14: return set.fds_bits.14 & mask != 0
    case 15: return set.fds_bits.15 & mask != 0
    case 16: return set.fds_bits.16 & mask != 0
    case 17: return set.fds_bits.17 & mask != 0
    case 18: return set.fds_bits.18 & mask != 0
    case 19: return set.fds_bits.19 & mask != 0
    case 20: return set.fds_bits.20 & mask != 0
    case 21: return set.fds_bits.21 & mask != 0
    case 22: return set.fds_bits.22 & mask != 0
    case 23: return set.fds_bits.23 & mask != 0
    case 24: return set.fds_bits.24 & mask != 0
    case 25: return set.fds_bits.25 & mask != 0
    case 26: return set.fds_bits.26 & mask != 0
    case 27: return set.fds_bits.27 & mask != 0
    case 28: return set.fds_bits.28 & mask != 0
    case 29: return set.fds_bits.29 & mask != 0
    case 30: return set.fds_bits.30 & mask != 0
    case 31: return set.fds_bits.31 & mask != 0
    default: return false
  }
}
