//
//  LKRBShield.swift
//  SwiftyLinkerKit
//
//  Created by Helge Hess on 08.06.18.
//

import Foundation
import SwiftyGPIO
import Dispatch

/**
 * The LK-Base-RB2 Shield for Raspberry Pi 3 boards.
 *
 * Ports:
 * - UART
 * - I2C
 * - 12 digital sockets
 * -  4 analog sockets (SPI ADC on board)
 *
 * Detailed information can be found over here:
 *
 *   http://www.linkerkit.de/index.php?title=LK-Base-RB_2
 *
 */
open class LKRBShield {
  
  public static let `default`    = LKRBShield(gpios: defaultGPIOs,
                                              spis:  defaultSPIs)
  public static var defaultGPIOs = SwiftyGPIO.GPIOs(for: .RaspberryPi3)
  public static var defaultSPIs  = SwiftyGPIO.hardwareSPIs(for: .RaspberryPi3)
  
  public  let gpios       : [ GPIOName : GPIO ]
  public  let spis        : [ SPIInterface ]
  private var accessories = [ Socket   : LKAccessory ]()
  
  public  let Q = DispatchQueue(label: "de.zeezide.linkerkit.Q.shield")
  
  public init(gpios: [ GPIOName: GPIO ], spis: [ SPIInterface ]?) {
    self.gpios = gpios
    self.spis  = spis ?? []
    _ = atexit {
      teardownShield()
    }
  }
  
  open func gpios(for socket: Socket) -> ( GPIO, GPIO )? {
    guard let names = socket.gpioNames else { return nil }
    guard let gpio0 = gpios[names.0]   else { return nil }
    guard let gpio1 = gpios[names.1]   else { return nil }
    return ( gpio0, gpio1 )
  }
  
  open func analogInfo(for socket: Socket) -> ( SPIInterface, UInt8, UInt8 )? {
    guard let pins = socket.analogPINs else { return nil }
    guard let spi  = spis.first else { return nil } // TBD: hardcoded by board?
    
    return ( spi, pins.0, pins.1 )
  }
  
  // MARK: - Threadsafe API
  
  open func connect(_ accessory: LKAccessory, to socket: Socket) {
    Q.async {
      self._connect(accessory, to: socket)
    }
  }
  open func disconnect(_ accessory: LKAccessory) {
    Q.async {
      self._disconnect(accessory)
    }
  }
  
  open func getAccessories(_ cb: @escaping ( [ Socket : LKAccessory ] ) -> ()) {
    Q.async {
      cb(self.accessories)
    }
  }
  
  open func teardownOnExit() {
    // called by `atexit` - disable all accessories
    for ( _, accessory ) in accessories {
      accessory.teardownOnExit()
    }
  }
  
  
  // MARK: - Internal Ops

  open func _disconnect(_ accessory: LKAccessory) {
    guard let old = accessories.first(where: { $1 === accessory }) else {
      return
    }
    
    let oldSocket = old.0
    accessories.removeValue(forKey: oldSocket)
    accessory.shield(self, disconnectedFrom: oldSocket)
  }
  
  open func _connect(_ accessory: LKAccessory, to socket: Socket) { // Q: own
    if accessories[socket] === accessory { return } // already hooked up
    
    if let old = accessories.first(where: { $1 === accessory }) {
      let oldSocket = old.0
      accessories.removeValue(forKey: oldSocket)
      accessory.shield(self, disconnectedFrom: oldSocket)
    }
    
    if let oldAccessory = accessories[socket] {
      accessories.removeValue(forKey: socket)
      oldAccessory.shield(self, disconnectedFrom: socket)
    }
    
    accessories[socket] = accessory
    accessory.shield(self, connectedTo: socket)
  }
  
  /**
   * Sockets on the LK-RB-Shield
   * ```
   * UART + I2C
   *          Digital GPIO
   * ┌─┐┌─┐   ┌─┐┌─┐
   * │ ││ │   │ ││ │
   * │ ││ │   │ ││ │/-------------
   * └─┘└─┘   └─┘└─┘| Analog Input
   * ┌─┐┌─┐┌─┐┌─┐┌─┐|┌─┐┌─┐
   * │ ││ ││ ││ ││ │|│ ││ │
   * │ ││ ││ ││ ││ │|│ ││ │ 
   * └─┘└─┘└─┘└─┘└─┘|└─┘└─┘ 
   * ┌─┐┌─┐┌─┐┌─┐┌─┐|┌─┐┌─┐
   * │ ││ ││ ││ ││ │|│ ││ │
   * │ ││ ││ ││ ││ │|│ ││ │
   * └─┘└─┘└─┘└─┘└─┘|└─┘└─┘
   * ```
   */
  public enum Socket : Hashable {
    // row1
    case uart
    case i2c
    case digital45
    case digital23
    // row2
    case digital1516
    case digital1415
    case digital1314
    case digital1213
    case digital56
    case analog01
    case analog23
    // row3
    case digital2627
    case digital2526
    case digital2122
    case digital2021
    case digital1920
    case analog45
    case analog67
    
    public init(row: Int, column: Int) {
      switch ( row, column ) {
        case ( 1, 1 ): self = .uart
        case ( 1, 2 ): self = .i2c
        case ( 1, 3 ): self = .digital45
        case ( 1, 4 ): self = .digital23
        case ( 2, 1 ): self = .digital1516
        case ( 2, 2 ): self = .digital1415
        case ( 2, 3 ): self = .digital1314
        case ( 2, 4 ): self = .digital1213
        case ( 2, 5 ): self = .digital56
        case ( 2, 6 ): self = .analog01
        case ( 2, 7 ): self = .analog23
        case ( 3, 1 ): self = .digital2627
        case ( 3, 2 ): self = .digital2526
        case ( 3, 3 ): self = .digital2122
        case ( 3, 4 ): self = .digital2021
        case ( 3, 5 ): self = .digital1920
        case ( 3, 6 ): self = .analog45
        case ( 3, 7 ): self = .analog67
        default: fatalError("invalid socket position: \(row)/\(column)")
      }
    }
    
    public var gpioNames : ( GPIOName, GPIOName )? {
      switch self {
        case .uart:        return nil // TBD
        case .i2c:         return nil // TBD
        case .digital45:   return ( .P4,  .P5  )
        case .digital23:   return ( .P2,  .P3  )
        case .digital1516: return ( .P15, .P16 )
        case .digital1415: return ( .P14, .P15 )
        case .digital1314: return ( .P13, .P14 )
        case .digital1213: return ( .P12, .P13 )
        case .digital56:   return ( .P5,  .P6  )
        case .analog01:    return ( .P0,  .P1  ) // TBD
        case .analog23:    return ( .P2,  .P3  ) // TBD
        case .digital2627: return ( .P26, .P27 )
        case .digital2526: return ( .P25, .P26 )
        case .digital2122: return ( .P21, .P22 )
        case .digital2021: return ( .P20, .P21 )
        case .digital1920: return ( .P19, .P20 )
        case .analog45:    return ( .P4,  .P5  ) // TBD
        case .analog67:    return ( .P6,  .P7  ) // TBD
      }
    }
    
    public var analogPINs : ( UInt8, UInt8 )? {
      switch self {
        case .analog01:    return ( 0, 1 )
        case .analog23:    return ( 2, 3 )
        case .analog45:    return ( 4, 5 )
        case .analog67:    return ( 6, 7 )
        default:
          assert(!isAnalog)
          return nil
      }
    }
    
    public var position : ( row: Int, column: Int ) {
      switch self {
        case .uart:        return ( 1, 1 )
        case .i2c:         return ( 1, 2 )
        case .digital45:   return ( 1, 3 )
        case .digital23:   return ( 1, 4 )
        case .digital1516: return ( 2, 1 )
        case .digital1415: return ( 2, 2 )
        case .digital1314: return ( 2, 3 )
        case .digital1213: return ( 2, 4 )
        case .digital56:   return ( 2, 5 )
        case .analog01:    return ( 2, 6 )
        case .analog23:    return ( 2, 7 )
        case .digital2627: return ( 3, 1 )
        case .digital2526: return ( 3, 2 )
        case .digital2122: return ( 3, 3 )
        case .digital2021: return ( 3, 4 )
        case .digital1920: return ( 3, 5 )
        case .analog45:    return ( 3, 6 )
        case .analog67:    return ( 3, 7 )
      }
    }
    
    public var isDigital : Bool {
      switch self {
        case .uart:        return false
        case .i2c:         return false
        case .digital45:   return true
        case .digital23:   return true
        case .digital1516: return true
        case .digital1415: return true
        case .digital1314: return true
        case .digital1213: return true
        case .digital56:   return true
        case .analog01:    return false
        case .analog23:    return false
        case .digital2627: return true
        case .digital2526: return true
        case .digital2122: return true
        case .digital2021: return true
        case .digital1920: return true
        case .analog45:    return false
        case .analog67:    return false
      }
    }
    public var isAnalog : Bool {
      switch self {
        case .uart:        return false
        case .i2c:         return false
        case .digital45:   return false
        case .digital23:   return false
        case .digital1516: return false
        case .digital1415: return false
        case .digital1314: return false
        case .digital1213: return false
        case .digital56:   return false
        case .analog01:    return true
        case .analog23:    return true
        case .digital2627: return false
        case .digital2526: return false
        case .digital2122: return false
        case .digital2021: return false
        case .digital1920: return false
        case .analog45:    return true
        case .analog67:    return true
      }
    }
  }
}

fileprivate func teardownShield() {
  LKRBShield.default.teardownOnExit()
}
