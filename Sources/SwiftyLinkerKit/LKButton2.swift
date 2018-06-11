//
//  LKButton2.swift
//  SwiftyLinkerKit
//
//  Created by Helge Hess on 08.06.18.
//

/**
 * A LinkerKit LK-Button2 component.
 *
 * See here for details:
 *
 *   http://www.linkerkit.de/index.php?title=LK-Button2
 *
 * Example:
 *
 *     let shield  = LKRBShield.default
 *     let buttons = LKButton2()
 *
 *     shield.connect(buttons, to: .digital2122)
 *
 *     buttons.onPress1 {
 *         print("Button 1 was pressed!")
 *     }
 *     buttons.onChange2 { isPressed in
 *         print("Button 2 changed, it is now: \(isPressed ? "pressed" : "off" )")
 *     }
 *
 */
open class LKButton2 : LKAccessoryBase  {
  
  public var button1 : GPIO?
  public var button2 : GPIO?

  public var change1Listeners = [ ( Bool ) -> () ]()
  public var change2Listeners = [ ( Bool ) -> () ]()

  var _button1State : Bool?
  var _button2State : Bool?
  
  
  // MARK: - API
  
  open func onChange1(_ cb: @escaping ( Bool ) -> ()) {
    asyncLocked { self.change1Listeners.append(cb) }
  }
  open func onChange2(_ cb: @escaping ( Bool ) -> ()) {
    asyncLocked { self.change2Listeners.append(cb) }
  }
  
  open func onPress1(_ vcb: @escaping () -> ()) {
    let cb : ( Bool ) -> () = { flag in if flag { vcb() }}
    asyncLocked { self.change1Listeners.append(cb) }
  }
  open func onPress2(_ vcb: @escaping () -> ()) {
    let cb : ( Bool ) -> () = { flag in if flag { vcb() }}
    asyncLocked { self.change2Listeners.append(cb) }
  }

  open func removeAllListeners() {
    asyncLocked {
      self.change1Listeners.removeAll()
      self.change2Listeners.removeAll()
    }
  }
  
  
  // MARK: - Tracker
  
  func handleChange1(_ value: Int) { // Q: shield
    let flag = value != 0
    
    lock.lock()
    let oldFlag = _button1State
    _button1State = flag
    let listeners = self.change1Listeners
    lock.unlock()
    
    guard oldFlag != flag else { return }
    for cb in listeners { cb(flag) }
  }
  
  func handleChange2(_ value: Int) { // Q: shield
    // stupid dupe
    let flag = value != 0
    
    lock.lock()
    let oldFlag = _button2State
    _button2State = flag
    let listeners = self.change2Listeners
    lock.unlock()
    
    guard oldFlag != flag else { return }
    for cb in listeners { cb(flag) }
  }
  

  // MARK: - Accessory Registration
  
  override open func shield(_ shield: LKRBShield, connectedTo socket: Socket) {
    assert(socket.isDigital, "attempt to connect digital accessory \(self) " +
                             "to non-digital socket: \(socket)")
    
    guard let ( gpio0, gpio1 ) = shield.gpios(for: socket) else { return }
    
    #if !os(macOS)
      gpio0.direction = .IN
      gpio1.direction = .IN
      
      // read initial state
      lock.lock()
      _button1State = gpio0.value != 0
      _button2State = gpio1.value != 0
      button1 = gpio0
      button2 = gpio1
      lock.unlock()
    #else
      button1 = gpio0
      button2 = gpio1
    #endif

    super.shield(shield, connectedTo: socket)
    
    #if !os(macOS)
      gpio0.onChange { [weak self] gpio in
        guard let me = self, let shield = me.shield else { return }
        assert(gpio === me.button1, "event from wrong GPIO?! \(gpio) \(me)")
        guard gpio === me.button1 else { return }
        
        let value = gpio.value
        shield.Q.async {
          me.handleChange1(value)
        }
      }
      gpio1.onChange { [weak self] gpio in
        guard let me = self, let shield = me.shield else { return }
        assert(gpio === me.button2, "event from wrong GPIO?! \(gpio) \(me)")
        guard gpio === me.button2 else { return }
        
        let value = gpio.value
        shield.Q.async {
          me.handleChange2(value)
        }
      }
    #endif
  }
  
  override open func shield(_ shield: LKRBShield, disconnectedFrom s: Socket) {
    button1?.clearListeners() // TODO: lock
    button2?.clearListeners()
    
    lock.lock()
    button1 = nil
    button2 = nil
    _button1State = nil
    _button2State = nil
    lock.unlock()
    
    super.shield(shield, disconnectedFrom: s)
  }
  
  
  // MARK: - Description
  
  override open func lockedAppendToDescription(_ ms: inout String) {
    super.lockedAppendToDescription(&ms)

    if let b = _button1State { ms += " b1=\(b ? "pressed" : "idle")" }
    if let b = _button2State { ms += " b2=\(b ? "pressed" : "idle")" }
  }
}
