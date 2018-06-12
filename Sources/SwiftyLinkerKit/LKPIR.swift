//
//  LKPIR.swift
//  SwiftyLinkerKit
//
//  Created by Helge Hess on 08.06.18.
//

/**
 * The LK-PIR move detection sensor.
 *
 * Detailed information can be found over here:
 *
 *   http://www.linkerkit.de/index.php?title=LK-PIR
 *
 * Example:
 *
 *     import SwiftyLinkerKit
 *
 *     let shield   = LKRBShield.default
 *     let watchdog = LKPIR()
 *
 *     watchdog.onChange { didMove in
 *         if didMove { print("careful, don't move!") }
 *         else       { print("nothing is moving.")   }
 *     }
 *
 */
open class LKPIR : LKAccessoryBase {
  
  public var signal : GPIO?
  public var listeners = [ ( Bool ) -> () ]()
  
  
  // MARK: - API
  
  @discardableResult
  open func onChange(_ cb: @escaping ( Bool ) -> ()) -> Self {
    asyncLocked { self.listeners.append(cb) }
    return self
  }
  
  open func removeAllListeners() {
    asyncLocked { self.listeners.removeAll() }
  }
  
  
  // MARK: - Tracker
    
  func handleChange(_ value: Int) { // Q: shield
    lock.lock()
    let listeners = self.listeners
    lock.unlock()
    
    for cb in listeners { cb(value != 0) }
  }

  
  // MARK: - Accessory Registration
  
  override open func shield(_ shield: LKRBShield, connectedTo socket: Socket) {
    assert(socket.isDigital, "attempt to connect digital accessory \(self) " +
                             "to non-digital socket: \(socket)")
    guard let ( gpio0, _ ) = shield.gpios(for: socket) else { return }
    
    #if !os(macOS)
      gpio0.direction = .IN
    #endif
    
    signal = gpio0

    #if false
      // the dox are talking about an LED, but I assume that is a different
      // thing and not built into the PIR
      let led = gpios[.P12]!
      led.direction = .OUT
      led.value = 1
    #endif

    super.shield(shield, connectedTo: socket)

    #if !os(macOS)
      gpio0.onChange { [weak self] gpio in
        guard let me = self, let shield = me.shield else { return }
        assert(gpio === me.signal, "event from wrong GPIO?! \(gpio) \(me)")
        guard gpio === me.signal else { return }
        
        let value = gpio.value
        shield.Q.async {
          me.handleChange(value)
        }
      }
    #endif
  }
  
  override open func shield(_ shield: LKRBShield, disconnectedFrom s: Socket) {
    signal?.clearListeners()
    signal = nil
    super.shield(shield, disconnectedFrom: s)
  }
}
