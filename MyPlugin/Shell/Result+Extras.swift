import Foundation

extension Result {
    var error: Failure? {
        switch self {
        case let .failure(failure):
            return failure
        default:
            return nil
        }
    }

    var value: Success? {
        switch self {
        case let .success(success):
            return success
        default:
            return nil
        }
    }
}
