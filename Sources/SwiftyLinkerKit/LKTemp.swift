//
//  LKTemp.swift
//  SwiftyLinkerKit
//
//  Created by Helge Hess on 11.06.18.
//

import struct Foundation.TimeInterval
import Dispatch
import SwiftyGPIO

/**
 * A LinkerKit LK-Button2 component.
 *
 * See here for details:
 *
 *   http://www.linkerkit.de/index.php?title=LK-Temp
 *
 * Example:
 *
 *      let shield      = LKRBShield.default
 *      let thermometer = LKTemp(interval: 5.0, valueType: .celsius)
 *
 *      thermometer.onChange { temperature in
 *          print("Temperatur is", temperature, "℃")
 *      }
 *
 */
open class LKTemp : LKAccessoryBase {
  
  public enum ValueType {
    case raw, voltage, celsius, fahrenheit
  }
  
  public let timer     : DispatchSourceTimer
  public let valueType : ValueType
  public let boardVoltage = 3.3

  public var listeners = [ ( Double ) -> () ]()
  public var spi       : SPIInterface?
  public var pin       : UInt8?

  public init(interval: TimeInterval = 1.0, valueType: ValueType = .celsius) {
    self.timer     = DispatchSource.makeTimerSource()
    self.valueType = valueType
    
    super.init()
    
    timer.setEventHandler { [weak self] in
      guard let me = self else { return }
      me.async(me.handleTimerEvent) // dispatch to right queue
    }
    timer.schedule(deadline  : .now(),
                   repeating : .milliseconds(Int(interval * 1000.0)),
                   leeway    : .milliseconds(1))
  }
  deinit {
    timer.cancel()
  }
  
  // MARK: - API
  
  open func onChange(_ cb: @escaping ( Double ) -> ()) {
    asyncLocked { self.listeners.append(cb) }
  }
  
  open func removeAllListeners() {
    asyncLocked { self.listeners.removeAll() }
  }
  
  // MARK: - Reading
  
  var connection : ( SPIInterface, UInt8 )? {
    lock.lock()
    let spiO = spi
    let pinO = pin
    lock.unlock()
    guard let spi = spiO, let pin = pinO else { return nil }
    return ( spi, pin )
  }
  
  open func readRawValue() -> Int? {
    guard let ( spi, pin ) = connection else { return nil }
    return spi.readLinkerKitADC(analogPIN: pin)
  }
  
  
  open func readValue() -> Double? {
    guard let rawValue = readRawValue() else { return nil }
    
    let voltage : Double = (Double(rawValue) * boardVoltage) / 1024
    let value   : Double
    switch valueType {
      case .raw:     value = Double(rawValue)
      case .voltage: value = voltage
      case .celsius: value = (voltage - 0.5) * 100
      case .fahrenheit:
        let celsius = (voltage - 0.5) * 100
        value = (celsius * 9 / 5) + 32
    }
    
    return value
  }

  // MARK: - Timer
  
  func handleTimerEvent() { // Q: shield
    guard let value = readValue() else { return }
    
    lock.lock()
    let listeners = self.listeners
    lock.unlock()
    
    for cb in listeners { cb(value) }
  }
  
  // MARK: - Accessory Registration
  
  override open func shield(_ shield: LKRBShield, connectedTo socket: Socket) {
    assert(socket.isAnalog, "attempt to connect analog accessory \(self) " +
                            "to non-analog socket: \(socket)")
    guard let ( spi, pin, _ ) = shield.analogInfo(for: socket) else { return }
    
    lock.lock()
    self.spi = spi
    self.pin = pin
    lock.unlock()
    
    super.shield(shield, connectedTo: socket)
    
    timer.resume()
  }
  
  override open func shield(_ shield: LKRBShield, disconnectedFrom s: Socket) {
    timer.suspend()
    
    lock.lock()
    self.spi = nil
    self.pin = nil
    lock.unlock()
    
    super.shield(shield, disconnectedFrom: s)
  }

  
  // MARK: - Description
  
  override open func lockedAppendToDescription(_ ms: inout String) {
    super.lockedAppendToDescription(&ms)
    
    ms += " type=\(valueType)"
  }
}
