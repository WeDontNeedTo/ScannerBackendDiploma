import Foundation

enum ItemJournalEventType {
    static let grabRequested = "grab_requested"
    static let grabApproved = "grab_approved"
    static let grabRequestApproved = "grab_request_approved"
    static let transferRequested = "transfer_requested"
    static let transferApproved = "transfer_approved"
    static let transferDirect = "transfer_direct"
    static let itemReturned = "item_returned"
    static let locationChanged = "location_changed"
    static let responsibleChanged = "responsible_changed"
    static let movedToBroken = "moved_to_broken"
}

enum ItemJournalMessageFactory {
    static func unknownUser() -> String { "неизвестный пользователь" }

    static func unknownLocation() -> String { "неизвестная локация" }

    static func itemLabel(name: String, number: String) -> String {
        "\"\(name)\" (\(number))"
    }

    static func grabRequested(actor: String, itemLabel: String, target: String) -> String {
        "\(actor) отправил запрос на выдачу предмета \(itemLabel) пользователю \(target)."
    }

    static func grabApproved(actor: String, itemLabel: String) -> String {
        "\(actor) взял предмет \(itemLabel)."
    }

    static func grabRequestApproved(approver: String, requester: String, itemLabel: String) -> String {
        "\(approver) одобрил выдачу предмета \(itemLabel) пользователю \(requester)."
    }

    static func transferRequested(actor: String, itemLabel: String, target: String) -> String {
        "\(actor) отправил запрос на передачу предмета \(itemLabel) пользователю \(target)."
    }

    static func transferApproved(approver: String, itemLabel: String, sourceOwner: String, targetOwner: String) -> String {
        "\(approver) одобрил передачу предмета \(itemLabel) от \(sourceOwner) пользователю \(targetOwner)."
    }

    static func transferDirect(actor: String, itemLabel: String, target: String) -> String {
        "\(actor) передал предмет \(itemLabel) пользователю \(target)."
    }

    static func itemReturned(actor: String, itemLabel: String) -> String {
        "\(actor) вернул предмет \(itemLabel)."
    }

    static func locationChanged(actor: String, itemLabel: String, locationName: String) -> String {
        "\(actor) переместил предмет \(itemLabel) в локацию \"\(locationName)\"."
    }

    static func responsibleChanged(actor: String, itemLabel: String, oldResponsible: String, newResponsible: String) -> String {
        "\(actor) сменил материально ответственного для предмета \(itemLabel): \(oldResponsible) -> \(newResponsible)."
    }

    static func movedToBroken(
        actor: String,
        itemLabel: String,
        locationName: String,
        quantity: Int,
        reason: String?,
        notes: String?
    ) -> String {
        var parts: [String] = []
        parts.append("\(actor) переместил в брак предмет \(itemLabel)")
        parts.append("локация: \"\(locationName)\"")
        parts.append("количество: \(quantity)")
        if let reason, !reason.isEmpty {
            parts.append("причина: \(reason)")
        }
        if let notes, !notes.isEmpty {
            parts.append("примечание: \(notes)")
        }
        return parts.joined(separator: ", ") + "."
    }
}
