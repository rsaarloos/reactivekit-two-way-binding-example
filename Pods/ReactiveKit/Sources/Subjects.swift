//
//  The MIT License (MIT)
//
//  Copyright (c) 2016 Srdan Rasic (@srdanrasic)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

internal class ObserverRegister<E: EventType> {
  private typealias Token = Int64
  private var nextToken: Token = 0
  private(set) var observers: ContiguousArray<E -> Void> = []
  
  private var observerStorage: [Token: E -> Void] = [:] {
    didSet {
      observers = ContiguousArray(observerStorage.values)
    }
  }

  private let tokenLock = SpinLock()

  func addObserver(observer: E -> Void) -> Disposable {
    tokenLock.lock()
    let token = nextToken
    nextToken = nextToken + 1
    tokenLock.unlock()

    observerStorage[token] = observer

    return BlockDisposable { [weak self] in
      self?.observerStorage.removeValueForKey(token)
    }
  }
}

public protocol SubjectType: ObserverType, RawStreamType {
}

public final class PublishSubject<E: EventType>: ObserverRegister<E>, SubjectType {

  private let lock = RecursiveLock(name: "ReactiveKit.PublishSubject")
  private var completed = false

  public override init() {
  }

  public func on(event: E) {
    guard !completed else { return }
    lock.lock(); defer { lock.unlock() }
    completed = event.isTermination
    observers.forEach { $0(event) }
  }

  public func observe(observer: E -> Void) -> Disposable {
    return addObserver(observer)
  }
}

public final class ReplaySubject<E: EventType>: ObserverRegister<E>, SubjectType {

  public let bufferSize: Int
  private var buffer: ArraySlice<E> = []
  private let lock = RecursiveLock(name: "ReactiveKit.ReplaySubject")

  public init(bufferSize: Int = Int.max) {
    self.bufferSize = bufferSize
  }

  public func on(event: E) {
    guard !completed else { return }
    lock.lock(); defer { lock.unlock() }
    buffer.append(event)
    buffer = buffer.suffix(bufferSize)
    observers.forEach { $0(event) }
  }

  public func observe(observer: E -> Void) -> Disposable {
    lock.lock(); defer { lock.unlock() }
    buffer.forEach(observer)
    return addObserver(observer)
  }

  private var completed: Bool {
    if let lastEvent = buffer.last {
      return lastEvent.isTermination
    } else {
      return false
    }
  }
}

public final class AnySubject<E: EventType>: SubjectType {
  private let baseObserve: (E -> Void) -> Disposable
  private let baseOn: E -> Void

  public init<S: SubjectType where S.Event == E>(base: S) {
    baseObserve = base.observe
    baseOn = base.on
  }

  public func on(event: E) {
    return baseOn(event)
  }

  public func observe(observer: E -> Void) -> Disposable {
    return baseObserve(observer)
  }
}

