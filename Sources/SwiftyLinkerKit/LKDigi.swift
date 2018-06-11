//
//  LKDigi.swift
//  SwiftyLinkerKit
//
//  Created by Helge Hess on 08.06.18.
//

import Foundation
import SwiftyTM1637

/**
 * The 7-segment LK-Digi display. Driven by the TM1637 chipset.
 *
 * Detailed information can be found over here:
 *
 *   http://www.linkerkit.de/index.php?title=LK-Digi
 *
 * Example:
 *
 *     let shield  = LKRBShield.default
 *     let display = LKDigi()
 *
 *     display.show("SWIFT")
 *     sleep(2)
 *
 *     display.show(1337)
 *     sleep(2)
 *
 *     display.showTime()
 *     sleep(2)
 *
 *     for i in (0...10).reversed {
 *         display.show(i)
 *         sleep(1)
 *     }
 *
 */
open class LKDigi : LKAccessoryBase {
  
  public typealias Brightness = SwiftyTM1637.TM1637.Brightness
  
  public enum Alignment {
    case left, center, right
  }
  
  public struct Segments4 {
    
    public static let segmentCount = 4
    
    var s1 : SevenSegment?
    var s2 : SevenSegment?
    var s3 : SevenSegment?
    var s4 : SevenSegment?
    
    public init(s1 : SevenSegment? = nil, s2 : SevenSegment? = nil,
                s3 : SevenSegment? = nil, s4 : SevenSegment? = nil)
    {
      self.s1 = s1
      self.s2 = s2
      self.s3 = s3
      self.s4 = s4
    }
    public init<T1, T2, T3, T4>(s1: T1?, s2: T2?, s3: T3?, s4: T4?)
            where T1: SevenSegmentRepresentable,
                  T2: SevenSegmentRepresentable,
                  T3: SevenSegmentRepresentable,
                  T4: SevenSegmentRepresentable
    {
      self.s1 = s1?.sevenSegmentValue
      self.s2 = s2?.sevenSegmentValue
      self.s3 = s3?.sevenSegmentValue
      self.s4 = s4?.sevenSegmentValue
    }
  }
  
  public let segmentCount = Segments4.segmentCount
  
  var display     : SwiftyTM1637.TM1637?
  var _brightness : Brightness?
  var _segments   = Segments4()
  
  /// Show a number, examples:
  ///
  ///     show(1337)
  ///     show(0x1337, radix: 16, align: .center)
  ///
  open func show(_ value: Int, radix: Int = 10, align: Alignment = .right) {
    show(String(value, radix: radix), align: align)
  }
  
  /// Show the time contained in the date segments.
  /// Even seconds trigger a dot.
  open func showTime(_ date: Foundation.DateComponents) {
    let hour   = date.hour   ?? 0
    let minute = date.minute ?? 0
    let second = date.second ?? 0
    
    let segment2 = SevenSegment(digit: hour % 10, dot: second % 2 != 0)
    show(s1: hour / 10, s2: segment2, s3: minute / 10, s4: minute % 10)
  }
  
  /// Show the time represented by the date.
  /// Even seconds trigger a dot.
  open func showTime(_ date: Foundation.Date = Foundation.Date(),
                     calendar cal: Calendar = Calendar.current)
  {
    return showTime(cal.dateComponents([.hour, .minute, .second], from: date))
  }
  
  open func turnOff() {
    let off = SevenSegment.off
    show(s1: off, s2: off, s3: off, s4: off)
  }

  /// Show the (representable) values of a collection (e.g the characters of a
  /// String). Example:
  ///
  ///     digi.show("42", align: .center)
  ///
  open func show<T: Collection>(_ s: T, align: Alignment = .left)
              where T.Element : SevenSegmentRepresentable
  {
    #if swift(>=4.1)
      let charSegments = s.compactMap { c in c.sevenSegmentValue }.suffix(4)
    #else
      let charSegments = s.flatMap { c in c.sevenSegmentValue }.suffix(4)
    #endif
    let count        = charSegments.count
    let off          = SevenSegment.off

    if count >= segmentCount {
      return show(s1: charSegments[0], s2: charSegments[1],
                  s3: charSegments[2], s4: charSegments[3])
    }
    if count == 0 {
      return show(s1: off, s2: off, s3: off, s4: off)
    }
    
    let missing = segmentCount - count
    let segs : ArraySlice<SevenSegment>
    switch align {
      case .left:
        segs = charSegments + repeatElement(off, count: missing)
      case .right:
        segs = repeatElement(off, count: missing) + charSegments
      case .center:
        switch missing {
          case 1:  segs = repeatElement(off, count: 1)
                        + charSegments
                        + repeatElement(off, count: 2)
          case 2:  segs = repeatElement(off, count: 1)
                        + charSegments
                        + repeatElement(off, count: 1)
          case 3:  segs = charSegments
                        + repeatElement(off, count: 1)
          default: segs = charSegments
        }
    }
    
    assert(segs.count == 4, "did not generate enough padding segments: \(segs)")
    show(s1: segs[0], s2: segs[1],
         s3: segs[2], s4: segs[3])
  }

  /// Show the given data in the slots. Example:
  ///
  ///     digi.show("1", 3, 3, SevenSegment(digit: 7, dot: true))
  ///
  open func show<T1, T2, T3, T4>(s1: T1?, s2: T2?, s3: T3?, s4: T4?)
            where T1: SevenSegmentRepresentable,
                  T2: SevenSegmentRepresentable,
                  T3: SevenSegmentRepresentable,
                  T4: SevenSegmentRepresentable
  {
    var didChange = false
    
    func apply<T: SevenSegmentRepresentable>(_ value: T?,
                                             _ storage: inout SevenSegment?)
    {
      guard let v = value?.sevenSegmentValue else { return }
      guard storage != v                     else { return }
      storage = v
      didChange = true
    }
    
    lock.lock()
    apply(s1, &_segments.s1)
    apply(s2, &_segments.s2)
    apply(s3, &_segments.s3)
    apply(s4, &_segments.s4)
    lock.unlock()
    
    if didChange { _flush() }
  }
 
  open var brightness: Brightness? {
    set {
      assert(newValue != nil, "cannot set a nil value?!")
      var didChange = false
      
      lock.lock()
      didChange = _brightness != newValue
      _brightness = newValue
      lock.unlock()
      
      if didChange { _flush() }
    }
    get {
      lock.lock()
      let v = _brightness
      lock.unlock()
      return v
    }
  }
  
  /// Write stored segments to display
  func _flush() {
    shield?.Q.async { // FIXME: shield is not protected?
      guard let display = self.display else { return }
      
      self.lock.lock()
      let segments = self._segments
      self.lock.unlock()
      
      display.show(s1: segments.s1, s2: segments.s2,
                   s3: segments.s3, s4: segments.s4)
    }
  }

  
  // MARK: - Accessory Registration
  
  override open func shield(_ shield: LKRBShield, connectedTo socket: Socket) {
    assert(socket.isDigital, "attempt to connect digital accessory \(self) " +
                             "to non-digital socket: \(socket)")
    
    guard let ( gpio0, gpio1 ) = shield.gpios(for: socket) else { return }
    
    assert(display == nil)
    #if !os(macOS)
      display = TM1637(clock: gpio0, data: gpio1)
    #endif
    
    if let brightness = brightness {
      display?.brightness = brightness
    }
    // TODO: push text

    super.shield(shield, connectedTo: socket)
  }
  
  override open func shield(_ shield: LKRBShield, disconnectedFrom s: Socket) {
    if let display = display {
      display.turnOff()
    }
    display = nil
    
    super.shield(shield, disconnectedFrom: s)
  }

  override open func teardownOnExit() {
    display?.turnOff()
  }
  
  
  // MARK: - Description

  override open func lockedAppendToDescription(_ ms: inout String) {
    super.lockedAppendToDescription(&ms)

    ms += " "
    if let v = _segments.s1 { ms += "[\(v)]" } else { ms += "[-]" }
    if let v = _segments.s2 { ms += "[\(v)]" } else { ms += "[-]" }
    if let v = _segments.s3 { ms += "[\(v)]" } else { ms += "[-]" }
    if let v = _segments.s4 { ms += "[\(v)]" } else { ms += "[-]" }
    
    if let v = _brightness { ms += " brightness=\(v)" }
  }
}
