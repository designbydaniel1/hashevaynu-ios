import SwiftUI
import UIKit

struct MoreView: View {
    @State private var copiedZelle = false
    @Environment(ToastCenter.self) private var toasts

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LinkRow("Announcements & Schedule", detail: "Join the Hashevaynu WhatsApp group",
                            symbol: "megaphone.fill", url: Links.announcementsWhatsApp)
                    LinkRow("Daf Yomi WhatsApp", symbol: "book.pages.fill", url: Links.dafWhatsApp)
                    LinkRow("Mishnah Berurah Yomi WhatsApp", symbol: "calendar", url: Links.mishnahBerurahWhatsApp)
                } header: { Text("Announcements") } footer: {
                    Text("Schedules, events, shiurim and news are posted in the WhatsApp group.")
                }

                Section("Donate") {
                    LinkRow("Make a Donation", detail: "Opens hashevaynu.org", symbol: "heart.fill", url: Links.donate)
                    LinkRow("Donate with PayPal", symbol: "creditcard.fill", url: Links.paypal)
                    Button {
                        UIPasteboard.general.string = Links.zelleEmail
                        copiedZelle = true
                        toasts.show("Zelle email copied", symbol: "doc.on.doc.fill")
                    } label: {
                        RowLabel(title: "Donate with Zelle",
                                 detail: copiedZelle ? "Email copied" : "Tap to copy \(Links.zelleEmail)",
                                 symbol: "dollarsign.circle.fill")
                    }
                    LinkRow("Sponsor the Daf", detail: "$36/week or $100/month", symbol: "star.fill", url: Links.donate)
                    LinkRow("Dedication Opportunities", symbol: "building.columns.fill", url: Links.dedications)
                }

                Section("Contact") {
                    LinkRow("Call", detail: Links.phoneDisplay, symbol: "phone.fill", url: Links.phone)
                    LinkRow("Email", detail: Links.zelleEmail, symbol: "envelope.fill", url: Links.email)
                    LinkRow("Ask the Rabbi", symbol: "questionmark.bubble.fill", url: Links.ask)
                    LinkRow("Directions", detail: Links.address, symbol: "map.fill", url: Links.maps)
                    LinkRow("Simcha Hall Rentals", detail: Links.hallPhoneDisplay, symbol: "party.popper.fill", url: Links.hallPhone)
                }

                Section("Follow") {
                    LinkRow("YouTube", symbol: "play.rectangle.fill", url: Links.youtube)
                    LinkRow("Instagram", symbol: "camera.fill", url: Links.instagram)
                    LinkRow("SoundCloud", symbol: "cloud.fill", url: Links.soundcloud)
                    LinkRow("Spotify", symbol: "headphones", url: Links.spotify)
                    LinkRow("Apple Podcasts", symbol: "mic.fill", url: Links.applePodcasts)
                }

                Section {
                    LinkRow("About Hashevaynu", symbol: "info.circle.fill", url: Links.about)
                    LinkRow("Website", detail: "hashevaynu.org", symbol: "globe", url: Links.website)
                } footer: {
                    Text("Hashevaynu is a 501(c)(3) non-profit. Tax ID 11-3295965.")
                }
            }
            .navigationTitle("More")
            .withMiniPlayer()
        }
    }
}

private struct LinkRow: View {
    let title: String, detail: String?, symbol: String, url: URL
    init(_ title: String, detail: String? = nil, symbol: String, url: URL) {
        self.title = title; self.detail = detail; self.symbol = symbol; self.url = url
    }
    var body: some View {
        Link(destination: url) { RowLabel(title: title, detail: detail, symbol: symbol) }
    }
}

private struct RowLabel: View {
    let title: String, detail: String?, symbol: String
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 7))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).foregroundStyle(.primary)
                if let detail { SwapText(detail).font(.caption).foregroundStyle(.secondary) }
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.tertiary)
        }
    }
}
