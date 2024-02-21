// RUN: %target-swift-frontend %s -emit-sil -o /dev/null -verify \
// RUN: -enable-builtin-module \
// RUN: -enable-experimental-feature NonescapableTypes \
// RUN: -disable-experimental-parser-round-trip \
// RUN: -enable-experimental-feature NoncopyableGenerics \
// RUN: -enable-experimental-lifetime-dependence-inference \
// RUN:  -Xllvm -enable-lifetime-dependence-diagnostics=true

// REQUIRES: asserts

// REQUIRES: swift_in_compiler

struct NCContainer : ~Copyable {
  let ptr: UnsafeRawBufferPointer
  let c: Int
  init(_ ptr: UnsafeRawBufferPointer, _ c: Int) {
    self.ptr = ptr
    self.c = c
  }
}

struct NEContainer : ~Escapable {
  let ptr: UnsafeRawBufferPointer
  let c: Int
  @_unsafeNonescapableResult
  init(_ ptr: UnsafeRawBufferPointer, _ c: Int) {
    self.ptr = ptr
    self.c = c
  }
}

struct View : ~Escapable {
  let ptr: UnsafeRawBufferPointer
  let c: Int
  @_unsafeNonescapableResult
  init(_ ptr: UnsafeRawBufferPointer, _ c: Int) {
    self.ptr = ptr
    self.c = c
  }
  init(_ otherBV: borrowing View) {
    self.ptr = otherBV.ptr
    self.c = otherBV.c
  }
  init(_ k: borrowing NCContainer) {
    self.ptr = k.ptr
    self.c = k.c
  }
  init(_ k: consuming NEContainer) {
    self.ptr = k.ptr
    self.c = k.c
  }
}

struct MutableView : ~Copyable, ~Escapable {
  let ptr: UnsafeRawBufferPointer
  let c: Int
  @_unsafeNonescapableResult
  init(_ ptr: UnsafeRawBufferPointer, _ c: Int) {
    self.ptr = ptr
    self.c = c
  }
  init(_ otherBV: borrowing View) {
    self.ptr = otherBV.ptr
    self.c = otherBV.c
  }
  init(_ k: borrowing NCContainer) {
    self.ptr = k.ptr
    self.c = k.c
  }
  init(_ k: consuming NEContainer) {
    self.ptr = k.ptr
    self.c = k.c
  }
}

func use(_ o : borrowing View) {}
func mutate(_ x: inout NCContainer) { }
func mutate(_ x: inout View) { }
func mutate(_ x: inout NEContainer) { }
func consume(_ o : consuming View) {}
func use(_ o : borrowing MutableView) {}
func consume(_ o : consuming MutableView) {}

func getConsumingView(_ x: consuming NEContainer) -> _consume(x) View {
  return View(x)
}

func getConsumingView(_ x: consuming View) -> _consume(x) View {
  return View(x.ptr, x.c)
}

func getBorrowingView(_ x: borrowing View) -> _borrow(x) View {
  return View(x.ptr, x.c)
}

func getBorrowingView(_ x: borrowing NCContainer) -> _borrow(x) View {
  return View(x.ptr, x.c)
}

func getBorrowingView(_ x: borrowing NEContainer) -> _borrow(x) View {
  return View(x.ptr, x.c)
}

func test1(_ a: Array<Int>) {
  a.withUnsafeBytes {
    var x = NEContainer($0, a.count)
    mutate(&x)
    let view = getConsumingView(x)
    let newView = View(view)
    use(newView)
    consume(view)
  }
}

func test2(_ a: Array<Int>) {
  a.withUnsafeBytes {
    var x = NCContainer($0, a.count)
    mutate(&x)
    let view = getBorrowingView(x)
    use(view)
    consume(view)
  }
}

func test3(_ a: Array<Int>) {
  a.withUnsafeBytes {
    var x = View($0, a.count)
    mutate(&x)
    let view = getConsumingView(x)
    use(view)
    consume(view)
  }
}

/*
// Currently fails because the lifetime dependence util isn't analyzing a
// def-use chain involving a stack temporary
func test4(_ a: Array<Int>) {
  a.withUnsafeBytes {
    var x = NCContainer($0, a.count)
    mutate(&x)
    let view = MutableView(x)
    use(view)
    consume(view)
  }
}
*/

func test5(_ a: Array<Int>) {
  a.withUnsafeBytes {
    let x = NEContainer($0, a.count)
    let view = getBorrowingView(x)
    let anotherView = getConsumingView(view)
    use(anotherView)
  }
}

func test6(_ a: Array<Int>) {
  var p : View?
  a.withUnsafeBytes {
    var x = NCContainer($0, a.count)
    mutate(&x)
    let view = View(x)
    p = view
  }
  use(p!)
}

func test7(_ a: UnsafeRawBufferPointer) {
  var x = NEContainer(a, a.count)
  do {
    let view = getBorrowingView(x)
    use(view)
  }
  mutate(&x)
}

func test8(_ a: Array<Int>) {
  a.withUnsafeBytes {
    var x = NEContainer($0, a.count)
    mutate(&x)
    let view = MutableView(x)
    use(view)
    consume(view)
  }
}

struct Wrapper : ~Escapable {
  var _view: View
  var view: View {
    _read {
      yield _view
    }
    _modify {
      yield &_view
    }
  }
  init(_ view: consuming View) {
    self._view = view
  }
}

func test9() {
  let a = [Int](repeating: 0, count: 4)
  a.withUnsafeBytes {
    let view = View($0, a.count)
    var c = Wrapper(view)
    use(c.view)
    mutate(&c.view)
  }
}

