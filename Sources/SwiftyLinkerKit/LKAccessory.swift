//
//  LKAccessory.swift
//  SwiftyLinkerKit
//
//  Created by Helge Hess on 08.06.18.
//

import class SwiftyGPIO.GPIO

public protocol LKAccessory : class {
  
  typealias GPIO   = SwiftyGPIO.GPIO
  typealias Shield = LKRBShield
  typealias Socket = LKRBShield.Socket
  
  var accessoryType : String { get }
  
  func shield(_ shield: LKRBShield, disconnectedFrom socket: Socket)
  func shield(_ shield: LKRBShield, connectedTo      socket: Socket)
  
  // turn off everything the accessory turned on!
  func teardownOnExit()

}

public extension LKAccessory {
  
  public var accessoryType : String {
    return "\(type(of: self))"
  }
  
  public func shield(_ shield: LKRBShield, connectedTo      socket: Socket) {}
  public func shield(_ shield: LKRBShield, disconnectedFrom socket: Socket) {}

  public func teardownOnExit() {}
}

import class Foundation.NSLock

open class LKAccessoryBase : LKAccessory, CustomStringConvertible {
  
  weak var _shield : LKRBShield?
  var      _socket : Socket?
  let      lock    = Foundation.NSLock()

  open var shield : LKRBShield? {
    lock.lock(); defer { lock.unlock() }
    return _shield
  }
  open var socket : Socket? {
    lock.lock(); defer { lock.unlock() }
    return _socket
  }

  public init() {}
  
  public var accessoryType : String {
    return "\(type(of: self))"
  }
  
  
  // MARK: - Threading
  
  open func async(_ cb: @escaping () -> ()) {
    if let Q = shield?.Q {
      Q.async(execute: cb)
    }
    else {
      cb()
    }
  }
  open func asyncLocked(_ cb: @escaping () -> ()) {
    if let Q = shield?.Q {
      Q.async {
        self.lock.lock(); defer { self.lock.unlock() }
        cb()
      }
    }
    else {
      lock.lock(); defer { lock.unlock() }
      cb()
    }
  }
  
  // MARK: - LKAccessory
  
  open func shield(_ shield: LKRBShield, connectedTo socket: Socket) {
    assert(self.socket == nil)
    assert(self.shield == nil)
    lock.lock()
    self._socket = socket
    self._shield = shield
    lock.unlock()
  }
  open func shield(_ shield: LKRBShield, disconnectedFrom socket: Socket) {
    assert(socket ==  self.socket || self.socket == nil)
    assert(shield === self.shield || self.shield == nil)
    lock.lock()
    self._socket = nil
    self._shield = nil
    lock.unlock()
  }
  
  open func teardownOnExit() {}
  
  public var description: String {
    lock.lock(); defer { lock.unlock() }

    var ms = "<\(accessoryType): "
    lockedAppendToDescription(&ms)
    ms += ">"
    return ms
  }
  
  open func lockedAppendToDescription(_ ms: inout String) {
    if _shield == nil       { ms += " no-shield"   }
    if let socket = _socket { ms += " [\(socket)]" }
  }
}
