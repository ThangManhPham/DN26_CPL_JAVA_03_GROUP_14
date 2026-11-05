import SwiftUI
import WidgetKit

private let appGroup = "group.com.ourspace.mobile"
private let latestPhotoFile = "latest-photo.jpg"

struct PhotoEntry: TimelineEntry {
  let date: Date
  let image: UIImage?
}

struct PhotoProvider: TimelineProvider {
  func placeholder(in context: Context) -> PhotoEntry {
    PhotoEntry(date: Date(), image: nil)
  }

  func getSnapshot(in context: Context, completion: @escaping (PhotoEntry) -> Void) {
    completion(PhotoEntry(date: Date(), image: loadPhoto()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<PhotoEntry>) -> Void) {
    let entry = PhotoEntry(date: Date(), image: loadPhoto())
    completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(15 * 60))))
  }

  private func loadPhoto() -> UIImage? {
    guard let container = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: appGroup
    ) else { return nil }
    return UIImage(contentsOfFile: container.appendingPathComponent(latestPhotoFile).path)
  }
}

struct OurSpaceWidgetView: View {
  let entry: PhotoEntry

  var body: some View {
    ZStack {
      Color(red: 0.99, green: 0.91, blue: 0.93)
      if let image = entry.image {
        Image(uiImage: image).resizable().scaledToFill()
      } else {
        VStack(spacing: 8) {
          Image(systemName: "heart.fill").foregroundStyle(Color(red: 0.78, green: 0.31, blue: 0.44))
          Text("Chưa có ảnh chung").font(.caption).foregroundStyle(.secondary)
        }
      }
    }
    .background(Color(red: 0.99, green: 0.91, blue: 0.93))
  }
}

struct OurSpaceWidget: Widget {
  let kind = "OurSpaceWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: PhotoProvider()) { entry in
      OurSpaceWidgetView(entry: entry)
    }
    .configurationDisplayName("OurSpace")
    .description("Khoảnh khắc mới nhất của hai bạn.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

@main
struct OurSpaceWidgetBundle: WidgetBundle {
  var body: some Widget { OurSpaceWidget() }
}
