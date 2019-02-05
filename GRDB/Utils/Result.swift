#if compiler(>=5.0)
typealias Result<Value> = Swift.Result<Value, Error>
#else
enum Result<Value> {
    case success(Value)
    case failure(Error)
    
    init(catching body: () throws -> Value) {
        do {
            self = try .success(body())
        } catch {
            self = .failure(error)
        }
    }
    
    func map<T>(_ transform: (Value) -> T) -> Result<T> {
        switch self {
        case .success(let value):
            return .success(transform(value))
        case .failure(let error):
            return .failure(error)
        }
    }
    
    func get() throws -> Value {
        switch self {
        case .success(let value):
            return value
        case .failure(let error):
            throw error
        }
    }
}
#endif
