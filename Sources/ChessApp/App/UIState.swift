import SwiftUI

/// Workaround für fehlendes `libSwiftUIMacros.dylib` in macOS CommandLineTools:
/// Kapselt veränderlichen State als DynamicProperty mit Binding.
@propertyWrapper
public struct LocalState<Value>: DynamicProperty {
    @StateObject private var container: StateContainer<Value>

    public init(wrappedValue: Value) {
        _container = StateObject(wrappedValue: StateContainer(value: wrappedValue))
    }

    public var wrappedValue: Value {
        get { container.value }
        nonmutating set { container.value = newValue }
    }

    public var projectedValue: Binding<Value> {
        Binding(
            get: { self.container.value },
            set: { self.container.value = $0 }
        )
    }
}

private final class StateContainer<Value>: ObservableObject {
    @Published var value: Value
    init(value: Value) { self.value = value }
}
