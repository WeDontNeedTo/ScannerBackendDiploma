enum OperationKind: Equatable {
    case create
    case update
}

struct OperationResult<Value> {
    let value: Value
    let kind: OperationKind
}
