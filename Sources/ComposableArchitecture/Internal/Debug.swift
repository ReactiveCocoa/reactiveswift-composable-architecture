import CustomDump
import Foundation

#if os(Linux) || os(Android)
  import let CDispatch.NSEC_PER_USEC
  import let CDispatch.NSEC_PER_SEC
#endif

extension String {
  func indent(by indent: Int) -> String {
    let indentation = String(repeating: " ", count: indent)
    return indentation + self.replacingOccurrences(of: "\n", with: "\n\(indentation)")
  }
}
