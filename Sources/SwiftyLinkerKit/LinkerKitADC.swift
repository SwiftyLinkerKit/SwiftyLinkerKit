//
//  LinkerKitADC.swift
//  SwiftyLinkerKit
//
//  Created by Helge Hess on 11.06.18.
//

import protocol SwiftyGPIO.SPIInterface

public extension SPIInterface {
  
  public func readLinkerKitADC(analogPIN: UInt8) -> Int {
    assert(analogPIN >= 0 && analogPIN <= 7,
           "analog PIN out of range \(analogPIN)")
    guard analogPIN >= 0 && analogPIN <= 7 else { return -1337 }
    
    let r = sendDataAndRead([ 1, 8 + analogPIN << 4, 0 ])
    let value = ((Int(r[1]) & 3) << 8) + Int(r[2])
    return value
  }
  
}
